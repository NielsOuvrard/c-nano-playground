# Deep Dive: Compilation Process & File Types

## The Complete Compilation Pipeline

```
Source Code → Preprocessing → Compilation → Assembly → Linking → Conversion → Upload
   (.c/.S)       (.i/.s)        (.s)         (.o)      (.elf)      (.hex)    (Flash)
```

Let me break down each step in detail:

---

## Step 1: Preprocessing
**Input:** `.c` (C source) or `.S` (assembly with preprocessor directives)  
**Output:** `.i` (preprocessed C) or `.s` (pure assembly)

What happens:
- Includes header files (`#include <avr/io.h>`)
- Expands macros (`#define LED_PIN 5` → replaces with `5`)
- Processes conditional compilation (`#ifdef`, `#ifndef`)
- Removes comments
- For `.S` files: resolves directives like `#include`, `.macro`

```bash
# See preprocessed output
avr-gcc -E -mmcu=atmega328p src/main.c -o build/main.i
```

**Example:**
```c
// Before preprocessing (main.c)
#include <avr/io.h>
#define LED_PIN 5

int main(void) {
    DDRB |= (1 << LED_PIN);
}
```

```c
// After preprocessing (main.i) - simplified
// ... thousands of lines from avr/io.h defining registers ...
int main(void) {
    (*(volatile uint8_t *)((0x04) + 0x20)) |= (1 << 5);
}
```

---

## Step 2: Compilation (C to Assembly)
**Input:** `.i` (preprocessed C)  
**Output:** `.s` (assembly code)

What happens:
- Parses C syntax and semantics
- Optimizes code (loop unrolling, dead code elimination, etc.)
- Generates AVR assembly instructions
- Allocates registers

```bash
# Generate assembly from C
avr-gcc -S -mmcu=atmega328p -O2 src/main.c -o build/main.s
```

**Example:**
```c
// C code
int x = 5;
x = x + 10;
```

```asm
; Generated assembly
ldi r24, 5      ; Load immediate 5 into r24
subi r24, -10   ; Subtract -10 (i.e., add 10)
```

---

## Step 3: Assembly (Assembly to Machine Code)
**Input:** `.s` or `.S` (assembly)  
**Output:** `.o` (object file - relocatable binary)

What happens:
- Converts assembly mnemonics to binary opcodes
- Creates symbol table (functions, variables)
- Generates relocation information (addresses not yet final)
- Produces binary machine code but addresses aren't resolved yet

```bash
# Assemble
avr-gcc -c -mmcu=atmega328p src/main.c -o build/main.o
# or directly from assembly
avr-as -mmcu=atmega328p src/blink.s -o build/blink.o
```

**Inside a .o file:**
- **Text section** (`.text`): executable code
- **Data section** (`.data`): initialized variables
- **BSS section** (`.bss`): uninitialized variables
- **Symbol table**: list of functions/variables
- **Relocation table**: "this address needs to be filled in later"

```bash
# Inspect object file
avr-objdump -d build/main.o
```

---

## Step 4: Linking
**Input:** Multiple `.o` files + libraries (`.a`)  
**Output:** `.elf` (Executable and Linkable Format)

What happens:
- Combines multiple object files into one
- Resolves symbol references (links function calls to actual addresses)
- Assigns final memory addresses
- Links with startup code (`crt0.o` - C runtime)
- Links with standard library (`libc.a`, `libm.a`)
- Organizes memory layout (where code/data goes in flash/RAM)

```bash
# Link
avr-gcc -mmcu=atmega328p build/main.o build/helper.o -o build/program.elf
```

**Memory layout example:**
```
Flash (Program Memory - 32KB):
├── 0x0000: Interrupt Vector Table
├── 0x0034: Startup code (crt0)
├── 0x0100: Your main() function
├── 0x0200: Other functions
└── 0x7FFF: End of flash

RAM (2KB):
├── 0x0100: .data (initialized variables)
├── 0x0200: .bss (zero-initialized variables)
├── 0x0300: Heap (dynamic memory)
└── 0x08FF: Stack (grows downward)
```

---

## Step 5: ELF to HEX Conversion
**Input:** `.elf` (full executable with metadata)  
**Output:** `.hex` (Intel HEX format - pure data)

What happens:
- Strips debugging symbols
- Removes section headers and metadata
- Extracts only flash memory contents
- Converts to ASCII text format for serial transmission

```bash
avr-objcopy -O ihex -R .eeprom build/program.elf build/program.hex
```

**ELF vs HEX:**

| Feature | ELF | HEX |
|---------|-----|-----|
| Format | Binary | ASCII text |
| Size | Larger (~2-3x) | Smaller |
| Debugging | Yes (symbols) | No |
| Readable | No | Somewhat |
| Flashable | No | Yes |
| Tools | gdb, objdump | avrdude |

---

## File Type Details

### 1. `.c` - C Source Code
```c
#include <avr/io.h>

int main(void) {
    DDRB = 0xFF;
    while(1) {
        PORTB ^= 0xFF;
    }
    return 0;
}
```

### 2. `.S` - Assembly with Preprocessor (Capital S)
```asm
#include <avr/io.h>

#define LED_PIN 5

.global main
main:
    sbi _SFR_IO_ADDR(DDRB), LED_PIN
    ret
```
- **Can use** `#include`, `#define`, `#ifdef`
- Processed by C preprocessor first

