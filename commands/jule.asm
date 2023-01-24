%ifndef _JULE_COM_ASM_
%define _JULE_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpUintLessEqualCommand_name :
	db "jule", 0
; jump if less equal
@jumpUintLessEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jbe @jumpCommand
	clc
	ret
%endif ; _JULE_COM_ASM_