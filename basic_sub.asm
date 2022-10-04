%ifndef _BASIC_SUB_ASM_
%define _BASIC_SUB_ASM_

	;        --- modules ---
	%include "ls32_sub.asm"
	%include "ls8_sub.asm"
	%include "str_sub.asm"
	%include "print_sub.asm"

	; --- data ---

basic_data:
.marks:
	;    a ls32. each slot stores address to the begining of sub-string and the length
	resw 1
	resd LS32_MAX
	.splitting_chars: ; characters that splits string into sub-strings (separator)
	db   " ", 0
	.standalone_chars: ; character that is always alone
	db   "~()", 0
	.str_chars: ; character that initiate or terminate strings
	db   0x22, 0x27, 0x60, 0

	; --- subroutines ---
	; print marks

basic_print_marks:
	pusha
	mov si, basic_data.marks
	LS32_GET_COUNT ; cx = count of marks
	add si, 2; si = begining of marks
	PRINT_CHAR '['

.loop:
	cmp cx, 0
	je  .loop_end

	push cx
	mov  word cx, [si]; cx = length of string
	add  si, 2
	mov  word bx, [si]; bx = string
	add  si, 2
	call print_n_str
	pop  cx
	PRINT_CHAR ','

	dec cx
	jmp .loop

.loop_end:
	PRINT_CHAR ']'
	popa
	ret

	; mark the sub-strings in the string (ls8) given, output into basic_data.marks
	; si <- address of string (ls8)

basic_mark:
	pusha
	mov di, basic_data.marks
	LS32_INIT
	LS8_GET_COUNT ; cx = count of chars
	add si, 2; si = begining of string
	mov bx, si; bx = address of begining of sub-string
	xor dx, dx; dx = length of sub-string
	xor ah, ah; ah = current str char

.loop:
	cmp cx, 0
	je  .loop_end

	mov al, [si]; al = current character

	cmp ah, 0
	je  .not_processing_str
	cmp ah, al
	je  .str_end
	inc dx
	jmp .skip_switch

.str_end:
	push si
	mov  si, basic_data.marks
	mov  ax, bx
	LS32_APPEND dx, ax
	pop  si
	add  bx, dx
	inc  bx
	xor  ax, ax
	xor  dx, dx
	jmp  .skip_switch

.not_processing_str:

	push si; >> BEGIN SWITCH <<
	mov  si, basic_data.splitting_chars
	call str_has_char
	jc   .is_splitting_char
	mov  si, basic_data.standalone_chars
	call str_has_char
	jc   .is_standalone_char
	mov  si, basic_data.str_chars
	call str_has_char
	jc   .is_str_char
	inc  dx
	jmp  .switch_end

.is_splitting_char:
	mov  si, basic_data.marks
	;    write into marks
	cmp  dx, 0
	je   .empty_mark
	push ax
	mov  ax, bx
	LS32_APPEND dx, ax
	pop  ax
	;    update state

.empty_mark:
	add bx, dx
	inc bx
	xor dx, dx
	jmp .switch_end

.is_standalone_char:
	mov  si, basic_data.marks
	;    write sub-string before standalone char into marks
	cmp  dx, 0
	je   .mark_standalone_char
	push ax
	mov  ax, bx
	LS32_APPEND dx, ax
	pop  ax
	;    write the standalone char into marks

.mark_standalone_char:
	add  bx, dx
	push ax
	mov  ax, bx
	mov  dx, 1
	LS32_APPEND dx, ax
	pop  ax
	;    update states
	inc  bx
	xor  dx, dx
	jmp  .switch_end

.is_str_char:
	mov  si, basic_data.marks
	;    write sub-string before str char into marks
	cmp  dx, 0
	je   .start_str
	push ax
	mov  ax, bx
	LS32_APPEND dx, ax
	pop  ax
	;    set current str char

.start_str:
	push bx
	mov  bh, al
	mov  ah, bh
	pop  bx
	;    update states
	add  bx, dx
	inc  bx
	xor  dx, dx
	jmp  .switch_end

.switch_end:
	clc ; clear flag set by str_has_char
	pop si; >> END SWITCH <<

.skip_switch:

	dec cx
	inc si
	jmp .loop

.loop_end:
	cmp dx, 0
	je  .cleaned_buffer
	mov si, basic_data.marks
	mov ax, bx
	LS32_APPEND dx, bx

.cleaned_buffer:
	popa
	ret

%endif ; _BASIC_SUB_ASM_
