%ifndef _JUL_COM_ASM_
%define _JUL_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpUintLessCommand_name :
	db "jul", 0
; jump if less
@jumpUintLessCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jb @jumpCommand
	clc
	ret
%endif ; _JUL_COM_ASM_