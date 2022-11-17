[bits 16]
[org 0]
%include "type_macros.asm"
; setup segment
	mov bx, 0x7c0
	mov ds, bx
; setup stack with 1024 bytes
	mov ss, bx
	mov bp, FREE_BEGIN + 1024
	mov sp, bp
	jmp main
; --- subroutine ---
%include "disk_sub.asm"
main :
; load kernel
	mov bx, KERNEL_CODE_BEGIN_SEG
	mov es, bx
	mov al, KERNEL_CODE_SECTOR_COUNT
	mov ch, 0
	mov cl, 0x02 ; right after boot sector
	mov dh, 0
	mov bx, 0
	DISK_READ
	jc boot_err.read_disk_err
; jmp into kernel
	jmp KERNEL_CODE_BEGIN_SEG : 0
	times 510-($-$$) db 0
	dw 0xaa55 ; sig of bootloader, end of bootloader
boot_err :
.read_disk_err :
	mov bx, disk_data.disk_read_err_str
	call print_err
	PRINT_BYTE ah
	PRINT_CHAR '.'
.jam :
	jmp $