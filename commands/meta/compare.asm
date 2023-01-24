%ifndef _COMPARE_META_ASM_
%define _COMPARE_META_ASM_
; --- modules ---
%include "commands/meta/command.asm"
; --- macros ---
%define COMPARE_BUFFER_CAPACITY 0x20
%define COMPARE_BUFFER_SIZE (COMPARE_BUFFER_SIZE + 2)
; Read compare buffer as uint.
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; ax -> uint of compare_buffer_a
; dx -> uint of compare_buffer_b
; ~si
%macro COMPARE_BUFFER_TO_UINT 0
	mov si, compare_data.compare_buffer_a
	COMMANDS_LIST82UINT
	mov ax, dx ; ax = uint of first compare buffer
	mov si, compare_data.compare_buffer_b
	COMMANDS_LIST82UINT
%endmacro
; --- data ---
compare_data :
.compare_buffer_a : ; A list 8 buffer for value to be compared (to compare_buffer_b).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
.compare_buffer_b : ; A list 8 buffer for value to be compared (to compare_buffer_a).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
%endif ; _COMPARE_META_ASM_