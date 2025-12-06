# Manual Memory Control on ATmega328P

When you need **absolute control** over where your data lives in memory on the ATmega328P, whether in **SRAM**, **EEPROM**, or even **Flash**, you can achieve this through a combination of C code, inline assembly, and custom linker scripts.

---

## SRAM Manual Address Control

### Understanding ATmega328P SRAM Layout

The **SRAM is 2KB (0x0800 bytes)** and lives at addresses:

- **Start**: `0x0100` (256 decimal)
- **End**: `0x08FF` (2303 decimal)

**Important**: Addresses `0x0000` to `0x00FF` are **registers + I/O space**, not SRAM!

### Default Memory Layout (without your intervention)

```
0x08FF ┌─────────────────┐ ← Stack pointer starts here (SP)
       │                 │
       │     STACK       │ (grows downward ↓)
       │                 │
       ├─────────────────┤ ← Stack/Heap collision danger zone
       │                 │
       │     HEAP        │ (grows upward ↑)
       │                 │
       ├─────────────────┤
       │  .bss (zeroed)  │ (uninitialized global/static vars)
       ├─────────────────┤
       │  .data (init)   │ (initialized global/static vars)
0x0100 └─────────────────┘
```

---

## Method 1: Absolute Address Placement (C)

### Using Linker Sections

```c
// Place a buffer at specific SRAM address
__attribute__((section(".mysection,\"aw\",@nobits#")))
uint8_t myBuffer[256] __attribute__((address(0x0500)));

// Or simpler with avr-gcc:
uint8_t *const FIXED_BUFFER = (uint8_t *)0x0500;

void setup() {
    // Write directly to address 0x0500
    FIXED_BUFFER[0] = 0xAA;
    FIXED_BUFFER[1] = 0xBB;
}
```

### Direct Pointer Method (simplest)

```c
// Reserve memory region 0x0500 to 0x05FF for custom use
#define CUSTOM_MEM_START 0x0500
#define CUSTOM_MEM_SIZE  256

uint8_t* customMemory = (uint8_t*)CUSTOM_MEM_START;

void writeCustomMem(uint16_t offset, uint8_t value) {
    if (offset < CUSTOM_MEM_SIZE) {
        customMemory[offset] = value;
    }
}

uint8_t readCustomMem(uint16_t offset) {
    return (offset < CUSTOM_MEM_SIZE) ? customMemory[offset] : 0;
}
```

---

## Method 2: Custom Linker Script (Ultimate Control)

This is **hardcore** - you modify how the compiler places everything.

### Step 1: Extract default linker script

```bash
# avr-gcc -mmcu=atmega328p -Wl,--verbose
cp /opt/homebrew/Cellar/avr-binutils/2.45.1/avr/lib/ldscripts/avr5.xn atmega328p.ld
```

### Step 2: Modify SRAM sections

```ld
MEMORY
{
  /* ... */
  data (rw!x) : ORIGIN = 0x800100, LENGTH = 0x800  /* 2KB SRAM */
}

SECTIONS
{
  /* Your custom reserved area */
  .reserved_mem 0x800100 :
  {
    __reserved_start = .;
    . = . + 256;  /* Reserve 256 bytes */
    __reserved_end = .;
  } > data

  /* Normal .data section starts after */
  .data __reserved_end :
  {
    *(.data)
    *(.data*)
  } > data

  /* ... rest of sections ... */
}
```

### Step 3: Access in C

```c
extern uint8_t __reserved_start;
extern uint8_t __reserved_end;

uint8_t* myReservedArea = &__reserved_start;
```

### Step 4: Compile with custom script

```bash
avr-gcc -mmcu=atmega328p -T atmega328p.ld -o program.elf program.c
```

---

## Method 3: Pure Assembly Control

```asm
; Define memory regions
.equ RESERVED_START, 0x0500
.equ RESERVED_SIZE,  256

; Write to specific address
ldi r24, 0xAA           ; Load value
sts RESERVED_START, r24 ; Store to address 0x0500

; Read from specific address
lds r24, RESERVED_START ; Load from 0x0500

; Block copy
ldi r26, lo8(RESERVED_START)  ; X register low
ldi r27, hi8(RESERVED_START)  ; X register high
ldi r24, 0xFF
st X+, r24                     ; Store and increment
```

