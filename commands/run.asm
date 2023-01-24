%ifndef _RUN_COM_ASM_
%define _RUN_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@runBufferCommand_name :
	db "run", 0
; n <- ignored
@runBufferCommand :
	push es
	mov ax, ds
	mov es, ax
	mov ax, BUFFER_BEGIN_SEG ; running first buffer
	xor bx, bx ; current running line
	mov byte [command_data.is_buffer_executing], 1
.loop :
	cmp ax, (BUFFER_BEGIN_SEG + BUFFER_SEG_COUNT)
	jae .loop_end
	cmp ax, BUFFER_BEGIN_SEG
	jb .loop_end
	mov word [command_data.executing_row], bx
	mov word [command_data.executing_seg], ax
; copy line from buffer to command_data.execution_buffer
	push ds
	xor si, si
	mov di, command_data.execution_buffer
	mov cx, BUFFER_WIDTH
	mov ds, ax
	cld
	rep movsb
	pop ds
; execute it
	mov si, command_data.execution_buffer
	mov cx, BUFFER_WIDTH
	clc
	call interpreterExecuteString
	jc .loop_end
; update current running row
	mov dx, [command_data.executing_row]
	cmp dx, bx
	jne .executing_row_changed
	inc bx
	jmp .executing_row_changed_end
.executing_row_changed :
	mov bx, dx
.executing_row_changed_end :
; update current running seg
	mov dx, [command_data.executing_seg]
	cmp dx, ax
	jne .executing_seg_changed
	add ax, BUFFER_SEG_PER_ROW
	jmp .executing_seg_changed_end
.executing_seg_changed :
	mov ax, dx
.executing_seg_changed_end :
	jmp .loop
.loop_end :
	mov byte [command_data.is_buffer_executing], 0
	pop es
	clc
	ret
%endif ; _RUN_COM_ASM_