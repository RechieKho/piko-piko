%ifndef _VAR_META_ASM_
%define _VAR_META_ASM_
; --- modules ---
%include "type_macros.asm"
; --- macros ---
%define VAR_CAPACITY BUFFER_WIDTH
%define VAR_SIZE (VAR_CAPACITY + 2) ; MUST within a byte
%define VAR_COUNT 0x1a ; MUST within a byte
; Consume mark and read as string (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- current mark
; bx -> string
; cx -> length
; si -> next mark
%macro VAR_CONSUME_MARK_READ_STRN 0
	call commandConsumeMark
	clc
	call varReadString
	jc err.invalid_variable_err
%endmacro
; Consume mark and read as string save it to list 8 (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- current_mark
; di <- address of list 8 to output to
; si -> next mark
%macro VAR_CONSUME_MARK_READ_STRN_TO_LIST8 0
	push bx
	push cx
	call commandConsumeMark
	clc
	call varReadString
	jc %%fail
	cmp ch , 0
	jne %%fail
	push si
	mov si, di
	mov di, bx
	clc
	call list8Set
	pop si
	jc %%fail
%%success :
	clc
	jmp %%end
%%fail :
	stc
%%end :
	pop cx
	pop bx
	jc err.invalid_value_err
%endmacro
; Consume mark and read as uint (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS.
; si <- current mark
; dx -> uint
; si -> next mark
%macro VAR_CONSUME_MARK_READ_UINT 0
	push bx
	push cx
	call commandConsumeMark
	push si
	clc
	call varReadString
	jc %%end
	mov si, bx
	clc
	call stringToUint
%%end :
	pop si
	pop cx
	pop bx
	jc err.invalid_uint_err
%endmacro
; --- data ---
var_data :
.variables :
%rep VAR_COUNT
	db VAR_CAPACITY, 0
	times (VAR_CAPACITY) db 0
%endrep
; --- subroutine ---
; Read string (accept variable referencing).
; bx <- string
; cx <- length
; bx -> string
; cx -> length
; cf -> set if fail
varReadString :
	push ax
	push dx
	push si
	cmp cx, 0
	je .success
	mov byte al, [bx]
	cmp al, '$'
	jne .string_literal
; variable referencing
	mov si, bx
	inc si
	dec cx
	clc
	call stringToUint
	jc .fail
	cmp dx, VAR_COUNT
	jae .fail
	mov al, VAR_SIZE
	mul dl
	mov si, var_data.variables
	add si, ax
	LIST8_GET_COUNT
	mov bx, si
	add bx, 2
	jmp .success
.string_literal :
	cmp al, '\'
	jne .success
	inc bx
	dec cx
	jmp .success
.success :
	clc
	jmp .end
.fail :
	stc
.end :
	pop si
	pop dx
	pop ax
	ret
; --- checks ---
%if (VAR_SIZE > 0xff) || (VAR_COUNT > 0xff)
%error "Variable size and count must be a byte."
%endif
%if (VAR_CAPACITY < 5)
%error "Variable too small for uint."
%endif
%endif ; _VAR_META_ASM_