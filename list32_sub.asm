%ifndef _LIST32_SUB_ASM_
%define _LIST32_SUB_ASM_
; list 32 - list of 32 bits
; structure diagram :
; | max (1B) | count (1B) | elements (4B each element) |
; --- macros ---
%define LIST32_MAX 0xff
; initialize list 32
; %1 <- max count of the element (excluding the header) {1B, !di}
; di <- address of list 32
%macro LIST32_INIT 0-1 LIST32_MAX
	push di
	mov byte [di], %1
	inc di
	mov byte [di], 0
	pop di
%endmacro
; get info from list 32
; si <- address of list 32
; cl -> max count of list 32
; ch -> count of list 32
%define LIST32_GET_INFO mov word cx, [si]
; get count of list 32
; si <- address of list 32
; cx -> count of list 32
%macro LIST32_GET_COUNT 0
	push ax
	LIST32_GET_INFO
	movzx ax, ch
	mov cx, ax ; cx = count
	pop ax
%endmacro
; clear list 32
; si <- address of list 32
%macro LIST32_CLEAR 0
	pusha
	LIST32_GET_INFO
	mov ch, 0
	mov word [si], cx
	popa
%endmacro
; append to list 32
; %1 <- lower part of element to be appended {2B, !ax, !bx}
; %2 <- upper part of element to be appended {2B, !bx}
; si <- address of list 32
%macro LIST32_APPEND 2
	pusha
	mov bx, %2
	mov ax, %1
	inc si
	mov byte dh, [si]
	dec si
	call list32Insert
	popa
%endmacro
; prepend to list 32
; %1 <- lower part of element to be prepend {2B, !ax, !bx}
; %2 <- upper part of element to be prepend {2B, !bx}
; si <- address of list 32
%macro LIST32_PREPEND 2
	pusha
	mov bx, %2
	mov ax, %1
	mov dh, 0
	call list32Insert
	popa
%endmacro
; pop last element of list 32
; si <- address of list 32
%macro LIST32_POP_LAST 0
	pusha
	inc si
	mov byte dh, [si]
	dec dh
	dec si
	call list32Erase
	popa
%endmacro
; pop first element of list 32
; si <- address of list 32
%macro LIST32_POP_FIRST 0
	pusha
	mov dh, 0
	call list32Erase
	popa
%endmacro
; --- subroutine ---
; check whether list 32s are equal
; si <- address of first list 32
; di <- address of second list 32
; cf -> set if list 32s are not equal
list32Equal :
	pusha
	mov word cx, [si] ; cl = max ; ch = count
	mov word dx, [di] ; dl = max ; dh = count
	cmp dh, ch
	jne .not_equal
	movzx cx, dh
	shl cx, 2 ; cx = count of words stored in both list 32
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
; erase element from list 32
; dh <- index of the element to be erased
; si <- address of list 32 header
; cf -> set if element fail to be inserted (either list 32 is empty or ah (index) is invalid)
list32Erase :
	pusha
	LIST32_GET_INFO ; cl = max ; ch = count
; check validity
	cmp ch, 0
	je .empty_err ; empty element, not entertained
	cmp dh, ch
	jae .invalid_index_err
; displace elements backward
	pusha ; > START DISPLACE <
	add si, 6
	movzx ax, dh
	shl ax, 2
	add si, ax ; si = address right after element to be erased
	mov di, si
	sub di, 4 ; di = address of element to be erased
	sub ch, dh
	dec ch
	movzx ax, ch
	mov cx, ax ; cx = number of element to be displaced
	mov ax, ds
	mov es, ax
	cld
	rep movsd
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
; insert element to list 32
; ax <- lower part of element to be inserted
; bx <- upper part of element to be inserted
; dh <- index of the element to be inserted
; si <- address of list 32 header
; cf -> set if element fail to be inserted (either list 32 is full or ah (index) is invalid)
list32Insert :
	pusha
	LIST32_GET_INFO ; cl = max ; ch = count
	cmp ch, cl
	jae .max_err ; already max out
	cmp dh, ch
	ja .invalid_index_err ; index is bigger than the count
; displace element forward
	pusha ; > START DISPLACE <
	movzx ax, ch
	shl ax, 2
	add si, ax ; si = address of end of list 32
	mov di, si
	add di, 4 ; di = address right after end of list 32
	sub ch, dh
	movzx ax, ch
	mov cx, ax ; cx = number of elements to be displaced
	mov ax, ds
	mov es, ax
	std
	rep movsd
	cld
	popa ; > END DISPLACE <
; insert element
	push si
	add si, 2
	push ax
	movzx ax, dh
	shl ax, 2
	add si, ax
	pop ax
	mov word [si], ax
	add si, 2
	mov word [si], bx
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
%endif ; _LIST32_SUB_ASM_