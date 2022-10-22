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

; --- macros ---
%define VARIABLE_SIZE 0x40 ; MUST within a byte
%define VARIABLE_COUNT 0x1a ; MUST within a byte
%define STACK_MAX_VAR (VARIABLE_COUNT * 5) ; number of variable able to store on stack

%macro COMMANDS_INIT 0 
	VAR_INIT
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
.invalid_arg_num_err_str:
	db "Invalid number of arguments.", 0
.invalid_uint_err_str:
	db "Invalid number.", 0
.shutdown_str:
	db "Shutting down...", 0
.variables:
	resb (VARIABLE_SIZE * VARIABLE_COUNT)
.stack:
	resb (STACK_MAX_VAR * VARIABLE_SIZE)
.stack_pointer:
	dw .stack

	; --- commands ---

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

	push cx 
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	add si, 2
	xchg bx, si
	call strn_to_uint
	pop cx
	jc commands_err.invalid_uint_err
	xchg bx, si
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

	push cx
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	add si, 2
	xchg bx, si
	call strn_to_uint
	pop cx
	jc commands_err.invalid_uint_err
	xchg bx, si
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
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	mov si, bx
	call strn_to_uint ; dx -> nth variable
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
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	xchg bx, si 
	call strn_to_uint ; dx -> nth variable
	jc commands_err.invalid_uint_err
	xchg bx, si 
	cmp dx, VARIABLE_COUNT
	jae commands_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, commands_data.variables 
	add di, ax ; di = variable address 

	add si, 2
	mov word cx, [si]
	add si, 2
	mov word bx, [si]
	mov si, bx 
	cmp ch, 0
	jne commands_err.value_too_long_err
	xchg si, di
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
	mov  word cx, [si]; cx = length of first argument
	add  si, 2
	mov  word bx, [si]; bx = argument
	add  si, 2
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
.invalid_uint_err:
	mov bx, commands_data.invalid_uint_err_str
.end: 
	clc
	call print_err_ln 
	popa 
	ret


; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
	%error "Variable size and count must be a byte."
%endif

%endif ; _COMMANDS_SUB_ASM_
