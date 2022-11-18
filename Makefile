BIN_NAME:=piko-piko.bin
BOOT_NAME:=boot.bin
KERNEL_NAME:=kernel.bin
KERNEL_CODE_SECTOR_COUNT:=40
STORAGE_SECTOR_COUNT:=720

QEMU?=qemu-system-x86_64
QEMU_RAM_SIZE:=256M
QEMU_FLAGS:= -m $(QEMU_RAM_SIZE) -drive file=$(BIN_NAME),format=raw

RM?=rm
DD?=dd
FORMATTER:=python fmt.py

NASM?=nasm
NASM_DEFINES:=KERNEL_CODE_SECTOR_COUNT=$(KERNEL_CODE_SECTOR_COUNT) STORAGE_SECTOR_COUNT=$(STORAGE_SECTOR_COUNT)
NASM_FLAGS:= -f bin $(addprefix -D, $(NASM_DEFINES))

default: dev

.PHONY: \
	default \
	dev-graphics \
	dev \
	fmt \
	clean

dev: QEMU_FLAGS+= -display curses
dev: $(BIN_NAME)
	$(QEMU) $(QEMU_FLAGS)

dev-graphics: $(BIN_NAME)
	$(QEMU) $(QEMU_FLAGS)

fmt:
	$(FORMATTER) $(wildcard *.asm)

clean:
	$(RM) -rf $(BOOT_NAME) $(KERNEL_NAME) $(BIN_NAME)

$(BIN_NAME): $(KERNEL_NAME) $(BOOT_NAME)
	$(DD) if=/dev/zero of=$@ bs=512 count=$$(( $(STORAGE_SECTOR_COUNT) + $(KERNEL_CODE_SECTOR_COUNT) + 1 ))
	$(DD) if=boot.bin of=$@ bs=512 conv=notrunc
	$(DD) if=kernel.bin of=$@ bs=512 seek=1 conv=notrunc

$(KERNEL_NAME): kernel.asm $(wildcard *_sub.asm) $(wildcard *_macro.asm)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BOOT_NAME): boot.asm disk_sub.asm print_sub.asm type_macros.asm
	$(NASM) $(NASM_FLAGS) $< -o $@
