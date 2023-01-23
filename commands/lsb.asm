%ifndef _LSB_COM_ASM_
%define _LSB_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@listBufferCommand_name :
	db "lsb", 0
; 1? <- starting row
; 2? <- count
@listBufferCommand :
	LIST32_GET_COUNT ; cx = args count
	xor dx, dx ; default 1st arg
	mov ax, 5 ; default 2nd arg
	cmp cx, 1 ; no args
	jbe .list
	cmp cx, 2 ; have starting row
	je .list_with_start
	cmp cx, 3 ; have count
	je .list_with_count
	jmp command_err.invalid_arg_num_err
.list_with_count :
	push si
	add si, 10 ; the third arg
	call commandConsumeMark
	clc
	call commandReadString
	jc .list_count_read_string_fail_err
	mov si, bx
	clc
	call stringToUint
.list_count_read_string_fail_err :
	pop si
	jc command_err.invalid_uint_err
	mov ax, dx ; ax = count
.list_with_start :
	add si, 6 ; the second arg
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = starting row
.list :
	mov cx, ax ; cx = counter
	mov bx, dx ; bx = starting row ; dx = current line
	mov ah, MAGENTA
.list_loop :
	cmp cx, 0
	je .list_loop_end
	cmp dx, BUFFER_HEIGHT
	jae .list_loop_end
	call consolePrintUint
	PRINT_CHAR ' '
	pusha
	push es
	push ds
; copy from buffer to video dump
; setup source
	mov ax, dx
	mov dx, BUFFER_SEG_PER_ROW
	mul dx
	add ax, [command_data.active_buffer]
	mov es, ax
	xor si, si
; setup destination
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl ; bx = index
	shl bx, 1
	mov di, bx
	mov cx, CONSOLE_DUMP_SEG
	mov ds, cx
	mov cx, BUFFER_WIDTH
	xor ax, ax
	mov ah, BRIGHT
.mov_loop :
	mov byte al, [es : si]
	mov word [ds : di], ax
	inc si
	add di, 2
	dec cx
	jnz .mov_loop
	pop ds
	pop es
	popa
	PRINT_NL
	inc dx
	dec cx
	jmp .list_loop
.list_loop_end :
.end :
	clc
	ret
%endif ; _LSB_COM_ASM_