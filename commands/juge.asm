%ifndef _JUGE_COM_ASM_
%define _JUGE_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpUintGreaterEqualCommand_name :
	db "juge", 0
; jump if greater equal
@jumpUintGreaterEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jae @jumpCommand
	clc
	ret
%endif ; _JUGE_COM_ASM_