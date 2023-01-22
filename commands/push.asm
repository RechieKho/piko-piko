%ifndef _PUSH_COM_ASM_
%define _PUSH_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@pushStackCommand_name :
	db "push", 0
; n <- variables to be pushed
@pushStackCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count excluding the command
	add si, 6 ; si = 1st arg
.push_loop :
	cmp cx, 0
	je .end
	mov word di, [command_data.stack_pointer] ; di = pointer to top of the stack
	cmp di, command_data.stack_pointer
	jae command_err.stack_full_err
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	push si
	push cx
	mov si, command_data.variables
	add si, ax ; si = variable address
	mov cx, VARIABLE_SIZE
	cld
	rep movsb
	mov word [command_data.stack_pointer], di
	pop cx
	pop si
	dec cx
	jmp .push_loop
.end :
	clc
	ret
%endif ; _PUSH_COM_ASM_