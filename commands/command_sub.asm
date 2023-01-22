%ifndef _COMMANDS_SUB_ASM_
%define _COMMANDS_SUB_ASM_
; NOTE : YOU MUST COMMANDS_INIT BEFORE USING ANYTHING IN THIS MODULE
; each command expecting :
; si <- address of list 32 of marks point to the arguments
; COMMANDS RETURN WITH CARRY FLAG SET WILL CANCEL RUNNING BUFFER.
; COMMANDS SHOULD NOT PUSHA/POPA AT THE BEGINING AND ENDING OF COMMANDS.
; --- modules ---
%include "print_sub.asm"
%include "list32_sub.asm"
%include "list8_sub.asm"
%include "str_sub.asm"
%include "type_macros.asm"
%include "console_sub.asm"
%include "interpreter_sub.asm"
%include "storage_sub.asm"
; --- macros ---
%define VARIABLE_CAPACITY BUFFER_WIDTH
%define VARIABLE_SIZE (VARIABLE_CAPACITY + 2) ; MUST within a byte
%define VARIABLE_COUNT 0x1a ; MUST within a byte
%define STACK_MAX_VAR 25 ; number of variable able to store on stack
%define COMPARE_BUFFER_CAPACITY 0x20
%define COMPARE_BUFFER_SIZE (COMPARE_BUFFER_SIZE + 2)
%macro COMMANDS_INIT 0
	BUFFER_INIT
%endmacro
; initiate buffer
%macro BUFFER_INIT 0
	pusha
	push es
	mov al, ' '
	xor bx, bx
	mov dx, (BUFFER_SEC_COUNT * BUFFER_COUNT)
	mov si, BUFFER_BEGIN_SEG
	mov cx, SECTOR_SIZE
%%set_loop :
	cmp dx, 0
	je %%set_loop_end
	mov es, si
	call byteset
	add si, (SECTOR_SIZE >> 4)
	dec dx
	jmp %%set_loop
%%set_loop_end :
	pop es
	popa
%endmacro
; Read list 8 as uint. MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN
; PUSH AND POP.
; si <- address of list 8
; dx -> uint
%macro COMMANDS_LIST82UINT 0
	push si
	LIST8_GET_COUNT
	add si, 2
	clc
	call stringToUint
	pop si
	jc command_err.invalid_uint_err
%endmacro
; Read compare buffer as uint. MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE
; IN BETWEEN PUSH AND POP.
; ax -> uint of compare_buffer_a
; dx -> uint of compare_buffer_b
; ~si
%macro COMMANDS_COMBUF2UINT 0
	mov si, command_data.compare_buffer_a
	COMMANDS_LIST82UINT
	mov ax, dx ; ax = uint of first compare buffer
	mov si, command_data.compare_buffer_b
	COMMANDS_LIST82UINT
