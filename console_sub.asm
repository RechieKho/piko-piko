%ifndef _CONSLE_SUB_ASM_
%define _CONSLE_SUB_ASM_

	; NOTE: YOU MUST CONSOLE_INIT BEFORE USING ANYTHING IN THIS MODULE

	;        --- modules ---
	%include "ls16_sub.asm"
	%include "mem_sub.asm"

	;       --- macro ---
	%define CONSOLE_VIDEO_MODE 0x03
	%define CONSOLE_DUMP_SEG 0xB800
	%define CONSOLE_WIDTH 80
	%define CONSOLE_HEIGHT 25

	%define BLACK 0x00
	%define BLUE 0x01
	%define GREEN 0x02
	%define CYAN 0x03
	%define RED 0x04
	%define MAGENTA 0x05
	%define YELLOW 0x06
	%define GREY 0x07
	%define BRIGHT 0x08
	%define WHITE (BRIGHT + GREY)
	;       BRIGHT + COLOR = BRIGHT COLOR
	;       BRIGHT itself is light grey

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

	%define CONSOLE_READ_LINE_DEFAULT_COLOR YELLOW

	;      initialize console
	%macro CONSOLE_INIT 0
	pusha
	mov    ah, 0x00
	mov    al, CONSOLE_VIDEO_MODE
	int    0x10
	popa
	%endmacro

	;      read keyboard input (wait for keystroke)
	;      al -> ascii character code
	;      ah -> scan code
	%macro CONSOLE_READ_CHAR 0
	mov    ah, 0x00
	int    0x16
	%endmacro

	;      set cursor
	;      dh <- row
	;      dl <- column
	%macro SET_CURSOR 0
	pusha
	mov    ah, 0x02
	mov    bh, 0
	int    0x10
	popa
	%endmacro

	;      get cursor
	;      dh -> row
	;      dl -> column
	;      ch -> cursor pixel Y-address
	;      cl -> cursor pixel X-address
	%macro GET_CURSOR 0
	push   ax
	push   bx
	mov    ah, 0x03
	mov    bh, 0
	int    0x10
	pop    bx
	pop    ax
	%endmacro

	;      move cursor backward
	%macro CURSOR_BACKWARD 0
	pusha
	GET_CURSOR
	cmp    dl, 0
	je     %%retract_row
	dec    dl
	jmp    %%retract_end

%%retract_row:
	cmp dh, 0
	je  %%skip_advance
	dec dh

%%skip_advance:
	mov dl, (CONSOLE_WIDTH - 1)

%%retract_end:
	SET_CURSOR
	popa
	%endmacro

	;      mov cursor forward
	%macro CURSOR_FORWARD 0
	pusha
	GET_CURSOR
	cmp    dl, (CONSOLE_WIDTH-1)
	je     %%advance_row
	inc    dl
	jmp    %%advance_end

%%advance_row:
	cmp dh, (CONSOLE_HEIGHT-1)
	je  %%skip_advance
	inc dh

%%skip_advance:
	mov dl, 0

%%advance_end:
	SET_CURSOR
	popa
	%endmacro

	;      mov cursor upward
	%macro CURSOR_UPWARD 0
	pusha
	GET_CURSOR
	cmp    dh, 0
	je     %%end
	dec    dh

%%end:
	SET_CURSOR
	popa
	%endmacro

	;      convert row and column to index for video dump
	;      %1 <- row {1-2B, !bx}
	;      %2 <- col {1-2B, !ax}
	;      bx -> index
	%macro CONSOLE_RC2IDX 2
	push   ax
	movzx  bx, %1
	mov    al, CONSOLE_WIDTH
	mul    bl
	mov    bx, ax
	movzx  ax, %2
	add    bx, ax
	pop    ax
	%endmacro

	; --- subroutine ---
	; scroll console upward
	; bl <- displacelment

