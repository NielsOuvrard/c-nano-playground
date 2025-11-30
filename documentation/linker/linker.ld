/******************************************************************************
 * custom.ld - Custom Linker Script for ATmega328P
 * 
 * Memory Layout:
 *   Flash:  0x0000 - 0x7DFF (31.5KB app) + 0x7E00 - 0x7FFF (512B bootloader)
 *   SRAM:   0x0100 - 0x08FF (2KB organized into regions)
 *   EEPROM: 0x000 - 0x3FF (1KB)
 *****************************************************************************/

OUTPUT_FORMAT("elf32-avr","elf32-avr","elf32-avr")
OUTPUT_ARCH(avr:5)
ENTRY(__vectors)

/******************************************************************************
 * MEMORY REGIONS
 *****************************************************************************/

MEMORY
{
    /* Flash Memory: 32KB total */
    text (rx)       : ORIGIN = 0x00000000, LENGTH = 0x7E00    /* 31.5KB for app */
    bootloader (rx) : ORIGIN = 0x00007E00, LENGTH = 0x0200    /* 512B reserved */
    
    /* SRAM: 2KB total, organized into functional regions */
    sys_vars (rw!x)    : ORIGIN = 0x00800100, LENGTH = 128    /* 0x0100-0x017F */
    serial_buf (rw!x)  : ORIGIN = 0x00800180, LENGTH = 256    /* 0x0180-0x027F */
    fixed_mem (rw!x)   : ORIGIN = 0x00800280, LENGTH = 256    /* 0x0280-0x037F */
    app_data (rw!x)    : ORIGIN = 0x00800380, LENGTH = 896    /* 0x0380-0x06FF */
    stack_area (rw!x)  : ORIGIN = 0x00800700, LENGTH = 512    /* 0x0700-0x08FF */
    
    /* EEPROM: 1KB */
    eeprom (rw!x)   : ORIGIN = 0x00810000, LENGTH = 0x0400
    
    /* Special regions */
    fuse (rw!x)      : ORIGIN = 0, LENGTH = 3
    lock (rw!x)      : ORIGIN = 0, LENGTH = 1
    signature (rw!x) : ORIGIN = 0, LENGTH = 3
}

/******************************************************************************
 * SECTIONS
 *****************************************************************************/

