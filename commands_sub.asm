%ifndef _COMMANDS_SUB_ASM_
%define _COMMANDS_SUB_ASM_
; NOTE : YOU MUST COMMANDS_INIT BEFORE USING ANYTHING IN THIS MODULE
; each commands expecting :
; si <- ls32 of marks point to the arguments
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
%macro COMMANDS_INIT 0
	VAR_INIT
	BUFFER_INIT
%endmacro
; initiate variables
%macro VAR_INIT 0
	pusha
	mov di, commands_data.variables
	mov cx, VARIABLE_COUNT
%%loop :
	LS8_INIT VARIABLE_CAPACITY
	add di, VARIABLE_SIZE
	dec cx
	jnz %%loop
	popa
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
	times (VARIABLE_SIZE * VARIABLE_COUNT) db 0
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
; --- commands ---
jump_command_name :
	db "jump", 0
; -1 <- nth row to be jump to
; 1? <- + if downward, - if upward (relative to the jump instruction)
jump_command :
	pusha
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
	popa
	ret
run_buffer_command_name :
	db "run", 0
; n <- ignored
run_buffer_command :
	pusha
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
	popa
	ret
clear_buffer_command_name :
	db "clb", 0
clear_buffer_command :
	pusha
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
	popa
	ret
set_active_buffer_command_name :
	db "stb", 0
; 1 <- buffer to be set
set_active_buffer_command :
	pusha
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
	popa
	ret
set_row_command_name :
	db "=", 0
; 1 <- row to be set
; 2 <- new row
set_row_command :
	pusha
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
	popa
	ret
list_buffer_command_name :
	db "lsb", 0
; 1? <- starting row
; 2? <- count
list_buffer_command :
	pusha
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
	popa
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
	pusha
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
	popa
	ret
push_stack_command_name :
	db "push", 0
; n <- variables to be pushed
push_stack_command :
	pusha
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
	popa
	ret
dump_command_name :
	db "dump", 0
; 1 <- nth variable
dump_command :
	pusha
	LS32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne commands_err.invalid_arg_num_err
	add si, 6
	clc
	call commands_consume_mark_as_uint ; dx = variable
	jc commands_err.invalid_uint_err
	cmp dx, VARIABLE_COUNT
	jae commands_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov si, commands_data.variables
	add si, ax ; si = variable address
	LS8_GET_COUNT ; cx = variable length
	mov bx, si
	add bx, 2
	call print_n_str
	PRINT_NL
.end :
	popa
	ret
set_command_name :
	db "set", 0
; 1 <- nth variable
; 2 <- value
set_command :
	pusha
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
	mov si, bx
	cmp ch, 0
	jne commands_err.value_too_long_err
	xchg si, di
	clc
	call ls8_set
	jc commands_err.value_too_long_err
	popa
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
	ret
say_command_name :
	db "say", 0
; n <- string to be printed
say_command :
	pusha
	LS32_GET_COUNT
	dec cx ; cx = number of arguments excluding itself
	add si, 6 ; si = arguments after its name
.loop :
	cmp cx, 0
	je .end
	push cx
	call commands_consume_mark
	call print_n_str
	pop cx
	PRINT_CHAR ' '
	dec cx
	jmp .loop
.end :
	PRINT_NL
	popa
	ret
; --- subroutine ---
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
	popa
	ret
; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
%error "Variable size and count must be a byte."
%endif
%endif ; _COMMANDS_SUB_ASM_