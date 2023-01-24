%ifndef _RST_COM_ASM_
%define _RST_COM_ASM_
; --- commands ---
@resetStackCommand_name :
	db "rst", 0
; n <- ignored
@resetStackCommand :
	mov word [stack_data.stack_pointer], stack_data.stack
	ret
%endif ; _RST_COM_ASM_