%ifndef _INTERPRETER_SUB_ASM_
%define _INTERPRETER_SUB_ASM_
; --- modules ---
%include "ls32_sub.asm"
%include "ls8_sub.asm"
%include "ls16_sub.asm"
%include "str_sub.asm"
%include "print_sub.asm"
%include "commands_sub.asm"
%include "console_sub.asm"
; --- macros ---
%define NORMAL_COLOR (YELLOW)
%define STRING_COLOR (GREEN)
%define SYMBOL_COLOR (WHITE)
; --- data ---
interpreter_data :
.marks :
; a ls32. each slot stores address to the begining of sub-string and the length
	times 1 dw 0
	times LS32_MAX dd 0
.splitting_chars : ; characters that splits string into sub-strings (separator)
	db " ", 0
.standalone_chars : ; character that is always alone
	db "=", 0
.str_chars : ; character that initiate or terminate strings
	db 0x22, 0x27, 0x60, 0
.commands_table :
; address to the command name and its corresponding function
	dw say_command_name, say_command
	dw set_command_name, set_command
	dw dump_command_name, dump_command
	dw push_stack_command_name, push_stack_command
	dw pop_stack_command_name, pop_stack_command
	dw reset_stack_command_name, reset_stack_command
	dw jump_command_name, jump_command
	dw list_buffer_command_name, list_buffer_command
	dw set_row_command_name, set_row_command
	dw clear_buffer_command_name, clear_buffer_command
	dw set_active_buffer_command_name, set_active_buffer_command
	dw run_buffer_command_name, run_buffer_command
	dw shutdown_command_name, shutdown_command
	dw 0
.invalid_command_err_str :
	db "Invalid command.", 0
; --- subroutines ---
; print marks
interpreter_print_marks :
	pusha
	mov si, interpreter_data.marks
	LS32_GET_COUNT ; cx = count of marks
	add si, 2 ; si = begining of marks
	PRINT_CHAR '['
.loop :
	cmp cx, 0
	je .loop_end
	push cx
	mov word cx, [si] ; cx = length of string
	add si, 2
	mov word bx, [si] ; bx = string
	add si, 2
	call print_n_str
	pop cx
	PRINT_CHAR ','
	dec cx
	jmp .loop
.loop_end :
	PRINT_CHAR ']'
	popa
	ret
; execute command string
; si <- address of string (ls8)
interpreter_execute :
	call interpreter_mark
	call interpreter_execute_mark
	ret
; execute command strn
; si <- address of string
; cx <- length of string
interpreter_execute_strn :
	call interpreter_mark_strn
	call interpreter_execute_mark
	ret
; execute command from interpreter_data.marks
interpreter_execute_mark :
	pusha
	mov si, interpreter_data.marks
	LS32_GET_COUNT
	cmp cx, 0
	je .end ; No argument, just end it.
	add si, 2
	mov word cx, [si] ; cx = length of first argument
	add si, 2
	mov word dx, [si]
	mov si, dx ; si = address of first argument
	mov bx, interpreter_data.commands_table
.loop_commands_table :
	mov word di, [bx] ; di = command name from commands table
	cmp di, 0
	je .invalid_command_err
; compare first token with command name
; si <- address of first argument [retained]
; cx <- length of first argument [retained]
; di <- command name
	push si
	push cx
.loop_cmp_command_char :
	mov byte al, [di] ; al = current character of command name
	cmp al, 0
	je .cmp_command_length
	cmp cx, 0
	je .loop_end
	mov byte ah, [si] ; ah = current character of first argument
	cmp al, ah
	jne .loop_end
	inc di
	inc si
	dec cx
	jmp .loop_cmp_command_char
.cmp_command_length :
	cmp cx, 0
	jne .loop_end
; First argument have the same length and same character sequence
; execute command function and end.
	pop cx
	pop si
	add bx, 2
	mov si, interpreter_data.marks
	mov di, [bx]
	pusha
; PRINT_WORD di
; PRINT_CHAR ' '
; PRINT_WORD say_command
	call di ; call function
	popa
	jmp .end
.loop_end :
	pop cx
	pop si
	add bx, 4
	jmp .loop_commands_table
.invalid_command_err :
; print error
	mov bx, interpreter_data.invalid_command_err_str
	jmp commands_err.print ; jmping to label from other files : 0
.end :
	popa
	ret
