%ifndef _TYPEDEF_MACROS_ASM_
%define _TYPEDEF_MACROS_ASM_
; --- macros ---
%define FREE_BEGIN 0x7e00
%define FREE_END 0x9fc00
%define KERNEL_CODE_BEGIN_SEG 0x1000
%ifndef KERNEL_CODE_SECTOR_COUNT
%define KERNEL_CODE_SECTOR_COUNT 30
%endif
%define KERNEL_CODE_SIZE KERNEL_CODE_SECTOR_COUNT * 512
%define KERNEL_STACK_SIZE 0x2000
%assign KERNEL_FINAL_ADDR ((KERNEL_CODE_BEGIN_SEG << 4) + KERNEL_CODE_SIZE + KERNEL_STACK_SIZE)
%define BUFFER_BEGIN_ADDR (KERNEL_FINAL_ADDR + 1000)
%define BUFFER_BEGIN_SEG (BUFFER_BEGIN_ADDR >> 4)
%define BUFFER_COUNT 3 ; {1B}
%define BUFFER_SEG_PER_ROW 3 ; width in segment unit, segment per row
%define BUFFER_SECT_PER_COL 5 ; height in (disk) sector unit, sector per column
%define BUFFER_WIDTH (BUFFER_SEG_PER_ROW << 4)
%define BUFFER_HEIGHT (BUFFER_SECT_PER_COL * 512)
%define BUFFER_SIZE (BUFFER_WIDTH * BUFFER_HEIGHT)
%define BUFFER_SEG_COUNT (BUFFER_SIZE >> 4)
%define BUFFER_SEC_COUNT (BUFFER_SIZE / 512)
; Memory mapping :
; high
; ...
; video dump
; ...
; buffer(s)
; stack
; code
; ...
; low
; --- checks ---
%if (BUFFER_WIDTH > 0xff) && (BUFFER_COUNT > 0xff)
%error "Buffer width and count must be a byte."
%elif (BUFFER_SEG_PER_ROW > 0xff)
%error "Buffer's segment per row must be a byte."
%endif
%if ((BUFFER_SEG_COUNT * (BUFFER_COUNT - 1)) > 0xffff)
%error "There are buffer in which its begin segment is greater than a word, causing invalid segment."
%endif
%if (BUFFER_BEGIN_ADDR + BUFFER_SIZE * BUFFER_COUNT) >= FREE_END
%error "Buffer exceed the end of free memory."
%endif
%endif ; _TYPEDEF_MACROS_ASM_