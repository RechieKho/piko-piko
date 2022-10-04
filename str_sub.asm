%ifndef _STR_SUB_ASM_
%define _STR_SUB_ASM_

	; some helpful functions for (null-terminated) string operation

	; check if string contains character
	; si <- string
	; al <- character
	; cf -> set if it contains the character

str_has_char:
	pusha
	mov cl, [si]

.loop:
	cmp cl, 0
	je  .no_char

	cmp cl, al
	je  .has_char

	inc si
	mov cl, [si]
	jmp .loop

.has_char:
	stc

.no_char:
	popa
	ret

%endif ; _STR_SUB_ASM_
