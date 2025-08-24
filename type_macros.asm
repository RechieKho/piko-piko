%ifndef _TYPEDEF_MACROS_ASM_
%define _TYPEDEF_MACROS_ASM_
; --- macros ---
%define SECTOR_SIZE 512
%define FREE_BEGIN 0x7e00
%define FREE_END 0x9fc00
%define KERNEL_CODE_BEGIN_SEG 0x1000
%define KERNEL_CODE_BEGIN_SEC 0x02 ; sector right after boot (1 in LBA addressing)
%ifndef KERNEL_CODE_SECTOR_COUNT
%define KERNEL_CODE_SECTOR_COUNT 30
%endif
%define KERNEL_CODE_END_SEC (KERNEL_CODE_BEGIN_SEC + KERNEL_CODE_SECTOR_COUNT - 1)
%define KERNEL_CODE_SIZE (KERNEL_CODE_SECTOR_COUNT * SECTOR_SIZE)
%define KERNEL_STACK_SIZE 0x2000
%assign KERNEL_FINAL_ADDR ((KERNEL_CODE_BEGIN_SEG << 4) + KERNEL_CODE_SIZE + KERNEL_STACK_SIZE)
%define BUFFER_BEGIN_ADDR ((KERNEL_FINAL_ADDR + 1000) ^ ((KERNEL_FINAL_ADDR + 1000) & 0xf))
%define BUFFER_BEGIN_SEG (BUFFER_BEGIN_ADDR >> 4)
%define BUFFER_COUNT 10
%define BUFFER_SEG_PER_ROW 2 ; width in segment unit, segment per row
%define BUFFER_SECT_PER_COL 3 ; height in (disk) sector unit, sector per column
%define BUFFER_WIDTH (BUFFER_SEG_PER_ROW << 4)
%define BUFFER_HEIGHT (BUFFER_SECT_PER_COL * SECTOR_SIZE)
%define BUFFER_SIZE (BUFFER_WIDTH * BUFFER_HEIGHT)
%define BUFFER_SEG_COUNT (BUFFER_SIZE >> 4)
%define BUFFER_SEC_COUNT (BUFFER_SIZE / SECTOR_SIZE)
%ifndef STORAGE_SECTOR_COUNT
%define STORAGE_SECTOR_COUNT 240
%endif
%define STORAGE_BEGIN_SEC (KERNEL_CODE_END_SEC + 1)
%define STORAGE_SIZE (STORAGE_SECTOR_COUNT * SECTOR_SIZE)
%define FILE_COUNT (STORAGE_SIZE / BUFFER_SIZE)
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
%if (BUFFER_SEC_COUNT >= 128)
%error "Buffer sector count must not larger than 128."
%endif
%if (FILE_COUNT > 0xff)
%error "File count must be a byte."
%endif
%endif ; _TYPEDEF_MACROS_ASM_