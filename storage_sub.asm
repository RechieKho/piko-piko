%ifndef _STORAGE_SUB_ASM_
%define _STORAGE_SUB_ASM_
; --- modules ---
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
	mov byte [storage_data.head_last_idx], dh
	mov word [storage_data.cylinder_sector_last_idx], cx
	jmp %%end
%%fail :
	mov byte [storage_data.initialized], 0
%%end :
	popa
%endmacro
; Read sectors & ensure data intergrity
; al <- number of sectors {max 128}
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- starting head on disk
; es : bx <- data buffer for loaded data
; cf -> set on fail
%macro STORAGE_DISK_READ 0
	pusha
	push es
	mov byte dl, [storage_data.initialized]
	cmp dl, 0
	je %%fail
	mov byte dl, [storage_data.drive_number]
	movzx si, al ; si = last sector count requested
	mov di, MAX_TRY_PER_OP ; di = try count
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
	call storage_add_chs
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
; Write sectors & ensure data intergrity
; al <- number of sectors {max 128}
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- starting head on disk
; es : bx <- data to be written on disk
; cf -> set on fail
%macro STORAGE_DISK_WRITE 0
	pusha
	push es
	mov byte dl, [storage_data.initialized]
	cmp dl, 0
	je %%fail
	mov byte dl, [storage_data.drive_number]
	movzx si, al ; si = last sector count requested
	mov di, MAX_TRY_PER_OP ; di = try count
%%loop :
	DISK_WRITE
	jnc %%success
	xor ah, ah ; ax/al = number of sectors written
	pusha
	mov dl, 20 ; 512 >> 4
	mul dl
	mov bx, es
	add bx, ax
	mov es, bx
	popa
	call storage_add_chs
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
.initialized :
	db 0 ; 0 if false, else true
.drive_number :
	db 0
.head_last_idx :
	db 0
.cylinder_sector_last_idx :
	dw 0
; --- subroutine ---
; Read sectors into memory
; ax <- number of sectors
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- starting head on disk
; es : bx <- data buffer for loaded data
; cf -> set on fail
storage_read :
	pusha
	push es
	mov byte dl, [storage_data.initialized]
	cmp dl, 0
	je .fail
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
	push ax
	mov ax, MAX_SEC_PER_OP
	call storage_add_chs
	pop ax
	jc .fail
	mov bx, es
	add bx, ((MAX_SEC_PER_OP * 512) >> 4)
	mov es, bx
	mov bx, ((MAX_SEC_PER_OP * 512) & 0x0f) ; digits that are shifted out
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
; write sectors into disk
; al <- number of sectors to write (nonzero, max 128)
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- head number
; dl <- drive number
; es : bx <- data to be written on disk
; cf -> set on fail
storage_write :
	pusha
	push es
	mov byte dl, [storage_data.initialized]
	cmp dl, 0
	je .fail
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
	STORAGE_DISK_WRITE
	pop ax
	jc .fail
	dec ah
	push ax
	mov ax, MAX_SEC_PER_OP
	call storage_add_chs
	pop ax
	jc .fail
	mov bx, es
	add bx, ((MAX_SEC_PER_OP * 512) >> 4)
	mov es, bx
	mov bx, ((MAX_SEC_PER_OP * 512) & 0x0f) ; digits that are shifted out
	jmp .loop
.loop_end :
	clc
	cmp al, 0
	je .success
	STORAGE_DISK_WRITE
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
; Add to CHS address
; ax -> value added
; cx <- cylinder sector
; dh <- head
; cx -> new cylinder sector
; dh -> new head
; cf -> set if fail
storage_add_chs :
	push ax
	push bx
	mov byte bl, [storage_data.initialized]
	cmp bl, 0
	je .fail
	mov word bx, [storage_data.cylinder_sector_last_idx]
	and bx, 111111b
	inc bx ; bx/bl = sector per track
	push dx
	mov dx, cx
	and dx, 111111b ; dx/dl = currect sector
	add dx, ax
	mov ax, dx
	pop dx
	div bl ; ah = new sector ; al = cylinder to be added
	mov word bx, [storage_data.cylinder_sector_last_idx]
	and bx, 1111111111000000b
	ror bx, 8
	inc bx ; bx = cylinder count
	push dx
	mov dx, cx
	and dx, 1111111111000000b
	ror dx, 8
	movzx cx, ah ; cx = new sector
	xor ah, ah
	add ax, dx ; ax = new cylinder
	pop dx
.subtract_loop :
	cmp ax, bx
	jl .subtract_loop_end
	sub ax, bx
	inc dh
	jmp .subtract_loop
.subtract_loop_end :
	mov bh, [storage_data.head_last_idx]
	cmp dh, bh
	ja .fail
.success :
	rol ax, 8
	or cx, ax
	clc
	jmp .end
.fail :
	stc
.end :
	pop bx
	pop ax
	ret
%endif ; _STORAGE_SUB_ASM_