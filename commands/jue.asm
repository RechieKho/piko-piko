%ifndef _JUE_COM_ASM_
%define _JUE_COM_ASM_
; --- commands ---
@jumpUintEqualCommand_name :
	db "jue", 0
; If uints in compare buffer are equal, jump command is executed.
@jumpUintEqualCommand :
	mov bx, si
	COMPARE_BUFFER_TO_UINT
	mov si, bx
	cmp ax, dx
	je @jumpCommand
	clc
	ret
%endif ; _JUE_COM_ASM_