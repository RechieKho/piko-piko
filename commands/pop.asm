%ifndef _POP_COM_ASM_
%define _POP_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@popStackCommand_name :
	db "pop", 0
; n <- variables to be popped
@popStackCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count exluding the command
	add si, 6 ; si i= 1st arg
.pop_loop :
	cmp cx, 0
	je .end
	mov word di, [command_data.stack_pointer]
	cmp di, command_data.stack
	jbe command_err.stack_empty_err
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	push si
	push cx
	mov si, di
	sub si, VARIABLE_SIZE ; si = stack pointer
	mov word [command_data.stack_pointer], si
	mov di, command_data.variables
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
%endif ; _POP_COM_ASM_