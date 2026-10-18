#!/bin/sh
# Host-only tests for `pikofs` (no QEMU needed).
# usage: tests/test_pikofs.sh [PIKOFS] [IMAGE]
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PIKOFS=${1:-$ROOT/pikofs}
IMAGE=${2:-$ROOT/piko-piko.bin}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Layout (see type_macros.asm): slot = 32 * 1536 bytes = 96 sectors.
SECTOR=512
SLOT_SECTORS=96
SLOT_SIZE=$((SLOT_SECTORS * SECTOR))
FIRST_SLOT_OFFSET=$(((40 + 2) * SECTOR))
ROW=32
SLOT_COUNT=7

pass=0
fail=0
ok() { pass=$((pass + 1)); printf 'ok   %s\n' "$1"; }
ko() { fail=$((fail + 1)); printf 'FAIL %s\n' "$1"; }
# check NAME CMD...  -> passes when CMD succeeds
check() { name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else ko "$name"; fi; }
# check_fails NAME CMD... -> passes when CMD exits non-zero (and not by crashing)
check_fails() {
    name=$1; shift
    "$@" >/dev/null 2>"$TMP/err"; rc=$?
    if [ $rc -ne 0 ] && [ $rc -lt 128 ] && [ -s "$TMP/err" ]; then ok "$name"; else ko "$name (rc=$rc)"; fi
}

fresh() { cp "$IMAGE" "$TMP/disk.bin"; DISK=$TMP/disk.bin; }
slot_bytes() { # slot_bytes SLOT FILE -> raw slot content
    dd if="$DISK" of="$2" bs=$SECTOR skip=$((FIRST_SLOT_OFFSET / SECTOR + $1 * SLOT_SECTORS)) \
        count=$SLOT_SECTORS 2>/dev/null
}

[ -x "$PIKOFS" ] || { echo "pikofs not built: $PIKOFS"; exit 1; }
[ -f "$IMAGE" ] || { echo "image not built: $IMAGE"; exit 1; }

printf 'say n hello\n  indented\n\nlast\n' >"$TMP/in.txt"

# --- raw layout ---
fresh
"$PIKOFS" import "$DISK" 2 "$TMP/in.txt" 2>"$TMP/err" || ko "import succeeds"
slot_bytes 2 "$TMP/slot"
{
    printf '%-32s' 'say n hello'
    printf '%-32s' '  indented'
    printf '%-32s' ''
    printf '%-32s' 'last'
} >"$TMP/expect_head"
head -c 128 "$TMP/slot" >"$TMP/got_head"
check "rows are padded with spaces to 32 columns" cmp "$TMP/expect_head" "$TMP/got_head"
tail -c +129 "$TMP/slot" | tr -d ' ' | wc -c | grep -qx 0 \
    && ok "rest of the slot is blank (spaces)" || ko "rest of the slot is blank (spaces)"
[ "$(wc -c <"$TMP/slot")" -eq $SLOT_SIZE ] && ok "slot is 49152 bytes" || ko "slot is 49152 bytes"

# --- isolation ---
fresh
cp "$DISK" "$TMP/before.bin"
"$PIKOFS" import "$DISK" 2 "$TMP/in.txt" 2>/dev/null
SIZE=$(wc -c <"$DISK")
[ "$SIZE" -eq "$(wc -c <"$TMP/before.bin")" ] && ok "image size unchanged" || ko "image size unchanged"
END=$((FIRST_SLOT_OFFSET + 2 * SLOT_SIZE))
check "boot sector, kernel and slots 0-1 untouched" \
    cmp -n $END "$TMP/before.bin" "$DISK"
check "slots after the imported one untouched" \
    cmp -i $((END + SLOT_SIZE)) "$TMP/before.bin" "$DISK"

# --- export ---
fresh
"$PIKOFS" import "$DISK" 4 "$TMP/in.txt" 2>/dev/null
"$PIKOFS" export "$DISK" 4 >"$TMP/out.txt" 2>/dev/null
check "export gives back the imported text" cmp "$TMP/in.txt" "$TMP/out.txt"
"$PIKOFS" export "$DISK" 4 "$TMP/out2.txt" 2>/dev/null
check "export to a file path" cmp "$TMP/in.txt" "$TMP/out2.txt"
"$PIKOFS" export "$DISK" 0 >"$TMP/empty.txt" 2>/dev/null
[ ! -s "$TMP/empty.txt" ] && ok "export of a never-written (all NUL) slot is empty" \
    || ko "export of a never-written (all NUL) slot is empty"

