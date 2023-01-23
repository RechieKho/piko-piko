%ifndef _RST_COM_ASM_
%define _RST_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@resetStackCommand_name :
	db "rst", 0
; n <- ignored
@resetStackCommand :
	mov word [command_data.stack_pointer], command_data.stack
	ret
%endif ; _RST_COM_ASM_