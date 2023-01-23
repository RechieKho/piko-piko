%ifndef _EQUAL_COM_ASM_
%define _EQUAL_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@setRowCommand_name :
	db "=", 0
; 1 <- row to be set
; 2 <- new row
@setRowCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3 ; no args
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = row
	cmp dx, BUFFER_HEIGHT
	jae command_err.invalid_buffer_row_err
	COMMANDS_CONSUME_MARK_READ_STRN
	mov si, bx ; si = new row content
	cmp cx, BUFFER_WIDTH
	jae command_err.value_too_big_err ; cx = content length
	mov ax, dx
	mov dx, BUFFER_SEG_PER_ROW
	mul dx
	add ax, [command_data.active_buffer] ; ax = buffer row seg
; clear the row
	push es
	mov es, ax
	push cx
	mov cx, BUFFER_WIDTH
	xor bx, bx
	mov al, ' '
	call byteset
	pop cx
	xor di, di
	cld
	rep movsb
	pop es
	clc
	ret
%endif ; _EQUAL_COM_ASM_