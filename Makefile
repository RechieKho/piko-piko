KERNEL_CODE_SECTOR_COUNT=20

QEMU_RAM_SIZE=256M

piko-piko.bin: kernel.bin boot.bin
	dd if=/dev/zero of=$@ bs=512 count=$$(( ${KERNEL_CODE_SECTOR_COUNT} + 3 ))
	dd if=boot.bin of=$@ bs=512 conv=notrunc
	dd if=kernel.bin of=$@ bs=512 seek=1 conv=notrunc

kernel.bin: kernel.asm \
		disk_sub.asm \
		console_sub.asm \
		print_sub.asm \
		ls8_sub.asm \
		ls16_sub.asm \
		ls32_sub.asm \
		str_sub.asm \
		basic_sub.asm \
		type_macros.asm
	nasm -dKERNEL_CODE_SECTOR_COUNT=${KERNEL_CODE_SECTOR_COUNT} -fbin $< -o $@

boot.bin: boot.asm \
		disk_sub.asm \
		console_sub.asm \
		print_sub.asm \
		ls8_sub.asm \
		ls16_sub.asm \
		type_macros.asm
	nasm -dKERNEL_CODE_SECTOR_COUNT=${KERNEL_CODE_SECTOR_COUNT} -fbin $< -o $@

dev-graphics: piko-piko.bin
	qemu-system-x86_64 \
		-m ${QEMU_RAM_SIZE} \
		-drive file=piko-piko.bin,format=raw

dev: piko-piko.bin
	qemu-system-x86_64 \
		-display curses \
		-m ${QEMU_RAM_SIZE} \
		-drive file=piko-piko.bin,format=raw

clean:
	rm -rf boot.bin kernel.bin piko-piko.bin
