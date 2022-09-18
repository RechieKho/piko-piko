%ifndef _LS_SUB_ASM_
%define _LS_SUB_ASM_

	; ls - list
	; it stores a header (2 bytes) and data of 2 bytes behind it.
	; It is like ls but with 2 bytes per slot instead of 1.
	; header structure:
	; max: (1 byte)
	; len: (1 byte)

	;        --- modules ---
	%include "print_sub.asm"

	;       --- macros ---
	%define LS_MAX 0xff

	;      initialize ls header
	;      %1 <- max length (how many 2 bytes it can stores, excluding the header) {!bx}
	;      bx <- address of ls header
	%macro LS_INIT 0-1 LS_MAX
	push   bx
	mov    byte [bx], %1
	inc    bx
	mov    byte [bx], 0
	pop    bx
	%endmacro

	;       get info from ls header
	;       bx <- address of ls header
	;       cl -> max length of ls
	;       ch -> length of ls
	%define LS_GET_INFO mov word cx, [bx]

	;      get length of ls
	;      bx <- address of ls header
	;      cx -> length of ls
	%macro LS_GET_LENGTH 0
	push   ax
	LS_GET_INFO
	movzx  ax, ch
	mov    cx, ax; cx = length
	pop    ax
	%endmacro

	;      clear ls
	;      bx <- address of ls header
	%macro LS_CLEAR 0
	pusha
	LS_GET_INFO
	mov    ch, 0
	mov    word [bx], cx
	popa
	%endmacro

	;      append to ls
	;      %1 <- element to be appended
	;      bx <- address of ls header
	%macro LS_APPEND 1
	pusha
	inc    bx
	mov    byte dh, [bx]
	mov    ax, %1
	dec    bx
	call   ls_insert
	popa
	%endmacro

	;      prepend to ls
	;      %1 <- element to be prepend
	;      bx <- address of ls header
	%macro LS_PREPEND 1
	pusha
	mov    ax, %1
	mov    dh, 0
	call   ls_insert
	popa
	%endmacro

	;      pop last element of ls
	;      bx <- address of ls header
	%macro LS_POP_LAST 0
	pusha
	inc    bx
	mov    byte ah, [bx]
	dec    dh
	dec    bx
	call   ls_erase
	popa
	%endmacro

	;      pop first element of ls
	;      bx <- address of ls header
	%macro LS_POP_FIRST 0
	pusha
	mov    dh, 0
	call   ls_erase
	popa
	%endmacro

	; --- subroutine ---
	; print ls to console
	; bx <- address of ls header

ls_print:
	pusha
	LS_GET_INFO ; cl = max; ch = length
	add bx, 2; bx = begining of list

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

	; print sublist of ls to console
	; al <- start (inclusive)
	; ah <- end (exclusive)
	; bx <- address of ls header

ls_print_sub:
	pusha
	LS_GET_INFO ; cl = max; ch = length
	add   bx, 2
	movzx dx, al
	add   bx, dx; bx = begining of sub str

	cmp ah, ch
	jbe .use_given
	mov ah, ch; the end exceed length, use length instead

.use_given:
	sub ah, al; ah = length of element to be printed

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

	; check whether ls is equal
	; si <- address of first ls header
	; di <- address of second ls header
	; cf -> set if ls are not equal

ls_equal:
	pusha
	mov   word cx, [si]; cl = max; ch = length
	mov   word dx, [di]; dl = max; dh = length
	cmp   dh, ch
	jne   .not_equal
	movzx cx, dh; cx = length of both ls
	add   si, 2; displace to the list
	add   di, 2; displace to the list

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

	; erase element from ls
	; bx <- address of ls header
	; dh <- index of the element to be erased
	; cf -> set if element fail to be inserted (either ls is empty or ah (index) is invalid)

ls_erase:
	pusha
	LS_GET_INFO ; cl = max; ch = length

	;   check validity
	cmp ch, 0
	je  .empty_err; empty list, not entertained
	cmp dh, ch
	jae .invalid_index_err

	;     displace elements backward
	pusha ; > START DISPLACE <
	mov   di, bx
	add   di, 2
	movzx ax, dh
	add   di, ax; di = address of element to be erased

	mov si, di
	inc si; si = address right after element to be erased

	sub   ch, dh
	dec   ch
	movzx bx, ch
	mov   cx, bx; cx = number of element to be displaced

	mov bx, ds
	mov es, bx

	rep  movsw
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

	; insert element to ls
	; ax <- element to be inserted
	; bx <- address of ls header
	; dh <- index of the element to be inserted
	; cf -> set if element fail to be inserted (either ls is full or ah (index) is invalid)

ls_insert:
	pusha
	LS_GET_INFO ; cl = max; ch = length

	cmp ch, cl
	jae .max_err; already max out

	cmp dh, ch
	ja  .invalid_index_err; index is bigger than the length

	;     displace element forward
	pusha ; > START DISPLACE <
	mov   si, bx

	sub   ch, dh
	movzx bx, ch
	mov   cx, bx; cx = number of elements to be displaced

	movzx dx, ch
	inc   dx; skip header
	add   si, dx; si = address of end of ls

	mov di, si
	inc di; di = address right after end of ls

	mov bx, ds
	mov es, bx

	std
	rep  movsw
	cld
	popa ; > END DISPLACE <

	;     insert element
	push  cx
	push  bx
	add   bx, 2
	movzx cx, dh
	add   bx, cx
	mov   word [bx], ax
	pop   bx
	pop   cx

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

%endif ; _LS_SUB_ASM_
