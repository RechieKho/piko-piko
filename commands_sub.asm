%ifndef _COMMANDS_SUB_ASM_
%define _COMMANDS_SUB_ASM_
; NOTE : YOU MUST COMMANDS_INIT BEFORE USING ANYTHING IN THIS MODULE
; each commands expecting :
; si <- ls32 of marks point to the arguments
; COMMANDS RETURN WITH CARRY FLAG SET WILL CANCEL RUNNING BUFFER.
; COMMANDS SHOULD NOT PUSHA/POPA AT THE BEGINING AND ENDING OF COMMANDS.
; --- modules ---
%include "print_sub.asm"
%include "ls32_sub.asm"
%include "ls8_sub.asm"
%include "str_sub.asm"
%include "type_macros.asm"
%include "console_sub.asm"
%include "interpreter_sub.asm"
; --- macros ---
%define VARIABLE_CAPACITY 0x20
%define VARIABLE_SIZE (VARIABLE_CAPACITY + 2) ; MUST within a byte
%define VARIABLE_COUNT 0x1a ; MUST within a byte
%define STACK_MAX_VAR (VARIABLE_COUNT * 5) ; number of variable able to store on stack
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
	mov cx, 512
%%set_loop :
	cmp dx, 0
	je %%set_loop_end
	mov es, si
	call byteset
	add si, (512 >> 4)
	dec dx
	jmp %%set_loop
%%set_loop_end :
	pop es
	popa
%endmacro
; Read ls8 as uint. MUST ONLY BE CALLED IN COMMANDS.
; si <- ls8
; dx -> uint
%macro COMMANDS_LS82UINT 0
	push si
	LS8_GET_COUNT
	add si, 2
	clc
	call strn_to_uint
	pop si
	jc commands_err.invalid_uint_err
%endmacro
; Read compare buffer as uint. MUST ONLY BE CALLED IN COMMANDS AND SHOULDN 'T BE 
; IN BETWEEN PUSH AND POP.
; ax -> uint of compare_buffer_a
; dx -> uint of compare_buffer_b
; ~si
%macro COMMANDS_COMBUF2UINT 0
	mov si, commands_data.compare_buffer_a
	COMMANDS_LS82UINT
	mov ax, dx ; ax = uint of first compare buffer
	mov si, commands_data.compare_buffer_b
	COMMANDS_LS82UINT
%endmacro
; --- data ---
commands_data :
.stack_empty_err_str :
	db "Stack is empty.", 0
.stack_full_err_str :
	db "Stack is full.", 0
.value_too_long_err_str :
	db "Value too long.", 0
.invalid_value_err_str :
	db "Invalid value.", 0
.invalid_variable_err_str :
	db "Invalid variable.", 0
.invalid_buffer_err_str :
	db "Invalid buffer.", 0
.invalid_buffer_row_err_str :
	db "Invalid buffer row.", 0
.invalid_arg_num_err_str :
	db "Invalid number of arguments.", 0
.not_running_buffer_err_str :
	db "Not running in the buffer.", 0
.invalid_uint_err_str :
	db "Invalid number.", 0
.debug_show_row_str :
	db "[line ", 0
.shutdown_str :
	db "Shutting down...", 0
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
	db 0 ; 0 = false, else = true
.executing_row : ; Current executing row in buffer.
	dw 0
.executing_seg : ; basically executing_row but in segment unit
	dw 0
.execution_buffer : ; Buffer for saving row to be executed.
	times BUFFER_WIDTH db 0
.compare_buffer_a : ; A ls8 buffer for value to be compared (to compare_buffer_b).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
.compare_buffer_b : ; A ls8 buffer for value to be compared (to compare_buffer_a).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
; --- commands ---
jump_uint_le_command_name :
	db "jule", 0
jump_uint_le_command :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jbe jump_command
	clc
	ret
jump_uint_l_command_name :
	db "jul", 0
jump_uint_l_command :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jb jump_command
	clc
	ret
jump_uint_ge_command_name :
	db "juge", 0
jump_uint_ge_command :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jae jump_command
	clc
	ret
jump_uint_g_command_name :
	db "jug", 0
jump_uint_g_command :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	ja jump_command
	clc
	ret
jump_uint_n_eq_command_name :
	db "june", 0
; If uints in compare buffer are not equal, jump command is executed.
jump_uint_n_eq_command :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	pop si
	jne jump_command
	clc
	ret
jump_uint_eq_command_name :
	db "jue", 0