### Mixed C and ASM

```c
void writeDirectASM(uint16_t addr, uint8_t value) {
    asm volatile (
        "sts %0, %1"
        :
        : "n" (addr), "r" (value)
    );
}

uint8_t readDirectASM(uint16_t addr) {
    uint8_t result;
    asm volatile (
        "lds %0, %1"
        : "=r" (result)
        : "n" (addr)
    );
    return result;
}
```

---

## Preventing Compiler from Using Your Reserved Memory

### Method A: Tell the linker where heap/stack start

```c
// Prevent heap from growing into your region
extern char __heap_start;
extern char __heap_end;

void setupCustomMemory() {
    // Force heap to end before your reserved area
    __malloc_heap_end = (char*)0x04FF;  // If you reserved 0x0500+
}
```

### Method B: Waste memory intentionally (crude but works)

```c
// Reserve 0x0500-0x05FF by declaring a dummy global
static uint8_t __attribute__((section(".noinit"))) reserved_area[256];

// Now use it directly
#define MY_MEMORY reserved_area
```

---

## EEPROM Manual Control

```c
#include <avr/eeprom.h>

// Define EEPROM addresses
#define EEPROM_CONFIG_ADDR  0x00
#define EEPROM_DATA_ADDR    0x10

// Write byte
void eeprom_write_manual(uint16_t addr, uint8_t data) {
    while (EECR & (1 << EEPE)); // Wait for previous write
    EEAR = addr;                 // Set address
    EEDR = data;                 // Set data
    EECR |= (1 << EEMPE);        // Master write enable
    EECR |= (1 << EEPE);         // Start write
}

// Read byte
uint8_t eeprom_read_manual(uint16_t addr) {
    while (EECR & (1 << EEPE)); // Wait for write
    EEAR = addr;                 // Set address
    EECR |= (1 << EERE);         // Start read
    return EEDR;                 // Return data
}
```

---

## Flash Memory Manual Control (Advanced)

Writing to Flash from the running program (self-programming):

```c
#include <avr/boot.h>

#define FLASH_PAGE_SIZE SPM_PAGESIZE  // 128 bytes for ATmega328P

void flash_write_page(uint16_t page_addr, uint8_t* data) {
    boot_page_erase(page_addr);
    boot_spm_busy_wait();

    for (uint16_t i = 0; i < FLASH_PAGE_SIZE; i += 2) {
        uint16_t word = data[i] | (data[i+1] << 8);
        boot_page_fill(page_addr + i, word);
    }

    boot_page_write(page_addr);
    boot_spm_busy_wait();
    boot_rww_enable();
}
```

---

## Complete Example: Full Manual Control

```c
#include <avr/io.h>

// Memory map definition
#define SRAM_START      0x0100
#define SRAM_END        0x08FF
#define MY_BUFFER_ADDR  0x0500
#define MY_BUFFER_SIZE  256

// Direct memory access
uint8_t* myBuffer = (uint8_t*)MY_BUFFER_ADDR;

void initMemory() {
    // Zero out your buffer
    for (uint16_t i = 0; i < MY_BUFFER_SIZE; i++) {
        myBuffer[i] = 0;
    }
}

void writeBuffer(uint8_t index, uint8_t value) {
    myBuffer[index] = value;
}

uint8_t readBuffer(uint8_t index) {
    return myBuffer[index];
}

int main() {
    initMemory();

    writeBuffer(0, 0xDE);
    writeBuffer(1, 0xAD);
    writeBuffer(2, 0xBE);
    writeBuffer(3, 0xEF);

    while(1) {
        // Your code
    }
}
```

---

## Summary: You Have Full Control

1. **SRAM (0x0100-0x08FF)**: Point anywhere, write/read directly
2. **EEPROM (0x000-0x3FF)**: Use EEAR/EEDR registers
3. **Flash (0x0000-0x7FFF)**: Use boot loader functions

**Warning**: If you manually manage memory, disable malloc/new or you'll have collisions!

Want me to help with a specific memory layout for your project?