console_scroll_up:
	pusha
	push ds
	push es
	mov  al, CONSOLE_WIDTH * 2
	mul  bl
	mov  si, ax
	xor  di, di
	mov  cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT * 2)
	sub  cx, ax
	mov  ax, CONSOLE_DUMP_SEG
	mov  es, ax
	mov  ds, ax
	rep  movsb

	;   clear the rest of the row
	mov al, CONSOLE_HEIGHT
	sub al, bl
	mov dl, (2 * CONSOLE_WIDTH)
	mul dl
	mov si, ax; si = begining of slots to be cleared
	mov al, bl
	mov dl, (2 * CONSOLE_WIDTH)
	mul dl
	mov cx, si; cx = number of slots to be cleared
	mov bx, si 
	xor ax, ax 
	call wordset
	pop es
	pop ds
	popa
	ret

	; write character & attribute to location using index
	; al <- character
	; ah <- attribute
	; bx <- index

console_write_idx:
	pusha
	cmp bx, (CONSOLE_WIDTH * CONSOLE_HEIGHT - 1)
	ja .end ; exceed video dump
	push es
	shl bx, 1; multiply by 2, skipping attribute
	mov cx, CONSOLE_DUMP_SEG
	mov es, cx
	mov word [es:bx], ax
	pop es
.end:
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
	cmp bx, (CONSOLE_WIDTH * CONSOLE_HEIGHT - 1)
	ja .end ; exceed video dump
	push es
	shl bx, 1; multiply by 2, skipping attribute
	mov cx, CONSOLE_DUMP_SEG
	mov es, cx
	mov byte [es:bx], al
	pop es
.end:
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
	cmp bx, (CONSOLE_WIDTH * CONSOLE_HEIGHT - 1)
	ja .end ; exceed video dump
	push es
	shl bx, 1; multiply by 2, skipping attribute
	mov cx, CONSOLE_DUMP_SEG
	mov es, cx
	inc bx
	mov byte [es:bx], ah
	pop es
.end:
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

	; write ls16 to location using index
	; bx <- index
	; si <- address of ls16

console_write_ls16_idx:
	pusha
	LS16_GET_COUNT ; cx = count
	mov ax, bx 
	add ax, cx 
	cmp ax, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	jb .within_video_dump
	mov cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	sub cx, bx
.within_video_dump:
	push es
	mov dx, CONSOLE_DUMP_SEG
	mov es, dx
	mov di, bx; di = offset for video dump
	shl di, 1
	add si, 2; si = start of string
	rep movsw
	pop es
	popa
	ret

	; write ls16 to location
	; cl <- row
	; ch <- column
	; si <- address of ls16

console_write_ls16:
	pusha
	CONSOLE_RC2IDX cl, ch
	call console_write_ls16_idx
	popa
	ret

	; write subset of ls16 to location using index
	; al <- start (inclusive)
	; ah <- end (exclusive)
	; bx <- index
	; si <- address of ls16

console_write_ls16_sub_idx:
	pusha
	cmp bx, (CONSOLE_WIDTH * CONSOLE_HEIGHT - 1)
	ja .end
	LS16_GET_INFO ; cl = max; ch = length
	sub   ah, al
	cmp   ah, ch
	jbe   .valid_length
	mov   ah, ch; the end exceed length, use length instead
	sub ah, al
.valid_length:
	movzx cx, ah
	add cx, bx
	cmp cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	jb .within_video_dump
	mov cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
.within_video_dump:
	sub cx, bx; cx = length of character to be print
	mov   di, bx
	shl di, 1 ; di = offset for console dump
	movzx bx, al
	shl   bx, 1
	add   si, 2
	add   si, bx; si = begining of substring
	push es
	mov   dx, CONSOLE_DUMP_SEG
	mov   es, dx
	rep   movsw
	pop es
.end:
	popa
	ret

	; write subset of ls16 to location
	; al <- start (inclusive)
	; ah <- end (exclusive)
	; cl <- row
	; ch <- column
	; si <- address of ls16

console_write_ls16_sub:
	pusha
	CONSOLE_RC2IDX cl, ch
	call console_write_ls16_sub_idx
	popa
	ret

	; write colored string to location using index
	; bx <- index
	; si <- colored string

console_write_colored_str_idx:
	pusha
	push es
	mov ax, CONSOLE_DUMP_SEG
	mov es, ax
	shl bx, 1

.loop:
	mov word ax, [si]
	cmp ax, 0
	je  .loop_end
	mov word [es:bx], ax
	add bx, 2
	add si, 2
	jmp .loop

