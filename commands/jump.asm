%ifndef _JUMP_COM_ASM_
%define _JUMP_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@jumpCommand_name :
	db "jump", 0
; -1 <- nth row to be jump to
; 1? <- + if downward, - if upward (relative to the jump instruction)
@jumpCommand :
	mov byte al, [command_data.is_buffer_executing]
	cmp al, 0
	je command_err.not_running_buffer_err ; command can only run in buffer
	LIST32_GET_COUNT
	add si, 6
	cmp cx, 2
	je .absolute
	cmp cx, 3
	je .relative
	jmp command_err.invalid_arg_num_err
.relative :
	COMMANDS_CONSUME_MARK_READ_STRN
	cmp cx, 1
	jne command_err.invalid_value_err
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = displacement
	mov cx, [command_data.executing_row] ; cx = current executing row
	mov byte al, [bx]
	cmp al, '+'
	je .downward
	cmp al, '-'
	je .upward
	jmp command_err.invalid_value_err
.downward :
	add cx, dx
	mov dx, cx
	jmp .set_seg
.upward :
	sub cx, dx
	mov dx, cx
	jmp .set_seg
.absolute :
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = nth row to be jump to
.set_seg :
	cmp dx, BUFFER_HEIGHT
	jae command_err.invalid_buffer_row_err
	call commandSetExecutingSegment
	clc
	ret
%endif ; _JUMP_COM_ASM_