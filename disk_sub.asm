%ifndef _DISK_SUB_ASM_
%define _DISK_SUB_ASM_
[bits 16]
; --- modules ---
%include "print_sub.asm"
; --- macros ---
; read sectors into memory
; al <- number of sectors to read (nonzero)
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; dl <- drive number
; es : bx <- data buffer for loaded data
; ah -> error code
; cf -> set on fail
%macro DISK_READ 0
	mov ah, 0x02
	int 0x13
%endmacro
; write sectors into disk
; al <- number of sectors to write (nonzero)
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; dl <- drive number
; es : bx <- data to be written on disk
; ah -> error code
; cf -> set on fail
%macro DISK_WRITE 0
	mov ah, 0x03
	int 0x13
%endmacro
; --- data ---
disk_data :
	.disk_read_err_str : db "Fail to read disk, error code: ", 0
	.disk_write_err_str : db "Fail to write disk, error code: ", 0
%endif ; _DISK_SUB_ASM_