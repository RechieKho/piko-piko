%ifndef _LOAD_COM_ASM_
%define _LOAD_COM_ASM_
; --- modules ---
%include "commands/meta.asm"
; --- commands ---
@loadCommand_name :
	db "load", 0
; 1 <- file index
@loadCommand :
	LIST32_GET_COUNT
	cmp cx, 2
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, FILE_COUNT
	jae command_err.invalid_file_err
	mov ax, BUFFER_SEC_COUNT
	mul dx
	add ax, STORAGE_BEGIN_SEC
	xor cx, cx
	xor dx, dx
	call storageAddCHS
	mov ax, BUFFER_SEC_COUNT ; ax = number of sectors
	push es
	mov word bx, [command_data.active_buffer]
	mov es, bx
	xor bx, bx
	call storageRead
	pop es
	jc command_err.disk_read_err
	ret
%endif ; _LOAD_COM_ASM_