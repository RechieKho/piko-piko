BIN_NAME:=piko-piko.bin
BOOT_NAME:=boot.bin
KERNEL_NAME:=kernel.bin
KERNEL_CODE_SECTOR_COUNT:=40
STORAGE_SECTOR_COUNT:=720
VERSION_MAJOR:='"1"'
VERSION_MINOR:='"0"'
VERSION_PATCH:='"0"'

QEMU?=qemu-system-x86_64
QEMU_RAM_SIZE:=256M
QEMU_HD_CYLINDER_COUNT:=1024
QEMU_HD_HEAD_COUNT:=16
QEMU_HD_SECTOR_COUNT:=63
QEMU_FLAGS:= -m $(QEMU_RAM_SIZE) -drive if=none,id=disk,file=$(BIN_NAME),format=raw -device ide-hd,drive=disk,cyls=$(QEMU_HD_CYLINDER_COUNT),heads=$(QEMU_HD_HEAD_COUNT),secs=$(QEMU_HD_SECTOR_COUNT)

RM?=rm
DD?=dd
FORMATTER:=python3 fmt.py

NASM?=nasm
NASM_DEFINES:=KERNEL_CODE_SECTOR_COUNT=$(KERNEL_CODE_SECTOR_COUNT) STORAGE_SECTOR_COUNT=$(STORAGE_SECTOR_COUNT) VERSION_MAJOR=$(VERSION_MAJOR) VERSION_MINOR=$(VERSION_MINOR) VERSION_PATCH=$(VERSION_PATCH)
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
	$(FORMATTER) $(wildcard *.asm) $(wildcard commands/*.asm) $(wildcard commands/meta/*.asm)

clean:
	$(RM) -rf $(BOOT_NAME) $(KERNEL_NAME) $(BIN_NAME)

$(BIN_NAME): $(KERNEL_NAME) $(BOOT_NAME)
	$(DD) if=/dev/zero of=$@ bs=512 count=$$(( $(STORAGE_SECTOR_COUNT) + $(KERNEL_CODE_SECTOR_COUNT) + 1 ))
	$(DD) if=boot.bin of=$@ bs=512 conv=notrunc
	$(DD) if=kernel.bin of=$@ bs=512 seek=1 conv=notrunc

$(KERNEL_NAME): kernel.asm $(wildcard *.asm) $(wildcard commands/*.asm) $(wildcard commands/meta/*.asm)
	$(NASM) $(NASM_FLAGS) $< -o $@

$(BOOT_NAME): boot.asm disk_sub.asm print_sub.asm type_macros.asm
	$(NASM) $(NASM_FLAGS) $< -o $@
