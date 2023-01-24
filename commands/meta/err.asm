%ifndef _ERR_META_ASM_
%define _ERR_META_ASM_
; --- modules ---
%include "print_sub.asm"
%include "commands/meta/buffer.asm"
; --- data ---
err_data :
.disk_write_error_c_string :
	db "Fail to write disk.", 0
.disk_read_error_c_string :
	db "Fail to read disk.", 0
.invalid_file_error_c_string :
	db "Invalid file.", 0
.stack_empty_error_c_string :
	db "Stack is empty.", 0
.stack_full_error_c_string :
	db "Stack is full.", 0
.value_too_big_error_c_string :
	db "Value too big.", 0
.invalid_value_error_c_string :
	db "Invalid value.", 0
.invalid_variable_error_c_string :
	db "Invalid variable.", 0
.invalid_buffer_error_c_string :
	db "Invalid buffer.", 0
.invalid_buffer_row_error_c_string :
	db "Invalid buffer row.", 0
.invalid_arg_num_error_c_string :
	db "Invalid number of arguments.", 0
.not_running_buffer_error_c_string :
	db "Not running in the buffer.", 0
.invalid_uint_error_c_string :
	db "Invalid number.", 0
.debug_show_row_c_string :
	db "[line ", 0
; --- subroutine ---
err :
.disk_write_err :
	mov bx, err_data.disk_write_error_c_string
	jmp .print
.disk_read_err :
	mov bx, err_data.disk_read_error_c_string
	jmp .print
.invalid_file_err :
	mov bx, err_data.invalid_file_error_c_string
	jmp .print
.value_too_big_err :
	mov bx, err_data.value_too_big_error_c_string
	jmp .print
.invalid_arg_num_err :
	mov bx, err_data.invalid_arg_num_error_c_string
	jmp .print
.stack_full_err :
	mov bx, err_data.stack_full_error_c_string
	jmp .print
.stack_empty_err :
	mov bx, err_data.stack_empty_error_c_string
	jmp .print
.invalid_value_err :
	mov bx, err_data.invalid_value_error_c_string
	jmp .print
.invalid_variable_err :
	mov bx, err_data.invalid_variable_error_c_string
	jmp .print
.invalid_buffer_err :
	mov bx, err_data.invalid_buffer_error_c_string
	jmp .print
.invalid_buffer_row_err :
	mov bx, err_data.invalid_buffer_row_error_c_string
	jmp .print
.not_running_buffer_err :
	mov bx, err_data.not_running_buffer_error_c_string
	jmp .print
.invalid_uint_err :
	mov bx, err_data.invalid_uint_error_c_string
.print :
	mov byte al, [buffer_data.is_buffer_executing]
	cmp al, 0
	je .not_running_buffer
	call printError
	PRINT_CHAR ' '
	mov bx, err_data.debug_show_row_c_string
	call printCString
	mov ah, MAGENTA
	mov dx, [buffer_data.executing_row]
	call consolePrintUint
	PRINT_CHAR ']'
	PRINT_NL
	jmp .end
.not_running_buffer :
	call printErrorLine
.end :
	stc
	ret
%endif ; _ERR_META_ASM_