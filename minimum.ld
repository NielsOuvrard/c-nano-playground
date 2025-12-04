/* Minimal Linker Script for ATmega328P
 * Flash: 32KB, SRAM: 2KB, EEPROM: 1KB
 * Based on avr5.xn linker script
 */

OUTPUT_FORMAT("elf32-avr","elf32-avr","elf32-avr")
OUTPUT_ARCH(avr:5)

MEMORY
{
  text   (rx)   : ORIGIN = 0x000000, LENGTH = 32K
  data   (rw!x) : ORIGIN = 0x800060, LENGTH = 2K
  eeprom (rw!x) : ORIGIN = 0x810000, LENGTH = 1K
}

SECTIONS
{
  /* Program code and constants */
  .text :
  {
    *(.vectors)
    KEEP(*(.vectors))
    
    /* Initialization sections */
    *(.init0) KEEP(*(.init0))
    *(.init1) KEEP(*(.init1))
    *(.init2) KEEP(*(.init2))
    *(.init3) KEEP(*(.init3))
    *(.init4) KEEP(*(.init4))
    *(.init5) KEEP(*(.init5))
    *(.init6) KEEP(*(.init6))
    *(.init7) KEEP(*(.init7))
    *(.init8) KEEP(*(.init8))
    *(.init9) KEEP(*(.init9))
    
    /* User code */
    *(.text)
    . = ALIGN(2);
    *(.text.*)
    . = ALIGN(2);
    
    /* Finalization sections */
    *(.fini9) KEEP(*(.fini9))
    *(.fini8) KEEP(*(.fini8))
    *(.fini7) KEEP(*(.fini7))
    *(.fini6) KEEP(*(.fini6))
    *(.fini5) KEEP(*(.fini5))
    *(.fini4) KEEP(*(.fini4))
    *(.fini3) KEEP(*(.fini3))
    *(.fini2) KEEP(*(.fini2))
    *(.fini1) KEEP(*(.fini1))
    *(.fini0) KEEP(*(.fini0))
    
    _etext = .;
  } > text

  /* Initialized data */
  .data :
  {
    PROVIDE(__data_start = .);
    *(.data)
    *(.data*)
    *(.rodata)
    *(.rodata*)
    . = ALIGN(2);
    _edata = .;
    PROVIDE(__data_end = .);
  } > data AT> text

  __data_load_start = LOADADDR(.data);
  __data_load_end = __data_load_start + SIZEOF(.data);

  /* Uninitialized data */
  .bss ADDR(.data) + SIZEOF(.data) : AT(ADDR(.bss))
  {
    PROVIDE(__bss_start = .);
    *(.bss)
    *(.bss*)
    *(COMMON)
    PROVIDE(__bss_end = .);
  } > data

  /* Non-initialized data */
  .noinit ADDR(.bss) + SIZEOF(.bss) : AT(ADDR(.noinit))
  {
    PROVIDE(__noinit_start = .);
    *(.noinit*)
    PROVIDE(__noinit_end = .);
    _end = .;
    PROVIDE(__heap_start = .);
  } > data

  /* EEPROM */
  .eeprom :
  {
    KEEP(*(.eeprom*))
    __eeprom_end = .;
  } > eeprom
}
