%ifndef _JULE_COM_ASM_
%define _JULE_COM_ASM_
; --- commands ---
@jumpUintLessEqualCommand_name :
	db "jule", 0
; jump if less equal
@jumpUintLessEqualCommand :
	mov bx, si
	COMPARE_BUFFER_TO_UINT
	mov si, bx
	cmp ax, dx
	jbe @jumpCommand
	clc
	ret
%endif ; _JULE_COM_ASM_