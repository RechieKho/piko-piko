%ifndef _LS32_SUB_ASM_
%define _LS32_SUB_ASM_

	; ls32 - list of 32 bits
	; structure diagram:
	; | max (1B) | count (1B) | elements (4B each element) |

	;       --- macros ---
	%define LS32_MAX 0xff

	;      initialize ls32
	;      %1 <- max count of the element (excluding the header) {1B, !di}
	;      di <- address of ls32
	%macro LS32_INIT 0-1 LS32_MAX
	push   di
	mov    byte [di], %1
	inc    di
	mov    byte [di], 0
	pop    di
	%endmacro

	;       get info from ls32
	;       si <- address of ls32
	;       cl -> max count of ls32
	;       ch -> count of ls32
	%define LS32_GET_INFO mov word cx, [si]

	;      get count of ls32
	;      si <- address of ls32
	;      cx -> count of ls32
	%macro LS32_GET_COUNT 0
	push   ax
	LS32_GET_INFO
	movzx  ax, ch
	mov    cx, ax; cx = count
	pop    ax
	%endmacro

	;      clear ls32
	;      si <- address of ls32
	%macro LS32_CLEAR 0
	pusha
	LS32_GET_INFO
	mov    ch, 0
	mov    word [si], cx
	popa
	%endmacro

	;      append to ls32
	;      %1 <- lower part of element to be appended {2B, !ax}
	;      %2 <- upper part of element to be appended {2B, !bx}
	;      si <- address of ls32
	%macro LS32_APPEND 2
	pusha
	inc    si
	mov    byte dh, [si]
	dec    si
	mov    ax, %1
	mov bx, %2
	call   ls32_insert
	popa
	%endmacro

	;      prepend to ls32
	;      %1 <- lower part of element to be prepend {2B, !ax}
	;      %2 <- upper part of element to be prepend {2B, !bx}
	;      si <- address of ls32
	%macro LS32_PREPEND 2
	pusha
	mov    ax, %1
	mov bx, %2
	mov    dh, 0
	call   ls32_insert
	popa
	%endmacro

	;      pop last element of ls32
	;      si <- address of ls32
	%macro LS32_POP_LAST 0
	pusha
	inc    si
	mov    byte dh, [si]
	dec    dh
	dec    si
	call   ls32_erase
	popa
	%endmacro

	;      pop first element of ls32
	;      si <- address of ls32
	%macro LS32_POP_FIRST 0
	pusha
	mov    dh, 0
	call   ls32_erase
	popa
	%endmacro

	; --- subroutine ---
	; check whether ls32s are equal
	; si <- address of first ls32
	; di <- address of second ls32
	; cf -> set if ls32s are not equal

ls32_equal:
	pusha
	mov   word cx, [si]; cl = max; ch = count
	mov   word dx, [di]; dl = max; dh = count
	cmp   dh, ch
	jne   .not_equal
	movzx cx, dh
	shl cx, 2; cx = count of words stored in both ls32
	add   si, 2; displace to the element
	add   di, 2; displace to the element

.loop:
	cmp cx, 0 
	je .equal
	mov  word ax, [si]
	mov  word bx, [di]
	cmp  ax, bx
	jne  .not_equal
	add si, 2
	add di, 2
	dec cx
	jmp .loop

.not_equal:
	stc

.equal:
	popa
	ret

	; erase element from ls32
	; dh <- index of the element to be erased
	; si <- address of ls32 header
	; cf -> set if element fail to be inserted (either ls32 is empty or ah (index) is invalid)

ls32_erase:
	pusha
	LS32_GET_INFO ; cl = max; ch = count

	;   check validity
	cmp ch, 0
	je  .empty_err; empty element, not entertained
	cmp dh, ch
	jae .invalid_index_err

	;     displace elements backward
	pusha ; > START DISPLACE <
	add   si, 6
	movzx ax, dh
	shl   ax, 2
	add   si, ax; si = address right after element to be erased

	mov di, si
	sub di, 4; di = address of element to be erased

	sub   ch, dh
	dec   ch
	movzx ax, ch
	mov   cx, ax; cx = number of element to be displaced

	mov ax, ds
	mov es, ax

	rep  movsd
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

	; insert element to ls32
	; ax <- lower part of element to be inserted
	; bx <- upper part of element to be inserted
	; dh <- index of the element to be inserted
	; si <- address of ls32 header
	; cf -> set if element fail to be inserted (either ls32 is full or ah (index) is invalid)

ls32_insert:
	pusha
	LS32_GET_INFO ; cl = max; ch = count

	cmp ch, cl
	jae .max_err; already max out

	cmp dh, ch
	ja  .invalid_index_err; index is bigger than the count

	;     displace element forward
	pusha ; > START DISPLACE <
	movzx ax, ch
	shl   ax, 2
	add   si, ax; si = address of end of ls32

	mov di, si
	add di, 4; di = address right after end of ls32

	sub   ch, dh
	movzx ax, ch
	mov   cx, ax; cx = number of elements to be displaced

	mov ax, ds
	mov es, ax

	std
	rep  movsd
	cld
	popa ; > END DISPLACE <

	;     insert element
	push  si
	add   si, 2
	push ax
	movzx ax, dh
	shl   ax, 2
	add   si, ax
	pop ax
	mov   word [si], ax
	add si, 2
	mov   word [si], bx
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

%endif ; _LS32_SUB_ASM_