; If uints in compare buffer are equal, jump command is executed.
jump_uint_eq_command :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	je jump_command
	clc
	ret
jump_str_n_eq_command_name :
	db "jsne", 0
; If strings in compare buffer are not equal, jump command is executed.
jump_str_n_eq_command :
	push si
	push di
	mov si, commands_data.compare_buffer_a
	mov di, commands_data.compare_buffer_b
	call ls8_equal
	pop di
	pop si
	jc jump_command
	clc
	ret
jump_str_eq_command_name :
	db "jse", 0
; If strings in compare buffer are equal, jump command is executed.
jump_str_eq_command :
	push si
	push di
	mov si, commands_data.compare_buffer_a
	mov di, commands_data.compare_buffer_b
	call ls8_equal
	pop di
	pop si
	jnc jump_command
	clc
	ret
compare_command_name :
	db "cmp", 0
; 1 <- value a
; 2 <- value b
compare_command :
	LS32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne commands_err.invalid_arg_num_err
	add si, 6
	call commands_consume_mark
	mov di, commands_data.compare_buffer_a
	clc
	call commands_read_strn
	jc commands_err.invalid_value_err
	call commands_consume_mark
	mov di, commands_data.compare_buffer_b
	clc
	call commands_read_strn
	jc commands_err.invalid_value_err
	clc
	ret
jump_command_name :
	db "jump", 0
; -1 <- nth row to be jump to
; 1? <- + if downward, - if upward (relative to the jump instruction)
jump_command :
	mov byte al, [commands_data.is_buffer_executing]
	cmp al, 0
	je commands_err.not_running_buffer_err ; command can only run in buffer
	LS32_GET_COUNT
	add si, 6
	cmp cx, 2
	je .absolute
	cmp cx, 3
	je .relative
	jmp commands_err.invalid_arg_num_err
.relative :
	call commands_consume_mark
	cmp cx, 1
	jne commands_err.invalid_value_err
	call commands_consume_mark_as_uint ; dx = displacement
	mov cx, [commands_data.executing_row] ; cx = current executing row
	mov byte al, [bx]
	cmp al, '+'
	je .downward
	cmp al, '-'
	je .upward
	jmp commands_err.invalid_value_err
.downward :
	add cx, dx
	mov dx, cx
	jmp .set_seg
.upward :
	sub cx, dx
	mov dx, cx
	jmp .set_seg
.absolute :
	call commands_consume_mark_as_uint ; dx = nth row to be jump to
.set_seg :
	cmp dx, BUFFER_HEIGHT
	jae commands_err.invalid_buffer_row_err
	call commands_set_executing_seg
	clc
	ret
run_buffer_command_name :
	db "run", 0
; n <- ignored
run_buffer_command :
	push es
	mov ax, ds
	mov es, ax
	mov ax, BUFFER_BEGIN_SEG ; running first buffer
	xor bx, bx ; current running line
	mov byte [commands_data.is_buffer_executing], 1
.loop :
	cmp ax, (BUFFER_BEGIN_SEG + BUFFER_SEG_COUNT)
	jae .loop_end
	cmp ax, BUFFER_BEGIN_SEG
	jb .loop_end
	mov word [commands_data.executing_row], bx
	mov word [commands_data.executing_seg], ax
; copy line from buffer to commands_data.execution_buffer
	push ds
	xor si, si
	mov di, commands_data.execution_buffer
	mov cx, BUFFER_WIDTH
	mov ds, ax
	cld
	rep movsb
	pop ds
; execute it
	mov si, commands_data.execution_buffer
	mov cx, BUFFER_WIDTH
	clc
	call interpreter_execute_strn
	jc .loop_end
; update current running row
	mov dx, [commands_data.executing_row]
	cmp dx, bx
	jne .executing_row_changed
	inc bx
	jmp .executing_row_changed_end
.executing_row_changed :
	mov bx, dx
.executing_row_changed_end :
; update current running seg
	mov dx, [commands_data.executing_seg]
	cmp dx, ax
	jne .executing_seg_changed
	add ax, BUFFER_SEG_PER_ROW
	jmp .executing_seg_changed_end
.executing_seg_changed :
	mov ax, dx
.executing_seg_changed_end :
	jmp .loop
.loop_end :
	mov byte [commands_data.is_buffer_executing], 0
	pop es
	clc
	ret
clear_buffer_command_name :
	db "clb", 0
