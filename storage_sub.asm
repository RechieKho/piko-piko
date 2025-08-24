%ifndef _STORAGE_SUB_ASM_
%define _STORAGE_SUB_ASM_
; --- modules ---
%include "type_macros.asm"
%include "disk_sub.asm"
; --- macros ---
%define MAX_SEC_PER_OP 128 ; max sector per operation
%define MAX_TRY_PER_OP 5
; Set and initialize drive
; dl <- drive number
%macro STORAGE_SET_DRIVE 0
	pusha
	mov byte [storage_data.drive_number], dl
	push es
	mov ah, 0x08
	xor di, di
	mov es, di
	int 0x13
	pop es
	jc %%fail
	mov byte [storage_data.initialized], 1
	inc dh
	mov byte [storage_data.head_count], dh
	mov bx, cx
	and bl, 0x3f
	mov byte [storage_data.sector_count], bl
	mov bx, cx
	and bx, 0xffc0
	ror bx, 8
	inc bx
	mov word [storage_data.cylinder_count], bx
	jmp %%end
%%fail :
	mov byte [storage_data.initialized], 0
%%end :
	popa
%endmacro
; Read sectors from storage
; al <- number of sectors {max 128}
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; es : bx <- data buffer for loaded data
; cf -> set on fail
%macro STORAGE_DISK_READ 0
	pusha
	mov byte dl, [storage_data.initialized]
	cmp dl, 0
	je %%fail
	mov byte dl, [storage_data.drive_number]
	DISK_READ
	jc %%fail
%%success :
	clc
	jmp %%end
%%fail :
	PRINT_BYTE ah
	PRINT_NL
	stc
%%end :
	popa
%endmacro
; Write sectors to storage
; al <- number of sectors {max 128}
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; es : bx <- data to be written on disk
; cf -> set on fail
%macro STORAGE_DISK_WRITE 0
	pusha
	push es
	mov byte dl, [storage_data.initialized]
	cmp dl, 0
	je %%fail
	mov byte dl, [storage_data.drive_number]
	DISK_WRITE
	jc %%fail
%%success :
	clc
	jmp %%end
%%fail :
	stc
%%end :
	pop es
	popa
%endmacro
; --- data ---
storage_data :
.initialized :
	db 0 ; 0 if false, else true
.drive_number :
	db 0
.head_count :
	db 0
.cylinder_count :
	dw 0
.sector_count :
	db 0
; --- subroutine ---
; Linear Indexing (LBA) to CHS
; ax <- index
; ch -> low eight bits of cylinder number
; cl -> sector number
; dh -> head number
; cf -> set on fail
storageToCHS :
	push ax
	push bx
	push si
	mov si, ax
	mov byte bl, [storage_data.sector_count] ; bl = sector count (sector per track)
	div bl ; ah = raw sector number (remainder) ; al = raw head number (quotient)
	mov cl, ah
	add cl, 1 ; cl = sector number
	xor ah, ah ; ax/al = raw head number
	mov byte bl, [storage_data.head_count] ; bl = head count (head per cylinder)
	div bl ; ah = head count (remainder)
	mov dh, ah ; dh = head count
	mov byte al, [storage_data.sector_count] ; al = sector count (sector per track)
	mul bl
	mov bx, ax ; bx = head count * sector count
	mov ax, si ; ax = index
	push dx
	xor dx, dx
	div bx ; ax = cylinder number
	pop dx
	mov word bx, [storage_data.cylinder_count]
	cmp ax, bx
	ja .fail
.success :
	clc
	jmp .end
.fail :
	stc
.end :
	pop si
	pop bx
	pop ax
	ret
%endif ; _STORAGE_SUB_ASM_