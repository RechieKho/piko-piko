/* pikofs - import/export text files into/out of a Piko-piko disk image.
 *
 * A Piko-piko "file" is a slot in the image's storage area holding one buffer:
 * BUFFER_HEIGHT rows of BUFFER_WIDTH characters (rows are space padded and each
 * row is a command). `save n` / `load n` in the OS copy a buffer to/from slot n.
 * This tool does the same from the host: one text line <-> one row.
 *
 * The geometry mirrors type_macros.asm; the Makefile passes the same values to
 * nasm and to this program, and tests/test_qemu.py checks them against the OS.
 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SECTOR_SIZE 512L
#ifndef KERNEL_CODE_SECTOR_COUNT
#define KERNEL_CODE_SECTOR_COUNT 40
#endif
#ifndef STORAGE_SECTOR_COUNT
#define STORAGE_SECTOR_COUNT 720
#endif
#define BUFFER_WIDTH 32L
#define BUFFER_HEIGHT 1536L

#define BUFFER_SIZE (BUFFER_WIDTH * BUFFER_HEIGHT)
#define BUFFER_SEC_COUNT (BUFFER_SIZE / SECTOR_SIZE)
/* boot sector (LBA 0), then the kernel, then storage (STORAGE_BEGIN_SEC). */
#define STORAGE_BEGIN_SEC (KERNEL_CODE_SECTOR_COUNT + 2L)
#define FILE_COUNT ((STORAGE_SECTOR_COUNT * SECTOR_SIZE) / BUFFER_SIZE)

#define PROG "pikofs"

static void usage(FILE *out)
{
	fprintf(out,
		"usage: " PROG " info   IMAGE\n"
		"       " PROG " import IMAGE SLOT [FILE|-]\n"
		"       " PROG " export IMAGE SLOT [FILE|-]\n"
		"\n"
		"  SLOT is the file number used by `load`/`save` (0-%ld).\n"
		"  import: each line of FILE (default stdin) becomes a %ld column row.\n"
		"  export: rows are written as lines (default stdout), trailing blanks trimmed.\n",
		FILE_COUNT - 1, BUFFER_WIDTH);
}

static int fail(const char *what, const char *name)
{
	if (errno)
		fprintf(stderr, PROG ": %s%s%s: %s\n", what, name ? " " : "", name ? name : "", strerror(errno));
	else
		fprintf(stderr, PROG ": %s%s%s\n", what, name ? " " : "", name ? name : "");
	return 1;
}

static int parse_slot(const char *text, long *slot)
{
	char *end;
	errno = 0;
	long value = strtol(text, &end, 10);
	if (*text == '\0' || *end != '\0' || errno || value < 0) {
		errno = 0;
		fprintf(stderr, PROG ": invalid slot '%s' (expected a number)\n", text);
		return 1;
	}
	if (value >= FILE_COUNT) {
		fprintf(stderr, PROG ": slot %ld out of range (0-%ld)\n", value, FILE_COUNT - 1);
		return 1;
	}
	*slot = value;
	return 0;
}

static long slot_offset(long slot)
{
	return (STORAGE_BEGIN_SEC + slot * BUFFER_SEC_COUNT) * SECTOR_SIZE;
}

/* Open the image and check that `slot` lies inside it. */
static FILE *open_image(const char *image, const char *mode, long slot)
{
	FILE *fp = fopen(image, mode);
	if (!fp) {
		fail("cannot open", image);
		return NULL;
	}
	if (fseek(fp, 0, SEEK_END) != 0) {
		fail("cannot seek in", image);
		fclose(fp);
		return NULL;
	}
	long size = ftell(fp);
	if (size < slot_offset(slot) + BUFFER_SIZE) {
		errno = 0;
		fprintf(stderr, PROG ": %s is too small (%ld bytes) to hold slot %ld; is it a piko-piko image?\n",
			image, size, slot);
		fclose(fp);
		return NULL;
	}
	return fp;
}

static int read_slot(FILE *fp, const char *image, long slot, unsigned char *buf)
{
	if (fseek(fp, slot_offset(slot), SEEK_SET) != 0 || fread(buf, 1, BUFFER_SIZE, fp) != (size_t)BUFFER_SIZE)
		return fail("cannot read", image);
	return 0;
}

static int blank(unsigned char c)
{
	return c == ' ' || c == '\0';
}

/* Length of the row once trailing blanks are dropped. */
static long row_length(const unsigned char *row)
{
	long len = BUFFER_WIDTH;
	while (len > 0 && blank(row[len - 1]))
		len--;
	return len;
}

/* Number of rows up to and including the last one with content. */
static long used_rows(const unsigned char *buf)
{
	long rows = BUFFER_HEIGHT;
	while (rows > 0 && row_length(buf + (rows - 1) * BUFFER_WIDTH) == 0)
		rows--;
	return rows;
}

