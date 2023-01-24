%ifndef _DIV_COM_ASM_
%define _DIV_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
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
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address for quotient
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov bx, command_data.variables
	add bx, ax ; bx = variable address for remainder
	COMMANDS_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dh, 0
	jne command_err.value_too_big_err
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