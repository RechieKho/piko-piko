%ifndef _CLB_COM_ASM_
%define _CLB_COM_ASM_
; --- commands ---
@clearBufferCommand_name :
	db "clb", 0
@clearBufferCommand :
	push es
	mov al, ' '
	xor bx, bx
	mov dx, BUFFER_SEC_COUNT
	mov si, [buffer_data.active_buffer]
	mov cx, SECTOR_SIZE
.clear_loop :
	cmp dx, 0
	je .clear_loop_end
	mov es, si
	call byteset
	add si, (SECTOR_SIZE >> 4)
	dec dx
	jmp .clear_loop
.clear_loop_end :
	pop es
	clc
	ret
%endif ; _CLB_COM_ASM_