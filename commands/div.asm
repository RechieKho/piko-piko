%ifndef _DIV_COM_ASM_
%define _DIV_COM_ASM_
; --- commands ---
@divCommand_name :
	db "div", 0
; 1 <- variable for storing quotient
; 2 <- variable for stonig remainder
; 3 <- dividend
; 4 <- divisor
@divCommand :
	LIST32_GET_COUNT
	cmp cx, 5
	jne err.invalid_arg_num_err
	add si, 6
	VAR_CONSUME_MARK_READ_UINT
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	mov di, var_data.variables
	add di, ax ; di = variable address for quotient
	VAR_CONSUME_MARK_READ_UINT
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	mov bx, var_data.variables
	add bx, ax ; bx = variable address for remainder
	VAR_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	VAR_CONSUME_MARK_READ_UINT
	cmp dh, 0
	jne err.value_too_big_err
	div dl
	mov dx, ax
	xor ax, ax
	mov al, dl
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	mov di, bx
	xor ax, ax
	mov al, dh
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
%endif ; _DIV_COM_ASM_