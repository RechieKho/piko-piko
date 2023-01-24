%ifndef _READ_COM_ASM_
%define _READ_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@readCommand_name :
	db "read", 0
; 1 <- nth variable
@readCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	mov si, command_data.read_buffer
	xor bx, bx
	call consoleReadLine
	call list16TakeLower
	PRINT_NL
	clc
	ret
%endif ; _READ_COM_ASM_