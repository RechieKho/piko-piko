%include "type_macros.asm"
; setup segment
	mov bx, KERNEL_CODE_BEGIN_SEG
	mov ds, bx
; setup stack
	mov ss, bx ; bx is ds
	mov bp, KERNEL_CODE_SIZE + KERNEL_STACK_SIZE
	mov sp, bp
	jmp main
; --- modules ---
%include "console_sub.asm"
%include "list16_sub.asm"
%include "list8_sub.asm"
%include "interpreter_sub.asm"
; --- data ---
kernel_data :
.greeting :
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
.input_buffer :
	times 1 dw 0 ; list 16 header (max and length)
	times BUFFER_WIDTH dw 0 ; list 16 content
.raw_buffer :
	times 1 dw 0 ; list 8 header (max and length)
	times BUFFER_WIDTH db 0 ; list 8 content
; --- subroutines ---
main :
; initialization
	STORAGE_SET_DRIVE
	CONSOLE_INIT
	INTERPRETER_INIT
	mov di, kernel_data.input_buffer
	LIST16_INIT BUFFER_WIDTH
	mov di, kernel_data.raw_buffer
	LIST8_INIT BUFFER_WIDTH
; print greeting
	mov si, kernel_data.greeting
	xor cx, cx
	call consoleWriteAttributedCString
	PRINT_NL
.loop :
	mov si, kernel_data.input_buffer
; get user input
	PRINT_CHAR '>'
	PRINT_CHAR ' '
	mov bx, interpreterPaint
	call consoleReadLine
	PRINT_NL
	mov di, kernel_data.raw_buffer
	call list16TakeLower
	mov si, kernel_data.raw_buffer
	clc
	call interpreterExecute
	jmp .loop
; --- checks ---
%if ($-$$) > KERNEL_CODE_SIZE
%error "Kernel is bigger than expected."
%endif
%if KERNEL_FINAL_ADDR > (CONSOLE_DUMP_SEG << 4)
%error "Kernel is overlapping video dump."
%endif