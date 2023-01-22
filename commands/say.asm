%ifndef _SAY_COM_ASM_
%define _SAY_COM_ASM_
%include "commands/command_sub.asm"
@sayCommand_name :
	db "say", 0
; -1 <- message to be printed
; 1? <- options
@sayCommand :
	LIST32_GET_COUNT
	mov ah, GREY ; ah = text color
	xor al, al ; al = number of new lines after print.
	add si, 6
	cmp cx, 2
	je .default
	cmp cx, 3
	je .set_option
	jmp command_err.invalid_arg_num_err
.set_option :
	COMMANDS_CONSUME_MARK_READ_STRN
.option_detection_loop :
	cmp cx, 0
	je .default
	mov byte dl, [bx]
	cmp dl, 'n'
	jne .not_newline_option
	inc al
	jmp .continue_option_detection_loop
.not_newline_option :
; %1 <- character
; %2 <- color
%macro COLOR_OPTION 2
	cmp dl, %1
	jne %%end
	mov ah, %2
	jmp .continue_option_detection_loop
%%end :
%endmacro
	COLOR_OPTION 'd', BLACK
	COLOR_OPTION 'b', BLUE
	COLOR_OPTION 'v', GREEN
	COLOR_OPTION 'c', CYAN
	COLOR_OPTION 'r', RED
	COLOR_OPTION 'm', MAGENTA
	COLOR_OPTION 'y', YELLOW
	COLOR_OPTION 'g', GREY
	COLOR_OPTION 'B', (BRIGHT + BLUE)
	COLOR_OPTION 'V', (BRIGHT + GREEN)
	COLOR_OPTION 'C', (BRIGHT + CYAN)
	COLOR_OPTION 'R', (BRIGHT + RED)
	COLOR_OPTION 'M', (BRIGHT + MAGENTA)
	COLOR_OPTION 'Y', (BRIGHT + YELLOW)
	COLOR_OPTION 'G', BRIGHT
	COLOR_OPTION 'w', WHITE
%unmacro COLOR_OPTION 2
.continue_option_detection_loop :
	inc bx
	dec cx
	jmp .option_detection_loop
.default :
	COMMANDS_CONSUME_MARK_READ_STRN
	cmp cx, 0
	je .newline_loop
	mov si, bx
.print_string :
	call consolePrintString
.newline_loop :
	cmp al, 0
	je .end
	PRINT_NL
	dec al
	jmp .newline_loop
.end :
	clc
	ret
%endif ; _SAY_COM_ASM_