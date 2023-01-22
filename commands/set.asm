%ifndef _SET_COM_ASM_
%define _SET_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@setCommand_name :
	db "set", 0
; 1 <- nth variable
; 2 <- value
@setCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	COMMANDS_CONSUME_MARK_READ_STRN_TO_LIST8
	clc
	ret
%endif ; _SET_COM_ASM_