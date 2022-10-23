%ifndef _COMMANDS_SUB_ASM_
%define _COMMANDS_SUB_ASM_

	; NOTE: YOU MUST COMMANDS_INIT BEFORE USING ANYTHING IN THIS MODULE

	; each commands expecting:
	; si <- ls32 of marks point to the arguments

	;        --- modules ---
	%include "print_sub.asm"
	%include "ls32_sub.asm"
	%include "ls8_sub.asm"
	%include "str_sub.asm"
	%include "type_macros.asm"
	%include "console_sub.asm"
	%include "interpreter_sub.asm"

; --- macros ---
%define VARIABLE_SIZE 0x40 ; MUST within a byte
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
%%loop:
	LS8_INIT (VARIABLE_SIZE - 1)
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
%%set_loop:
	cmp dx, 0 
	je %%set_loop_end
	mov es, si
	call byteset
	add si, (512 >> 4)
	dec dx 
	jmp %%set_loop
%%set_loop_end:
	pop es
	popa
%endmacro 

; --- data ---
commands_data:
.stack_empty_err_str:
	db "Stack is empty.", 0
.stack_full_err_str:
	db "Stack is full.", 0
.value_too_long_err_str:
	db "Value too long.", 0
.invalid_variable_err_str:
	db "Invalid variable.", 0
.invalid_buffer_err_str:
	db "Invalid buffer.", 0
.invalid_buffer_row_err_str:
	db "Invalid buffer row.", 0
.invalid_arg_num_err_str:
	db "Invalid number of arguments.", 0
.invalid_uint_err_str:
	db "Invalid number.", 0
.shutdown_str:
	db "Shutting down...", 0
.variables:
	times (VARIABLE_SIZE * VARIABLE_COUNT) db 0
.stack:
	times (STACK_MAX_VAR * VARIABLE_SIZE) db 0
.stack_pointer:
	dw .stack
.active_buffer:
	dw BUFFER_BEGIN_SEG
.is_running_buffer:
	db 0 ; 0 = false ; else = true
.buffer_row:
	times BUFFER_WIDTH db 0

	; --- commands ---
run_buffer_command_name:
	db "run", 0 

run_buffer_command:
	pusha 
	push es
	mov ax, ds 
	mov es, ax
	mov ax, BUFFER_BEGIN_SEG ; running first buffer 
	mov dx, BUFFER_HEIGHT
	mov byte [commands_data.is_running_buffer], 1
.loop: 
	cmp dx, 0 
	je .loop_end 
	; copy line from buffer to commands_data.buffer_row
	push ds
	xor si, si
	mov di, commands_data.buffer_row
	mov cx, BUFFER_WIDTH
	mov ds, ax
	cld
	rep movsb
	pop ds
	; execute it
	mov si, commands_data.buffer_row
	mov cx, BUFFER_WIDTH
	clc
	call interpreter_execute_strn
	jc .loop_end
	add ax, BUFFER_SEG_PER_ROW
	dec dx 
	jmp .loop
.loop_end:
	mov byte [commands_data.is_running_buffer], 0
	pop es
	popa
	ret

clear_buffer_command_name:
	db "clb", 0 

clear_buffer_command:
	pusha 
	push es 
	mov al, ' '
	xor bx, bx 
	mov dx, BUFFER_SEC_COUNT
	mov si, [commands_data.active_buffer]
	mov cx, 512 
.clear_loop:
	cmp dx, 0 
	je .clear_loop_end 
	mov es, si 
	call byteset 
	add si, (512 >> 4)
	dec dx 
	jmp .clear_loop
.clear_loop_end:
	pop es
	popa 
	ret

set_active_buffer_command_name:
	db "stb", 0 

; 1 <- buffer to be set 
set_active_buffer_command:
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

set_row_command_name:
	db "=", 0 

; 1 <- row to be set
; n <- new row
set_row_command:
	pusha 
	LS32_GET_COUNT ; cx = args count 
	cmp cx, 1 ; no args
	je commands_err.invalid_arg_num_err
	
	mov ax, cx ; ax = args count (temp)
	add si, 6 

	clc
	call commands_consume_mark_as_uint ; dx = uint
	jc commands_err.invalid_uint_err
	cmp dx, BUFFER_HEIGHT
	jae commands_err.invalid_buffer_row_err
	mov cx, ax ; cx = args count

	mov ax, dx 
	mov dx, BUFFER_SEG_PER_ROW
	mul dx 
	add ax, [commands_data.active_buffer] ; ax = buffer seg
	xor di, di

	push es 
	mov es, ax 

	; clear the row
	push cx
	mov cx, BUFFER_WIDTH
	xor bx, bx
	mov al, ' ' 
	call byteset
	pop cx

	xor di, di
	sub cx, 2
