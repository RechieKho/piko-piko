%ifndef _MUL_COM_ASM_
%define _MUL_COM_ASM_
; --- commands ---
@mulCommand_name :
	db "mul", 0
; 1 <- value for storing the product
; 2 <- first value
; 3 <- second value
@mulCommand :
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
	mul dx
	cmp dx, 0
	jne err.value_too_big_err
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
%endif ; _MUL_COM_ASM_