clear_buffer_command :
	push es
	mov al, ' '
	xor bx, bx
	mov dx, BUFFER_SEC_COUNT
	mov si, [commands_data.active_buffer]
	mov cx, 512
.clear_loop :
	cmp dx, 0
	je .clear_loop_end
	mov es, si
	call byteset
	add si, (512 >> 4)
	dec dx
	jmp .clear_loop
.clear_loop_end :
	pop es
	clc
	ret
set_active_buffer_command_name :
	db "stb", 0
; 1 <- buffer to be set
set_active_buffer_command :
	LS32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne commands_err.invalid_arg_num_err
	add si, 6
	clc
	call commands_consume_mark_as_uint ; dx = buffer index
	jc commands_err.invalid_uint_err
	cmp dx, BUFFER_COUNT
	jae commands_err.invalid_buffer_err
	mov ax, BUFFER_SEG_COUNT
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [commands_data.active_buffer], ax
	clc
	ret
set_row_command_name :
	db "=", 0
; 1 <- row to be set
; 2 <- new row
set_row_command :
	LS32_GET_COUNT ; cx = args count
	cmp cx, 3 ; no args
	jne commands_err.invalid_arg_num_err
	add si, 6
	clc
	call commands_consume_mark_as_uint ; dx = row
	jc commands_err.invalid_uint_err
	cmp dx, BUFFER_HEIGHT
	jae commands_err.invalid_buffer_row_err
	call commands_consume_mark
	mov si, bx ; si = new row content
	cmp cx, BUFFER_WIDTH
	jae commands_err.value_too_long_err ; cx = content length
	mov ax, dx
	mov dx, BUFFER_SEG_PER_ROW
	mul dx
	add ax, [commands_data.active_buffer] ; ax = buffer row seg
; clear the row
	push es
	mov es, ax
	push cx
	mov cx, BUFFER_WIDTH
	xor bx, bx
	mov al, ' '
	call byteset
	pop cx
	xor di, di
	cld
	rep movsb
	pop es
	clc
	ret
list_buffer_command_name :
	db "lsb", 0
; 1? <- starting row
; 2? <- count
list_buffer_command :
	LS32_GET_COUNT ; cx = args count
	xor dx, dx ; default 1st arg
	mov ax, 5 ; default 2nd arg
	cmp cx, 1 ; no args
	jbe .list
	cmp cx, 2 ; have starting row
	je .list_with_start
	cmp cx, 3 ; have count
	je .list_with_count
	jmp commands_err.invalid_arg_num_err
.list_with_count :
	push si
	add si, 10 ; the third arg
	clc
	call commands_consume_mark_as_uint
	pop si
	jc commands_err.invalid_uint_err
	mov ax, dx ; ax = count
.list_with_start :
	add si, 6 ; the second arg
	clc
	call commands_consume_mark_as_uint ; dx = starting row
	jc commands_err.invalid_uint_err
.list :
	mov cx, ax ; cx = counter
	mov bx, dx ; bx = starting row ; dx = current line
	mov ah, MAGENTA
.list_loop :
	cmp cx, 0
	je .list_loop_end
	cmp dx, BUFFER_HEIGHT
	jae .list_loop_end
	call console_print_uint
	PRINT_CHAR ' '
	pusha
	push es
	push ds
; copy from buffer to video dump
; setup source
	mov ax, dx
	mov dx, BUFFER_SEG_PER_ROW
	mul dx
	add ax, [commands_data.active_buffer]
	mov es, ax
	xor si, si
; setup destination
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl ; bx = index
	shl bx, 1
	mov di, bx
	mov cx, CONSOLE_DUMP_SEG
	mov ds, cx
	mov cx, BUFFER_WIDTH
	xor ax, ax
	mov ah, BRIGHT
.mov_loop :
	mov byte al, [es : si]
	mov word [ds : di], ax
	inc si
	add di, 2
	dec cx
	jnz .mov_loop
	pop ds
	pop es
	popa
	PRINT_NL
	inc dx
	dec cx
	jmp .list_loop
.list_loop_end :
.end :
	clc
	ret
reset_stack_command_name :
	db "rst", 0
; n <- ignored
reset_stack_command :
	mov word [commands_data.stack_pointer], commands_data.stack
	ret
pop_stack_command_name :
	db "pop", 0
; n <- variables to be popped
pop_stack_command :
	LS32_GET_COUNT ; cx = args count
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count exluding the command
	add si, 6 ; si i= 1st arg
