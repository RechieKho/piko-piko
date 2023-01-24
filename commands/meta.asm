%ifndef _META_COM_ASM_
%define _META_COM_ASM_
; NOTE : YOU MUST COMMANDS_INIT BEFORE USING ANYTHING IN THIS MODULE
; each command expecting :
; si <- address of list 32 of marks point to the arguments
; COMMANDS RETURN WITH CARRY FLAG SET WILL CANCEL RUNNING BUFFER.
; COMMANDS SHOULD NOT PUSHA/POPA AT THE BEGINING AND ENDING OF COMMANDS.
; --- modules ---
%include "print_sub.asm"
%include "list32_sub.asm"
%include "list8_sub.asm"
%include "str_sub.asm"
%include "type_macros.asm"
%include "console_sub.asm"
%include "interpreter_sub.asm"
%include "storage_sub.asm"
; --- macros ---
%define VARIABLE_CAPACITY BUFFER_WIDTH
%define VARIABLE_SIZE (VARIABLE_CAPACITY + 2) ; MUST within a byte
%define VARIABLE_COUNT 0x1a ; MUST within a byte
%define STACK_MAX_VAR 25 ; number of variable able to store on stack
%define COMPARE_BUFFER_CAPACITY 0x20
%define COMPARE_BUFFER_SIZE (COMPARE_BUFFER_SIZE + 2)
%macro COMMANDS_INIT 0
	BUFFER_INIT
%endmacro
; initiate buffer
%macro BUFFER_INIT 0
	pusha
	push es
	mov al, ' '
	xor bx, bx
	mov dx, (BUFFER_SEC_COUNT * BUFFER_COUNT)
	mov si, BUFFER_BEGIN_SEG
	mov cx, SECTOR_SIZE
%%set_loop :
	cmp dx, 0
	je %%set_loop_end
	mov es, si
	call byteset
	add si, (SECTOR_SIZE >> 4)
	dec dx
	jmp %%set_loop
%%set_loop_end :
	pop es
	popa
%endmacro
; Read list 8 as uint. MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN
; PUSH AND POP.
; si <- address of list 8
; dx -> uint
%macro COMMANDS_LIST82UINT 0
	push si
	LIST8_GET_COUNT
	add si, 2
	clc
	call stringToUint
	pop si
	jc command_err.invalid_uint_err
%endmacro
; Read compare buffer as uint. MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE
; IN BETWEEN PUSH AND POP.
; ax -> uint of compare_buffer_a
; dx -> uint of compare_buffer_b
; ~si
%macro COMMANDS_COMBUF2UINT 0
	mov si, command_data.compare_buffer_a
	COMMANDS_LIST82UINT
	mov ax, dx ; ax = uint of first compare buffer
	mov si, command_data.compare_buffer_b
	COMMANDS_LIST82UINT
