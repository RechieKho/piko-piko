%ifndef _JUG_COM_ASM_
%define _JUG_COM_ASM_
; --- commands ---
@jumpUintGreaterCommand_name :
	db "jug", 0
; jump if greater
@jumpUintGreaterCommand :
	mov bx, si
	COMPARE_BUFFER_TO_UINT
	mov si, bx
	cmp ax, dx
	ja @jumpCommand
	clc
	ret
%endif ; _JUG_COM_ASM_