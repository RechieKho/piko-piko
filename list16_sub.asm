%ifndef _LIST16_SUB_ASM_
%define _LIST16_SUB_ASM_
; list 16 - list of 16 bits
; structure diagram :
; | max (1B) | count (1B) | elements (2B each element) |
; --- modules ---
%include "print_sub.asm"
%include "list8_sub.asm"
; --- macros ---
%define LIST16_MAX 0xff
; initialize list 16
; %1 <- max count of the element (excluding the header) {1B, !di}
; di <- address of list 16
%macro LIST16_INIT 0-1 LIST16_MAX
	push di
	mov byte [di], %1
	inc di
	mov byte [di], 0
	pop di
%endmacro
; get info from list 16
; si <- address of list 16
; cl -> max count of list 16
; ch -> count of list 16
%define LIST16_GET_INFO mov word cx, [si]
; get count of list 16
; si <- address of list 16
; cx -> count of list 16
%macro LIST16_GET_COUNT 0
	push ax
	LIST16_GET_INFO
	movzx ax, ch
	mov cx, ax ; cx = count
	pop ax
%endmacro
; clear list 16
; si <- address of list 16
%macro LIST16_CLEAR 0
	pusha
	LIST16_GET_INFO
	mov ch, 0
	mov word [si], cx
	popa
%endmacro
; append to list 16
; %1 <- element to be appended {2B, !ax}
; si <- address of list 16
%macro LIST16_APPEND 1
	pusha
	inc si
	mov byte dh, [si]
	dec si
	mov ax, %1
	call list16Insert
	popa
%endmacro
; prepend to list 16
; %1 <- element to be prepend {2B, !ax}
; si <- address of list 16
%macro LIST16_PREPEND 1
	pusha
	mov ax, %1
	mov dh, 0
	call list16Insert
	popa
%endmacro
; pop last element of list 16
; si <- address of list 16
%macro LIST16_POP_LAST 0
	pusha
	inc si
	mov byte dh, [si]
	dec dh
	dec si
	call list16Erase
	popa
%endmacro
; pop first element of list 16
; si <- address of list 16
%macro LIST16_POP_FIRST 0
	pusha
	mov dh, 0
	call list16Erase
	popa
%endmacro
; --- subroutine ---
; check whether list 16s are equal
; si <- address of first list 16
; di <- address of second list 16
; cf -> set if list 16s are not equal
list16Equal :
	pusha
	mov word cx, [si] ; cl = max ; ch = count
	mov word dx, [di] ; dl = max ; dh = count
	cmp dh, ch
	jne .not_equal
	movzx cx, dh ; cx = count of both list 16
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
; erase element from list 16
; dh <- index of the element to be erased
; si <- address of list 16 header
; cf -> set if element fail to be inserted (either list 16 is empty or ah (index) is invalid)
list16Erase :
	pusha
	LIST16_GET_INFO ; cl = max ; ch = count
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
; insert element to list 16
; ax <- element to be inserted
; dh <- index of the element to be inserted
; si <- address of list 16 header
; cf -> set if element fail to be inserted (either list 16 is full or ah (index) is invalid)
list16Insert :
	pusha
	LIST16_GET_INFO ; cl = max ; ch = count
	cmp ch, cl
	jae .max_err ; already max out
	cmp dh, ch
	ja .invalid_index_err ; index is bigger than the count
; displace element forward
	pusha ; > START DISPLACE <
	movzx bx, ch
	shl bx, 1
	add si, bx ; si = address of end of list 16
	mov di, si
	add di, 2 ; di = address right after end of list 16
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
; take lower byte and turn it into a list 8
; si <- address of list 16
; di <- address of list 8
list16TakeLower :
	pusha
	LIST16_GET_COUNT ; cx = count
	xchg si, di ; di = address of list 16 ; si = address of list 8
	LIST8_CLEAR
	add di, 2
.loop :
	cmp cx, 0
	je .loop_end
	mov word bx, [di]
	LIST8_APPEND bl
	add di, 2
	dec cx
	jmp .loop
.loop_end :
	popa
	ret
%endif ; _LIST16_SUB_ASM_