%ifndef _ADD_COM_ASM_
%define _ADD_COM_ASM_
; --- commands ---
@addCommand_name :
	db "add", 0
; 1 <- value for storing the sum
; 2 <- first value
; 3 <- second value
@addCommand :
	LIST32_GET_COUNT
	cmp cx, 4
	jne err.invalid_arg_num_err
	add si, 6
	VAR_CONSUME_MARK_READ_UINT
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	mov di, var_data.variables
	add di, ax ; di = variable address
	VAR_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	VAR_CONSUME_MARK_READ_UINT
	add ax, dx
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
%endif ; _ADD_COM_ASM_