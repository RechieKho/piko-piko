%ifndef _LS8_SUB_ASM_
%define _LS8_SUB_ASM_

	; ls8 - list of 8 bits
	; structure diagram:
	; | max (1B) | count (1B) | elements (1B each element) |

	;        --- modules ---
	%include "print_sub.asm"

	;       --- macros ---
	%define LS8_MAX 0xff

	;      initialize ls8
	;      %1 <- max count of the element (excluding the header) {1B, !di}
	;      di <- address of ls8
	%macro LS8_INIT 0-1 LS8_MAX
	push   di
	mov    byte [di], %1
	inc    di
	mov    byte [di], 0
	pop    di
	%endmacro

	;       get info from ls8
	;       si <- address of ls8
	;       cl -> max count of ls8
	;       ch -> count of ls8
	%define LS8_GET_INFO mov word cx, [si]

	;      get count of ls8
	;      si <- address of ls8
	;      cx -> count of ls8
	%macro LS8_GET_COUNT 0
	push   ax
	LS8_GET_INFO
	movzx  ax, ch
	mov    cx, ax; cx = count
	pop    ax
	%endmacro

	;      clear ls8
	;      si <- address of ls8
	%macro LS8_CLEAR 0
	pusha
	LS8_GET_INFO
	mov    ch, 0
	mov    word [si], cx
	popa
	%endmacro

	;      append to ls8
	;      %1 <- element to be appended {1B, !al}
	;      si <- address of ls8
	%macro LS8_APPEND 1
	pusha
	inc    si
	mov    byte dh, [si]
	dec    bx
	mov    al, %1
	call   ls8_insert
	popa
	%endmacro

	;      prepend to ls8
	;      %1 <- element to be prepend {1B, !al}
	;      si <- address of ls8
	%macro LS8_PREPEND 1
	pusha
	mov    al, %1
	mov    dh, 0
	call   ls8_insert
	popa
	%endmacro

	;      pop last element of ls8
	;      si <- address of ls8
	%macro LS8_POP_LAST 0
	pusha
	inc    si
	mov    byte dh, [si]
	dec    dh
	dec    si
	call   ls8_erase
	popa
	%endmacro

	;      pop first element of ls8
	;      si <- address of ls8
	%macro LS8_POP_FIRST 0
	pusha
	mov    dh, 0
	call   ls8_erase
	popa
	%endmacro

	; --- subroutine ---
	; print ls8 as ascii to console
	; si <- address of ls8

ls8_print_ascii:
	pusha
	LS8_GET_COUNT ; cx = count
	add si, 2; si = begining of element

.loop:
	cmp cx, 0 
	je .loop_end
	PRINT_CHAR [si]
	inc  si
	dec cx 
	jmp .loop
.loop_end:
	popa
	ret

	; check whether ls8s are equal
	; si <- address of first ls8
	; di <- address of second ls8
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
	cmp cx, 0 
	je .equal
	mov  byte al, [si]
	mov  byte bl, [di]
	cmp  al, bl
	jne  .not_equal
	inc  si
	inc  di
	dec cx 
	jmp .loop

.not_equal:
	stc

.equal:
	popa
	ret

	; erase element from ls8
	; dh <- index of the element to be erased
	; si <- address of ls8
	; cf -> set if element fail to be inserted (either ls8 is empty or ah (index) is invalid)

ls8_erase:
	pusha
	LS8_GET_INFO ; cl = max; ch = count

	;   check validity
	cmp ch, 0
	je  .empty_err; empty element, not entertained
	cmp dh, ch
	jae .invalid_index_err

	;     displace elements backward
	pusha ; > START DISPLACE <
	add   si, 3
	movzx ax, dh
	add   si, ax; si = address right after element to be erased

	mov di, si
	dec di; di = address of element to be erased

	sub   ch, dh
	dec   ch
	movzx ax, ch
	mov   cx, ax; cx = number of element to be displaced

	mov ax, ds
	mov es, ax

	rep  movsb
	popa ; > STOP DISPLACE <

	;   update state
	dec ch
	inc si
	mov byte [si], ch

	jmp .success

.empty_err:
.invalid_index_err:
	stc

.success:
	popa
	ret

	; insert element to ls8
	; al <- element to be inserted
	; si <- address of ls8
	; dh <- index of the element to be inserted
	; cf -> set if element fail to be inserted (either ls8 is full or ah (index) is invalid)

ls8_insert:
	pusha
	LS8_GET_INFO ; cl = max; ch = count

	cmp ch, cl
	jae .max_err; already max out

	cmp dh, ch
	ja  .invalid_index_err; index is bigger than the count

	;     displace element forward
	pusha ; > START DISPLACE <
	movzx bx, ch
	inc   bx; skip header
	add   si, bx; si = address of end of ls8

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
	push  si
	add   si, 2
	movzx bx, ah
	add   si, bx
	mov   byte [si], al
	pop   si

	;   update state
	inc ch
	inc si; set to address of count
	mov byte [si], ch; update count

	jmp .success

.max_err:
.invalid_index_err:
	stc

.success:
	popa
	ret

%endif ; _LS8_SUB_ASM_
