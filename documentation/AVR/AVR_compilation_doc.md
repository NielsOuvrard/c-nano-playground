# AVR Compilation Pipeline Visual Guide

## Complete Compilation Flow

```mermaid
graph TD
    A[Source Code  <br/>  .c .S] --> B[Preprocessing]
    B --> C[.i .s]
    C --> D[Compilation]
    D --> E[.s Assembly]
    E --> F[Assembly]
    F --> G[.o Object]
    G --> H[Linking]
    H --> I[.elf Executable]
    I --> J[Conversion]
    J --> K[.hex Intel HEX]
    K --> L[Upload]
    L --> M[MCU Flash]
    
    style A fill:#333,color:#fff
    style C fill:#333,color:#fff
    style E fill:#333,color:#fff
    style G fill:#333,color:#fff
    style I fill:#333,color:#fff
    style K fill:#333,color:#fff
    style M fill:#333,color:#fff
```

### Input: `main.c`
```c
#include <avr/io.h>
#define LED_PIN 5

int main(void) {
    DDRB |= (1 << LED_PIN);
}
```

### Command
```bash
# -E means preprocess only
avr-gcc -E -mmcu=atmega328p src/main.c -o build/main.i
```

### Output: `main.i`
```c
// ... thousands of lines ...
int main(void) {
    (*(volatile uint8_t *)(0x24)) |= (1 << 5);
}
```

---

## Step 2: Compilation (C → Assembly)

### Input: `main.c`
```c
int x = 5;
x = x + 10;
return x;
```

### Command
```bash
# -S means compile to assembly only
avr-gcc -S -mmcu=atmega328p -O2 src/main.c -o build/main.s
```

### Output: `main.s`
```asm
main:
    ldi r24, 5        ; x = 5
    subi r24, -10     ; x += 10
    ret
```

---

## Step 3: Assembly (ASM → Object)

### Input: `blink.s`
```asm
.global main
main:
    sbi 0x04, 5    ; Set bit 5 in DDRB
    ret
```

### Command
```bash
# -c means compile to object file only
avr-gcc -c -mmcu=atmega328p src/blink.s -o build/blink.o
```

### Output: `blink.o` (binary)
```
ELF Header + Sections:
  .text: 9a 5d 08 95 (machine code)
  .symtab: main @ 0x0000
  .rela.text: (relocations)
```

---

## Step 4: Linking

```mermaid
flowchart TD
    A["main.o"] --> L{Linker}
    B["helper.o"] --> L
    C["crt0.o <br/> Startup"] --> L
    D["libc.a <br/> Standard Lib"] --> L
    
    L --> E["Resolve Symbols"]
    L --> F["Assign Addresses"]
    L --> G["Memory Layout"]
    
    E --> H[".elf <br/> Executable"]
    F --> H
    G --> H
    
    style A fill:#333,color:#fff
    style B fill:#333,color:#fff
    style C fill:#333,color:#fff
    style D fill:#333,color:#fff
    style L fill:#333,color:#fff
    style E fill:#333,color:#fff
    style F fill:#333,color:#fff
    style G fill:#333,color:#fff
    style H fill:#333,color:#fff
```

### Command
```bash
avr-gcc -mmcu=atmega328p build/main.o build/helper.o -o build/program.elf
```

---

## Memory Layout in ELF

```mermaid
graph LR
    subgraph Flash["Flash Memory (32KB)"]
        A["0x0000: Vectors <br/> Interrupt table"]
        B["0x0034: Startup <br/> crt0.o"]
        C["0x0100: .text <br/> Your code"]
        D["0x7FFF: End"]
    end
    
    subgraph RAM["SRAM (2KB)"]
        E["0x0100: .data <br/> Initialized vars"]
        F["0x0200: .bss <br/> Zero vars"]
        G["0x0300: Heap <br/> malloc()"]
        H["0x08FF: Stack <br/> ↓ grows down"]
    end
    
    A --> B --> C --> D
    E --> F --> G --> H
    
    style Flash fill:#333,color:#fff
    style RAM fill:#333,color:#fff
    style C fill:#333,color:#fff
    style E fill:#333,color:#fff
    style F fill:#333,color:#fff
```

---

## ELF File Structure

```mermaid
graph LR
    A["program.elf"] --> B["ELF Header <br/> Magic: 0x7F454C46"]
    A --> C["Program Headers <br/> Load segments"]
    A --> D[".text Section <br/> Code"]
    A --> E[".data Section <br/> Initialized data"]
    A --> F[".bss Section <br/> Uninitialized"]
    A --> G[".debug_info <br/> DWARF symbols"]
    A --> H["Symbol Table <br/> Function names"]
    
    style A fill:#333,color:#fff
    style B fill:#333,color:#fff
    style C fill:#333,color:#fff
    style D fill:#333,color:#fff
    style E fill:#333,color:#fff
    style F fill:#333,color:#fff
    style G fill:#333,color:#fff
    style H fill:#333,color:#fff
```

