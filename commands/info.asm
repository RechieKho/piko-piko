%ifndef _INFO_COM_ASM_
%define _INFO_COM_ASM_
; --- data ---
info_com_data :
.version_c_string:
    db "Piko-piko version: ", 0
.version_major_c_string:
    db VERSION_MAJOR, 0
.version_minor_c_string:
    db VERSION_MINOR, 0
.version_patch_c_string:
    db VERSION_PATCH, 0
.file_count_c_string:
    db "File count: ", 0
.buffer_count_c_string:
    db "Buffer count: ", 0
.buffer_resolution_c_string:
    db "Buffer resolution: ", 0
; --- commands ---
@infoCommand_name :
    db "info", 0
; n <- ignored
@infoCommand :
    mov bx, info_com_data.version_c_string
    call printCString
    mov bx, info_com_data.version_major_c_string
    call printCString
    PRINT_CHAR '.'
    mov bx, info_com_data.version_minor_c_string
    call printCString
    PRINT_CHAR '.'
    mov bx, info_com_data.version_patch_c_string
    call printCString
    PRINT_NL
    mov bx, info_com_data.file_count_c_string
    call printCString
    PRINT_WORD FILE_COUNT
    PRINT_NL
    mov bx, info_com_data.buffer_count_c_string
    call printCString
    PRINT_WORD BUFFER_COUNT
    PRINT_NL
    mov bx, info_com_data.buffer_resolution_c_string
    call printCString
    PRINT_WORD BUFFER_WIDTH
    PRINT_CHAR ' '
    PRINT_CHAR '*'
    PRINT_CHAR ' '
    PRINT_WORD BUFFER_HEIGHT
    PRINT_NL
    ret
%endif ; _INFO_COM_ASM_