%ifndef _POP_COM_ASM_
%define _POP_COM_ASM_
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
	mov word di, [stack_data.stack_pointer]
	cmp di, stack_data.stack
	jbe err.stack_empty_err
	VAR_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VAR_COUNT
	jae err.invalid_variable_err
	mov al, VAR_SIZE
	mul dl
	push si
	push cx
	mov si, di
	sub si, VAR_SIZE ; si = stack pointer
	mov word [stack_data.stack_pointer], si
	mov di, var_data.variables
	add di, ax ; di = variable address
	mov cx, VAR_SIZE
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