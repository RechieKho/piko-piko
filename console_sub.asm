%ifndef _CONSLE_SUB_ASM_
%define _CONSLE_SUB_ASM_

; NOTE: YOU MUST CONSOLE_INIT BEFORE USING ANYTHING IN THIS MODULE

; --- modules ---
%include "dstr_sub.asm"

; --- macro --- 
%define CONSOLE_VIDEO_MODE 0x03 
%define CONSOLE_DUMP_SEG 0xB800 
%define CONSOLE_WIDTH 80 
%define CONSOLE_HEIGHT 25

%define BLACK_FG 0x00 
%define BLACK_BG 0x00 
%define D_BLUE_FG 0x01
%define D_BLUE_BG 0x10
%define D_GREEN_FG 0x02 
%define D_GREEN_BG 0x20
%define D_CYAN_FG 0x03
%define D_CYAN_BG 0x30
%define D_RED_FG 0x04
%define D_RED_BG 0x40 
%define D_MAGENTA_FG 0x05 
%define D_MAGENTA_BG 0x50
%define D_YELLOW_FG 0x06
%define D_YELLOW_BG 0x60
%define L_GREY_BG 0x07
%define L_GREY_FG 0x70
%define D_GREY_BG 0x08
%define D_GREY_FG 0x80
%define L_BLUE_FG 0x09
%define L_BLUE_BG 0x90
%define L_GREEN_FG 0x0a
%define L_GREEN_BG 0xa0
%define L_CYAN_FG 0x0b
%define L_CYAN_BG 0xb0
%define L_RED_BG 0x0c
%define L_RED_FG 0xc0
%define L_MAGENTA_FG 0x0d
%define L_MAGENTA_BG 0xd0
%define L_YELLOW_FG 0x0e
%define L_YELLOW_BG 0xe0
%define WHITE_FG 0x0f
%define WHITE_BG 0xf0

%define KEY_ESC 0x011b
%define KEY_1 0x0231
%define KEY_2 0x0232
%define KEY_3 0x0233
%define KEY_4 0x0234
%define KEY_5 0x0235
%define KEY_6 0x0236
%define KEY_7 0x0237
%define KEY_8 0x0238
%define KEY_9 0x0239
%define KEY_MINUS 0x0c2d 
%define KEY_EQUAL 0x0d3d
%define KEY_BS 0x0e08 
%define KEY_TAB 0x0f09 
%define KEY_ENTER 0x1c0d
%define KEY_UP 0x4800 
%define KEY_LEFT 0x4b00
%define KEY_RIGHT 0x4d00 
%define KEY_DOWN 0x5000

; initialize console 
%macro CONSOLE_INIT 0 
	pusha 
		mov ah, 0x00
		mov al, CONSOLE_VIDEO_MODE
		int 0x10
	popa
%endmacro


; read keyboard input (wait for keystroke)
; al -> ascii character code 
; ah -> scan code
%macro CONSOLE_READ_CHAR 0
	mov ah, 0x00 
	int 0x16 
%endmacro

; set cursor
; dh <- row 
; dl <- column
%macro SET_CURSOR 0
	pusha
		mov ah, 0x02 
		mov bh, 0
		int 0x10
	popa
%endmacro

; get cursor
; dh -> row 
; dl -> column 
; ch -> cursor pixel Y-address 
; cl -> cursor pixel X-address
%macro GET_CURSOR 0
	push ax
	push bx 
		mov ah, 0x03
		mov bh, 0
		int 0x10
	pop bx
	pop ax 
%endmacro

; move cursor backward
%macro CURSOR_BACKWARD 0
	pusha 
		GET_CURSOR 
		cmp dl, 0
		je %%retract_row
			dec dl
		jmp %%retract_end
		%%retract_row:
			dec dh 
			mov dl, (CONSOLE_WIDTH - 1)
		%%retract_end:
		SET_CURSOR
	popa
%endmacro 

; mov cursor forward 
%macro CURSOR_FORWARD 0
	pusha 
		GET_CURSOR 
		cmp dl, (CONSOLE_WIDTH-1)
		je %%advance_row
			inc dl
		jmp %%advance_end
		%%advance_row:
			inc dh 
			mov dl, 0
		%%advance_end:
		SET_CURSOR
	popa
%endmacro 

; convert row and column to index for video dump
; %1 <- row {1-2 bytes, !bx}
; %2 <- col {1-2 bytes, !ax} 
; bx -> index
%macro CONSOLE_RC2IDX 2
	push ax
		movzx bx, %1
		mov al, CONSOLE_WIDTH
		mul bl
		mov bx, ax
		movzx ax, %2
		add bx, ax
	pop ax
%endmacro 

; --- subroutine ---
; write character & attribute to location using index 
; al <- character 
; ah <- attribute
; bx <- index 
console_write_idx: 
	pusha 
		mov cx, CONSOLE_DUMP_SEG
		mov es, cx
		shl bx, 1 ; multiply by 2, skipping attribute
		mov word [es:bx], ax
	popa
	ret

; write character & attribute to location 
; al <- character
; ah <- attribute
; cl <- row
; ch <- column
console_write: 
	pusha
		CONSOLE_RC2IDX cl, ch
		call console_write_idx
	popa
	ret

; write only character to location using index 
; al <- character 
; bx <- index 
console_write_char_idx:
	pusha 
		mov cx, CONSOLE_DUMP_SEG
		mov es, cx
		shl bx, 1 ; multiply by 2, skipping attribute
		mov byte [es:bx], al
	popa
	ret
	
