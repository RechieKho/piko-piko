%ifndef _JUNE_COM_ASM_
%define _JUNE_COM_ASM_
; --- commands ---
@jumpUintNotEqualCommand_name :
	db "june", 0
; If uints in compare buffer are not equal, jump command is executed.
@jumpUintNotEqualCommand :
	mov bx, si
	COMPARE_BUFFER_TO_UINT
	mov si, bx
	pop si
	jne @jumpCommand
	clc
	ret
%endif ; _JUNE_COM_ASM_