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
	resw BUFFER_WIDTH; ls16 content

.raw_buffer:
	resw 1; ls8 header (max and length)
	resb BUFFER_WIDTH; ls16 content

	; --- subroutines ---
; a function that do nothing
pass:
	ret

main:
	; initialization
	CONSOLE_INIT
	COMMANDS_INIT

	mov di, kernel_data.input_buffer
	LS16_INIT BUFFER_WIDTH
	mov di, kernel_data.raw_buffer
	LS8_INIT BUFFER_WIDTH

	;    print greeting
	mov  si, kernel_data.greeting
	xor  cx, cx
	call console_write_colored_str
	PRINT_NL

.loop:
	mov  si, kernel_data.input_buffer
	;    get user input
	PRINT_CHAR '>'
	PRINT_CHAR ' '
	mov bx, interpreter_paint
	call console_read_line
	PRINT_NL
	mov  di, kernel_data.raw_buffer
	call ls16_take_lower
	mov  si, kernel_data.raw_buffer
	call interpreter_execute
	jmp  .loop

	; --- checks ---
	%if    ($-$$) > KERNEL_CODE_SIZE
	%error "Kernel is bigger than expected."
	%endif

	%if KERNEL_FINAL_ADDR > (CONSOLE_DUMP_SEG << 4)
	%error "Kernel is overlapping video dump."
	%endif
