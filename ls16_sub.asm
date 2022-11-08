%ifndef _LS16_SUB_ASM_
%define _LS16_SUB_ASM_
; ls16 - list of 16 bits
; structure diagram :
; | max (1B) | count (1B) | elements (2B each element) |
; --- modules ---
%include "print_sub.asm"
%include "ls8_sub.asm"
; --- macros ---
%define LS16_MAX 0xff
; initialize ls16
; %1 <- max count of the element (excluding the header) {1B, !di}
; di <- address of ls16
%macro LS16_INIT 0-1 LS16_MAX
	push di
	mov byte [di], %1
	inc di
	mov byte [di], 0
	pop di
%endmacro
; get info from ls16
; si <- address of ls16
; cl -> max count of ls16
; ch -> count of ls16
%define LS16_GET_INFO mov word cx, [si]
; get count of ls16
; si <- address of ls16
; cx -> count of ls16
%macro LS16_GET_COUNT 0
	push ax
	LS16_GET_INFO
	movzx ax, ch
	mov cx, ax ; cx = count
	pop ax
%endmacro
; clear ls16
; si <- address of ls16
%macro LS16_CLEAR 0
	pusha
	LS16_GET_INFO
	mov ch, 0
	mov word [si], cx
	popa
%endmacro
; append to ls16
; %1 <- element to be appended {2B, !ax}
; si <- address of ls16
%macro LS16_APPEND 1
	pusha
	inc si
	mov byte dh, [si]
	dec si
	mov ax, %1
	call ls16_insert
	popa
%endmacro
; prepend to ls16
; %1 <- element to be prepend {2B, !ax}
; si <- address of ls16
%macro LS16_PREPEND 1
	pusha
	mov ax, %1
	mov dh, 0
	call ls16_insert
	popa
%endmacro
; pop last element of ls16
; si <- address of ls16
%macro LS16_POP_LAST 0
	pusha
	inc si
	mov byte dh, [si]
	dec dh
	dec si
	call ls16_erase
	popa
%endmacro
; pop first element of ls16
; si <- address of ls16
%macro LS16_POP_FIRST 0
	pusha
	mov dh, 0
	call ls16_erase
	popa
%endmacro
; --- subroutine ---
; check whether ls16s are equal
; si <- address of first ls16
; di <- address of second ls16
; cf -> set if ls16s are not equal
ls16_equal :
	pusha
	mov word cx, [si] ; cl = max ; ch = count
	mov word dx, [di] ; dl = max ; dh = count
	cmp dh, ch
	jne .not_equal
	movzx cx, dh ; cx = count of both ls16
	add si, 2 ; displace to the element
	add di, 2 ; displace to the element
.loop :
	cmp cx, 0
	je .equal
	mov word ax, [si]
	mov word bx, [di]
	cmp ax, bx
	jne .not_equal
	add si, 2
	add di, 2
	dec cx
	jmp .loop
.equal :
	clc
	jmp .end
.not_equal :
	stc
.end :
	popa
	ret
; erase element from ls16
; dh <- index of the element to be erased
; si <- address of ls16 header
; cf -> set if element fail to be inserted (either ls16 is empty or ah (index) is invalid)
ls16_erase :
	pusha
	LS16_GET_INFO ; cl = max ; ch = count
; check validity
	cmp ch, 0
	je .empty_err ; empty element, not entertained
	cmp dh, ch
	jae .invalid_index_err
; displace elements backward
	pusha ; > START DISPLACE <
	add si, 4
	movzx ax, dh
	shl ax, 1
	add si, ax ; si = address right after element to be erased
	mov di, si
	sub di, 2 ; di = address of element to be erased
	sub ch, dh
	dec ch
	movzx ax, ch
	mov cx, ax ; cx = number of element to be displaced
	mov ax, ds
	mov es, ax
	cld
	rep movsw
	popa ; > STOP DISPLACE <
; update state
	dec ch
	inc si
	mov byte [si], ch
	clc
	jmp .success
.empty_err :
.invalid_index_err :
	stc
.success :
	popa
	ret
; insert element to ls16
; ax <- element to be inserted
; dh <- index of the element to be inserted
; si <- address of ls16 header
; cf -> set if element fail to be inserted (either ls16 is full or ah (index) is invalid)
ls16_insert :
	pusha
	LS16_GET_INFO ; cl = max ; ch = count
	cmp ch, cl
	jae .max_err ; already max out
	cmp dh, ch
	ja .invalid_index_err ; index is bigger than the count
; displace element forward
	pusha ; > START DISPLACE <
	movzx bx, ch
	shl bx, 1
	add si, bx ; si = address of end of ls16
	mov di, si
	add di, 2 ; di = address right after end of ls16
	sub ch, dh
	movzx bx, ch
	mov cx, bx ; cx = number of elements to be displaced
	mov bx, ds
	mov es, bx
	std
	rep movsw
	cld
	popa ; > END DISPLACE <
; insert element
	push si
	add si, 2
	movzx bx, dh
	shl bx, 1
	add si, bx
	mov word [si], ax
	pop si
; update state
	inc ch
	inc si ; set to address of count
	mov byte [si], ch ; update count
	clc
	jmp .success
.max_err :
.invalid_index_err :
	stc
.success :
	popa
	ret
; take lower byte and turn it into a ls8
; si <- address of ls16
; di <- address of ls8
ls16_take_lower :
	pusha
	LS16_GET_COUNT ; cx = count
	xchg si, di ; di = ls16 ; si = ls8
	LS8_CLEAR
	add di, 2
.loop :
	cmp cx, 0
	je .loop_end
	mov word bx, [di]
	LS8_APPEND bl
	add di, 2
	dec cx
	jmp .loop
.loop_end :
	popa
	ret
%endif ; _LS16_SUB_ASM_