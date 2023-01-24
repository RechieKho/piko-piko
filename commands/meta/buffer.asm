%ifndef _BUFFER_META_ASM_
%define _BUFFER_META_ASM_
; --- modules ---
%include "type_macros.asm"
%include "mem_sub.asm"
; --- macros ---
; initiate buffer
%macro BUFFER_INIT 0
	pusha
	push es
	mov al, ' '
	xor bx, bx
	mov dx, (BUFFER_SEC_COUNT * BUFFER_COUNT)
	mov si, BUFFER_BEGIN_SEG
	mov cx, SECTOR_SIZE
%%set_loop :
	cmp dx, 0
	je %%set_loop_end
	mov es, si
	call byteset
	add si, (SECTOR_SIZE >> 4)
	dec dx
	jmp %%set_loop
%%set_loop_end :
	pop es
	popa
%endmacro
; --- data ---
buffer_data :
.active_buffer :
	dw BUFFER_BEGIN_SEG
.is_buffer_executing :
	db 0 ; 0 = false, else = true
.executing_row : ; Current executing row in buffer.
	dw 0
.executing_seg : ; basically executing_row but in segment unit
	dw 0
.execution_buffer : ; Buffer for saving row to be executed.
	times BUFFER_WIDTH db 0
; --- subroutine ---
; Set executing row together with its corresponding executing segment.
; dx <- executing row
bufferSetExecutingSegment :
	push ax
	push dx
	mov word [buffer_data.executing_row], dx
	mov ax, BUFFER_SEG_PER_ROW
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [buffer_data.executing_seg], ax
	pop dx
	pop ax
	ret
; --- checks ---
%if (VAR_CAPACITY < BUFFER_WIDTH)
%error "Variable too small for buffer row."
%endif
%endif ; _BUFFER_META_ASM_