.loop_end:
	pop es
	popa
	ret

	; write colored string to location
	; cl <- row
	; ch <- column
	; si <- colored string

console_write_colored_str:
	pusha
	CONSOLE_RC2IDX cl, ch
	call console_write_colored_str_idx
	popa
	ret

	; read line from console
	; si <- ls16 for storing output
	; bx <- painter function that colorize the the input
	; 		arguments:
	; 		si <- ls16 buffer 

console_read_line:
	pusha
	LS16_CLEAR
	push bx
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl
	mov dx, bx; dx = starting index
	pop bx

.loop:
	CONSOLE_READ_CHAR

	;    get cursor's index on console
	push bx
	push dx
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl
	mov  cx, bx; cx = current index
	pop  dx
	pop bx

	cmp cx, dx
	jb  .reject_handle; invalid cursor index

	; ah = scan code {update per loop}
	; al = ascii character {update per loop}
	; cx = current cursor index (during a keystroke detected) {update per loop}
	; si = ls16 buffer
	; dx = starting cursor index
	; bx = painter function

	;   classify
	cmp ax, KEY_ENTER
	je  .handle_enter
	cmp ax, KEY_LEFT
	je  .handle_left
	cmp ax, KEY_RIGHT
	je  .handle_right
	cmp ax, KEY_BS
	je  .handle_bs
	jmp .handle_normal

.handle_enter:
	jmp .loop_end

; cx <- current cursor index 
; dx <- starting cursor index
.handle_left:
	cmp cx, dx
	je  .reject_handle; cursor at the begining
	CURSOR_BACKWARD
	jmp .loop

; cx <- current cursor index 
; dx <- starting cursor index
; ~cx
; ~ax
.handle_right:
	mov ax, cx; ax = current cursor index
	sub ax, dx; ax = cursor pos relative to begining
	LS16_GET_INFO ; cl = max; ch = length
	cmp al, ch
	jae .reject_handle
	CURSOR_FORWARD
	jmp .loop

.handle_bs:
	cmp  cx, dx
	je   .reject_handle; cursor index at begining
	call _clear_input_line
	pusha
	sub cx, dx 
	dec cx ; cx = index of character to be erased, right before cursor 
	mov dh, cl 
	call ls16_erase 
	popa 
	call bx
	call _update_input_line
	jc .reject_handle
	CURSOR_BACKWARD
	jmp .loop

; ax <- scancode 
; cx <- current cursor index
; dx <- starting cursor index
.handle_normal:
	cmp  al, 0
	je   .reject_handle; invalid ascii character
	pusha
	sub  cx, dx ; cx = index of character to be inserted
	mov dh, cl
	mov ah, CONSOLE_READ_LINE_DEFAULT_COLOR
	call ls16_insert
	popa
	call bx
	call _update_input_line
	jc .reject_handle
	CURSOR_FORWARD
	jmp .loop

.reject_handle:
	clc
	PRINT_CHAR 0x07 ; ring a bell
	jmp .loop

.loop_end:
	popa
	ret

; update region in console with ls16 user input buffer
; si <- ls16 buffer 
; dx <- starting index
; dx -> updated starting index (if scroll)
_update_input_line:
	push cx
	push bx 
	LS16_GET_COUNT ; cx = count
	add cx, dx 
	mov bl, 0 ; bl = lines to be scrolled 
.count_loop:
	cmp cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	jb .count_loop_end
	inc bl 
	sub dx, CONSOLE_WIDTH
	sub cx, CONSOLE_WIDTH
.count_loop_end:
	call console_scroll_up
	mov bx, dx 
	call console_write_ls16_idx
	pop bx 
	pop cx
	ret

; clear region in console that is written with ls16 user input buffer 
; si <- ls16 buffer
; dx <- starting index
_clear_input_line:
	pusha 
	LS16_GET_COUNT ; cx = count 
	mov bx, dx 
	; limit cx, not beyond the video dump 
	add cx, bx 
	cmp cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	jb .within_video_dump 
	mov cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
.within_video_dump:
	sub cx, bx
	push es
	mov dx, CONSOLE_DUMP_SEG
	mov es, dx 
	shl bx, 1
	xor ax, ax
	call wordset
	pop es 
	popa
	ret

%endif ; _CONSLE_SUB_ASM_
