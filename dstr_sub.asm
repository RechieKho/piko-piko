%ifndef _DSTR_SUB_ASM_
%define _DSTR_SUB_ASM_

	; dstr - dynamic string
	; it stores a header (2 bytes) and the string after it (non 0 terminated)
	; header structure:
	; max: (1 byte)
	; len: (1 byte)

	;        --- modules ---
	%include "print_sub.asm"

	;       --- macros ---
	%define DSTR_MAX 0xff

	;      initialize dstr header
	;      %1 <- max length of the string (excluding the header) {!bx}
	;      bx <- address of dstr header
	%macro DSTR_INIT 0-1 DSTR_MAX
	push   bx
	mov    byte [bx], %1
	inc    bx
	mov    byte [bx], 0
	pop    bx
	%endmacro

	;       get info from dstr header
	;       bx <- address of dstr header
	;       cl -> max length of dstr
	;       ch -> length of dstr
	%define DSTR_GET_INFO mov word cx, [bx]

	;      get length of dstr
	;      bx <- address of dstr header
	;      cx -> length of dstr
	%macro DSTR_GET_LENGTH 0
	push   ax
	DSTR_GET_INFO
	movzx  ax, ch
	mov    cx, ax; cx = length
	pop    ax
	%endmacro

	;      clear dstr
	;      bx <- address of dstr header
	%macro DSTR_CLEAR 0
	pusha
	DSTR_GET_INFO
	mov    ch, 0
	mov    word [bx], cx
	popa
	%endmacro

	;      append to dstr
	;      %1 <- character to be appended
	;      bx <- address of dstr header
	%macro DSTR_APPEND 1
	pusha
	inc    bx
	mov    byte ah, [bx]
	mov    al, %1
	dec    bx
	call   dstr_insert
	popa
	%endmacro

	;      prepend to dstr
	;      %1 <- character to be prepend
	;      bx <- address of dstr header
	%macro DSTR_PREPEND 1
	pusha
	mov    al, %1
	mov    ah, 0
	call   dstr_insert
	popa
	%endmacro

	;      pop last character of dstr
	;      bx <- address of dstr header
	%macro DSTR_POP_LAST 0
	pusha
	inc    bx
	mov    byte ah, [bx]
	dec    ah
	dec    bx
	call   dstr_erase
	popa
	%endmacro

	;      pop first character of dstr
	;      bx <- address of dstr header
	%macro DSTR_POP_FIRST 0
	pusha
	mov    ah, 0
	call   dstr_erase
	popa
	%endmacro

	; --- subroutine ---
	; print dstr to console
	; bx <- address of dstr header

dstr_print:
	pusha
	DSTR_GET_INFO ; cl = max; ch = length
	add bx, 2; bx = begining of string

.loop:
	cmp ch, 0
	jbe .end
	PRINT_CHAR [bx]
	inc bx
	dec ch
	jmp .loop

.end:
	popa
	ret

	; print substring of dstr to console
	; al <- start (inclusive)
	; ah <- end (exclusive)
	; bx <- address of dstr header

dstr_print_sub:
	pusha
	DSTR_GET_INFO ; cl = max; ch = length
	add   bx, 2
	movzx dx, al
	add   bx, dx; bx = begining of sub str

	cmp ah, ch
	jbe .use_given
	mov ah, ch; the end exceed length, use length instead

.use_given:
	sub ah, al; ah = length of character to be printed

.loop:
	cmp ah, 0
	je  .end
	PRINT_CHAR [bx]
	inc bx
	dec ah
	jmp .loop

.end:
	popa
	ret

	; check whether dstr is equal
	; si <- address of first dstr header
	; di <- address of second dstr header
	; cf -> set if dstr are not equal

dstr_equal:
	pusha
	mov   word cx, [si]; cl = max; ch = length
	mov   word dx, [di]; dl = max; dh = length
	cmp   dh, ch
	jne   .not_equal
	movzx cx, dh; cx = length of both dstr
	add   si, 2; displace to the string
	add   di, 2; displace to the string

.loop:
	mov  byte al, [si]
	mov  byte bl, [di]
	cmp  al, bl
	jne  .not_equal
	inc  si
	inc  si
	loop .loop
	jmp  .equal

.not_equal:
	stc

.equal:
	popa
	ret

	; erase character from dstr
	; ah <- index of the character to be erased
	; bx <- address of dstr header
	; cf -> set if character fail to be inserted (either dstr is empty or ah (index) is invalid)

dstr_erase:
	pusha
	DSTR_GET_INFO ; cl = max; ch = length

	;   check validity
	cmp ch, 0
	je  .empty_err; empty string, not entertained
	cmp ah, ch
	jae .invalid_index_err

	;     displace characters backward
	pusha ; > START DISPLACE <
	mov   di, bx
	add   di, 2
	movzx dx, ah
	add   di, dx; di = address of character to be erased

	mov si, di
	inc si; si = address right after character to be erased

	sub   ch, ah
	dec   ch
	movzx bx, ch
	mov   cx, bx; cx = number of character to be displaced

	mov bx, ds
	mov es, bx

	rep  movsb
	popa ; > STOP DISPLACE <

	;   update state
	dec ch
	inc bx
	mov byte [bx], ch

	jmp .success

.empty_err:
.invalid_index_err:
	stc

.success:
	popa
	ret

	; insert character to dstr
	; al <- character to be inserted
	; ah <- index of the character to be inserted
	; bx <- address of dstr header
	; cf -> set if character fail to be inserted (either dstr is full or ah (index) is invalid)

dstr_insert:
	pusha
	DSTR_GET_INFO ; cl = max; ch = length

	cmp ch, cl
	jae .max_err; already max out

	cmp ah, ch
	ja  .invalid_index_err; index is bigger than the length

	;     displace character forward
	pusha ; > START DISPLACE <
	mov   si, bx
	movzx dx, ch
	inc   dx; skip header
	add   si, dx; si = address of end of dstr

	mov di, si
	inc di; di = address right after end of dstr

	sub   ch, ah
	movzx bx, ch
	mov   cx, bx; cx = number of characters to be displaced

	mov bx, ds
	mov es, bx

	std
	rep  movsb
	cld
	popa ; > END DISPLACE <

	;     insert character
	push  bx
	add   bx, 2
	movzx dx, ah
	add   bx, dx
	mov   byte [bx], al
	pop   bx

	;   update state
	inc ch
	inc bx; set to address of length
	mov byte [bx], ch; update length

	jmp .success

.max_err:
.invalid_index_err:
	stc

.success:
	popa
	ret

%endif ; _DSTR_SUB_ASM_
