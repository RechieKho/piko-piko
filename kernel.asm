%include "type_macros.asm"

	;   setup segment
	mov bx, KERNEL_CODE_BEGIN_SEG
	mov ds, bx

	;   setup stack
	mov ss, bx; bx is dx
	mov bp, KERNEL_CODE_SIZE + KERNEL_STACK_SIZE
	mov sp, bp

	jmp main

	;        --- modules ---
	%include "console_sub.asm"
	%include "ls16_sub.asm"

	; --- data ---

kernel_data:
.greeting:
	db "Welcome to piko-piko!", 0

.input_buffer:
	resw 1; ls16 header (max and length)
	resw LS16_MAX; ls16 content

	; --- subroutines ---

main:
	CONSOLE_INIT

	;    print greeting
	mov  bx, kernel_data.greeting
	call print_str
	PRINT_NL

	mov di, kernel_data.input_buffer
	LS16_INIT

.loop:
	mov  si, kernel_data.input_buffer
	;    get user input
	call console_read_line
	PRINT_NL
	jmp  .loop

	;      Checks for kernel memories
	%if    ($-$$) > KERNEL_CODE_SIZE
	%error "Kernel is bigger than " %+  KERNEL_SIZE %+ "."
	%endif
	%if    ((KERNEL_CODE_BEGIN_SEG << 4) + KERNEL_CODE_SIZE + KERNEL_STACK_SIZE + KERNEL_MEMORY_SIZE) > (STORAGE_BEGIN_SEG << 4)
	%error "Kernel memory is overlapping the storage memory."
	%endif
