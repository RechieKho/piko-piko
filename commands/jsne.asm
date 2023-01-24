%ifndef _JSNE_COM_ASM_
%define _JSNE_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpStringNotEqualCommand_name :
	db "jsne", 0
; If strings in compare buffer are not equal, jump command is executed.
@jumpStringNotEqualCommand :
	push si
	push di
	mov si, command_data.compare_buffer_a
	mov di, command_data.compare_buffer_b
	call list8Equal
	pop di
	pop si
	jc @jumpCommand
	clc
	ret
%endif ; _JSNE_COM_ASM_