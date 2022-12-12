%ifndef _LIST8_SUB_ASM_
%define _LIST8_SUB_ASM_
; list 8 - list of 8 bits
; structure diagram :
; | max (1B) | count (1B) | elements (1B each element) |
; --- modules ---
%include "print_sub.asm"
; --- macros ---
%define LIST8_MAX 0xff
; initialize list 8
; %1 <- max count of the element (excluding the header) {1B, !di}
; di <- address of list 8
%macro LIST8_INIT 0-1 LIST8_MAX
	push di
	mov byte [di], %1
	inc di
	mov byte [di], 0
	pop di
%endmacro
; get info from list 8
; si <- address of list 8
; cl -> max count of list 8
; ch -> count of list 8
%define LIST8_GET_INFO mov word cx, [si]
; get count of list 8
; si <- address of list 8
; cx -> count of list 8
%macro LIST8_GET_COUNT 0
	push ax
	LIST8_GET_INFO
	movzx ax, ch
	mov cx, ax ; cx = count
	pop ax
%endmacro
; clear list 8
; si <- address of list 8
%macro LIST8_CLEAR 0
	pusha
	LIST8_GET_INFO
	mov ch, 0
	mov word [si], cx
	popa
%endmacro
; append to list 8
; %1 <- element to be appended {1B, !al}
; si <- address of list 8
%macro LIST8_APPEND 1
	pusha
	inc si
	mov byte dh, [si]
	dec si
	mov al, %1
	call list8Insert
	popa
%endmacro
; prepend to list 8
; %1 <- element to be prepend {1B, !al}
; si <- address of list 8
%macro LIST8_PREPEND 1
	pusha
	mov al, %1
	mov dh, 0
	call list8Insert
	popa
%endmacro
; pop last element of list 8
; si <- address of list 8
%macro LIST8_POP_LAST 0
	pusha
	inc si
	mov byte dh, [si]
	dec dh
	dec si
	call list8Erase
	popa
%endmacro
; pop first element of list 8
; si <- address of list 8
%macro LIST8_POP_FIRST 0
	pusha
	mov dh, 0
	call list8Erase
	popa
%endmacro
; --- subroutine ---
; print list 8 as ascii to console
; si <- address of list 8
list8PrintAscii :
	pusha
	LIST8_GET_COUNT ; cx = count
	add si, 2 ; si = begining of element
.loop :
	cmp cx, 0
	je .loop_end
	PRINT_CHAR [si]
	inc si
	dec cx
	jmp .loop
.loop_end :
	popa
	ret
; check whether list 8s are equal
; si <- address of first list 8
; di <- address of second list 8
; cf -> set if list 8s are not equal
list8Equal :
	pusha
	mov word cx, [si] ; cl = max ; ch = count
	mov word dx, [di] ; dl = max ; dh = count
	cmp dh, ch
	jne .not_equal
	movzx cx, dh ; cx = count of both list 8
	add si, 2 ; displace to the element
	add di, 2 ; displace to the element
.loop :
	cmp cx, 0
	je .equal
	mov byte al, [si]
	mov byte bl, [di]
	cmp al, bl
	jne .not_equal
	inc si
	inc di
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
; erase element from list 8
; dh <- index of the element to be erased
; si <- address of list 8
; cf -> set if element fail to be inserted (either list 8 is empty or ah (index) is invalid)
list8Erase :
	pusha
	LIST8_GET_INFO ; cl = max ; ch = count
; check validity
	cmp ch, 0
	je .empty_err ; empty element, not entertained
	cmp dh, ch
	jae .invalid_index_err
; displace elements backward
	pusha ; > START DISPLACE <
	add si, 3
	movzx ax, dh
	add si, ax ; si = address right after element to be erased
	mov di, si
	dec di ; di = address of element to be erased
	sub ch, dh
	dec ch
	movzx ax, ch
	mov cx, ax ; cx = number of element to be displaced
	mov ax, ds
	mov es, ax
	cld
	rep movsb
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
; set the whole list 8
; si <- address of list 8
; di <- address of data
; cl <- count
; cf -> set if fail to be set (count exceed max)
list8Set :
	pusha
	mov dl, cl ; dl = count
	LIST8_GET_INFO ; cl = max
	cmp dl, cl
	ja .exceed_max
	mov ch, dl
	mov word [si], cx
	add si, 2
	xchg si, di
	mov bx, ds
	mov es, bx
	movzx cx, dl
	cld
	rep movsb
	clc
	jmp .end
.exceed_max :
	stc
.end :
	popa
	ret
; insert element to list 8
; al <- element to be inserted
; si <- address of list 8
; dh <- index of the element to be inserted
; cf -> set if element fail to be inserted (either list 8 is full or ah (index) is invalid)
list8Insert :
	pusha
	LIST8_GET_INFO ; cl = max ; ch = count
	cmp ch, cl
	jae .max_err ; already max out
	cmp dh, ch
	ja .invalid_index_err ; index is bigger than the count
; displace element forward
	pusha ; > START DISPLACE <
	movzx bx, ch
	inc bx ; skip header
	add si, bx ; si = address of end of list 8
	mov di, si
	inc di ; di = address right after end of list 8
	sub ch, dh
	movzx bx, ch
	mov cx, bx ; cx = number of elements to be displaced
	mov bx, ds
	mov es, bx
	std
	rep movsb
	cld
	popa ; > END DISPLACE <
; insert element
	push si
	add si, 2
	movzx bx, dh
	add si, bx
	mov byte [si], al
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
%endif ; _LIST8_SUB_ASM_