%ifndef _STORAGE_SUB_ASM_
%define _STORAGE_SUB_ASM_
; --- modules ---
%include "disk_sub.asm"
; --- macros ---
%define MAX_SEC_PER_OP 128 ; max sector per operation
%define MAX_TRY_PER_OP 5
; %1 <- drive number
%macro STORAGE_SET_DRIVE 1
	mov byte [storage_data.drive_number], %1
%endmacro
; Read sectors & ensure data intergrity
; al <- number of sectors {max 128}
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- starting head on disk
; es <- data buffer for loaded data
; cf -> set on fail
%macro STORAGE_DISK_READ 0
	pusha
	push es
	mov byte dl, [storage_data.drive_number]
	movzx si, al ; si = last sector count requested
	mov di, MAX_TRY_PER_OP ; di = try count
	xor bx, bx
%%loop :
	DISK_READ
	jnc %%success
	xor ah, ah ; ax/al = number of sectors read
	pusha
	mov dl, 20 ; 512 >> 4
	mul dl
	mov bx, es
	add bx, ax
	mov es, bx
	popa
	ror cx, 5
	add cx, ax
	rol cx, 5
	adc dh, 0
	sub si, ax
	mov ax, si
	dec di
	jz %%fail
	cmp al, 0
	jne %%loop
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
.drive_number :
	db 0
; --- subroutine ---
; Read sectors into memory
; ax <- number of sectors
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- starting head on disk
; es <- data buffer for loaded data
; cf -> set on fail
storage_read :
	pusha
	push es
	push dx
	mov dl, MAX_SEC_PER_OP
	div dl
	pop dx
	xchg al, ah ; ah = number of 128 sectors ; al = number of sectors
.loop :
	cmp ah, 0
	je .loop_end
	push ax
	mov al, MAX_SEC_PER_OP
	STORAGE_DISK_READ
	pop ax
	jc .fail
	dec ah
; add cx, MAX_SEC_PER_OP
	push ax
	ror cx, 5
	add cx, MAX_SEC_PER_OP
	rol cx, 5
	adc dh, 0
	pop ax
	mov bx, es
	add bx, (MAX_SEC_PER_OP >> 4)
	mov es, bx
	mov bx, (MAX_SEC_PER_OP & 0x0f) ; digits that are shifted out
	jmp .loop
.loop_end :
	clc
	cmp al, 0
	je .success
	STORAGE_DISK_READ
	jc .fail
.success :
	clc
	jmp .end
.fail :
	stc
.end :
	pop es
	popa
	ret
%endif ; _STORAGE_SUB_ASM_
