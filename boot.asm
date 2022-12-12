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
; --- modules ---
%include "disk_sub.asm"
%include "print_sub.asm"
; --- data ---
boot_data :
.disk_read_error_c_string :
	db "Fail to read disk, error code: ", 0
; --- subroutine ---
main :
; load kernel
	mov bx, KERNEL_CODE_BEGIN_SEG
	mov es, bx
	mov al, KERNEL_CODE_SECTOR_COUNT
	mov ch, 0
	mov cl, KERNEL_CODE_BEGIN_SEC
	mov dh, 0
	mov bx, 0
	DISK_READ
	jc boot_err.read_disk_err
; jmp into kernel
	jmp KERNEL_CODE_BEGIN_SEG : 0
boot_err :
.read_disk_err :
	mov bx, boot_data.disk_read_error_c_string
	call printError
	PRINT_BYTE ah
	PRINT_CHAR '.'
.jam :
	jmp $
	times 510-($-$$) db 0
	dw 0xaa55 ; sig of bootloader, end of bootloader