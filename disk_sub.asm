%ifndef _DISK_SUB_ASM_
%define _DISK_SUB_ASM_
[bits 16]
; --- data ---
disk_sub_data :
	.read_disk_err : db "Fail to read disk, error code: " , 0
	.write_disk_err : db "Fail to write disk, error cord: " , 0
; --- macros ---
; --- subroutines ---
%include "print_sub.asm"
; read sectors into memory
; al <- number of sectors to read (nonzero)
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; dl <- drive number
; es : bx <- data buffer for loaded data
read_disk :
	pusha
	mov ah, 0x02
	int 0x13
	jc .err
	popa
	ret
.err :
	mov bx, disk_sub_data.read_disk_err
	call print_err
	PRINT_BYTE ah
	PRINT_CHAR '.'
	PRINT_NL
	jmp $
; write sectors into disk
; al <- number of sectors to write (nonzero)
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; dl <- drive number
; es : bx <- data to be written on disk
write_disk :
	pusha
	mov ah, 0x03
	int 0x13
	jc .err
	popa
	ret
.err :
	mov bx, disk_sub_data.write_disk_err
	call print_err
	mov bl, ah
	PRINT_BYTE ah
	PRINT_CHAR '.'
	PRINT_NL
	jmp $
%endif ; _DISK_SUB_ASM_