%endmacro
; Consume mark and read as string (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- current mark
; bx -> string
; cx -> length
; si -> next mark
%macro COMMANDS_CONSUME_MARK_READ_STRN 0
	call commandConsumeMark
	clc
	call commandReadString
	jc command_err.invalid_variable_err
%endmacro
; Consume mark and read as string save it to list 8 (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS AND SHOULD NOT BE IN BETWEEN PUSH AND POP.
; si <- current_mark
; di <- address of list 8 to output to
; si -> next mark
%macro COMMANDS_CONSUME_MARK_READ_STRN_TO_LIST8 0
	push bx
	push cx
	call commandConsumeMark
	clc
	call commandReadString
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
	jc command_err.invalid_value_err
%endmacro
; Consume mark and read as uint (accept variable referencing).
; MUST ONLY BE CALLED IN COMMANDS.
; si <- current mark
; dx -> uint
; si -> next mark
%macro COMMANDS_CONSUME_MARK_READ_UINT 0
	push bx
	push cx
	call commandConsumeMark
	push si
	clc
	call commandReadString
	jc %%end
	mov si, bx
	clc
	call stringToUint
%%end :
	pop si
	pop cx
	pop bx
	jc command_err.invalid_uint_err
%endmacro
; --- data ---
command_data :
.disk_write_error_c_string :
	db "Fail to write disk.", 0
.disk_read_error_c_string :
	db "Fail to read disk.", 0
.invalid_file_error_c_string :
	db "Invalid file.", 0
.stack_empty_error_c_string :
	db "Stack is empty.", 0
.stack_full_error_c_string :
	db "Stack is full.", 0
.value_too_big_error_c_string :
	db "Value too big.", 0
.invalid_value_error_c_string :
	db "Invalid value.", 0
.invalid_variable_error_c_string :
	db "Invalid variable.", 0
.invalid_buffer_error_c_string :
	db "Invalid buffer.", 0
.invalid_buffer_row_error_c_string :
	db "Invalid buffer row.", 0
.invalid_arg_num_error_c_string :
	db "Invalid number of arguments.", 0
.not_running_buffer_error_c_string :
	db "Not running in the buffer.", 0
.invalid_uint_error_c_string :
	db "Invalid number.", 0
.debug_show_row_c_string :
	db "[line ", 0
.bye_c_string :
	db "Shutting down... Wait, I am still alive? Maybe holding down the power button will completely kill me.", 0
.variables :
%rep VARIABLE_COUNT
	db VARIABLE_CAPACITY, 0
	times (VARIABLE_CAPACITY) db 0
%endrep
.stack :
	times (STACK_MAX_VAR * VARIABLE_SIZE) db 0
.stack_pointer :
	dw .stack
.active_buffer :
	dw BUFFER_BEGIN_SEG
.is_buffer_executing :
	db 0 ; 0 = falist e, elist e = true
.executing_row : ; Current executing row in buffer.
	dw 0
.executing_seg : ; basically executing_row but in segment unit
	dw 0
.execution_buffer : ; Buffer for saving row to be executed.
	times BUFFER_WIDTH db 0
.compare_buffer_a : ; A list 8 buffer for value to be compared (to compare_buffer_b).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
.compare_buffer_b : ; A list 8 buffer for value to be compared (to compare_buffer_a).
	db COMPARE_BUFFER_CAPACITY, 0
	times (COMPARE_BUFFER_CAPACITY) db 0
.read_buffer : ; A list 16 buffer for read command.
	db VARIABLE_SIZE, 0
	times (VARIABLE_SIZE) dw 0
; --- command ---
@clearConsoleCommand_name :
	db "cls", 0
; n <- ignored
@clearConsoleCommand :
	push es
	mov bx, CONSOLE_DUMP_SEG
	mov es, bx
	mov cx, (CONSOLE_WIDTH * CONSOLE_HEIGHT)
	xor bx, bx
	xor ax, ax
	call wordset
	pop es
	xor dx, dx
	SET_CURSOR
	clc
	ret
@readCommand_name :
	db "read", 0
; 1 <- nth variable
@readCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	mov si, command_data.read_buffer
	xor bx, bx
	call consoleReadLine
	call list16TakeLower
	PRINT_NL
	clc
	ret
@saveCommand_name :
	db "save", 0
; 1 <- file index
@saveCommand :
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
	call storageWrite
	pop es
	jc command_err.disk_write_err
	ret
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
@divCommand_name :
	db "div", 0
; 1 <- variable for storing quotient
; 2 <- variable for stonig remainder
; 3 <- dividend
; 4 <- divisor
@divCommand :
	LIST32_GET_COUNT
	cmp cx, 5
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address for quotient
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov bx, command_data.variables
	add bx, ax ; bx = variable address for remainder
	COMMANDS_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dh, 0
	jne command_err.value_too_big_err
	div dl
	mov dx, ax
	xor ax, ax
	mov al, dl
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	mov di, bx
	xor ax, ax
	mov al, dh
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
@mulCommand_name :
	db "mul", 0
; 1 <- value for storing the product
; 2 <- first value
; 3 <- second value
@mulCommand :
	LIST32_GET_COUNT
	cmp cx, 4
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	COMMANDS_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	COMMANDS_CONSUME_MARK_READ_UINT
	mul dx
	cmp dx, 0
	jne command_err.value_too_big_err
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
@subCommand_name :
	db "sub", 0
; 1 <- variable for storing the result
; 2 <- value to be subtracted
; 3 <- subtracted value
@subCommand :
	LIST32_GET_COUNT
	cmp cx, 4
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	COMMANDS_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	COMMANDS_CONSUME_MARK_READ_UINT
	sub ax, dx
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
@addCommand_name :
	db "add", 0
; 1 <- value for storing the sum
; 2 <- first value
; 3 <- second value
@addCommand :
	LIST32_GET_COUNT
	cmp cx, 4
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	COMMANDS_CONSUME_MARK_READ_UINT
	mov ax, dx ; ax = first value
	COMMANDS_CONSUME_MARK_READ_UINT
	add ax, dx
	inc di
	mov byte [di], 5
	inc di
	call uintToString
	clc
	ret
@jumpUintLessEqualCommand_name :
	db "jule", 0
; jump if less equal
@jumpUintLessEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jbe @jumpCommand
	clc
	ret
@jumpUintLessCommand_name :
	db "jul", 0
; jump if less
@jumpUintLessCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jb @jumpCommand
	clc
	ret
@jumpUintGreaterEqualCommand_name :
	db "juge", 0
; jump if greater equal
@jumpUintGreaterEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	jae @jumpCommand
	clc
	ret
@jumpUintGreaterCommand_name :
	db "jug", 0
; jump if greater
@jumpUintGreaterCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	ja @jumpCommand
	clc
	ret
@jumpUintNotEqualCommand_name :
	db "june", 0
; If uints in compare buffer are not equal, jump command is executed.
@jumpUintNotEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	pop si
	jne @jumpCommand
	clc
	ret
@jumpUintEqualCommand_name :
	db "jue", 0
; If uints in compare buffer are equal, jump command is executed.
@jumpUintEqualCommand :
	mov bx, si
	COMMANDS_COMBUF2UINT
	mov si, bx
	cmp ax, dx
	je @jumpCommand
	clc
	ret
@jumpStringNotEqualCommand_name :
	db "jsne", 0
; If strings in compare buffer are not equal, jump command is executed.
@jumpStringNotEqualCommand :
	push si
	push di
	mov si, command_data.compare_buffer_a
	mov di, command_data.compare_buffer_b
	call list8Equal
	pop di
	pop si
	jc @jumpCommand
	clc
	ret
@jumpStringEqualCommand_name :
	db "jse", 0
; If strings in compare buffer are equal, jump command is executed.
@jumpStringEqualCommand :
	push si
	push di
	mov si, command_data.compare_buffer_a
	mov di, command_data.compare_buffer_b
	call list8Equal
	pop di
	pop si
	jnc @jumpCommand
	clc
	ret
@compareCommand_name :
	db "cmp", 0
; 1 <- value a
; 2 <- value b
@compareCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne command_err.invalid_arg_num_err
	add si, 6
	mov di, command_data.compare_buffer_a
	COMMANDS_CONSUME_MARK_READ_STRN_TO_LIST8
	mov di, command_data.compare_buffer_b
	COMMANDS_CONSUME_MARK_READ_STRN_TO_LIST8
	clc
	ret
@jumpCommand_name :
	db "jump", 0
; -1 <- nth row to be jump to
; 1? <- + if downward, - if upward (relative to the jump instruction)
@jumpCommand :
	mov byte al, [command_data.is_buffer_executing]
	cmp al, 0
	je command_err.not_running_buffer_err ; command can only run in buffer
	LIST32_GET_COUNT
	add si, 6
	cmp cx, 2
	je .absolute
	cmp cx, 3
	je .relative
	jmp command_err.invalid_arg_num_err
.relative :
	COMMANDS_CONSUME_MARK_READ_STRN
	cmp cx, 1
	jne command_err.invalid_value_err
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = displacement
	mov cx, [command_data.executing_row] ; cx = current executing row
	mov byte al, [bx]
	cmp al, '+'
	je .downward
	cmp al, '-'
	je .upward
	jmp command_err.invalid_value_err
.downward :
	add cx, dx
	mov dx, cx
	jmp .set_seg
.upward :
	sub cx, dx
	mov dx, cx
	jmp .set_seg
.absolute :
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = nth row to be jump to
.set_seg :
	cmp dx, BUFFER_HEIGHT
	jae command_err.invalid_buffer_row_err
	call commandSetExecutingSegment
	clc
	ret
@runBufferCommand_name :
	db "run", 0
; n <- ignored
@runBufferCommand :
	push es
	mov ax, ds
	mov es, ax
	mov ax, BUFFER_BEGIN_SEG ; running first buffer
	xor bx, bx ; current running line
	mov byte [command_data.is_buffer_executing], 1
.loop :
	cmp ax, (BUFFER_BEGIN_SEG + BUFFER_SEG_COUNT)
	jae .loop_end
	cmp ax, BUFFER_BEGIN_SEG
	jb .loop_end
	mov word [command_data.executing_row], bx
	mov word [command_data.executing_seg], ax
; copy line from buffer to command_data.execution_buffer
	push ds
	xor si, si
	mov di, command_data.execution_buffer
	mov cx, BUFFER_WIDTH
	mov ds, ax
	cld
	rep movsb
	pop ds
; execute it
	mov si, command_data.execution_buffer
	mov cx, BUFFER_WIDTH
	clc
	call interpreterExecuteString
	jc .loop_end
; update current running row
	mov dx, [command_data.executing_row]
	cmp dx, bx
	jne .executing_row_changed
	inc bx
	jmp .executing_row_changed_end
.executing_row_changed :
	mov bx, dx
.executing_row_changed_end :
; update current running seg
	mov dx, [command_data.executing_seg]
	cmp dx, ax
	jne .executing_seg_changed
	add ax, BUFFER_SEG_PER_ROW
	jmp .executing_seg_changed_end
.executing_seg_changed :
	mov ax, dx
.executing_seg_changed_end :
	jmp .loop
.loop_end :
	mov byte [command_data.is_buffer_executing], 0
	pop es
	clc
	ret
@clearBufferCommand_name :
	db "clb", 0
@clearBufferCommand :
	push es
	mov al, ' '
	xor bx, bx
	mov dx, BUFFER_SEC_COUNT
	mov si, [command_data.active_buffer]
	mov cx, SECTOR_SIZE
.clear_loop :
	cmp dx, 0
	je .clear_loop_end
	mov es, si
	call byteset
	add si, (SECTOR_SIZE >> 4)
	dec dx
	jmp .clear_loop
.clear_loop_end :
	pop es
	clc
	ret
@setActiveBufferCommand_name :
	db "stb", 0
; 1 <- buffer to be set
@setActiveBufferCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 2
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = buffer index
	cmp dx, BUFFER_COUNT
	jae command_err.invalid_buffer_err
	mov ax, BUFFER_SEG_COUNT
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [command_data.active_buffer], ax
	clc
	ret
@setRowCommand_name :
	db "=", 0
; 1 <- row to be set
; 2 <- new row
@setRowCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3 ; no args
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = row
	cmp dx, BUFFER_HEIGHT
	jae command_err.invalid_buffer_row_err
	COMMANDS_CONSUME_MARK_READ_STRN
	mov si, bx ; si = new row content
	cmp cx, BUFFER_WIDTH
	jae command_err.value_too_big_err ; cx = content length
	mov ax, dx
	mov dx, BUFFER_SEG_PER_ROW
	mul dx
	add ax, [command_data.active_buffer] ; ax = buffer row seg
; clear the row
	push es
	mov es, ax
	push cx
	mov cx, BUFFER_WIDTH
	xor bx, bx
	mov al, ' '
	call byteset
	pop cx
	xor di, di
	cld
	rep movsb
	pop es
	clc
	ret
@listBufferCommand_name :
	db "lsb", 0
; 1? <- starting row
; 2? <- count
@listBufferCommand :
	LIST32_GET_COUNT ; cx = args count
	xor dx, dx ; default 1st arg
	mov ax, 5 ; default 2nd arg
	cmp cx, 1 ; no args
	jbe .list
	cmp cx, 2 ; have starting row
	je .list_with_start
	cmp cx, 3 ; have count
	je .list_with_count
	jmp command_err.invalid_arg_num_err
.list_with_count :
	push si
	add si, 10 ; the third arg
	call commandConsumeMark
	clc
	call commandReadString
	jc .list_count_read_string_fail_err
	mov si, bx
	clc
	call stringToUint
.list_count_read_string_fail_err :
	pop si
	jc command_err.invalid_uint_err
	mov ax, dx ; ax = count
.list_with_start :
	add si, 6 ; the second arg
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = starting row
.list :
	mov cx, ax ; cx = counter
	mov bx, dx ; bx = starting row ; dx = current line
	mov ah, MAGENTA
.list_loop :
	cmp cx, 0
	je .list_loop_end
	cmp dx, BUFFER_HEIGHT
	jae .list_loop_end
	call consolePrintUint
	PRINT_CHAR ' '
	pusha
	push es
	push ds
; copy from buffer to video dump
; setup source
	mov ax, dx
	mov dx, BUFFER_SEG_PER_ROW
	mul dx
	add ax, [command_data.active_buffer]
	mov es, ax
	xor si, si
; setup destination
	GET_CURSOR
	CONSOLE_RC2IDX dh, dl ; bx = index
	shl bx, 1
	mov di, bx
	mov cx, CONSOLE_DUMP_SEG
	mov ds, cx
	mov cx, BUFFER_WIDTH
	xor ax, ax
	mov ah, BRIGHT
.mov_loop :
	mov byte al, [es : si]
	mov word [ds : di], ax
	inc si
	add di, 2
	dec cx
	jnz .mov_loop
	pop ds
	pop es
	popa
	PRINT_NL
	inc dx
	dec cx
	jmp .list_loop
.list_loop_end :
.end :
	clc
	ret
@resetStackCommand_name :
	db "rst", 0
; n <- ignored
@resetStackCommand :
	mov word [command_data.stack_pointer], command_data.stack
	ret
@popStackCommand_name :
	db "pop", 0
; n <- variables to be popped
@popStackCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count exluding the command
	add si, 6 ; si i= 1st arg
.pop_loop :
	cmp cx, 0
	je .end
	mov word di, [command_data.stack_pointer]
	cmp di, command_data.stack
	jbe command_err.stack_empty_err
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	push si
	push cx
	mov si, di
	sub si, VARIABLE_SIZE ; si = stack pointer
	mov word [command_data.stack_pointer], si
	mov di, command_data.variables
	add di, ax ; di = variable address
	mov cx, VARIABLE_SIZE
	cld
	rep movsb
	pop cx
	pop si
	dec cx
	jmp .pop_loop
.end :
	clc
	ret
@pushStackCommand_name :
	db "push", 0
; n <- variables to be pushed
@pushStackCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 1
	jbe .end
	dec cx ; cx = args count excluding the command
	add si, 6 ; si = 1st arg
.push_loop :
	cmp cx, 0
	je .end
	mov word di, [command_data.stack_pointer] ; di = pointer to top of the stack
	cmp di, command_data.stack_pointer
	jae command_err.stack_full_err
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	push si
	push cx
	mov si, command_data.variables
	add si, ax ; si = variable address
	mov cx, VARIABLE_SIZE
	cld
	rep movsb
	mov word [command_data.stack_pointer], di
	pop cx
	pop si
	dec cx
	jmp .push_loop
.end :
	clc
	ret
@setCommand_name :
	db "set", 0
; 1 <- nth variable
; 2 <- value
@setCommand :
	LIST32_GET_COUNT ; cx = args count
	cmp cx, 3
	jne command_err.invalid_arg_num_err
	add si, 6
	COMMANDS_CONSUME_MARK_READ_UINT ; dx = variable
	cmp dx, VARIABLE_COUNT
	jae command_err.invalid_variable_err
	mov al, VARIABLE_SIZE
	mul dl
	mov di, command_data.variables
	add di, ax ; di = variable address
	COMMANDS_CONSUME_MARK_READ_STRN_TO_LIST8
	clc
	ret
@byeCommand_name :
	db "bye", 0
; n <- ignored
@byeCommand :
	mov bx, command_data.bye_c_string
	call printCString
	PRINT_NL
	mov ax, 0x5307
	mov cx, 0x03
	mov bx, 0x01
	int 0x15
	clc
	ret
@sayCommand_name :
	db "say", 0
; -1 <- message to be printed
; 1? <- options
@sayCommand :
	LIST32_GET_COUNT
	mov ah, GREY ; ah = text color
	xor al, al ; al = number of new lines after print.
	add si, 6
	cmp cx, 2
	je .default
	cmp cx, 3
	je .set_option
	jmp command_err.invalid_arg_num_err
.set_option :
	COMMANDS_CONSUME_MARK_READ_STRN
.option_detection_loop :
	cmp cx, 0
	je .default
	mov byte dl, [bx]
	cmp dl, 'n'
	jne .not_newline_option
	inc al
	jmp .continue_option_detection_loop
.not_newline_option :
; %1 <- character
; %2 <- color
%macro COLOR_OPTION 2
	cmp dl, %1
	jne %%end
	mov ah, %2
	jmp .continue_option_detection_loop
%%end :
%endmacro
	COLOR_OPTION 'd', BLACK
	COLOR_OPTION 'b', BLUE
	COLOR_OPTION 'v', GREEN
	COLOR_OPTION 'c', CYAN
	COLOR_OPTION 'r', RED
	COLOR_OPTION 'm', MAGENTA
	COLOR_OPTION 'y', YELLOW
	COLOR_OPTION 'g', GREY
	COLOR_OPTION 'B', (BRIGHT + BLUE)
	COLOR_OPTION 'V', (BRIGHT + GREEN)
	COLOR_OPTION 'C', (BRIGHT + CYAN)
	COLOR_OPTION 'R', (BRIGHT + RED)
	COLOR_OPTION 'M', (BRIGHT + MAGENTA)
	COLOR_OPTION 'Y', (BRIGHT + YELLOW)
	COLOR_OPTION 'G', BRIGHT
	COLOR_OPTION 'w', WHITE
%unmacro COLOR_OPTION 2
.continue_option_detection_loop :
	inc bx
	dec cx
	jmp .option_detection_loop
.default :
	COMMANDS_CONSUME_MARK_READ_STRN
	cmp cx, 0
	je .newline_loop
	mov si, bx
.print_string :
	call consolePrintString
.newline_loop :
	cmp al, 0
	je .end
	PRINT_NL
	dec al
	jmp .newline_loop
.end :
	clc
	ret
; --- subroutine ---
; Read string (accept variable referencing).
; bx <- string
; cx <- length
; bx -> string
; cx -> length
; cf -> set if fail
commandReadString :
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
	cmp dx, VARIABLE_COUNT
	jae .fail
	mov al, VARIABLE_SIZE
	mul dl
	mov si, command_data.variables
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
; Set executing row together with its corresponding executing segment.
; dx <- executing row
commandSetExecutingSegment :
	push ax
	push dx
	mov word [command_data.executing_row], dx
	mov ax, BUFFER_SEG_PER_ROW
	mul dx
	add ax, BUFFER_BEGIN_SEG
	mov word [command_data.executing_seg], ax
	pop dx
	pop ax
	ret
; si <- current mark
; bx -> address of argument
; cx -> length of argument
; si -> next mark
commandConsumeMark :
	mov word cx, [si]
	add si, 2
	mov word bx, [si]
	add si, 2
	ret
; There is so many repeating lines of code for handling err so I just put it all in one place.
command_err :
.disk_write_err :
	mov bx, command_data.disk_write_error_c_string
	jmp .print
.disk_read_err :
	mov bx, command_data.disk_read_error_c_string
	jmp .print
.invalid_file_err :
	mov bx, command_data.invalid_file_error_c_string
	jmp .print
.value_too_big_err :
	mov bx, command_data.value_too_big_error_c_string
	jmp .print
.invalid_arg_num_err :
	mov bx, command_data.invalid_arg_num_error_c_string
	jmp .print
.stack_full_err :
	mov bx, command_data.stack_full_error_c_string
	jmp .print
.stack_empty_err :
	mov bx, command_data.stack_empty_error_c_string
	jmp .print
.invalid_value_err :
	mov bx, command_data.invalid_value_error_c_string
	jmp .print
.invalid_variable_err :
	mov bx, command_data.invalid_variable_error_c_string
	jmp .print
.invalid_buffer_err :
	mov bx, command_data.invalid_buffer_error_c_string
	jmp .print
.invalid_buffer_row_err :
	mov bx, command_data.invalid_buffer_row_error_c_string
	jmp .print
.not_running_buffer_err :
	mov bx, command_data.not_running_buffer_error_c_string
	jmp .print
.invalid_uint_err :
	mov bx, command_data.invalid_uint_error_c_string
.print :
	mov byte al, [command_data.is_buffer_executing]
	cmp al, 0
	je .not_running_buffer
	call printError
	PRINT_CHAR ' '
	mov bx, command_data.debug_show_row_c_string
	call printCString
	mov ah, MAGENTA
	mov dx, [command_data.executing_row]
	call consolePrintUint
	PRINT_CHAR ']'
	PRINT_NL
	jmp .end
.not_running_buffer :
	call printErrorLine
.end :
	stc
	ret
; --- checks ---
%if (VARIABLE_SIZE > 0xff) || (VARIABLE_COUNT > 0xff)
%error "Variable size and count must be a byte."
%endif
%if (VARIABLE_CAPACITY < 5)
%error "Variable too small for uint."
%endif
%if (VARIABLE_CAPACITY < BUFFER_WIDTH)
%error "Variable too small for buffer row."
%endif
%endif ; _COMMANDS_SUB_ASM_