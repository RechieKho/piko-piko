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

	; --- commands ---

dump_command_name:
	db "dump", 0 

; 1 <- nth variable 
dump_command:
	pusha 
	LS32_GET_COUNT ; cx = args count 
	cmp cx, 2 
	jne .invalid_arg_num_err
	add si, 6 
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	mov si, bx
	call strn_to_uint ; dx -> nth variable
	jc .invalid_uint_err
	cmp dx, VARIABLE_COUNT
	jae .invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov si, commands_data.variables 
	add si, ax ; si = variable address 
	LS8_GET_COUNT ; cx = variable length 
	mov bx, si 
	add bx, 2
	call print_n_str
	jmp .end
.invalid_variable_err:
	mov bx, commands_data.invalid_variable_err_str
	call print_err 
	jmp .end
.invalid_uint_err:
	clc
	mov bx, commands_data.invalid_uint_err_str
	call print_err 
	jmp .end
.invalid_arg_num_err:
	mov bx, commands_data.invalid_arg_num_err_str
	call print_err
.end:
	PRINT_NL
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
	jne .invalid_arg_num_err

	add si, 6 
	mov word cx, [si]
	add si, 2 
	mov word bx, [si]
	xchg bx, si 
	call strn_to_uint ; dx -> nth variable
	jc .invalid_uint_err
	xchg bx, si 
	cmp dx, VARIABLE_COUNT
	jae .invalid_variable_err
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
	jne .value_too_long_err
	xchg si, di
	call ls8_set 
	jc .value_too_long_err

	jmp .end
.value_too_long_err:
	clc
	mov bx, commands_data.value_too_long_err_str
	call print_err 
	jmp .end
.invalid_variable_err:
	mov bx, commands_data.invalid_variable_err_str
	call print_err 
	jmp .end
.invalid_uint_err:
	clc
	mov bx, commands_data.invalid_uint_err_str
	call print_err 
	jmp .end
.invalid_arg_num_err:
	mov bx, commands_data.invalid_arg_num_err_str
	call print_err
.end:
	PRINT_NL
	popa
	ret


shutdown_command_name:
  db "shutdown", 0 

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

; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
	%error "Variable size and count must be a byte."
%endif

%endif ; _COMMANDS_SUB_ASM_