%endmacro
; Consume mark and read as string (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- current mark
; bx -> string
; cx -> length
; si -> next mark
%macro COMMANDS_CONSUME_MARK_READ_STRN 0
	call commandConsumeMark
	clc
	call commandReadString
	jc command_err.invalid_variable_err
%endmacro
; Consume mark and read as string save it to list 8 (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- current_mark
; di <- address of list 8 to output to
; si -> next mark
%macro COMMANDS_CONSUME_MARK_READ_STRN_TO_LIST8 0
	push bx
	push cx
	call commandConsumeMark
	clc
	call commandReadString
	jc %%fail
	cmp ch , 0
	jne %%fail
	push si
	mov si, di
	mov di, bx
	clc
	call list8Set
	pop si
	jc %%fail
%%success :
	clc
	jmp %%end
%%fail :
	stc
%%end :
	pop cx
	pop bx
	jc command_err.invalid_value_err
%endmacro
; Consume mark and read as uint (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS.
; si <- current mark
; dx -> uint
; si -> next mark
%macro COMMANDS_CONSUME_MARK_READ_UINT 0
	push bx
	push cx
	call commandConsumeMark
	push si
	clc
	call commandReadString
	jc %%end
	mov si, bx
	clc
	call stringToUint
%%end :
	pop si
	pop cx
	pop bx
	jc command_err.invalid_uint_err
%endmacro
; --- data ---
command_data :
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
.variables :
%rep VARIABLE_COUNT
	db VARIABLE_CAPACITY, 0
	times (VARIABLE_CAPACITY) db 0
%endrep
.stack :
	times (STACK_MAX_VAR * VARIABLE_SIZE) db 0
.stack_pointer :
	dw .stack
.active_buffer :
	dw BUFFER_BEGIN_SEG
.is_buffer_executing :
	db 0 ; 0 = falist e, elist e = true
.executing_row : ; Current executing row in buffer.
	dw 0
.executing_seg : ; basically executing_row but in segment unit
	dw 0
.execution_buffer : ; Buffer for saving row to be executed.
	times BUFFER_WIDTH db 0
.compare_buffer_a : ; A list 8 buffer for value to be compared (to compare_buffer_b).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
.compare_buffer_b : ; A list 8 buffer for value to be compared (to compare_buffer_a).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
.read_buffer : ; A list 16 buffer for read command.
	db VARIABLE_SIZE, 0
	times (VARIABLE_SIZE) dw 0
; --- subroutine ---
; Read string (accept variable referencing).
; bx <- string
; cx <- length
; bx -> string
; cx -> length
; cf -> set if fail
commandReadString :
	push ax
	push dx
	push si
	cmp cx, 0
	je .success
	mov byte al, [bx]
	cmp al, '$'
	jne .string_literal
; variable referencing
	mov si, bx
	inc si
	dec cx
	clc
	call stringToUint
	jc .fail
	cmp dx, VARIABLE_COUNT
	jae .fail
	mov al, VARIABLE_SIZE
	mul dl
	mov si, command_data.variables
	add si, ax
	LIST8_GET_COUNT
	mov bx, si
	add bx, 2
	jmp .success
.string_literal :
	cmp al, '\'
	jne .success
	inc bx
	dec cx
	jmp .success
.success :
	clc
	jmp .end
.fail :
	stc
.end :
	pop si
	pop dx
	pop ax
	ret
; Set executing row together with its corresponding executing segment.
; dx <- executing row
commandSetExecutingSegment :
	push ax
	push dx
	mov word [command_data.executing_row], dx
	mov ax, BUFFER_SEG_PER_ROW
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [command_data.executing_seg], ax
	pop dx
	pop ax
	ret
; si <- current mark
; bx -> address of argument
; cx -> length of argument
; si -> next mark
commandConsumeMark :
	mov word cx, [si]
	add si, 2
	mov word bx, [si]
	add si, 2
	ret
; There is so many repeating lines of code for handling err so I just put it all in one place.
command_err :
.disk_write_err :
	mov bx, command_data.disk_write_error_c_string
	jmp .print
.disk_read_err :
	mov bx, command_data.disk_read_error_c_string
	jmp .print
.invalid_file_err :
	mov bx, command_data.invalid_file_error_c_string
	jmp .print
.value_too_big_err :
	mov bx, command_data.value_too_big_error_c_string
	jmp .print
.invalid_arg_num_err :
	mov bx, command_data.invalid_arg_num_error_c_string
	jmp .print
.stack_full_err :
	mov bx, command_data.stack_full_error_c_string
	jmp .print
.stack_empty_err :
	mov bx, command_data.stack_empty_error_c_string
	jmp .print
.invalid_value_err :
	mov bx, command_data.invalid_value_error_c_string
	jmp .print
.invalid_variable_err :
	mov bx, command_data.invalid_variable_error_c_string
	jmp .print
.invalid_buffer_err :
	mov bx, command_data.invalid_buffer_error_c_string
	jmp .print
.invalid_buffer_row_err :
	mov bx, command_data.invalid_buffer_row_error_c_string
	jmp .print
.not_running_buffer_err :
	mov bx, command_data.not_running_buffer_error_c_string
	jmp .print
.invalid_uint_err :
	mov bx, command_data.invalid_uint_error_c_string
.print :
	mov byte al, [command_data.is_buffer_executing]
	cmp al, 0
	je .not_running_buffer
	call printError
	PRINT_CHAR ' '
	mov bx, command_data.debug_show_row_c_string
	call printCString
	mov ah, MAGENTA
	mov dx, [command_data.executing_row]
	call consolePrintUint
	PRINT_CHAR ']'
	PRINT_NL
	jmp .end
.not_running_buffer :
	call printErrorLine
.end :
	stc
	ret
; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
%error "Variable size and count must be a byte."
%endif
%if (VARIABLE_CAPACITY < 5)
%error "Variable too small for uint."
%endif
%if (VARIABLE_CAPACITY < BUFFER_WIDTH)
%error "Variable too small for buffer row."
%endif
%endif ; _META_COM_ASM_