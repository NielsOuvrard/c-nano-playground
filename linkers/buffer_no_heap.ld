/* Minimal Linker Script for ATmega328P with Static Buffer Partitioning
 * Flash: 32KB, SRAM: 2KB, EEPROM: 1KB
 * Based on avr5.xn linker script
 * 
 * Static Buffer Memory Layout (SRAM starts at 0x800100):
 * - buffer_128: 128 bytes (0x800100 - 0x80017F)
 * - buffer_256: 256 bytes (0x800180 - 0x80027F)
 * - buffer_640: 640 bytes (0x800280 - 0x8004FF)
 * - data/bss/noinit: Variable memory (0x800500 onwards)
 * - stack: Remaining space (grows downward from 0x8008FF)
 */

OUTPUT_FORMAT("elf32-avr","elf32-avr","elf32-avr")
OUTPUT_ARCH(avr:5)

MEMORY
{
  text        (rx)   : ORIGIN = 0x000000, LENGTH = 32K
  
  /* Static buffer partitions - strict memory boundaries (buffers first) */
  buffer_128  (rw!x) : ORIGIN = 0x800100, LENGTH = 128
  buffer_256  (rw!x) : ORIGIN = 0x800180, LENGTH = 256
  buffer_640  (rw!x) : ORIGIN = 0x800280, LENGTH = 640
  
  /* Data section follows buffers */
  data        (rw!x) : ORIGIN = 0x800500, LENGTH = 1K
  eeprom      (rw!x) : ORIGIN = 0x810000, LENGTH = 1K
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

  /* Static Buffer Sections - Strictly Sized and Partitioned (placed first in SRAM) */
  
  /* 128-byte buffer section */
  .buffer_128 (NOLOAD) :
  {
    PROVIDE(__buffer_128_start = .);
    *(.buffer_128)
    *(.buffer_128*)
    . = ORIGIN(buffer_128) + LENGTH(buffer_128);
    PROVIDE(__buffer_128_end = .);
  } > buffer_128
  
  ASSERT(SIZEOF(.buffer_128) <= 128, "ERROR: .buffer_128 exceeds 128 bytes")
  
  /* 256-byte buffer section */
  .buffer_256 (NOLOAD) :
  {
    PROVIDE(__buffer_256_start = .);
    *(.buffer_256)
    *(.buffer_256*)
    . = ORIGIN(buffer_256) + LENGTH(buffer_256);
    PROVIDE(__buffer_256_end = .);
  } > buffer_256
  
  ASSERT(SIZEOF(.buffer_256) <= 256, "ERROR: .buffer_256 exceeds 256 bytes")
  
  /* 640-byte buffer section */
  .buffer_640 (NOLOAD) :
  {
    PROVIDE(__buffer_640_start = .);
    *(.buffer_640)
    *(.buffer_640*)
    . = ORIGIN(buffer_640) + LENGTH(buffer_640);
    PROVIDE(__buffer_640_end = .);
  } > buffer_640
  
  ASSERT(SIZEOF(.buffer_640) <= 640, "ERROR: .buffer_640 exceeds 640 bytes")

  /* Initialized data (placed after buffers) */
  .data :
  {
    PROVIDE(__data_start = .);
    *(.data)
    *(.data*)
    *(.rodata)  /* Constants need to be in RAM for AVR-GCC's default behavior */
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
  } > data
  
  /* EEPROM */
  .eeprom :
  {
    KEEP(*(.eeprom*))
    __eeprom_end = .;
  } > eeprom
}