.set_loop:
	cmp cx, 0
	je .set_loop_end 

	push cx 
	call commands_consume_mark
.write_loop:
	cmp di, BUFFER_WIDTH
	jae .write_loop_end ; the row is fully filled
	cmp cx, 0 
	je .write_loop_end
	mov byte al, [bx]
	mov byte [es:di], al
	inc bx 
	inc di 
	dec cx 
	jmp .write_loop
.write_loop_end:
	pop cx 
	inc di 
	dec cx
	jmp .set_loop
.set_loop_end:
	pop es
	popa 
	ret


list_buffer_command_name:
	db "lsb", 0

; 1? <- starting row
; 2? <- count
list_buffer_command:
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

.list_with_count:
	push si 
	add si, 10 ; the third arg
	clc
	call commands_consume_mark_as_uint
	pop si
	jc commands_err.invalid_uint_err
	mov ax, dx ; ax = count
.list_with_start:
	add si, 6 ; the second arg 
	clc
	call commands_consume_mark_as_uint ; dx = starting row
	jc commands_err.invalid_uint_err
.list:
	mov cx, ax ; cx = counter
	mov bx, dx ; bx = starting row ; dx = current line 
	mov ah, MAGENTA
.list_loop:
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
.mov_loop:
	mov byte al, [es:si]
	mov word [ds:di], ax
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
.list_loop_end:
.end:
	popa 
	ret

reset_stack_command_name:
	db "rst", 0

; n <- ignored
reset_stack_command:
	mov word [commands_data.stack_pointer], commands_data.stack
	ret

pop_stack_command_name:
	db "pop", 0 

; n <- variables to be popped
pop_stack_command:
	pusha 
	LS32_GET_COUNT ; cx = args count 
	cmp cx, 1 
	jbe .end 
	dec cx ; cx = args count exluding the command 
	add si, 6 ; si i= 1st arg 

.pop_loop:
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

.end:
	popa 
	ret

push_stack_command_name:
	db "push", 0 

; n <- variables to be pushed
push_stack_command:
	pusha 
	LS32_GET_COUNT ; cx = args count 
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count excluding the command
	add si, 6 ; si = 1st arg

.push_loop:
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

.end:
	popa 
	ret

dump_command_name:
	db "dump", 0 

; 1 <- nth variable 
dump_command:
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
.end:
	popa 
	ret

set_command_name:
	db "set", 0 

; 1 <- nth variable
; 2 <- value 
set_command: 
	pusha 
	LS32_GET_COUNT ; cx = args count 
	cmp  cx, 3
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


shutdown_command_name:
  db "bye", 0 

shutdown_command:
  mov bx, commands_data.shutdown_str 
  call print_str
  mov ax, 0x5307
  mov cx, 3
  mov bx, 1 
  int 0x15
  .halt:
    cli
    hlt
    jmp .halt
  ret

say_command_name:
	db "say", 0

say_command:
	pusha
	LS32_GET_COUNT
	dec cx; cx = number of arguments excluding itself
	add si, 6; si = arguments after its name

.loop:
	cmp cx, 0
	je  .end

	push cx
	call commands_consume_mark
	call print_n_str
	pop  cx
	PRINT_CHAR ' '

	dec cx
	jmp .loop

.end:
	PRINT_NL
	popa
	ret

; --- subroutine --- 
; si <- current mark
; bx -> address of argument 
; cx -> length of argument
; si -> next mark
commands_consume_mark:
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	add si, 2 
	ret

; si <- current mark 
; dx -> uint 
; si -> next mark
; cf -> set if fail to convert to uint
commands_consume_mark_as_uint:
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
commands_err:
.value_too_long_err:
	mov bx, commands_data.value_too_long_err_str
	jmp .end
.invalid_arg_num_err:
	mov bx, commands_data.invalid_arg_num_err_str
	jmp .end
.stack_full_err:
	mov bx, commands_data.stack_full_err_str
	jmp .end
.stack_empty_err:
	mov bx, commands_data.stack_empty_err_str 
	jmp .end
.invalid_variable_err: 
	mov bx, commands_data.invalid_variable_err_str
	jmp .end
.invalid_buffer_err:
	mov bx, commands_data.invalid_buffer_err_str
	jmp .end
.invalid_buffer_row_err:
	mov bx, commands_data.invalid_buffer_row_err_str
	jmp .end
.invalid_uint_err:
	mov bx, commands_data.invalid_uint_err_str
.end: 
	call print_err_ln 
	stc
	popa 
	ret


; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
	%error "Variable size and count must be a byte."
%endif

%endif ; _COMMANDS_SUB_ASM_