.pop_loop :
	cmp cx, 0
	je .end
	mov word di, [commands_data.stack_pointer]
	cmp di, commands_data.stack
	jbe commands_err.stack_empty_err
	clc
	call commands_consume_mark_as_uint ; dx = variable
	jc commands_err.invalid_uint_err
	cmp dx, VARIABLE_COUNT
	jae commands_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	push si
	push cx
	mov si, di
	sub si, VARIABLE_SIZE ; si = stack pointer
	mov word [commands_data.stack_pointer], si
	mov di, commands_data.variables
	add di, ax ; di = variable address
	mov cx, VARIABLE_SIZE
	cld
	rep movsb
	pop cx
	pop si
	dec cx
	jmp .pop_loop
.end :
	clc
	ret
push_stack_command_name :
	db "push", 0
; n <- variables to be pushed
push_stack_command :
	LS32_GET_COUNT ; cx = args count
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count excluding the command
	add si, 6 ; si = 1st arg
.push_loop :
	cmp cx, 0
	je .end
	mov word di, [commands_data.stack_pointer] ; di = pointer to top of the stack
	cmp di, commands_data.stack_pointer
	jae commands_err.stack_full_err
	clc
	call commands_consume_mark_as_uint ; dx = variable
	jc commands_err.invalid_uint_err
	cmp dx, VARIABLE_COUNT
	jae commands_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	push si
	push cx
	mov si, commands_data.variables
	add si, ax ; si = variable address
	mov cx, VARIABLE_SIZE
	cld
	rep movsb
	mov word [commands_data.stack_pointer], di
	pop cx
	pop si
	dec cx
	jmp .push_loop
.end :
	clc
	ret
set_command_name :
	db "set", 0
; 1 <- nth variable
; 2 <- value
set_command :
	LS32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne commands_err.invalid_arg_num_err
	add si, 6
	clc
	call commands_consume_mark_as_uint ; dx = variable
	jc commands_err.invalid_uint_err
	cmp dx, VARIABLE_COUNT
	jae commands_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, commands_data.variables
	add di, ax ; di = variable address
	call commands_consume_mark
	clc
	call commands_read_strn
	jc commands_err.invalid_value_err
	clc
	ret
shutdown_command_name :
	db "bye", 0
; n <- ignored
shutdown_command :
	mov bx, commands_data.shutdown_str
	call print_str
	mov ax, 0x5307
	mov cx, 3
	mov bx, 1
	int 0x15
.halt :
	cli
	hlt
	jmp .halt
	clc
	ret
say_command_name :
	db "say", 0
; -1 <- string to be printed
; 1? <- options
say_command :
	LS32_GET_COUNT
	mov ah, GREY ; ah = text color
	xor al, al ; al = number of new lines after print.
	add si, 6
	cmp cx, 2
	je .default
	cmp cx, 3
	je .set_option
	jmp commands_err.invalid_arg_num_err
.set_option :
	call commands_consume_mark
.option_detection_loop :
	cmp cx, 0
	je .default
	mov byte dl, [bx]
	cmp dl, 'n'
	jne .not_newline_option
	inc al
	jmp .continue_option_detection_loop
.not_newline_option :
; %1 <- character
; %2 <- color
%macro COLOR_OPTION 2
	cmp dl, %1
	jne %%end
	mov ah, %2
	jmp .continue_option_detection_loop
%%end :
%endmacro
	COLOR_OPTION 'd', BLACK
	COLOR_OPTION 'b', BLUE
	COLOR_OPTION 'v', GREEN
	COLOR_OPTION 'c', CYAN
	COLOR_OPTION 'r', RED
	COLOR_OPTION 'm', MAGENTA
	COLOR_OPTION 'y', YELLOW
	COLOR_OPTION 'g', GREY
	COLOR_OPTION 'B', (BRIGHT + BLUE)
	COLOR_OPTION 'V', (BRIGHT + GREEN)
	COLOR_OPTION 'C', (BRIGHT + CYAN)
	COLOR_OPTION 'R', (BRIGHT + RED)
	COLOR_OPTION 'M', (BRIGHT + MAGENTA)
	COLOR_OPTION 'Y', (BRIGHT + YELLOW)
	COLOR_OPTION 'G', BRIGHT
	COLOR_OPTION 'w', WHITE
%unmacro COLOR_OPTION 2
.continue_option_detection_loop :
	inc bx
	dec cx
	jmp .option_detection_loop
