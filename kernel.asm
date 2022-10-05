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
	%include "ls8_sub.asm"
	%include "interpreter_sub.asm"

	; --- data ---

kernel_data:
.greeting:
	db "W", (WHITE)
	db "e", (WHITE)
	db "l", (WHITE)
	db "c", (WHITE)
	db "o", (WHITE)
	db "m", (WHITE)
	db "e", (WHITE)
	db " ", (WHITE)
	db "t", (WHITE)
	db "o", (WHITE)
	db " ", (WHITE)
	db "p", (BRIGHT + YELLOW)
	db "i", (BRIGHT + RED)
	db "k", (BRIGHT + GREEN)
	db "o", (BRIGHT + BLUE)
	db "-", (WHITE)
	db "p", (BRIGHT + CYAN)
	db "i", (BRIGHT + MAGENTA)
	db "k", (BRIGHT + GREEN)
	db "o", (BRIGHT + YELLOW)
	db "!", (WHITE)
	dw 0

.input_buffer:
	resw 1; ls16 header (max and length)
	resw LS16_MAX; ls16 content

.raw_buffer:
	resw 1; ls8 header (max and length)
	resb LS8_MAX; ls16 content

	; --- subroutines ---

main:
	CONSOLE_INIT

	;    print greeting
	mov  si, kernel_data.greeting
	xor  cx, cx
	call console_write_colored_str
	PRINT_NL

	mov di, kernel_data.input_buffer
	LS16_INIT
	mov di, kernel_data.raw_buffer
	LS8_INIT

.loop:
	mov  si, kernel_data.input_buffer
	;    get user input
	PRINT_CHAR '>'
	PRINT_CHAR ' '
	call console_read_line
	PRINT_NL
	mov  di, kernel_data.raw_buffer
	call ls16_take_lower
	mov  si, kernel_data.raw_buffer
	call interpreter_execute
	jmp  .loop

	;      Checks for kernel memories
	%if    ($-$$) > KERNEL_CODE_SIZE
	%error "Kernel is bigger than " %+  KERNEL_SIZE %+ "."
	%endif
	%if    ((KERNEL_CODE_BEGIN_SEG << 4) + KERNEL_CODE_SIZE + KERNEL_STACK_SIZE + KERNEL_MEMORY_SIZE) > (STORAGE_BEGIN_SEG << 4)
	%error "Kernel memory is overlapping the storage memory."
	%endif
