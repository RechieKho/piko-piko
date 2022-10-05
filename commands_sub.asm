%ifndef _COMMANDS_SUB_ASM_
%define _COMMANDS_SUB_ASM_

	; each commands expecting:
	; si <- ls32 of marks point to the arguments

	;        --- modules ---
	%include "print_sub.asm"
	%include "ls32_sub.asm"

	; -- commands ---

say_command_name:
	db "say", 0

say_command:
	pusha
	LS32_GET_COUNT
	dec cx; cx = number of arguments excluding itself
	add si, 6; si = arguments after its name

.loop:
	cmp cx, 0
	je  .end

	push cx
	mov  word cx, [si]; cx = length of first argument
	add  si, 2
	mov  word bx, [si]; bx = argument
	add  si, 2
	call print_n_str
	pop  cx
	PRINT_CHAR ' '

	dec cx
	jmp .loop

.end:
	PRINT_NL
	popa
	ret

%endif ; _COMMANDS_SUB_ASM_
