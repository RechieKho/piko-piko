%ifndef _READ_COM_ASM_
%define _READ_COM_ASM_
; --- data ---
read_com_data :
.read_buffer : ; A list 16 buffer for read command.
	db VAR_SIZE, 0
	times (VAR_SIZE) dw 0
; --- commands ---
@readCommand_name :
	db "read", 0
; 1 <- nth variable
@readCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne err.invalid_arg_num_err
	add si, 6
	VAR_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	mov di, var_data.variables
	add di, ax ; di = variable address
	mov si, read_com_data.read_buffer
	xor bx, bx
	call consoleReadLine
	call list16TakeLower
	PRINT_NL
	clc
	ret
%endif ; _READ_COM_ASM_