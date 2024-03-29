%ifndef _CMP_COM_ASM_
%define _CMP_COM_ASM_
; --- commands ---
@compareCommand_name :
	db "cmp", 0
; 1 <- value a
; 2 <- value b
@compareCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne err.invalid_arg_num_err
	add si, 6
	mov di, compare_data.compare_buffer_a
	VAR_CONSUME_MARK_READ_STRN_TO_LIST8
	mov di, compare_data.compare_buffer_b
	VAR_CONSUME_MARK_READ_STRN_TO_LIST8
	clc
	ret
%endif ; _CMP_COM_ASM_