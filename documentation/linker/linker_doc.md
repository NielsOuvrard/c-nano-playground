# Linker Script Documentation for ATmega328P

## Table of Contents
1. [What is a Linker?](#what-is-a-linker)
2. [Linker Script Basics](#linker-script-basics)
3. [ATmega328P Default Linker Script](#atmega328p-default-linker-script)
4. [Memory Regions](#memory-regions)
5. [Sections](#sections)
6. [Custom Linker Scripts](#custom-linker-scripts)
7. [Advanced Topics](#advanced-topics)

---

# What is a Linker?

## Compilation Process Overview

```
Source Code (.c, .cpp)
         ↓
    Preprocessor (handles #include, #define)
         ↓
    Compiler (generates assembly)
         ↓
    Assembler (generates object files .o)
         ↓
    LINKER ← YOU ARE HERE
         ↓
    Executable (.elf)
         ↓
    objcopy (converts to .hex for programming)
         ↓
    Final Program (.hex)
```

### What the Linker Does:

1. **Combines multiple object files** into one executable
2. **Resolves symbols** (connects function calls to their definitions)
3. **Assigns addresses** to code and data
4. **Organizes memory layout** (where things go in Flash/SRAM)
5. **Creates the final binary** with all parts in the right places

### Example:

```c
// file1.c
int global_var = 42;

void setup() {
    external_function();  // Defined in file2.c
}

// file2.c
void external_function() {
    // Do something
}
```

**Compilation:**
```
file1.c → Compiler → file1.o (global_var at ???, external_function at ???)
file2.c → Compiler → file2.o (external_function at ???)
```

**Linking:**
```
Linker reads linker script:
  1. Place global_var at 0x0100 (SRAM start)
  2. Place setup() at 0x0000 (Flash start)
  3. Place external_function() at 0x00A4 (after setup)
  4. Resolve external_function call → point to 0x00A4

Result: program.elf with everything at fixed addresses
```

---

# Linker Script Basics

## Linker Script Language

Linker scripts are written in **GNU ld script language** (used by avr-gcc).

### Basic Structure:

```ld
MEMORY {
    /* Define available memory regions */
}

SECTIONS {
    /* Define how to organize code/data into memory */
}
```

---

# ATmega328P Default Linker Script

## Simplified Default Linker Script

Here's the ATmega328P default linker script, annotated:

```ld
/******************************************************************************
 * ATmega328P Default Linker Script (Simplified & Annotated)
 *****************************************************************************/

/* Entry point - where execution starts */
ENTRY(__vectors)

/* Memory layout of ATmega328P */
MEMORY
{
    /* 
     * Flash Memory (Program Storage)
     * Origin: 0x00000000 (but actually mapped to 0x0000 in AVR addressing)
     * Length: 32KB = 0x8000 bytes
     * Attributes: rx = readable, executable
     */
    text (rx)   : ORIGIN = 0x00000000, LENGTH = 32K
    
    /* 
     * SRAM (Data Memory)
     * Origin: 0x00800100 (AVR memory map: 0x0100 after registers/IO)
     * Length: 2KB = 0x0800 bytes
     * Attributes: rw = readable, writable
     *             !x = not executable
     */
    data (rw!x) : ORIGIN = 0x00800100, LENGTH = 0x0800
    
    /* 
     * EEPROM (Persistent Storage)
     * Origin: 0x00810000 (separate address space)
     * Length: 1KB = 0x0400 bytes
     * Attributes: rw = readable, writable
     */
    eeprom (rw!x) : ORIGIN = 0x00810000, LENGTH = 0x0400
    
    /* 
     * Fuse bits (special configuration memory)
     * Not normally modified by linker
     */
    fuse (rw!x) : ORIGIN = 0, LENGTH = 3
    
    /* Lock bits */
    lock (rw!x) : ORIGIN = 0, LENGTH = 1
    
    /* Signature bytes (read-only, factory programmed) */
    signature (rw!x) : ORIGIN = 0, LENGTH = 3
}

/* Section definitions - where different types of data go */
SECTIONS
{
    /* ========================================================================
     * FLASH SECTIONS (Code and Read-Only Data)
     * ======================================================================== */
    
    /* 
     * .text - Program code
     * This is where your actual program instructions live
     */
    .text :
    {
        /* Start of .text section */
        __text_start = .;
        
        /* 
         * Interrupt Vector Table
         * Must be at address 0x0000
         * Contains jump instructions to interrupt handlers
         */
        *(.vectors)
        
        /* Keep vectors even if they appear unused */
        KEEP(*(.vectors))
        
        /* 
         * Program initialization code
         * .init0 through .init9 run before main()
         */
        KEEP(*(.init0))  /* Start here after reset */
        KEEP(*(.init1))  /* Clear __zero_reg__ (r1) */
        KEEP(*(.init2))  /* Initialize stack pointer */
        KEEP(*(.init3))  /* (unused by default) */
        KEEP(*(.init4))  /* Copy .data from Flash to SRAM */
        KEEP(*(.init5))  /* (unused by default) */
        KEEP(*(.init6))  /* Initialize C library */
        KEEP(*(.init7))  /* (unused by default) */
        KEEP(*(.init8))  /* Call global constructors (C++) */
        KEEP(*(.init9))  /* Jump to main() */
        
        /* 
         * Regular program code
         * All your functions go here
         */
        *(.text)
        *(.text*)
        
        /* 
         * Finalization code (runs after main returns)
         * .fini9 through .fini0
         */
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
        
        /* End of .text section */
        __text_end = .;
    } > text  /* Place in Flash memory */
    
    /* 
     * .rodata - Read-only data (constants)
     * Strings, const arrays, etc.
     */
    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > text  /* Also in Flash */
    
    /* 
     * .progmem - PROGMEM data
     * Data explicitly marked with PROGMEM keyword
     */
    .progmem.data :
    {
        *(.progmem.data)
    } > text
    
    /* ========================================================================
     * SRAM SECTIONS (Runtime Data)
     * ======================================================================== */
    
    /* 
     * .data - Initialized global/static variables
     * These have initial values that must be copied from Flash to SRAM
     */
    .data :
    {
        /* Start of .data in SRAM */
        __data_start = .;
        
        *(.data)
        *(.data*)
        
        /* End of .data in SRAM */
        __data_end = .;
    } > data AT > text  /* Lives in SRAM, but initial values stored in Flash */
    
    /* 
     * Store the Flash address where .data initialization values are stored
     * Used by startup code to copy .data from Flash to SRAM
     */
    __data_load_start = LOADADDR(.data);
    
    /* 
     * .bss - Uninitialized global/static variables
     * These are zeroed at startup (no Flash storage needed)
     */
    .bss :
    {
        /* Start of .bss */
        __bss_start = .;
        
        *(.bss)
        *(.bss*)
        *(COMMON)  /* Common symbols (old C feature) */
        
        /* End of .bss */
        __bss_end = .;
    } > data  /* Only in SRAM, not stored in Flash */
    
    /* 
     * .noinit - Uninitialized data that persists across resets
     * Not zeroed at startup
     * Useful for preserving data during watchdog resets
     */
    .noinit (NOLOAD) :
    {
        *(.noinit)
        *(.noinit*)
    } > data
    
    /* 
     * End of SRAM usage
     * Stack starts here and grows downward
     */
    __heap_start = .;
    __heap_end = ORIGIN(data) + LENGTH(data);
    
    /* ========================================================================
     * EEPROM SECTIONS
     * ======================================================================== */
    
    .eeprom :
    {
        *(.eeprom)
        *(.eeprom*)
    } > eeprom
    
    /* ========================================================================
     * SPECIAL SECTIONS (Fuses, Locks, Signatures)
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
     * DEBUG SECTIONS (not loaded to chip)
     * ======================================================================== */
    
    /* DWARF debugging information */
    .debug_info     0 : { *(.debug_info) }
    .debug_abbrev   0 : { *(.debug_abbrev) }
    .debug_line     0 : { *(.debug_line) }
    /* ... more debug sections ... */
}
```

---

# Memory Regions

## MEMORY Command Explained

```ld
MEMORY
{
    name (attributes) : ORIGIN = address, LENGTH = size
}
```

### Attributes:

- **r** - Read
- **w** - Write
- **x** - Execute
- **a** - Allocatable
- **!** - NOT (inverts next attribute)

### ATmega328P Memory Regions:

```ld
MEMORY
{
    /* Flash: readable, executable */
    text (rx)    : ORIGIN = 0x00000000, LENGTH = 32K
    
    /* SRAM: readable, writable, NOT executable */
    data (rw!x)  : ORIGIN = 0x00800100, LENGTH = 0x0800
    
    /* EEPROM: readable, writable */
    eeprom (rw!x): ORIGIN = 0x00810000, LENGTH = 0x0400
}
```

### Why These Addresses?

#### Flash (text): ORIGIN = 0x00000000

```
AVR uses word addressing for Flash:
  Linker address: 0x00000000 = byte 0
  AVR address:    0x0000 = word 0
  
Physical mapping:
  Linker 0x0000 = AVR Flash word 0 (bytes 0-1)
  Linker 0x0002 = AVR Flash word 1 (bytes 2-3)
  Linker 0x7FFE = AVR Flash word 16383 (bytes 32766-32767)
```

#### SRAM (data): ORIGIN = 0x00800100

```
AVR data address space:
  0x0000 - 0x001F: CPU registers (R0-R31)
  0x0020 - 0x005F: I/O registers
  0x0060 - 0x00FF: Extended I/O
  0x0100 - 0x08FF: SRAM (actual RAM)
  
Linker uses full address:
  0x00800000 = AVR data space base
  0x00800100 = SRAM start (skips registers/IO)
```

#### EEPROM: ORIGIN = 0x00810000

```
Separate address space:
  0x00810000 = EEPROM base in linker addressing
  Maps to AVR EEPROM addresses 0x000-0x3FF
```

---

# Sections

## Common Section Types

### .text (Flash - Code)

```c
void my_function() {    // Goes in .text
    // Code here
}

int main() {            // Goes in .text
    return 0;
}
```

**Compiled to:**
```asm
.section .text
my_function:
    push r28
    ; ... instructions ...
    ret
```

### .rodata (Flash - Read-Only Data)

```c
const char message[] = "Hello";  // Goes in .rodata
const int values[] = {1,2,3};    // Goes in .rodata
```

### .progmem.data (Flash - Explicit PROGMEM)

```c
const char text[] PROGMEM = "Stored in Flash";  // Goes in .progmem.data
```

**Accessing PROGMEM:**
```c
char c = pgm_read_byte(&text[0]);  // Read from Flash
```

### .data (SRAM - Initialized Variables)

```c
int counter = 0;           // Goes in .data
char buffer[] = "abc";     // Goes in .data
static int value = 42;     // Goes in .data
```

**Startup code copies from Flash to SRAM:**
```asm
; In .init4 section:
ldi r26, lo8(__data_start)        ; Destination in SRAM
ldi r27, hi8(__data_start)
ldi r30, lo8(__data_load_start)   ; Source in Flash
ldi r31, hi8(__data_load_start)
ldi r24, lo8(__data_end - __data_start)  ; Size

copy_loop:
    lpm r0, Z+                     ; Load from Flash
    st X+, r0                      ; Store to SRAM
    dec r24
    brne copy_loop
```

### .bss (SRAM - Uninitialized Variables)

```c
int uninitialized;         // Goes in .bss
static char buffer[100];   // Goes in .bss
```

**Startup code zeros .bss:**
```asm
; In .init4 section:
ldi r26, lo8(__bss_start)
ldi r27, hi8(__bss_start)
ldi r24, lo8(__bss_end - __bss_start)
clr r0

zero_loop:
    st X+, r0
    dec r24
    brne zero_loop
```

### .noinit (SRAM - Persistent Variables)

```c
int persistent_value __attribute__((section(".noinit")));

void setup() {
    // persistent_value retains value across resets!
    // (unless power is lost)
}
```

### .eeprom (EEPROM)

```c
#include <avr/eeprom.h>

// Allocate space in EEPROM
uint8_t EEMEM eeprom_data[100];

void write_eeprom() {
    eeprom_write_byte(&eeprom_data[0], 42);
}
```

---

# Custom Linker Scripts

## Minimal custom.ld (example)

You can use the supplied `custom.ld` as a compact linker script that contains all the essentials:

- Flash and SRAM memory regions
- Vector table placement at the start of flash
- Sections: `.text`, `.data`, `.bss`, and optional `.noinit`
- Useful symbols for runtime: `__data_start`, `__data_end`, `__bss_start`, `__bss_end`, `__heap_start`, `_end`, and `__stack`

Place `custom.ld` in your project root and use it when linking by passing the script to the linker:

```sh
avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL -Os -c src/*.c
avr-gcc -mmcu=atmega328p -o project.elf *.o -Wl,-T,custom.ld
avr-objcopy -O ihex project.elf project.hex
```

Notes:
- `custom.ld` assumes 32KB of flash and 2KB of SRAM. If you use a different MCU variant, modify the macro values accordingly.
- The script defines `__stack` as the top of SRAM; the C runtime will initialize SP from this or from `__stack_start` if defined.
- If you need EEPROM or special memory areas (fuses, lockbits, etc.), add them to the MEMORY block and the sections block appropriately.

This minimal linker script is ideal when you want to customize memory allocation sizes or reserve RAM areas for buffers, but it avoids the complexity of the default `avr5.xn` linker script.


## Example 1: Reserve SRAM Region for Manual Buffer

**Goal:** Reserve 0x0500-0x05FF for custom use, prevent compiler from using it.

```ld
/******************************************************************************
 * Custom Linker Script - Reserved SRAM Buffer
 *****************************************************************************/

ENTRY(__vectors)

MEMORY
{
    text (rx)   : ORIGIN = 0x00000000, LENGTH = 32K
    data (rw!x) : ORIGIN = 0x00800100, LENGTH = 0x0800
    eeprom (rw!x) : ORIGIN = 0x00810000, LENGTH = 0x0400
}

SECTIONS
{
    /* Flash sections (same as default) */
    .text :
    {
        *(.vectors)
        KEEP(*(.vectors))
        *(.text)
        *(.text*)
    } > text
    
    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > text
    
    /* ========================================
     * CUSTOM: Reserved Memory Region
     * ======================================== */
    
    /* 
     * Reserve 0x0500-0x05FF (256 bytes)
     * This creates a gap that compiler won't use
     */
    .reserved_memory 0x00800500 (NOLOAD) :
    {
        __reserved_start = .;
        . = . + 256;  /* Reserve 256 bytes */
        __reserved_end = .;
    } > data
    
    /* ========================================
     * Normal SRAM Sections (AFTER Reserved)
     * ======================================== */
    
    /* 
     * .data starts AFTER reserved region
     * Compiler will use 0x0100-0x04FF and 0x0600+
     */
    .data :
    {
        __data_start = .;
        *(.data)
        *(.data*)
        __data_end = .;
    } > data AT > text
    
    __data_load_start = LOADADDR(.data);
    
    .bss :
    {
        __bss_start = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > data
    
    .noinit (NOLOAD) :
    {
        *(.noinit)
        *(.noinit*)
    } > data
    
    /* Heap/Stack */
    __heap_start = .;
    __heap_end = ORIGIN(data) + LENGTH(data);
    
    /* EEPROM section */
    .eeprom :
    {
        *(.eeprom)
        *(.eeprom*)
    } > eeprom
}
```

**Using it in C:**

```c
// Access reserved memory
extern uint8_t __reserved_start;
extern uint8_t __reserved_end;

uint8_t* reserved_buffer = &__reserved_start;
uint16_t reserved_size = &__reserved_end - &__reserved_start;

void setup() {
    Serial.begin(115200);
    Serial.print("Reserved: 0x");
    Serial.print((uint16_t)&__reserved_start, HEX);
    Serial.print(" - 0x");
    Serial.println((uint16_t)&__reserved_end, HEX);
    
    // Use reserved buffer
    reserved_buffer[0] = 0xAA;
    reserved_buffer[255] = 0xBB;
}
```

**Compile with custom script:**
```bash
avr-gcc -mmcu=atmega328p -T custom_linker.ld -o program.elf main.c
```

---

## Example 2: Bootloader-Compatible Script

**Goal:** Reserve top 512 bytes of Flash for bootloader.

```ld
/******************************************************************************
 * Bootloader-Compatible Linker Script
 *****************************************************************************/

ENTRY(__vectors)

MEMORY
{
    /* 
     * Application Flash: 0x0000 - 0x7DFF (31.5KB)
     * Bootloader Flash: 0x7E00 - 0x7FFF (512 bytes) - RESERVED
     */
    text (rx)   : ORIGIN = 0x00000000, LENGTH = 0x7E00  /* Reduced! */
    
    /* Bootloader section (separate) */
    bootloader (rx) : ORIGIN = 0x00007E00, LENGTH = 0x0200
    
    data (rw!x) : ORIGIN = 0x00800100, LENGTH = 0x0800
    eeprom (rw!x) : ORIGIN = 0x00810000, LENGTH = 0x0400
}

SECTIONS
{
    /* Application code */
    .text :
    {
        *(.vectors)
        KEEP(*(.vectors))
        *(.text)
        *(.text*)
    } > text  /* Only uses 0x0000-0x7DFF */
    
    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > text
    
    /* 
     * Bootloader section
     * Only if compiling bootloader code
     */
    .bootloader :
    {
        *(.bootloader)
    } > bootloader
    
    /* SRAM sections (unchanged) */
    .data :
    {
        __data_start = .;
        *(.data)
        *(.data*)
        __data_end = .;
    } > data AT > text
    
    __data_load_start = LOADADDR(.data);
    
    .bss :
    {
        __bss_start = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > data
    
    .noinit (NOLOAD) :
    {
        *(.noinit)
        *(.noinit*)
    } > data
    
    __heap_start = .;
    __heap_end = ORIGIN(data) + LENGTH(data);
    
    .eeprom :
    {
        *(.eeprom)
        *(.eeprom*)
    } > eeprom
}
```

---

## Example 3: Multiple SRAM Regions

**Goal:** Organize SRAM into named regions (buffers, data, stack).

```ld
/******************************************************************************
 * Organized SRAM Layout
 *****************************************************************************/

ENTRY(__vectors)

MEMORY
{
    text (rx)   : ORIGIN = 0x00000000, LENGTH = 32K
    
    /* Split SRAM into logical regions */
    system_ram (rw!x)  : ORIGIN = 0x00800100, LENGTH = 256   /* 0x0100-0x01FF */
    buffers (rw!x)     : ORIGIN = 0x00800200, LENGTH = 512   /* 0x0200-0x03FF */
    app_data (rw!x)    : ORIGIN = 0x00800400, LENGTH = 768   /* 0x0400-0x06FF */
    stack_ram (rw!x)   : ORIGIN = 0x00800700, LENGTH = 512   /* 0x0700-0x08FF */
    
    eeprom (rw!x) : ORIGIN = 0x00810000, LENGTH = 0x0400
}

SECTIONS
{
    /* Flash sections */
    .text :
    {
        *(.vectors)
        KEEP(*(.vectors))
        *(.text)
        *(.text*)
    } > text
    
    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > text
    
    /* System variables in system_ram */
    .system_data :
    {
        __system_start = .;
        *(.system_data)
        __system_end = .;
    } > system_ram AT > text
    
    /* Buffers in buffers region */
    .buffer_section :
    {
        __buffers_start = .;
        *(.buffer_data)
        __buffers_end = .;
    } > buffers
    
    /* Application data in app_data */
    .data :
    {
        __data_start = .;
        *(.data)
        *(.data*)
        __data_end = .;
    } > app_data AT > text
    
    __data_load_start = LOADADDR(.data);
    
    .bss :
    {
        __bss_start = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > app_data
    
    /* Stack in stack_ram */
    __stack_start = ORIGIN(stack_ram) + LENGTH(stack_ram);
    
    .eeprom :
    {
        *(.eeprom)
        *(.eeprom*)
    } > eeprom
}
```

**Using it in C:**

```c
// Place variables in specific sections
uint8_t system_var __attribute__((section(".system_data")));
uint8_t buffer[256] __attribute__((section(".buffer_data")));
uint8_t normal_var;  // Goes in .data (app_data region)

extern uint8_t __buffers_start;
extern uint8_t __buffers_end;

void setup() {
    Serial.print("Buffers: 0x");
    Serial.print((uint16_t)&__buffers_start, HEX);
    Serial.print(" - 0x");
    Serial.println((uint16_t)&__buffers_end, HEX);
}
```

---

# Advanced Topics

## Linker Symbols

Symbols are variables created by the linker (addresses, not actual memory).

### Accessing Linker Symbols:

```c
// Declare as extern (no storage allocated by compiler)
extern uint8_t __data_start;
extern uint8_t __data_end;
extern uint8_t __bss_start;
extern uint8_t __bss_end;
extern uint8_t __heap_start;

void print_memory_layout() {
    Serial.println("Memory Layout:");
    Serial.print("  .data: 0x");
    Serial.print((uint16_t)&__data_start, HEX);
    Serial.print(" - 0x");
    Serial.println((uint16_t)&__data_end, HEX);
    
    Serial.print("  .bss:  0x");
    Serial.print((uint16_t)&__bss_start, HEX);
    Serial.print(" - 0x");
    Serial.println((uint16_t)&__bss_end, HEX);
    
    Serial.print("  heap:  0x");
    Serial.println((uint16_t)&__heap_start, HEX);
}
```

### Creating Custom Symbols:

```ld
SECTIONS
{
    .data :
    {
        __data_start = .;        /* Symbol = current address */
        *(.data)
        __data_end = .;
        __data_size = __data_end - __data_start;  /* Computed symbol */
    } > data AT > text
}
```

---

## Location Counter (Dot)

The `.` (dot) represents the **current address** in the linker script.

```ld
.data :
{
    __data_start = .;     /* . = 0x00800100 (start of region) */
    *(.data)              /* . advances by size of .data */
    __data_end = .;       /* . = 0x00800100 + size of .data */
    . = . + 256;          /* Manually advance . by 256 bytes */
    __gap_end = .;        /* . = __data_end + 256 */
}
```

### Alignment:

```ld
.data :
{
    *(.data)
    . = ALIGN(4);         /* Round up to next 4-byte boundary */
    *(.more_data)
}
```

---

## AT Keyword (Load Address vs Run Address)

The `AT` keyword specifies where data is **stored** vs where it **runs**.

```ld
.data :
{
    /* This data RUNS in SRAM (0x0100+) */
    *(.data)
} > data                /* VMA (Virtual Memory Address) = SRAM */
  AT > text             /* LMA (Load Memory Address) = Flash */
```

**Why?**

```
Initialized variables must be stored in Flash:
  
Flash 0x1000: [initial values of .data]
              ↓ (copied by startup code)
SRAM 0x0100:  [.data variables during runtime]
```

**Without AT:**
```ld
.data : { *(.data) } > data
/* Error! .data would only exist in SRAM, loses initial values */
```

---

## KEEP Keyword

Prevents linker from removing "unused" sections.

```ld
.text :
{
    KEEP(*(.vectors))     /* Don't optimize away interrupt vectors! */
    KEEP(*(.init0))       /* Don't remove startup code! */
}
```

**Why needed:**

```c
// Interrupt vector table
__attribute__((section(".vectors")))
const void* __vectors[] = {
    (void*)0x0C94,  // RESET
    (void*)0x0C94,  // INT0
    // ...
};

// Without KEEP, linker sees:
//   "__vectors is never accessed" → removes it!
//   Result: No interrupt vectors → chip doesn't boot!
```

---

## PROVIDE Keyword

Defines a symbol **only if not already defined**.

```ld
PROVIDE(__stack = ORIGIN(data) + LENGTH(data));

/* If user defines __stack in their code, use that.
   Otherwise, use this default value. */
```

---

## ASSERT Command

Add compile-time checks:

```ld
ASSERT(__data_end < 0x00800900, "Error: .data overflows SRAM!")
ASSERT(__text_end < 0x7E00, "Error: Code too large for bootloader!")
```

---

## Viewing Linker Output

### Size of sections:

```bash
avr-size -A program.elf
```

Output:
```
program.elf  :
section        size      addr
.text          2048         0
.data            64    8388864
.bss            128    8388928
.noinit           0    8389056
```

### Memory map:

```bash
avr-nm -n program.elf
```

Output:
```
00000000 T __vectors
00000068 T __init
000000a4 T setup
000001c2 T loop
00800100 D counter
00800104 B buffer
```

### Detailed map file:

```bash
avr-gcc -Wl,-Map=output.map -o program.elf main.c
```

**output.map** contains full memory layout, symbol addresses, section sizes.

---

## Complete Custom Linker Script Template

```ld
/******************************************************************************
 * Complete Custom Linker Script for ATmega328P
 * 
 * Features:
 * - Reserved SRAM regions
 * - Bootloader space
 * - Organized memory layout
 * - Safety assertions
 *****************************************************************************/

OUTPUT_FORMAT("elf32-avr")
OUTPUT_ARCH(avr:5)
ENTRY(__vectors)

/* Memory configuration */
MEMORY
{
    /* Flash: Reserve 512 bytes for bootloader */
    text (rx)   : ORIGIN = 0x00000000, LENGTH = 0x7E00  /* 31.5KB */
    bootloader (rx) : ORIGIN = 0x00007E00, LENGTH = 0x0200  /* 512B */
    
    /* SRAM: 2KB total, organized into regions */
    sys_ram (rw!x)    : ORIGIN = 0x00800100, LENGTH = 256   /* System */
    serial_ram (rw!x) : ORIGIN = 0x00800200, LENGTH = 256   /* Serial buffers */
    buffer_ram (rw!x) : ORIGIN = 0x00800300, LENGTH = 512   /* General buffers */
    app_ram (rw!x)    : ORIGIN = 0x00800500, LENGTH = 768   /* Application data */
    stack_ram (rw!x)  : ORIGIN = 0x00800800, LENGTH = 256   /* Stack */
    
    /* EEPROM */
    eeprom (rw!x) : ORIGIN = 0x00810000, LENGTH = 0x0400
    
    /* Special sections */
    fuse (rw!x)   : ORIGIN = 0, LENGTH = 3
    lock (rw!x)   : ORIGIN = 0, LENGTH = 1
    signature (rw!x) : ORIGIN = 0, LENGTH = 3
}

/* Section definitions */
SECTIONS
{
    /* ========================================================================
     * FLASH SECTIONS
     * ======================================================================== */
    
    .text :
    {
        __text_start = .;
        
        /* Interrupt vectors */
        *(.vectors)
        KEEP(*(.vectors))
        
        /* Initialization sections */
        KEEP(*(.init0))
        KEEP(*(.init1))
        KEEP(*(.init2))
        KEEP(*(.init3))
        KEEP(*(.init4))
        KEEP(*(.init5))
        KEEP(*(.init6))
        KEEP(*(.init7))
        KEEP(*(.init8))
        KEEP(*(.init9))
        
        /* Program code */
        *(.text)
        *(.text*)
        
        /* Cleanup sections */
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
        
        __text_end = .;
    } > text
    
    .rodata :
    {
        *(.rodata)
        *(.rodata*)
    } > text
    
    .progmem.data :
    {
        *(.progmem.data)
    } > text
    
    /* Bootloader section (optional) */
    .bootloader :
    {
        *(.bootloader)
    } > bootloader
    
    /* ========================================================================
     * SRAM SECTIONS
     * ======================================================================== */
    
    /* System data */
    .system_data :
    {
        __system_start = .;
        *(.system_data)
        __system_end = .;
    } > sys_ram AT > text
    
    /* Serial buffers */
    .serial_buffers (NOLOAD) :
    {
        __serial_start = .;
        *(.serial_data)
        __serial_end = .;
    } > serial_ram
    
    /* General buffers */
    .buffers (NOLOAD) :
    {
        __buffer_start = .;
        *(.buffer_data)
        __buffer_end = .;
    } > buffer_ram
    
    /* Application initialized data */
    .data :
    {
        __data_start = .;
        *(.data)
        *(.data*)
        __data_end = .;
    } > app_ram AT > text
    
    __data_load_start = LOADADDR(.data);
    __data_size = SIZEOF(.data);
    
    /* Application uninitialized data */
    .bss :
    {
        __bss_start = .;
        *(.bss)
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > app_ram
    
    __bss_size = SIZEOF(.bss);
    
    /* Persistent data */
    .noinit (NOLOAD) :
    {
        __noinit_start = .;
        *(.noinit)
        *(.noinit*)
        __noinit_end = .;
    } > app_ram
    
    /* Heap */
    __heap_start = .;
    __heap_end = ORIGIN(app_ram) + LENGTH(app_ram);
    
    /* Stack */
    __stack_start = ORIGIN(stack_ram);
    __stack_end = ORIGIN(stack_ram) + LENGTH(stack_ram);
    PROVIDE(__stack = __stack_end);
    
    /* ========================================================================
     * EEPROM SECTION
     * ======================================================================== */
    
    .eeprom :
    {
        *(.eeprom)
        *(.eeprom*)
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
     * SAFETY ASSERTIONS
     * ======================================================================== */
    
    /* Check Flash doesn't overflow */
    ASSERT(__text_end <= 0x7E00, "ERROR: Code overflows into bootloader space!")
    
    /* Check SRAM doesn't overflow */
    ASSERT(__heap_start <= __heap_end, "ERROR: Heap overflow!")
    ASSERT(__stack_end <= 0x00800900, "ERROR: Stack overflow!")
    
    /* Check .data can fit */
    ASSERT(__data_size < LENGTH(app_ram), "ERROR: .data too large!")
}
```

**Compile:**
```bash
avr-gcc -mmcu=atmega328p -T custom_complete.ld -Wl,-Map=output.map -o program.elf main.c
```

---

## Summary

**Linker Script Essentials:**

1. **MEMORY**: Define available regions (Flash, SRAM, EEPROM)
2. **SECTIONS**: Define what goes where
3. **Symbols**: Create addresses accessible from C
4. **AT**: Separate load address (Flash) from run address (SRAM)
5. **KEEP**: Prevent optimization of critical sections
6. **Dot (.)**: Current location counter
7. **ASSERT**: Compile-time safety checks

**ATmega328P Memory:**
- Flash: 0x0000 - 0x7FFF (32KB)
- SRAM: 0x0100 - 0x08FF (2KB)
- EEPROM: 0x000 - 0x3FF (1KB)

**Common Customizations:**
- Reserve SRAM regions
- Bootloader space protection
- Organized memory layout
- Custom section placement

Want me to create a specific linker script for your exact use case?