SECTIONS
{
    /* ========================================================================
     * FLASH SECTIONS
     * ======================================================================== */
    
    /* Main program code */
    .text :
    {
        /* Mark start of .text section */
        __text_start = .;
        __trampolines_start = .;
        
        /* Interrupt Vector Table (must be at address 0) */
        *(.vectors)
        KEEP(*(.vectors))
        
        __trampolines_end = .;
        __ctors_start = .;
        *(.ctors)
        __ctors_end = .;
        __dtors_start = .;
        *(.dtors)
        __dtors_end = .;
        
        /* Initialization sections (.init0 through .init9) */
        KEEP(*(.init0))  /* Start here after reset */
        KEEP(*(.init1))
        KEEP(*(.init2))  /* Clear __zero_reg__ */
        KEEP(*(.init3))
        KEEP(*(.init4))  /* Copy .data from Flash to SRAM */
        KEEP(*(.init5))
        KEEP(*(.init6))
        KEEP(*(.init7))
        KEEP(*(.init8))
        KEEP(*(.init9))  /* Jump to main() */
        
        /* Regular program code */
        *(.text)
        *(.text*)
        
        /* Finalization sections */
        KEEP(*(.fini9))
        KEEP(*(.fini8))
        KEEP(*(.fini7))
        KEEP(*(.fini6))
        KEEP(*(.fini5))
        KEEP(*(.fini4))
        KEEP(*(.fini3))
        KEEP(*(.fini2))
        KEEP(*(.fini1))
        KEEP(*(.fini0))
        
        /* Mark end of .text section */
        __text_end = .;
    } > text
    
    /* Critical code in known location (after .text) */
    .critical_code :
    {
        __critical_start = .;
        *(.critical_code)
        __critical_end = .;
    } > text
    
    /* Read-only data (const variables) */
    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > text
    
    /* PROGMEM data */
    .progmem.data :
    {
        __progmem_start = .;
        *(.progmem.data)
        *(.progmem*)
        __progmem_end = .;
    } > text
    
    /* Bootloader section (optional, for reference) */
    .bootloader :
    {
        *(.bootloader)
    } > bootloader
    
    /* ========================================================================
     * SRAM SECTIONS
     * ======================================================================== */
    
    /* System variables region */
    .sys_vars :
    {
        __sys_start = .;
        *(.sys_data)
        __sys_end = .;
    } > sys_vars AT > text
    
    /* Serial buffers (NOLOAD = not copied from Flash) */
    .serial_buffers (NOLOAD) :
    {
        __serial_start = .;
        *(.serial_buffers)
        __serial_end = .;
    } > serial_buf
    
    /* Fixed memory region at 0x0280 */
    .fixed_memory (NOLOAD) :
    {
        __fixed_start = .;
        *(.fixed_memory)
        __fixed_end = .;
    } > fixed_mem
    
    /* Initialized data (.data section) */
    .data :
    {
        __data_start = .;
        *(.data)
        *(.data*)
        *(.rodata)  /* Small const data may go here */
        *(.rodata*)
        __data_end = .;
    } > app_data AT > text
    
    /* Store Flash address of .data initialization values */
    __data_load_start = LOADADDR(.data);
    __data_load_end = __data_load_start + SIZEOF(.data);
    
    /* Uninitialized data (.bss section - zeroed at startup) */
    .bss :
    {
        __bss_start = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > app_data
    
    /* Persistent data (.noinit - not zeroed at startup) */
    .noinit (NOLOAD) :
    {
        __noinit_start = .;
        *(.noinit)
        *(.noinit*)
        __noinit_end = .;
    } > app_data
    
    /* Heap region (for malloc - starts after .noinit) */
    __heap_start = .;
    __heap_end = ORIGIN(app_data) + LENGTH(app_data);
    
    /* Stack region (grows downward from top) */
    __stack_start = ORIGIN(stack_area);
    __stack_end = ORIGIN(stack_area) + LENGTH(stack_area);
    
    /* Set stack pointer to top of stack region */
    PROVIDE(__stack = __stack_end);
    
    /* ========================================================================
     * EEPROM SECTION
     * ======================================================================== */
    
    .eeprom :
    {
        __eeprom_start = .;
        *(.eeprom)
        *(.eeprom*)
        __eeprom_end = .;
    } > eeprom
    
    /* ========================================================================
     * SPECIAL SECTIONS
     * ======================================================================== */
    
    .fuse :
    {
        KEEP(*(.fuse))
        KEEP(*(.lfuse))
        KEEP(*(.hfuse))
        KEEP(*(.efuse))
    } > fuse
    
    .lock :
    {
        KEEP(*(.lock))
    } > lock
    
    .signature :
    {
        KEEP(*(.signature))
    } > signature
    
    /* ========================================================================
     * DEBUG SECTIONS (not loaded to chip, only for debugging)
     * ======================================================================== */
    
    .stab 0 : { *(.stab) }
    .stabstr 0 : { *(.stabstr) }
    .stab.excl 0 : { *(.stab.excl) }
    .stab.exclstr 0 : { *(.stab.exclstr) }
    .stab.index 0 : { *(.stab.index) }
    .stab.indexstr 0 : { *(.stab.indexstr) }
    .comment 0 : { *(.comment) }
    .debug 0 : { *(.debug) }
    .line 0 : { *(.line) }
    .debug_srcinfo 0 : { *(.debug_srcinfo) }
    .debug_sfnames 0 : { *(.debug_sfnames) }
    .debug_aranges 0 : { *(.debug_aranges) }
    .debug_pubnames 0 : { *(.debug_pubnames) }
    .debug_info 0 : { *(.debug_info .gnu.linkonce.wi.*) }
    .debug_abbrev 0 : { *(.debug_abbrev) }
    .debug_line 0 : { *(.debug_line .debug_line.* .debug_line_end ) }
    .debug_frame 0 : { *(.debug_frame) }
    .debug_str 0 : { *(.debug_str) }
    .debug_loc 0 : { *(.debug_loc) }
    .debug_macinfo 0 : { *(.debug_macinfo) }
    .debug_weaknames 0 : { *(.debug_weaknames) }
    .debug_funcnames 0 : { *(.debug_funcnames) }
    .debug_typenames 0 : { *(.debug_typenames) }
    .debug_varnames 0 : { *(.debug_varnames) }
    .debug_pubtypes 0 : { *(.debug_pubtypes) }
    .debug_ranges 0 : { *(.debug_ranges) }
    .debug_macro 0 : { *(.debug_macro) }
    
    /* ========================================================================
     * SAFETY CHECKS
     * ======================================================================== */
    
    /* Ensure code doesn't overflow into bootloader space */
    ASSERT(__text_end + __critical_end <= 0x7E00, 
           "ERROR: Code overflows into bootloader region!")
    
    /* Ensure SRAM doesn't overflow */
    ASSERT(__heap_start <= __heap_end, 
           "ERROR: SRAM overflow - data too large!")
    
    /* Ensure stack has space */
    ASSERT(LENGTH(stack_area) >= 256, 
           "ERROR: Stack space too small (need at least 256 bytes)!")
}

/******************************************************************************
 * SYMBOL EXPORTS
 * (These can be accessed from C code as extern variables)
 *****************************************************************************/

/* Provide default symbols if not defined */
PROVIDE(__do_copy_data = 1);
PROVIDE(__do_clear_bss = 1);