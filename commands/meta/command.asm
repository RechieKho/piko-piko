%ifndef _COMMAND_META_ASM_
%define _COMMAND_META_ASM_
; Each command expecting :
; si <- address of list 32 of marks point to the arguments
; --- modules ---
%include "str_sub.asm"
; --- macros ---
; Read list 8 as uint.
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- address of list 8
; dx -> uint
%macro COMMANDS_LIST82UINT 0
	push si
	LIST8_GET_COUNT
	add si, 2
	clc
	call stringToUint
	pop si
	jc err.invalid_uint_err
%endmacro
; --- subroutine ---
; si <- current mark
; bx -> address of argument
; cx -> length of argument
; si -> next mark
commandConsumeMark :
	mov word cx, [si]
	add si, 2
	mov word bx, [si]
	add si, 2
	ret
%endif ; _COMMAND_META_ASM_