; mark the subs-strings in the strn given, output into interpreter_data.marks
; si <- address of string
; cx <- length of string
interpreter_mark_strn :
	pusha
	mov di, interpreter_data.marks
	LS32_INIT
	mov bx, si ; bx = address of begining of sub-string
	xor dx, dx ; dx = length of sub-string
	xor ah, ah ; ah = current str char
.loop :
	cmp cx, 0
	je .loop_end
	mov al, [si] ; al = current character
	cmp ah, 0
	je .not_processing_str
	cmp ah, al
	je .str_end
	inc dx
	jmp .skip_switch
.str_end :
	push si
	mov si, interpreter_data.marks
	mov ax, bx
	LS32_APPEND dx, ax
	pop si
	add bx, dx
	inc bx
	xor ax, ax
	xor dx, dx
	jmp .skip_switch
.not_processing_str :
	push si ; >> BEGIN SWITCH <<
	mov si, interpreter_data.splitting_chars
	call str_has_char
	jc .is_splitting_char
	mov si, interpreter_data.standalone_chars
	call str_has_char
	jc .is_standalone_char
	mov si, interpreter_data.str_chars
	call str_has_char
	jc .is_str_char
	inc dx
	jmp .switch_end
.is_splitting_char :
	mov si, interpreter_data.marks
; write into marks
	cmp dx, 0
	je .empty_mark
	push ax
	mov ax, bx
	LS32_APPEND dx, ax
	pop ax
; update state
.empty_mark :
	add bx, dx
	inc bx
	xor dx, dx
	jmp .switch_end
.is_standalone_char :
	mov si, interpreter_data.marks
; write sub-string before standalone char into marks
	cmp dx, 0
	je .mark_standalone_char
	push ax
	mov ax, bx
	LS32_APPEND dx, ax
	pop ax
; write the standalone char into marks
.mark_standalone_char :
	add bx, dx
	push ax
	mov ax, bx
	mov dx, 1
	LS32_APPEND dx, ax
	pop ax
; update states
	inc bx
	xor dx, dx
	jmp .switch_end
.is_str_char :
	mov si, interpreter_data.marks
; write sub-string before str char into marks
	cmp dx, 0
	je .start_str
	push ax
	mov ax, bx
	LS32_APPEND dx, ax
	pop ax
; set current str char
.start_str :
	push bx
	mov bh, al
	mov ah, bh
	pop bx
; update states
	add bx, dx
	inc bx
	xor dx, dx
	jmp .switch_end
.switch_end :
	clc ; clear flag set by str_has_char
	pop si ; >> END SWITCH <<
.skip_switch :
	dec cx
	inc si
	jmp .loop
.loop_end :
	cmp dx, 0
	je .cleaned_buffer
	mov si, interpreter_data.marks
	mov ax, bx
	LS32_APPEND dx, bx
.cleaned_buffer :
	popa
	ret
; mark the sub-strings in the string (ls8) given, output into interpreter_data.marks
; si <- address of string (ls8)
interpreter_mark :
	pusha
	LS8_GET_COUNT ; cx = count of chars
	add si, 2 ; si = begining of string
	call interpreter_mark_strn
	popa
	ret
; paint the ls16 buffer
; si <- ls16 buffer
interpreter_paint :
	pusha
	LS16_GET_COUNT ; cx = count
	mov di, si
	add di, 2 ; di = begining of buffer
	xor bl, bl ; bl = current str char
.loop :
	cmp cx, 0
	je .loop_end
	mov byte al, [di] ; al = current character
	cmp bl, 0
	je .not_processing_str
	cmp bl, al
	jne .not_str_end
	xor bl, bl
.not_str_end :
	push di
	inc di ; move to attribute
	mov byte [di], STRING_COLOR
	pop di
	jmp .continue
.not_processing_str :
	push di ; >> BEGIN SWITCH <<
	mov si, interpreter_data.standalone_chars
	call str_has_char
	jc .is_standalone_char
	mov si, interpreter_data.str_chars
	call str_has_char
	jc .is_str_char
	jmp .is_normal_char
.is_standalone_char :
	inc di ; move to attribute
	mov byte [di], SYMBOL_COLOR
	jmp .switch_end
.is_str_char :
	mov bl, al
	inc di ; move to attribute
	mov byte [di], STRING_COLOR
	jmp .switch_end
.is_normal_char :
	inc di
	mov byte [di], NORMAL_COLOR
.switch_end :
	clc
	pop di ; >> END SWITCH <<
.continue :
	add di, 2
	dec cx
	jmp .loop
.loop_end :
	popa
	ret
%endif ; _INTERPRETER_SUB_ASM_