### 3. `.s` - Pure Assembly (Lowercase s)
```asm
.global main
main:
    ldi r24, 0xFF
    out 0x04, r24  ; Direct port address
    ret
```
- **Cannot use** preprocessor directives
- Raw assembly only

### 4. `.i` - Preprocessed C
```c
// All includes expanded, macros replaced
int main(void) {
    (*(volatile uint8_t *)(0x24)) = 0xFF;
    return 0;
}
```

### 5. `.o` - Object File (Relocatable Binary)
```
Binary format containing:
- Machine code (incomplete addresses)
- Symbol table
- Relocation entries
- Section information
```

```bash
# View symbols
avr-nm build/main.o

# View disassembly
avr-objdump -d build/main.o
```

### 6. `.elf` - Executable and Linkable Format
```
Complete executable with:
- Final machine code
- All addresses resolved
- Debugging symbols (DWARF format)
- Section headers (.text, .data, .bss)
- Program headers (memory layout)
```

```bash
# View sections
avr-size -A build/program.elf

# View all symbols
avr-nm build/program.elf

# Disassemble with source
avr-objdump -S build/program.elf

# View headers
avr-readelf -h build/program.elf
```

**ELF sections:**
```
Section Headers:
  [Nr] Name              Type            Addr     Size
  [ 0]                   NULL            00000000 000000
  [ 1] .text             PROGBITS        00000000 000156
  [ 2] .data             PROGBITS        00800100 000010
  [ 3] .bss              NOBITS          00800110 000008
  [ 4] .debug_info       PROGBITS        00000000 001234
  [ 5] .debug_line       PROGBITS        00000000 000456
```

### 7. `.hex` - Intel HEX Format
```
:10000000C0000000C0000000C0000000C00000003C
:10001000C0000000C0000000C0000000C00000002C
:10002000C0000000C0000000C0000000C00000001C
:00000001FF
```

**Format breakdown:**
```
:10 0000 00 C0000000C0000000C0000000C0000000 3C
 │   │   │  │                                 │
 │   │   │  │                                 └─ Checksum
 │   │   │  └─ Data (16 bytes)
 │   │   └─ Record type (00=data, 01=EOF)
 │   └─ Address (where to write in flash)
 └─ Byte count (0x10 = 16 bytes)
```

---


## Complete Example with All Steps

**src/main.c:**
```c
#include <avr/io.h>
#define F_CPU 16000000UL
#include <util/delay.h>

void blink(uint8_t times);

int main(void) {
    DDRB |= (1 << DDB5);  // Set PB5 as output
    
    while(1) {
        blink(3);
        _delay_ms(1000);
    }
    
    return 0;
}

void blink(uint8_t times) {
    for(uint8_t i = 0; i < times; i++) {
        PORTB |= (1 << PORTB5);   // LED on
        _delay_ms(100);
        PORTB &= ~(1 << PORTB5);  // LED off
        _delay_ms(100);
    }
}
```

**Compilation steps:**

```bash
# 1. Preprocessing
avr-gcc -E -mmcu=atmega328p -DF_CPU=16000000UL src/main.c -o build/main.i
# Output: main.i (thousands of lines with expanded headers)

# 2. Compilation (C to assembly)
avr-gcc -S -mmcu=atmega328p -DF_CPU=16000000UL -O2 src/main.c -o build/main.s
# Output: main.s (AVR assembly)

# 3. Assembly (assembly to object)
avr-gcc -c -mmcu=atmega328p -DF_CPU=16000000UL -O2 src/main.c -o build/main.o
# Output: main.o (binary object file)

# 4. Linking
avr-gcc -mmcu=atmega328p build/main.o -o build/main.elf
# Output: main.elf (complete executable)

# 5. Convert to HEX
avr-objcopy -O ihex -R .eeprom build/main.elf build/main.hex
# Output: main.hex (Intel HEX format)

# 6. Upload
avrdude -c avrisp2 -p atmega328p -P /dev/cu.usbserial-110 -b 19200 \
        -U flash:w:build/main.hex:i
```

**Inspect intermediate files:**

```bash
# View assembly generated from C
avr-gcc -S -fverbose-asm -O2 -mmcu=atmega328p src/main.c -o build/main.s
cat build/main.s

# View object file symbols
avr-nm build/main.o

# View object file disassembly
avr-objdump -d build/main.o

# View ELF file information
avr-size -A build/main.elf
avr-readelf -a build/main.elf

# View ELF disassembly with C source
avr-objdump -S build/main.elf

# View HEX file
cat build/main.hex
```

---

## Summary Table

| File | Created By | Contains | Size | Use |
|------|-----------|----------|------|-----|
| `.c` | You | C source code | Small | Human writing |
| `.S` | You | Assembly + preprocessor | Small | Human writing |
| `.s` | Compiler | Pure assembly | Small | Inspect output |
| `.i` | Preprocessor | Expanded C | Large | Debug macros |
| `.o` | Assembler | Machine code + relocations | Medium | Intermediate |
| `.elf` | Linker | Complete executable + debug | Large | Debugging |
| `.hex` | objcopy | Flash data only | Small | Programming chip |

The AVR assembly you're using is **Atmel AVR assembly language** - a RISC-based 8-bit instruction set specific to AVR microcontrollers like your ATmega328p.