### Inspect ELF
```bash
# Size of sections
avr-size -A build/program.elf
# Output:
# section      size    addr
# .text        1234    0x00
# .data          16    0x800100
# .bss            8    0x800110

# Disassembly
avr-objdump -d build/program.elf

# Symbols
avr-nm build/program.elf
```

---

## Step 5: ELF → HEX Conversion

```mermaid
flowchart LR
    A["program.elf <br/> Binary + Debug"] --> B{objcopy}
    B --> |Strip| C["Remove .debug_*"]
    B --> |Extract| D["Get .text .data"]
    B --> |Format| E["Convert to ASCII"]
    
    C --> F["program.hex <br/> Intel HEX"]
    D --> F
    E --> F
    
    style A fill:#333,color:#fff
    style B fill:#333,color:#fff
    style C fill:#333,color:#fff
    style D fill:#333,color:#fff
    style E fill:#333,color:#fff
    style F fill:#333,color:#fff
```

### Command
```bash
# -O ihex means output in Intel HEX format
avr-objcopy -O ihex -R .eeprom build/program.elf build/program.hex
```

### HEX File Format

```mermaid
graph LR
    A[":"] --> B["10 <br/> Byte count"]
    B --> C["0000 <br/> Address"]
    C --> D["00 <br/> Record type"]
    D --> E["Data bytes..."]
    E --> F["3C <br/> Checksum"]
    
    style A fill:#333,color:#fff
    style B fill:#333,color:#fff
    style C fill:#333,color:#fff
    style D fill:#333,color:#fff
    style E fill:#333,color:#fff
    style F fill:#333,color:#fff
```

### Example: `program.hex`
```
:10000000C0000000C0000000C0000000C00000003C
:10001000C0000000C0000000C0000000C00000002C
:020020009A5D60
:00000001FF
```

**Legend:**
- `:10` = 16 bytes of data
- `0000` = address 0x0000
- `00` = data record
- `C000...` = data (16 bytes)
- `3C` = checksum

---

## Step 6: Upload to MCU

```mermaid
sequenceDiagram
    participant PC as Computer
    participant AVR as AVRDUDE
    participant ISP as AVRISP mkII
    participant MCU as ATmega328p
    
    PC->>AVR: program.hex
    AVR->>ISP: /dev/cu.usbserial-110
    ISP->>MCU: SPI Protocol
    MCU-->>ISP: Chip signature
    ISP-->>AVR: 0x1E950F (328p)
    AVR->>ISP: Flash page data
    ISP->>MCU: Write flash
    MCU-->>ISP: Verify
    ISP-->>AVR: Success
    AVR-->>PC: Bytes written: 1234
```

### Command
```bash
avrdude -c avrisp2 \
        -p atmega328p \
        -P /dev/cu.usbserial-110 \
        -b 19200 \
        -U flash:w:build/program.hex:i
```

---

## File Types Comparison

```mermaid
graph TD
    subgraph Source["Source Files"]
        A1[".c <br/> C source <br/> Human readable"]
        A2[".S <br/> ASM + preprocessor <br/> Human readable"]
    end
    
    subgraph Intermediate["Intermediate Files"]
        B1[".i <br/> Preprocessed C <br/> Text"]
        B2[".s <br/> Pure assembly <br/> Text"]
        B3[".o <br/> Object code <br/> Binary"]
    end
    
    subgraph Final["Final Products"]
        C1[".elf <br/> Full executable <br/> Binary + Debug"]
        C2[".hex <br/> Flash data only <br/> ASCII"]
    end
    
    A1 --> B1 --> B2 --> B3 --> C1 --> C2
    A2 --> B2
    
    style Source fill:#333,color:#fff
    style Intermediate fill:#333,color:#fff
    style Final fill:#333,color:#fff
```

---

## Complete Build Flow

```mermaid
graph TB
    A[Write Code] --> B{Language?}
    B -->|C| C[main.c]
    B -->|ASM| D[blink.S]
    
    C --> E[Preprocess <br/> -E]
    D --> E
    
    E --> F[Compile <br/> -S]
    F --> G[Assemble <br/> -c]
    G --> H[Link <br/> -o .elf]
    H --> I[Convert <br/> objcopy]
    I --> J[Upload <br/> avrdude]
    J --> K[MCU Running]
    
    style C fill:#333,color:#fff
    style D fill:#333,color:#fff
    style E fill:#333,color:#fff
    style F fill:#333,color:#fff
    style G fill:#333,color:#fff
    style H fill:#333,color:#fff
    style I fill:#333,color:#fff
    style J fill:#333,color:#fff
    style K fill:#333,color:#fff
```