# trailing blank rows dropped, inner blank rows kept, trailing spaces trimmed
fresh
printf 'a   \n\n\nb\n\n\n' >"$TMP/blanks.txt"
"$PIKOFS" import "$DISK" 1 "$TMP/blanks.txt" 2>/dev/null
"$PIKOFS" export "$DISK" 1 >"$TMP/out.txt" 2>/dev/null
printf 'a\n\n\nb\n' >"$TMP/expect.txt"
check "export trims trailing spaces and trailing blank rows" cmp "$TMP/expect.txt" "$TMP/out.txt"

# stdin / stdout and CRLF
fresh
printf 'one\r\ntwo\r\n' | "$PIKOFS" import "$DISK" 3 - 2>/dev/null
"$PIKOFS" export "$DISK" 3 - >"$TMP/out.txt" 2>/dev/null
printf 'one\ntwo\n' >"$TMP/expect.txt"
check "import from stdin, CRLF accepted" cmp "$TMP/expect.txt" "$TMP/out.txt"

# last line without newline, full-width row, overwrite shrinks
fresh
printf '12345678901234567890123456789012' >"$TMP/full.txt"
"$PIKOFS" import "$DISK" 6 "$TMP/full.txt" 2>/dev/null
"$PIKOFS" export "$DISK" 6 >"$TMP/out.txt" 2>/dev/null
printf '12345678901234567890123456789012\n' >"$TMP/expect.txt"
check "32-column row and missing final newline" cmp "$TMP/expect.txt" "$TMP/out.txt"
printf 'short\n' >"$TMP/short.txt"
"$PIKOFS" import "$DISK" 6 "$TMP/short.txt" 2>/dev/null
"$PIKOFS" export "$DISK" 6 >"$TMP/out.txt" 2>/dev/null
printf 'short\n' >"$TMP/expect.txt"
check "re-import fully replaces the old content" cmp "$TMP/expect.txt" "$TMP/out.txt"

# max rows
fresh
i=0; : >"$TMP/max.txt"
awk 'BEGIN{for(i=0;i<1536;i++) print "r" i}' >"$TMP/max.txt"
"$PIKOFS" import "$DISK" 0 "$TMP/max.txt" 2>/dev/null
"$PIKOFS" export "$DISK" 0 >"$TMP/out.txt" 2>/dev/null
check "1536 rows fit and round-trip" cmp "$TMP/max.txt" "$TMP/out.txt"

# --- info ---
fresh
"$PIKOFS" import "$DISK" 5 "$TMP/in.txt" 2>/dev/null
"$PIKOFS" info "$DISK" >"$TMP/info.txt" 2>&1
grep -q "Slots: $SLOT_COUNT" "$TMP/info.txt" && ok "info shows slot count" || ko "info shows slot count"
grep -q "^5 .*4 rows" "$TMP/info.txt" && ok "info shows used slot with row count" || ko "info shows used slot with row count"
grep -q "^0 .*empty" "$TMP/info.txt" && ok "info shows empty slot" || ko "info shows empty slot"

# --- failures must not touch the image and must explain themselves ---
fresh
cp "$DISK" "$TMP/before.bin"
printf '123456789012345678901234567890123\n' >"$TMP/wide.txt"
check_fails "line wider than 32 columns is rejected" "$PIKOFS" import "$DISK" 1 "$TMP/wide.txt"
awk 'BEGIN{for(i=0;i<1537;i++) print "x"}' >"$TMP/tall.txt"
check_fails "more than 1536 rows is rejected" "$PIKOFS" import "$DISK" 1 "$TMP/tall.txt"
printf 'bad\001byte\n' >"$TMP/ctl.txt"
check_fails "control characters are rejected" "$PIKOFS" import "$DISK" 1 "$TMP/ctl.txt"
printf 'ok\n' >"$TMP/ok.txt"
check_fails "slot out of range (import)" "$PIKOFS" import "$DISK" $SLOT_COUNT "$TMP/ok.txt"
check_fails "slot out of range (export)" "$PIKOFS" export "$DISK" $SLOT_COUNT
check_fails "slot must be a number" "$PIKOFS" export "$DISK" abc
check_fails "missing input file" "$PIKOFS" import "$DISK" 1 "$TMP/nope.txt"
check_fails "missing image" "$PIKOFS" export "$TMP/nope.bin" 1
check_fails "unknown command" "$PIKOFS" frobnicate "$DISK"
check_fails "no arguments" "$PIKOFS"
head -c 1024 "$DISK" >"$TMP/tiny.bin"
check_fails "image too small for the storage area" "$PIKOFS" export "$TMP/tiny.bin" 1
check "failed imports left the image untouched" cmp "$TMP/before.bin" "$DISK"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
