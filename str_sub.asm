%ifndef _STR_SUB_ASM_
%define _STR_SUB_ASM_
; some helpful functions for (null-terminated) string operation
; check if string contains character
; si <- string
; al <- character
; cf -> set if it contains the character
str_has_char :
	pusha
	mov cl, [si]
.loop :
	cmp cl, 0
	je .no_char
	cmp cl, al
	je .has_char
	inc si
	mov cl, [si]
	jmp .loop
.no_char :
	clc
	jmp .end
.has_char :
	stc
.end :
	popa
	ret
; check is string with n length unsigned interger
; si <- string
; cx <- length
; cf -> set if it is an unsigned interger
strn_is_uint :
	pusha
	cmp cx, 0
	je .not_uint
.loop :
	mov byte al, [si]
	cmp al, '0'
	jb .not_uint
	cmp al, '9'
	ja .not_uint
	dec cx
	jnz .loop
	clc
	jmp .is_uint
.not_uint :
	stc
.is_uint :
	popa
	ret
; convert string with n length to unsigned interger
; si <- string
; cx <- length
; dx -> unsigned interger
; cf -> set if it is invalid (not unsigned int or too big)
strn_to_uint :
	push ax
	push bx
	push cx
	push si
	push di
	call strn_is_uint
	jc .invalid_uint
	xor bx, bx
	xor di, di
	add si, cx
	dec si
.char_loop :
	xor ax, ax
	mov byte al, [si]
	sub ax, '0'
	push cx
	push bx
	xor dx, dx
	mov cx, 10
.mul_loop :
	cmp bx, 0
	je .mul_loop_end
	mul cx
	dec bx
	jmp .mul_loop
.mul_loop_end :
	pop bx
	pop cx
	cmp dx, 0
	jne .invalid_uint
	add di, ax ; using di as sum temporarily because running out of register
	jc .invalid_uint
	inc bx
	dec si
	dec cx
	jnz .char_loop
	clc
	jmp .success
.invalid_uint :
	stc
.success :
	mov dx, di
	pop di
	pop si
	pop cx
	pop bx
	pop ax
	ret
; Turn uint to strn (always 5 digits)
; ax <- number
; di <- location to be written to
uint_to_strn :
	pusha
	mov cx, 5
	mov bx, 10
	add di, 4
.loop :
	xor dx, dx
	div bx
	add dl, '0'
	mov byte [di], dl
	dec di
	dec cx
	jnz .loop
	popa
	ret
%endif ; _STR_SUB_ASM_