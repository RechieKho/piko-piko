BIN_NAME:=piko-piko.bin
BOOT_NAME:=boot.bin
KERNEL_NAME:=kernel.bin

QEMU?=qemu-system-x86_64
QEMU_RAM_SIZE:=256M
QEMU_FLAGS:= -m $(QEMU_RAM_SIZE) -drive file=$(BIN_NAME),format=raw

RM?=rm
DD?=dd
NASM?=nasm
FORMATTER:=python fmt.py

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
	$(DD) if=/dev/zero of=$@ bs=512 count=$$(( $(KERNEL_CODE_SECTOR_COUNT) + 3 ))
	$(DD) if=boot.bin of=$@ bs=512 conv=notrunc
	$(DD) if=kernel.bin of=$@ bs=512 seek=1 conv=notrunc

$(KERNEL_NAME): kernel.asm $(wildcard *_sub.asm) $(wildcard *_macro.asm)
	$(NASM) -fbin $< -o $@

$(BOOT_NAME): boot.asm disk_sub.asm print_sub.asm type_macros.asm
	$(NASM) -fbin $< -o $@