static int cmd_info(const char *image)
{
	unsigned char *buf = malloc(BUFFER_SIZE);
	if (!buf)
		return fail("out of memory", NULL);
	FILE *fp = open_image(image, "rb", FILE_COUNT - 1);
	if (!fp) {
		free(buf);
		return 1;
	}
	printf("Image: %s\nSlots: %ld\nSlot size: %ld columns * %ld rows\n", image, FILE_COUNT, BUFFER_WIDTH,
	       BUFFER_HEIGHT);
	int rc = 0;
	for (long slot = 0; slot < FILE_COUNT && !rc; slot++) {
		rc = read_slot(fp, image, slot, buf);
		if (rc)
			break;
		long rows = used_rows(buf);
		if (rows)
			printf("%ld  offset 0x%06lx  %ld rows\n", slot, slot_offset(slot), rows);
		else
			printf("%ld  offset 0x%06lx  empty\n", slot, slot_offset(slot));
	}
	fclose(fp);
	free(buf);
	return rc;
}

static int cmd_import(const char *image, long slot, const char *input)
{
	int use_stdin = input == NULL || strcmp(input, "-") == 0;
	FILE *in = use_stdin ? stdin : fopen(input, "rb");
	if (!in)
		return fail("cannot open", input);
	unsigned char *buf = malloc(BUFFER_SIZE);
	if (!buf) {
		if (!use_stdin)
			fclose(in);
		return fail("out of memory", NULL);
	}
	memset(buf, ' ', BUFFER_SIZE);

	/* Parse everything first so a bad input never leaves a half-written slot. */
	const char *name = use_stdin ? "<stdin>" : input;
	long row = 0, col = 0, line = 1;
	int rc = 0, c;
	while (!rc && (c = getc(in)) != EOF) {
		if (c == '\n') {
			row++;
			col = 0;
			line++;
			continue;
		}
		if (c == '\r') {
			int next = getc(in);
			ungetc(next, in);
			if (next == '\n' || next == EOF)
				continue;
		}
		if (c < 0x20 || c > 0x7e) {
			errno = 0;
			fprintf(stderr, PROG ": %s:%ld: unsupported character 0x%02x (only printable ASCII)\n", name, line,
				c);
			rc = 1;
		} else if (row >= BUFFER_HEIGHT) {
			errno = 0;
			fprintf(stderr, PROG ": %s:%ld: too many lines (a file holds %ld rows)\n", name, line,
				BUFFER_HEIGHT);
			rc = 1;
		} else if (col >= BUFFER_WIDTH) {
			errno = 0;
			fprintf(stderr, PROG ": %s:%ld: line longer than %ld columns\n", name, line, BUFFER_WIDTH);
			rc = 1;
		} else {
			buf[row * BUFFER_WIDTH + col++] = (unsigned char)c;
		}
	}
	if (!rc && ferror(in))
		rc = fail("cannot read", name);
	if (!use_stdin)
		fclose(in);

	if (!rc) {
		FILE *fp = open_image(image, "r+b", slot);
		if (!fp) {
			rc = 1;
		} else {
			if (fseek(fp, slot_offset(slot), SEEK_SET) != 0 || fwrite(buf, 1, BUFFER_SIZE, fp) != (size_t)BUFFER_SIZE)
				rc = fail("cannot write", image);
			if (fclose(fp) != 0 && !rc)
				rc = fail("cannot write", image);
		}
	}
	free(buf);
	return rc;
}

static int cmd_export(const char *image, long slot, const char *output)
{
	unsigned char *buf = malloc(BUFFER_SIZE);
	if (!buf)
		return fail("out of memory", NULL);
	FILE *fp = open_image(image, "rb", slot);
	if (!fp) {
		free(buf);
		return 1;
	}
	int rc = read_slot(fp, image, slot, buf);
	fclose(fp);
	if (rc) {
		free(buf);
		return rc;
	}

	int use_stdout = output == NULL || strcmp(output, "-") == 0;
	FILE *out = use_stdout ? stdout : fopen(output, "wb");
	if (!out) {
		free(buf);
		return fail("cannot open", output);
	}
	long rows = used_rows(buf);
	for (long r = 0; r < rows; r++) {
		const unsigned char *line = buf + r * BUFFER_WIDTH;
		long len = row_length(line);
		for (long i = 0; i < len; i++)
			putc(line[i] == '\0' ? ' ' : line[i], out);
		putc('\n', out);
	}
	if (fflush(out) != 0 || ferror(out))
		rc = fail("cannot write", use_stdout ? "<stdout>" : output);
	if (!use_stdout && fclose(out) != 0 && !rc)
		rc = fail("cannot write", output);
	free(buf);
	return rc;
}

int main(int argc, char **argv)
{
	if (argc < 2) {
		usage(stderr);
		return 2;
	}
	const char *cmd = argv[1];
	if (strcmp(cmd, "-h") == 0 || strcmp(cmd, "--help") == 0 || strcmp(cmd, "help") == 0) {
		usage(stdout);
		return 0;
	}
	long slot = 0;
	if (strcmp(cmd, "info") == 0 && argc == 3)
		return cmd_info(argv[2]);
	if ((strcmp(cmd, "import") == 0 || strcmp(cmd, "export") == 0) && (argc == 4 || argc == 5)) {
		if (parse_slot(argv[3], &slot))
			return 1;
		const char *file = argc == 5 ? argv[4] : NULL;
		return cmd[0] == 'i' ? cmd_import(argv[2], slot, file) : cmd_export(argv[2], slot, file);
	}
	fprintf(stderr, PROG ": %s\n\n", strcmp(cmd, "info") && strcmp(cmd, "import") && strcmp(cmd, "export")
					      ? "unknown command"
					      : "wrong number of arguments");
	usage(stderr);
	return 2;
}