; write only character to location 
; al <- character 
; cl <- row 
; ch <- column
console_write_char: 
	pusha
		CONSOLE_RC2IDX cl, ch
		call console_write_char_idx
	popa
	ret

; set the attribute of the character 
; ah <- attribute
; bx <- index
console_paint_idx:
	pusha 
		mov cx, CONSOLE_DUMP_SEG
		mov es, cx
		shl bx, 1 ; multiply by 2, skipping attribute
		inc bx
		mov byte [es:bx], ah
	popa
	ret

; write only character to location 
; ah <- attribute
; cl <- row 
; ch <- column
console_paint: 
	pusha
		CONSOLE_RC2IDX cl, ch
		call console_paint_idx
	popa
	ret

; write dstr to location using index 
; si <- address of dstr header
; bx <- index
console_write_dstr_idx:
	pusha 
		push bx
		mov bx, si
		DSTR_GET_INFO ; cl = max; ch = length 
		pop bx
		add si, 2 ; si = start of string
		.loop:
			cmp ch, 0 
			je .loop_end
				mov al, [si]
				call console_write_char_idx
			inc si
			inc bx
			dec ch
			jmp .loop
		.loop_end:
	popa 
	ret

; write dstr to location 
; si <- address of dstr header
; cl <- row 
; ch <- column
console_write_dstr: 
	pusha
		CONSOLE_RC2IDX cl, ch
		call console_write_dstr_idx
	popa
	ret

; write substring of dstr to location using index 
; al <- start (inclusive) 
; ah <- end (exclusive)
; si <- address of dstr header
; bx <- index
console_write_dstr_sub_idx:
	pusha 
		push bx
		mov bx, si
		DSTR_GET_INFO ; cl = max; ch = length 
		pop bx
		add si, 2
		movzx dx, al 
		add si, dx ; si = begining of substring


		cmp ah, ch 
		jbe .use_given 
		mov ah, ch ; the end exceed length, use length instead 
		.use_given:
		sub ah, al ; ah = length of character to be print
		.loop:
			cmp ah, 0 
			je .loop_end
				mov al, [si]
				call console_write_char_idx
			inc si
			inc bx
			dec ah
			jmp .loop
		.loop_end:
	popa 
	ret

; read line from console
; bx <- (initiated) dstr for storing output
console_read_line: 
	pusha
		DSTR_CLEAR
		push bx
			GET_CURSOR
			CONSOLE_RC2IDX dh, dl
			mov dx, bx ; dx = initial index
		pop bx
	.loop:
		CONSOLE_READ_CHAR
		
		; classify 
		cmp ax, KEY_ENTER
		je .handle_enter
		cmp ax, KEY_LEFT
		je .handle_left 
		cmp ax, KEY_RIGHT
		je .handle_right
		cmp ax, KEY_BS 
		je .handle_bs
		jmp .handle_normal

		.handle_enter:
			jmp .loop_end

		.handle_left:
			push bx
			push dx 
				GET_CURSOR
				CONSOLE_RC2IDX dh, dl
				mov cx, bx ; cx = current index
			pop dx 
			pop bx

			cmp cx, dx 
			jbe .reject_handle ; cx at the begining
			CURSOR_BACKWARD
			jmp .loop

		.handle_right:
			push bx
			push dx 
				GET_CURSOR
				CONSOLE_RC2IDX dh, dl
				mov ax, bx ; ax = current index
			pop dx 
			pop bx

			DSTR_GET_INFO ; cl = max; ch = length 
			cmp ax, dx 
			jl .reject_handle ; invalid cursor pos

			sub ax, dx ; ax = cursor pos relative to begining
			cmp al, ch
			jae .reject_handle

			CURSOR_FORWARD
			jmp .loop

		.handle_bs:
			; update buffer
			push bx
			push dx 
				GET_CURSOR
				CONSOLE_RC2IDX dh, dl
				mov cx, bx ; cx = current index
			pop dx 
			pop bx

			cmp cx, dx 
			jbe .reject_handle ; invalid cursor pos
			
			push cx
			sub cx, dx
			mov ah, cl
			dec ah ; ah = index of character to be erased, which is right before cursor
			call dstr_erase 
			jc .reject_handle
			pop cx

			; update screen
			CURSOR_BACKWARD
			push bx
				mov si, bx
				mov bx, cx 
				dec bx
				mov ch, ah 
				mov al, ch 
				mov ah, DSTR_MAX
				call console_write_dstr_sub_idx

				; clear the last character
				mov bx, si
				DSTR_GET_INFO ; cl = max ; ch = length 
				xor bx, bx
				movzx bx, ch
				add bx, dx
				mov al, 0
				call console_write_char_idx
			pop bx

			jmp .loop
			

		.handle_normal:
			cmp al, 0 
			je .reject_handle ; invalid ascii character
			; get current cursor info
			push bx
			push dx
				GET_CURSOR
				CONSOLE_RC2IDX dh, dl
				mov cx, bx ; cx = current index
			pop dx
			pop bx

			cmp cx, dx 
			jl .reject_handle ; invalid cursor pos
			
			; update buffer
			push cx
			sub cx, dx
			mov ah, cl ; ah = index of character to be inserted
			call dstr_insert
			jc .reject_handle
			pop cx ; cx still is current index

			; update screen
			CURSOR_FORWARD
			push bx
				mov si, bx
				mov bx, cx 
				mov ch, ah 
				mov al, ch 
				mov ah, DSTR_MAX
				call console_write_dstr_sub_idx
			pop bx

			jmp .loop


		.reject_handle:
			PRINT_CHAR 0x07 ; ring a bell 
			jmp .loop

	.loop_end:

	popa
	ret


%endif ;_CONSLE_SUB_ASM_
