%ifndef MEM_SUB_ASM
%define MEM_SUB_ASM 

; Utilities for dealing with memory 

; set the word(s) with value 
; ax <- value 
; es:bx <- start address 
; cx <- count 
wordset:
	pusha 
.loop:
	cmp cx, 0 
	je .loop_end 
	mov word [es:bx], ax 
	add bx, 2
	dec cx 
	jmp .loop
.loop_end:
	popa 
	ret

; set the byte(s) with value 
; al <- value 
; es:bx <- start address 
; cx <- count 
byteset:
	pusha 
.loop:
	cmp cx, 0 
	je .loop_end 
	mov byte [es:bx], al
	inc bx
	dec cx 
	jmp .loop
.loop_end:
	popa 
	ret


%endif ;MEM_SUB_ASM
