%ifndef _PRINT_SUB_ASM_
%define _PRINT_SUB_ASM_
; --- data ---
print_data :
.error_prefix :
	db "ERROR: ", 0
; --- macros ---
; print a character and advance the cursor
; %1 <- character to be printed {1B, !al}
%macro PRINT_CHAR 1
	pusha
	mov al, %1
	mov ah, 0x0e
	int 0x10
	popa
%endmacro
; print new line
%macro PRINT_NL 0
	PRINT_CHAR 0x0a
	PRINT_CHAR 0x0d
%endmacro
; write a character on the cursor location (no advancing)
; %1 <- character to be wrote {1B, !al}
%macro WRITE_CHAR 1
	pusha
	mov ah, 0x0a
	mov al, %1
	mov bh, 0 ; page number
	mov cx, 1 ; write one only
	int 0x10
	popa
%endmacro
; convert one hex (4 bits) to ascii hex representation
; %1 <- a hex {2B, !ax}
; al -> hex representation of %1 in ascii
%macro H2A 1
	mov ax, %1
	and ax, 0xf ; select the lower 4 bits
	add ax, 0x30
	cmp ax, 0x3a
	jb %%done
	add ax, 0x27
%%done :
%endmacro
; print byte as hex to screen
; %1 <- a byte {1B, !bl}
%macro PRINT_BYTE 1
	pusha
	xor bx, bx
	mov bl, %1
	rol bl, 4
	PRINT_CHAR '0'
	PRINT_CHAR 'x'
%rep 2
	H2A bx
	PRINT_CHAR al
	rol bl, 4
%endrep
	popa
%endmacro
; print word as hex to screen
; %1 <- a word {2B, !bx}
%macro PRINT_WORD 1
	pusha
	mov bx, %1
	rol bx, 4
	PRINT_CHAR '0'
	PRINT_CHAR 'x'
%rep 4
	H2A bx
	PRINT_CHAR al
	rol bx, 4
%endrep
	popa
%endmacro
; --- subroutines ---
; print c string to console
; bx <- c string
printCString :
	pusha
.loop :
	mov al, [bx]
	cmp al, 0
	je .loop_end
	mov ah, 0xe
	int 0x10
	inc bx
	jmp .loop
.loop_end :
	popa
	ret
; print string to console
; bx <- string
; cx <- count
printCStringing :
	pusha
.loop :
	cmp cx, 0
	je .loop_end
	mov al, [bx]
	mov ah, 0xe
	int 0x10
	dec cx
	inc bx
	jmp .loop
.loop_end :
	popa
	ret
; print error (message are prefix with "ERROR: " )
; bx <- error message
printError :
	pusha
	push bx
	mov bx, print_data.error_prefix
	call printCString
	pop bx
	call printCString
	popa
	ret
; print error in one line
; bx <- err message
printErrorLine :
	call printError
	PRINT_NL
	ret
%endif ; _PRINT_SUB_ASM_