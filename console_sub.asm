%ifndef _CONSLE_SUB_ASM_
%define _CONSLE_SUB_ASM_

	; NOTE: YOU MUST CONSOLE_INIT BEFORE USING ANYTHING IN THIS MODULE

	;        --- modules ---
	%include "ls16_sub.asm"

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

	%define CONSOLE_READ_LINE_COLOR YELLOW

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

.clear_loop:
	cmp cx, 0
	je  .clear_loop_end
	mov word [si], 0x00
	add si, 2
	dec cx
	jmp .clear_loop

.clear_loop_end:

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
	mov cx, CONSOLE_DUMP_SEG
	mov es, cx
	shl bx, 1; multiply by 2, skipping attribute
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
	shl bx, 1; multiply by 2, skipping attribute
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
	shl bx, 1; multiply by 2, skipping attribute
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

	; write ls16 to location using index
	; bx <- index
	; si <- address of ls16

console_write_ls16_idx:
	pusha
	mov cx, CONSOLE_DUMP_SEG
	mov es, cx
	shl bx, 1
	mov di, bx; di = offset for video dump
	LS16_GET_COUNT ; cx = count
	add si, 2; si = start of string
	rep movsw
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
	mov   cx, CONSOLE_DUMP_SEG
	mov   es, cx
	shl   bx, 1
	mov   di, bx; di = offset for console dump
	LS16_GET_INFO ; cl = max; ch = length
	add   si, 2
	movzx bx, al
	shl   bx, 1
	add   si, bx; si = begining of substring
	cmp   ah, ch
	jbe   .use_given
	mov   ah, ch; the end exceed length, use length instead

.use_given:
	sub   ah, al
	movzx cx, ah; cx = length of character to be print
	rep   movsw
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

console_read_line:
	pusha
	LS16_CLEAR
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl
	mov dx, bx; dx = starting index

.loop:
	CONSOLE_READ_CHAR

	;    get cursor's index on console
	push dx
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl
	mov  cx, bx; cx = current index
	pop  dx

	cmp cx, dx
	jb  .reject_handle; invalid cursor index

	; initial information
	; ah = scan code
	; al = ascii character
	; si = ls16 buffer
	; cx = current cursor index (when a keystroke detected)
	; dx = starting cursor index

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

.handle_left:
	cmp cx, dx
	je  .reject_handle; cursor at the begining
	CURSOR_BACKWARD
	jmp .loop

.handle_right:
	mov ax, cx; ax = current cursor index
	sub ax, dx; ax = cursor pos relative to begining
	LS16_GET_INFO ; cl = max; ch = length
	cmp al, ch
	jae .reject_handle
	CURSOR_FORWARD
	jmp .loop

	; update the console
	; ah <- starting ls16 index
	; cx <- starting console index to be updated
	; si <- ls16 buffer

.handle_update_console:
	;     clear the character after ls16
	pusha
	LS16_GET_INFO ; cl = max ; ch = length
	xor   bx, bx
	movzx bx, ch
	add   bx, dx
	push ax
	xor ax, ax
	call  console_write_idx
	pop ax
	popa
	;     scroll if required
	cmp   cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT - 1)
	jb    .no_scroll
	;mov  bl, 1
	;call console_scroll_up; should have just use PRINT_NL instead
	PRINT_NL
	sub   dx, CONSOLE_WIDTH
	sub   cx, CONSOLE_WIDTH

.no_scroll:
	;    write ls16 to console
	mov  bl, ah
	mov  al, bl
	mov  bx, cx
	mov  ah, LS16_MAX
	call console_write_ls16_sub_idx
	jmp  .loop

	; erase character in buffer (& jmp to handle_update_console)
	; ah <- index of character to be erased
	; cx <- starting console index to be updated
	; si <- ls16 buffer

.handle_erase_front:
	push dx
	mov  dh, ah
	call ls16_erase
	pop  dx
	jc   .reject_handle
	CURSOR_BACKWARD
	jmp  .handle_update_console

	; insert (in front of cursor) character into buffer (& jmp to handle_update_console)
	; al <- character to be inserted
	; ah <- index of character to be inserted
	; cx <- starting console index to be updated
	; si <- ls16 buffer

.handle_insert_front:
	push dx
	push ax
	mov  dh, ah
	mov  ah, CONSOLE_READ_LINE_COLOR
	call ls16_insert
	pop  ax
	pop  dx
	jc   .reject_handle
	CURSOR_FORWARD
	jmp  .handle_update_console

.handle_bs:
	cmp  cx, dx
	je   .reject_handle; cursor index at begining
	push cx
	sub  cx, dx
	mov  ah, cl
	dec  ah; ah = index of character to be erased, which is right before cursor
	pop  cx
	dec  cx
	jmp  .handle_erase_front

.handle_normal:
	cmp  al, 0
	je   .reject_handle; invalid ascii character
	push cx
	sub  cx, dx
	mov  ah, cl; ah = index of character to be inserted
	pop  cx; cx still is current index

	jmp .handle_insert_front

.reject_handle:
	clc
	PRINT_CHAR 0x07 ; ring a bell
	jmp .loop

.loop_end:
	popa
	ret

%endif ; _CONSLE_SUB_ASM_
