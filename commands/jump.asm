%ifndef _JUMP_COM_ASM_
%define _JUMP_COM_ASM_
; --- commands ---
@jumpCommand_name :
	db "jump", 0
; -1 <- nth row to be jump to
; 1? <- + if downward, - if upward (relative to the jump instruction)
@jumpCommand :
	mov byte al, [buffer_data.is_buffer_executing]
	cmp al, 0
	je err.not_running_buffer_err ; command can only run in buffer
	LIST32_GET_COUNT
	add si, 6
	cmp cx, 2
	je .absolute
	cmp cx, 3
	je .relative
	jmp err.invalid_arg_num_err
.relative :
	VAR_CONSUME_MARK_READ_STRN
	cmp cx, 1
	jne err.invalid_value_err
	VAR_CONSUME_MARK_READ_UINT ; dx = displacement
	mov cx, [buffer_data.executing_row] ; cx = current executing row
	mov byte al, [bx]
	cmp al, '+'
	je .downward
	cmp al, '-'
	je .upward
	jmp err.invalid_value_err
.downward :
	add cx, dx
	mov dx, cx
	jmp .set_seg
.upward :
	sub cx, dx
	mov dx, cx
	jmp .set_seg
.absolute :
	VAR_CONSUME_MARK_READ_UINT ; dx = nth row to be jump to
.set_seg :
	cmp dx, BUFFER_HEIGHT
	jae err.invalid_buffer_row_err
	call bufferSetExecutingSegment
	clc
	ret
%endif ; _JUMP_COM_ASM_