%ifndef _JUE_COM_ASM_
%define _JUE_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpUintEqualCommand_name :
	db "jue", 0
; If uints in compare buffer are equal, jump command is executed.
@jumpUintEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	je @jumpCommand
	clc
	ret
%endif ; _JUE_COM_ASM_