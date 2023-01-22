%ifndef _BYE_COM_ASM_
%define _BYE_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- data ---
bye_com_data :
.bye_c_string :
	db "Shutting down... Wait, I am still alive? Maybe holding down the power button will completely kill me.", 0
; --- commands ---
@byeCommand_name :
	db "bye", 0
; n <- ignored
@byeCommand :
	mov bx, bye_com_data.bye_c_string
	call printCString
	PRINT_NL
	mov ax, 0x5307
	mov cx, 0x03
	mov bx, 0x01
	int 0x15
	clc
	ret
%endif ; _BYE_COM_ASM_