%ifndef _PUSH_COM_ASM_
%define _PUSH_COM_ASM_
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
	mov word di, [stack_data.stack_pointer] ; di = pointer to top of the stack
	cmp di, stack_data.stack_pointer
	jae err.stack_full_err
	VAR_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	push si
	push cx
	mov si, var_data.variables
	add si, ax ; si = variable address
	mov cx, VAR_SIZE
	cld
	rep movsb
	mov word [stack_data.stack_pointer], di
	pop cx
	pop si
	dec cx
	jmp .push_loop
.end :
	clc
	ret
%endif ; _PUSH_COM_ASM_