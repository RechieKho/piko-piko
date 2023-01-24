%ifndef _JSE_COM_ASM_
%define _JSE_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpStringEqualCommand_name :
	db "jse", 0
; If strings in compare buffer are equal, jump command is executed.
@jumpStringEqualCommand :
	push si
	push di
	mov si, command_data.compare_buffer_a
	mov di, command_data.compare_buffer_b
	call list8Equal
	pop di
	pop si
	jnc @jumpCommand
	clc
	ret
%endif ; _JSE_COM_ASM_