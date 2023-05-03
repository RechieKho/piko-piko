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
	mov dl, 20 ; SECTOR_SIZE >> 4
	mul dl
	mov bx, es
	add bx, ax
	mov es, bx
	popa
	call storageAddCHS_v2
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
	mov dl, 20 ; SECTOR_SIZE >> 4
	mul dl
	mov bx, es
	add bx, ax
	mov es, bx
	popa
	call storageAddCHS_v2
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
.head_count : ; from 0 to 255
	db 0
.cylinder_count : ; from 0 to 1024
	dw 0
.sector_count : ; from 1 to 63
	db 0
; --- subroutine ---
; Read sectors into memory
; ax <- number of sectors
; ch <- low eight bits of cylinder number
; cl <- sector number (1-63 bits 0-5)
; dh <- starting head on disk
; es : bx <- data buffer for loaded data
; cf -> set on fail
storageRead :
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
	call storageAddCHS_v2
	pop ax
	jc .fail
	mov bx, es
	add bx, ((MAX_SEC_PER_OP * SECTOR_SIZE) >> 4)
	mov es, bx
	mov bx, ((MAX_SEC_PER_OP * SECTOR_SIZE) & 0x0f) ; digits that are shifted out
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
storageWrite :
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
	call storageAddCHS_v2
	pop ax
	jc .fail
	mov bx, es
	add bx, ((MAX_SEC_PER_OP * SECTOR_SIZE) >> 4)
	mov es, bx
	mov bx, ((MAX_SEC_PER_OP * SECTOR_SIZE) & 0x0f) ; digits that are shifted out
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
storageAddCHS :
	push ax
	push bx
	mov byte bl, [storage_data.initialized]
	cmp bl, 0
	je .fail
	xor bx, bx
	mov byte bl, [storage_data.sector_count] ; bx/bl = sector per track
	push dx
	mov dx, cx
	and dx, 0x3f ; dx/dl = currect sector
	add dx, ax
	mov ax, dx
	pop dx
	div bl ; ah = new sector ; al = cylinder to be added
	mov word bx, [storage_data.cylinder_count] ; bx = cylinder count
	push dx
	mov dx, cx
	and dx, 0xffc0
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
	mov bh, [storage_data.head_count]
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
; Add to CHS address
; S < H < C
; ax -> value added
; cx <- cylinder sector
; dh <- head
; cx -> new cylinder sector
; dh -> new head
; cf -> set if fail
storageAddCHS_v2 :
    push bx
    push ax
	mov byte bl, [storage_data.initialized]
	cmp bl, 0
	je .fail
	mov byte bl, [storage_data.sector_count] ; bx/bl = sector per track
    push dx
    mov dx, cx
	and dx, 0x3f ; dx/dl = currect sector
    add ax, dx
    pop dx
	div bl ; ah = new sector ; al = head to be added
    add dh, al
    mov byte bl, [storage_data.head_count]
    push ax
    movzx ax, dh
    div bl
    mov dx, ax ; dh = new head ; dl = cylinder to be added
    pop ax
    push ax
    mov ax, cx
	and ax, 0xffc0
	ror ax, 8
    movzx bx, dl
    add ax, bx
    mov cx, ax
    pop ax
    mov word bx, [storage_data.cylinder_count]
    cmp cx, bx
    jae .fail
    rol cx, 8
    xor al, al
    shr ax, 8
    or cx, ax
    clc
    jmp .end
.fail:
    stc
.end:
    pop ax
    pop bx
    ret
%endif ; _STORAGE_SUB_ASM_
