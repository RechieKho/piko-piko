%ifndef _LS16_SUB_ASM_
%define _LS16_SUB_ASM_

	; ls16 - list of 16 bits
	; structure diagram: 
	; | max (1 byte) | count (1 byte) | elements (2 byte each element) |

	;        --- modules ---
	%include "print_sub.asm"

	;       --- macros ---
	%define LS16_MAX 0xff

	;      initialize ls16 header
	;      %1 <- max count of the element (excluding the header) {!bx}
	;      bx <- address of ls16 header
	%macro LS16_INIT 0-1 LS16_MAX
	push   bx
	mov    byte [bx], %1
	inc    bx
	mov    byte [bx], 0
	pop    bx
	%endmacro

	;       get info from ls16 header
	;       bx <- address of ls16 header
	;       cl -> max count of ls16
	;       ch -> count of ls16
	%define LS16_GET_INFO mov word cx, [bx]

	;      get count of ls16
	;      bx <- address of ls16 header
	;      cx -> count of ls16
	%macro LS16_GET_COUNT 0
	push   ax
	LS16_GET_INFO
	movzx  ax, ch
	mov    cx, ax; cx = count
	pop    ax
	%endmacro

	;      clear ls16
	;      bx <- address of ls16 header
	%macro LS16_CLEAR 0
	pusha
	LS16_GET_INFO
	mov    ch, 0
	mov    word [bx], cx
	popa
	%endmacro

	;      append to ls16
	;      %1 <- element to be appended
	;      bx <- address of ls16 header
	%macro LS16_APPEND 1
	pusha
	inc    bx
	mov    byte dh, [bx]
	mov    ax, %1
	dec    bx
	call   ls16_insert
	popa
	%endmacro

	;      prepend to ls16
	;      %1 <- element to be prepend
	;      bx <- address of ls16 header
	%macro LS16_PREPEND 1
	pusha
	mov    ax, %1
	mov    dh, 0
	call   ls16_insert
	popa
	%endmacro

	;      pop last element of ls16
	;      bx <- address of ls16 header
	%macro LS16_POP_LAST 0
	pusha
	inc    bx
	mov    byte dh, [bx]
	dec    dh
	dec    bx
	call   ls16_erase
	popa
	%endmacro

	;      pop first element of ls16
	;      bx <- address of ls16 header
	%macro LS16_POP_FIRST 0
	pusha
	mov    dh, 0
	call   ls16_erase
	popa
	%endmacro

	; --- subroutine ---
	; print subelement of ls16 to console
	; al <- start (inclusive)
	; ah <- end (exclusive)
	; bx <- address of ls16 header

	; check whether ls16s are equal
	; si <- address of first ls16 header
	; di <- address of second ls16 header
	; cf -> set if ls16s are not equal

ls16_equal:
	pusha
	mov   word cx, [si]; cl = max; ch = count
	mov   word dx, [di]; dl = max; dh = count
	cmp   dh, ch
	jne   .not_equal
	movzx cx, dh; cx = count of both ls16
	add   si, 2; displace to the element
	add   di, 2; displace to the element

.loop:
	mov  word ax, [si]
	mov  word bx, [di]
	cmp  ax, bx
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

	; erase element from ls16
	; bx <- address of ls16 header
	; dh <- index of the element to be erased
	; cf -> set if element fail to be inserted (either ls16 is empty or ah (index) is invalid)

ls16_erase:
	pusha
	LS16_GET_INFO ; cl = max; ch = count

	;   check validity
	cmp ch, 0
	je  .empty_err; empty element, not entertained
	cmp dh, ch
	jae .invalid_index_err

	;     displace elements backward
	pusha ; > START DISPLACE <
	mov   di, bx
	add   di, 2
	movzx ax, dh
	shl ax, 1
	add   di, ax ; di = address of element to be erased

	mov si, di
	add si, 2 ; si = address right after element to be erased

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

	; insert element to ls16
	; ax <- element to be inserted
	; bx <- address of ls16 header
	; dh <- index of the element to be inserted
	; cf -> set if element fail to be inserted (either ls16 is full or ah (index) is invalid)

ls16_insert:
	pusha
	LS16_GET_INFO ; cl = max; ch = count

	cmp ch, cl
	jae .max_err; already max out

	cmp dh, ch
	ja  .invalid_index_err; index is bigger than the count

	;     displace element forward
	pusha ; > START DISPLACE <
	push dx
	mov   si, bx
	movzx dx, ch
	inc   dx; skip header
	shl dx, 1 
	add   si, dx ; si = address of end of ls16
	pop dx

	mov di, si
	add di, 2 ; di = address right after end of ls16

	sub   ch, dh
	movzx bx, ch
	mov   cx, bx ; cx = number of elements to be displaced

	mov bx, ds
	mov es, bx

	std
	rep  movsw
	cld
	popa ; > END DISPLACE <

	;     insert element
	push cx
	push  bx
	add   bx, 2
	movzx cx, dh
	shl cx, 1
	add   bx, cx
	mov   word [bx], ax
	pop   bx
	pop cx

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

%endif ; _LS16_SUB_ASM_
