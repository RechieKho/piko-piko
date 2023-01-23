%ifndef _STB_COM_ASM_
%define _STB_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@setActiveBufferCommand_name :
	db "stb", 0
; 1 <- buffer to be set
@setActiveBufferCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = buffer index
	cmp dx, BUFFER_COUNT
	jae command_err.invalid_buffer_err
	mov ax, BUFFER_SEG_COUNT
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [command_data.active_buffer], ax
	clc
	ret
%endif ; _STB_COM_ASM_