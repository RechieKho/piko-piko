%ifndef _JUG_COM_ASM_
%define _JUG_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpUintGreaterCommand_name :
	db "jug", 0
; jump if greater
@jumpUintGreaterCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	ja @jumpCommand
	clc
	ret
%endif ; _JUG_COM_ASM_