%ifndef _SET_COM_ASM_
%define _SET_COM_ASM_
; --- commands ---
@setCommand_name :
	db "set", 0
; 1 <- nth variable
; 2 <- value
@setCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne err.invalid_arg_num_err
	add si, 6
	VAR_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	mov di, var_data.variables
	add di, ax ; di = variable address
	VAR_CONSUME_MARK_READ_STRN_TO_LIST8
	clc
	ret
%endif ; _SET_COM_ASM_