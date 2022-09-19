%ifndef _LS8_SUB_ASM_
%define _LS8_SUB_ASM_

	; ls8 - list of 8 bits
	; structure diagram: 
	; | max (1 byte) | count (1 byte) | elements (1 byte each element) |

	;        --- modules ---
	%include "print_sub.asm"

	;       --- macros ---
	%define LS8_MAX 0xff

	;      initialize ls8 header
	;      %1 <- max count of the element (excluding the header) {!bx}
	;      bx <- address of ls8 header
	%macro LS8_INIT 0-1 LS8_MAX
	push   bx
	mov    byte [bx], %1
	inc    bx
	mov    byte [bx], 0
	pop    bx
	%endmacro

	;       get info from ls8 header
	;       bx <- address of ls8 header
	;       cl -> max count of ls8
	;       ch -> count of ls8
	%define LS8_GET_INFO mov word cx, [bx]

	;      get count of ls8
	;      bx <- address of ls8 header
	;      cx -> count of ls8
	%macro LS8_GET_COUNT 0
	push   ax
	LS8_GET_INFO
	movzx  ax, ch
	mov    cx, ax; cx = count
	pop    ax
	%endmacro

	;      clear ls8
	;      bx <- address of ls8 header
	%macro LS8_CLEAR 0
	pusha
	LS8_GET_INFO
	mov    ch, 0
	mov    word [bx], cx
	popa
	%endmacro

	;      append to ls8
	;      %1 <- element to be appended
	;      bx <- address of ls8 header
	%macro LS8_APPEND 1
	pusha
	inc    bx
	mov    byte ah, [bx]
	mov    al, %1
	dec    bx
	call   ls8_insert
	popa
	%endmacro

	;      prepend to ls8
	;      %1 <- element to be prepend
	;      bx <- address of ls8 header
	%macro LS8_PREPEND 1
	pusha
	mov    al, %1
	mov    ah, 0
	call   ls8_insert
	popa
	%endmacro

	;      pop last element of ls8
	;      bx <- address of ls8 header
	%macro LS8_POP_LAST 0
	pusha
	inc    bx
	mov    byte ah, [bx]
	dec    ah
	dec    bx
	call   ls8_erase
	popa
	%endmacro

	;      pop first element of ls8
	;      bx <- address of ls8 header
	%macro LS8_POP_FIRST 0
	pusha
	mov    ah, 0
	call   ls8_erase
	popa
	%endmacro

	; --- subroutine ---
	; print ls8 as ascii to console
	; bx <- address of ls8 header

ls8_print_ascii:
	pusha
	LS8_GET_COUNT ; cx = count
	add bx, 2; bx = begining of element
.loop:
	PRINT_CHAR [bx]
	inc bx
	loop .loop
	popa
	ret

	; print subelement of ls8 to console
	; al <- start (inclusive)
	; ah <- end (exclusive)
	; bx <- address of ls8 header

	; check whether ls8s are equal
	; si <- address of first ls8 header
	; di <- address of second ls8 header
	; cf -> set if ls8s are not equal

ls8_equal:
	pusha
	mov   word cx, [si]; cl = max; ch = count
	mov   word dx, [di]; dl = max; dh = count
	cmp   dh, ch
	jne   .not_equal
	movzx cx, dh; cx = count of both ls8
	add   si, 2; displace to the element
	add   di, 2; displace to the element

.loop:
	mov  byte al, [si]
	mov  byte bl, [di]
	cmp  al, bl
	jne  .not_equal
	inc  si
	inc  di
	loop .loop
	jmp  .equal

.not_equal:
	stc

.equal:
	popa
	ret

	; erase element from ls8
	; ah <- index of the element to be erased
	; bx <- address of ls8 header
	; cf -> set if element fail to be inserted (either ls8 is empty or ah (index) is invalid)

ls8_erase:
	pusha
	LS8_GET_INFO ; cl = max; ch = count

	;   check validity
	cmp ch, 0
	je  .empty_err; empty element, not entertained
	cmp ah, ch
	jae .invalid_index_err

	;     displace elements backward
	pusha ; > START DISPLACE <
	mov   di, bx
	add   di, 2
	movzx dx, ah
	add   di, dx; di = address of element to be erased

	mov si, di
	inc si; si = address right after element to be erased

	sub   ch, ah
	dec   ch
	movzx bx, ch
	mov   cx, bx; cx = number of element to be displaced

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

	; insert element to ls8
	; al <- element to be inserted
	; ah <- index of the element to be inserted
	; bx <- address of ls8 header
	; cf -> set if element fail to be inserted (either ls8 is full or ah (index) is invalid)

ls8_insert:
	pusha
	LS8_GET_INFO ; cl = max; ch = count

	cmp ch, cl
	jae .max_err; already max out

	cmp ah, ch
	ja  .invalid_index_err; index is bigger than the count

	;     displace element forward
	pusha ; > START DISPLACE <
	mov   si, bx
	movzx dx, ch
	inc   dx; skip header
	add   si, dx; si = address of end of ls8

	mov di, si
	inc di; di = address right after end of ls8

	sub   ch, ah
	movzx bx, ch
	mov   cx, bx; cx = number of elements to be displaced

	mov bx, ds
	mov es, bx

	std
	rep  movsb
	cld
	popa ; > END DISPLACE <

	;     insert element
	push  bx
	add   bx, 2
	movzx dx, ah
	add   bx, dx
	mov   byte [bx], al
	pop   bx

	;   update state
	inc ch
	inc bx; set to address of count
	mov byte [bx], ch; update count

	jmp .success

.max_err:
.invalid_index_err:
	stc

.success:
	popa
	ret

%endif ; _LS8_SUB_ASM_
