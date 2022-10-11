%ifndef _TYPEDEF_MACROS_ASM_
%define _TYPEDEF_MACROS_ASM_

	;       --- macros ---
	%define FREE_BEGIN 0x7e00
	%define FREE_END 0x9fc00

	%define KERNEL_CODE_BEGIN_SEG 0x1000
	%ifndef KERNEL_CODE_SECTOR_COUNT
	%define KERNEL_CODE_SECTOR_COUNT 30
	%endif
	%define KERNEL_CODE_SIZE KERNEL_CODE_SECTOR_COUNT * 512
	%define KERNEL_STACK_SIZE 0x2000

	%assign KERNEL_FINAL_ADDR ((KERNEL_CODE_BEGIN_SEG << 4) + KERNEL_CODE_SIZE + KERNEL_STACK_SIZE)

	%define BUFFER_BEGIN_ADDR (KERNEL_FINAL_ADDR + 1000)
	%define BUFFER_BEGIN_SEG (BUFFER_BEGIN_ADDR >> 4)

	; Memory mapping: 
	; high 
	; ...
	; video dump 
	; ... 
	; buffer
	; stack 
	; code
	; ...
	; low

	%endif ; _TYPEDEF_MACROS_ASM_
