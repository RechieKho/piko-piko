%ifndef _JUL_COM_ASM_
%define _JUL_COM_ASM_
; --- commands ---
@jumpUintLessCommand_name :
	db "jul", 0
; jump if less
@jumpUintLessCommand :
	mov bx, si
	COMPARE_BUFFER_TO_UINT
	mov si, bx
	cmp ax, dx
	jb @jumpCommand
	clc
	ret
%endif ; _JUL_COM_ASM_