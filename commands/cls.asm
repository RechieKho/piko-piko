%ifndef _CLS_COM_ASM_
%define _CLS_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- command ---
@clearConsoleCommand_name :
	db "cls", 0
; n <- ignored
@clearConsoleCommand :
	push es
	mov bx, CONSOLE_DUMP_SEG
	mov es, bx
	mov cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	xor bx, bx
	xor ax, ax
	call wordset
	pop es
	xor dx, dx
	SET_CURSOR
	clc
	ret
%endif ; _CLS_COM_ASM_