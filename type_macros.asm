%ifndef _TYPEDEF_MACROS_ASM_
%define _TYPEDEF_MACROS_ASM_

	;       --- macros ---
	%define FREE_BEGIN 0x7e00
	%define FREE_END 0x9fc00

	%define KERNEL_CODE_BEGIN_SEG 0x1000
	%ifndef KERNEL_CODE_SECTOR_COUNT
	%define KERNEL_CODE_SECTOR_COUNT 2
	%endif
	%define KERNEL_CODE_SIZE KERNEL_CODE_SECTOR_COUNT * 512
	%define KERNEL_STACK_SIZE 0x2000
	%define KERNEL_MEMORY_SIZE 0x1000

	; Note that kernel stack and memory is right after its code
	; low .....| code | stack | memory |.....| storage |..... high

	%define STORAGE_BEGIN_SEG 0xdead

	%endif ; _TYPEDEF_MACROS_ASM_
