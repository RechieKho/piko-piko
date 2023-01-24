%ifndef _STACK_META_ASM_
%define _STACK_META_ASM_
; --- modules ---
%include "commands/meta/var.asm"
; --- macros ---
%define STACK_MAX_VAR 25 ; number of variable able to store on stack
; --- data ---
stack_data :
.stack :
	times (STACK_MAX_VAR * VAR_SIZE) db 0
.stack_pointer :
	dw .stack
%endif ; _STACK_META_ASM_