.default :
	call commands_consume_mark
	cmp cx, 0
	je .newline_loop
	mov si, bx
	mov byte dl, [si]
	cmp dl, '$'
	jne .not_var
; Reading variable to be output
	inc si
	dec cx
	clc
	call strn_to_uint
	jc commands_err.invalid_uint_err
	cmp dx, VARIABLE_COUNT
	jae commands_err.invalid_variable_err
	push ax
	mov al, VARIABLE_SIZE
	mul dl
	mov si, commands_data.variables
	add si, ax
	pop ax
	LS8_GET_COUNT
	add si, 2
	jmp .print_strn
.not_var :
	cmp dl, '\'
	jne .print_strn
; Skip first character if it is '\'
	inc si
	dec cx
.print_strn :
	call console_print_strn
.newline_loop :
	cmp al, 0
	je .end
	PRINT_NL
	dec al
	jmp .newline_loop
.end :
	clc
	ret
; --- subroutine ---
; Read strn to ls8 (accept variable referencing).
; bx <- string
; cx <- string length
; di <- ls8 to be output to
; cf -> set if fail
commands_read_strn :
	pusha
	cmp cx, 0
	je .success
	mov byte al, [bx]
	cmp al, '$'
	jne .not_var
; variable referencing
	mov si, bx
	inc si
	dec cx
	clc
	call strn_to_uint
	jc .fail
	cmp dx, VARIABLE_COUNT
	jae .fail
	mov al, VARIABLE_SIZE
	mul dl
	mov si, commands_data.variables
	add si, ax
	LS8_GET_COUNT
	xchg si, di ; di = variable ; si = ls8 output
	add di, 2
	jmp .set
.not_var :
	mov si, di
	mov di, bx
	cmp al, '\'
	jne .set
	inc di
	dec cx
.set :
	clc
	call ls8_set
	jc .fail
	jmp .success
.fail :
	stc
.success :
	popa
	ret
; Set executing row together with its corresponding executing segment.
; dx <- executing row
commands_set_executing_seg :
	push ax
	push dx
	mov word [commands_data.executing_row], dx
	mov ax, BUFFER_SEG_PER_ROW
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [commands_data.executing_seg], ax
	pop dx
	pop ax
	ret
; si <- current mark
; bx -> address of argument
; cx -> length of argument
; si -> next mark
commands_consume_mark :
	mov word cx, [si]
	add si, 2
	mov word bx, [si]
	add si, 2
	ret
; si <- current mark
; dx -> uint
; si -> next mark
; cf -> set if fail to convert to uint
commands_consume_mark_as_uint :
	push cx
	push bx
	mov word cx, [si]
	add si, 2
	mov word bx, [si]
	add si, 2
	xchg bx, si
	call strn_to_uint
	xchg bx, si
	pop bx
	pop cx
	ret
; There is so many repeating lines of code for handling err so I just put it all in one place.
commands_err :
.value_too_long_err :
	mov bx, commands_data.value_too_long_err_str
	jmp .print
.invalid_arg_num_err :
	mov bx, commands_data.invalid_arg_num_err_str
	jmp .print
.stack_full_err :
	mov bx, commands_data.stack_full_err_str
	jmp .print
.stack_empty_err :
	mov bx, commands_data.stack_empty_err_str
	jmp .print
.invalid_value_err :
	mov bx, commands_data.invalid_value_err_str
	jmp .print
.invalid_variable_err :
	mov bx, commands_data.invalid_variable_err_str
	jmp .print
.invalid_buffer_err :
	mov bx, commands_data.invalid_buffer_err_str
	jmp .print
.invalid_buffer_row_err :
	mov bx, commands_data.invalid_buffer_row_err_str
	jmp .print
.not_running_buffer_err :
	mov bx, commands_data.not_running_buffer_err_str
	jmp .print
.invalid_uint_err :
	mov bx, commands_data.invalid_uint_err_str
.print :
	mov byte al, [commands_data.is_buffer_executing]
	cmp al, 0
	je .not_running_buffer
	call print_err
	PRINT_CHAR ' '
	mov bx, commands_data.debug_show_row_str
	call print_str
	mov ah, MAGENTA
	mov dx, [commands_data.executing_row]
	call console_print_uint
	PRINT_CHAR ']'
	PRINT_NL
	jmp .end
.not_running_buffer :
	call print_err_ln
.end :
	stc
	ret
; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
%error "Variable size and count must be a byte."
%endif
%endif ; _COMMANDS_SUB_ASM_