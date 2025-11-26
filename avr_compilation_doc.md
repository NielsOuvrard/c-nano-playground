# AVR Compilation Pipeline Visual Guide

## Complete Compilation Flow

```mermaid
graph LR
    A[Source Code<br/>.c .S] --> B[Preprocessing]
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
    
    style A fill:#4a90e2,color:#fff
    style C fill:#f5a623
    style E fill:#f5a623
    style G fill:#d0021b,color:#fff
    style I fill:#7ed321
    style K fill:#50e3c2
    style M fill:#9013fe,color:#fff
```

---

## Step 1: Preprocessing

```mermaid
flowchart TD
    A["main.c<br/>#include &lt;avr/io.h&gt;<br/>#define LED 5"] --> B{Preprocessor}
    C["avr/io.h<br/>Register definitions"] --> B
    B --> D["main.i<br/>Expanded macros<br/>Included headers<br/>No comments"]
    
    style A fill:#e1f5ff
    style C fill:#e1f5ff
    style B fill:#ffc107
    style D fill:#fff3cd
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

```mermaid
flowchart TD
    A["main.i<br/>Preprocessed C"] --> B{Compiler}
    B --> |Parse| C[AST]
    C --> |Optimize| D[IR]
    D --> |Generate| E["main.s<br/>AVR Assembly"]
    
    style A fill:#fff3cd
    style B fill:#ff9800
    style C fill:#ffe0b2
    style D fill:#ffe0b2
    style E fill:#ffecb3
```

### Input: `main.c`
```c
int x = 5;
x = x + 10;
return x;
```

### Command
```bash
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

```mermaid
flowchart TD
    A["blink.s<br/>Assembly Code"] --> B{Assembler}
    B --> C["Opcodes<br/>Binary"]
    B --> D["Symbol Table<br/>Functions/Variables"]
    B --> E["Relocation Info<br/>Unresolved addresses"]
    C --> F[".o Object File"]
    D --> F
    E --> F
    
    style A fill:#ffecb3
    style B fill:#f44336,color:#fff
    style C fill:#ffcdd2
    style D fill:#ffcdd2
    style E fill:#ffcdd2
    style F fill:#ef9a9a
```

### Input: `blink.s`
```asm
.global main
main:
    sbi 0x04, 5    ; Set bit 5 in DDRB
    ret
```

### Command
```bash
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
    C["crt0.o<br/>Startup"] --> L
    D["libc.a<br/>Standard Lib"] --> L
    
    L --> E["Resolve Symbols"]
    L --> F["Assign Addresses"]
    L --> G["Memory Layout"]
    
    E --> H[".elf<br/>Executable"]
    F --> H
    G --> H
    
    style A fill:#ef9a9a
    style B fill:#ef9a9a
    style C fill:#ef9a9a
    style D fill:#ef9a9a
    style L fill:#4caf50,color:#fff
    style E fill:#c8e6c9
    style F fill:#c8e6c9
    style G fill:#c8e6c9
    style H fill:#81c784
```

### Command
```bash
avr-gcc -mmcu=atmega328p build/main.o build/helper.o -o build/program.elf
```

---

## Memory Layout in ELF

```mermaid
graph TB
    subgraph Flash["Flash Memory (32KB)"]
        A["0x0000: Vectors<br/>Interrupt table"]
        B["0x0034: Startup<br/>crt0.o"]
        C["0x0100: .text<br/>Your code"]
        D["0x7FFF: End"]
    end
    
    subgraph RAM["SRAM (2KB)"]
        E["0x0100: .data<br/>Initialized vars"]
        F["0x0200: .bss<br/>Zero vars"]
        G["0x0300: Heap<br/>malloc()"]
        H["0x08FF: Stack<br/>↓ grows down"]
    end
    
    A --> B --> C --> D
    E --> F --> G --> H
    
    style Flash fill:#e3f2fd
    style RAM fill:#fff3e0
    style C fill:#4caf50,color:#fff
    style E fill:#ff9800,color:#fff
    style F fill:#ff9800,color:#fff
```

---

## ELF File Structure

```mermaid
graph TD
    A["program.elf"] --> B["ELF Header<br/>Magic: 0x7F454C46"]
    A --> C["Program Headers<br/>Load segments"]
    A --> D[".text Section<br/>Code"]
    A --> E[".data Section<br/>Initialized data"]
    A --> F[".bss Section<br/>Uninitialized"]
    A --> G[".debug_info<br/>DWARF symbols"]
    A --> H["Symbol Table<br/>Function names"]
    
    style A fill:#81c784,color:#fff
    style B fill:#c8e6c9
    style C fill:#c8e6c9
    style D fill:#a5d6a7
    style E fill:#a5d6a7
    style F fill:#a5d6a7
    style G fill:#c8e6c9
    style H fill:#c8e6c9
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
    A["program.elf<br/>Binary + Debug"] --> B{objcopy}
    B --> |Strip| C["Remove .debug_*"]
    B --> |Extract| D["Get .text .data"]
    B --> |Format| E["Convert to ASCII"]
    
    C --> F["program.hex<br/>Intel HEX"]
    D --> F
    E --> F
    
    style A fill:#81c784
    style B fill:#00bcd4,color:#fff
    style C fill:#b2ebf2
    style D fill:#b2ebf2
    style E fill:#b2ebf2
    style F fill:#4dd0e1
```

### Command
```bash
avr-objcopy -O ihex -R .eeprom build/program.elf build/program.hex
```

### HEX File Format

```mermaid
graph LR
    A[":"] --> B["10<br/>Byte count"]
    B --> C["0000<br/>Address"]
    C --> D["00<br/>Record type"]
    D --> E["Data bytes..."]
    E --> F["3C<br/>Checksum"]
    
    style A fill:#4dd0e1
    style B fill:#80deea
    style C fill:#80deea
    style D fill:#80deea
    style E fill:#b2ebf2
    style F fill:#4dd0e1
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
        A1[".c<br/>C source<br/>Human readable"]
        A2[".S<br/>ASM + preprocessor<br/>Human readable"]
    end
    
    subgraph Intermediate["Intermediate Files"]
        B1[".i<br/>Preprocessed C<br/>Text"]
        B2[".s<br/>Pure assembly<br/>Text"]
        B3[".o<br/>Object code<br/>Binary"]
    end
    
    subgraph Final["Final Products"]
        C1[".elf<br/>Full executable<br/>Binary + Debug"]
        C2[".hex<br/>Flash data only<br/>ASCII"]
    end
    
    A1 --> B1 --> B2 --> B3 --> C1 --> C2
    A2 --> B2
    
    style Source fill:#e3f2fd
    style Intermediate fill:#fff3e0
    style Final fill:#e8f5e9
```

---

## Assembly Types: .S vs .s

```mermaid
flowchart TD
    A["blink.S<br/>CAPITAL S"] --> B{Preprocessor}
    B --> C["Can use:<br/>#include<br/>#define<br/>#ifdef"]
    C --> D["blink.s<br/>Pure ASM"]
    
    E["direct.s<br/>lowercase s"] --> F{No Preprocessing}
    F --> G["Cannot use:<br/>Preprocessor directives"]
    G --> D
    
    style A fill:#81c784
    style B fill:#ffc107
    style E fill:#81c784
    style F fill:#e0e0e0
    style D fill:#ffecb3
```

### `.S` (with preprocessor)
```asm
#include <avr/io.h>
#define LED_PIN 5

.global main
main:
    sbi _SFR_IO_ADDR(DDRB), LED_PIN
    ret
```

### `.s` (pure assembly)
```asm
.global main
main:
    sbi 0x04, 5    ; Direct address
    ret
```

---

## AVR Instruction Set Categories

```mermaid
mindmap
    root((AVR ISA))
        Arithmetic
            add sub
            inc dec
            mul
            adc sbc
        Logic
            and or eor
            com neg
            cbr sbr
        Branch
            rjmp jmp
            rcall call ret
            brne breq
            brlt brge
        Bit Ops
            sbi cbi
            lsl lsr
            rol ror
            bst bld
        Data Transfer
            ldi ld st
            mov movw
            push pop
            in out
        Special
            nop
            sleep
            wdr
            break
```

---

## AVR Register Architecture

```mermaid
graph TD
    subgraph Registers["32 General Purpose Registers"]
        A["r0-r15<br/>General use"]
        B["r16-r31<br/>Can use ldi"]
        C["r26-r27 = X<br/>r28-r29 = Y<br/>r30-r31 = Z<br/>Pointer registers"]
    end
    
    subgraph Special["Special Registers"]
        D["SREG<br/>Status flags<br/>C Z N V S H T I"]
        E["SP<br/>Stack Pointer<br/>SPH:SPL"]
        F["PC<br/>Program Counter"]
    end
    
    style A fill:#bbdefb
    style B fill:#90caf9
    style C fill:#42a5f5,color:#fff
    style D fill:#ef5350,color:#fff
    style E fill:#ef5350,color:#fff
    style F fill:#ef5350,color:#fff
```

---

## Complete Build Flow

```mermaid
graph TB
    A[Write Code] --> B{Language?}
    B -->|C| C[main.c]
    B -->|ASM| D[blink.S]
    
    C --> E[Preprocess<br/>-E]
    D --> E
    
    E --> F[Compile<br/>-S]
    F --> G[Assemble<br/>-c]
    G --> H[Link<br/>-o .elf]
    H --> I[Convert<br/>objcopy]
    I --> J[Upload<br/>avrdude]
    J --> K[MCU Running]
    
    style C fill:#4a90e2,color:#fff
    style D fill:#4a90e2,color:#fff
    style E fill:#f5a623
    style F fill:#f5a623
    style G fill:#d0021b,color:#fff
    style H fill:#7ed321
    style I fill:#50e3c2
    style J fill:#bd10e0,color:#fff
    style K fill:#9013fe,color:#fff
```

---

## Makefile Workflow

```mermaid
flowchart TD
    A[make all] --> B[Create build/]
    B --> C[Compile .c → .o]
    B --> D[Assemble .S → .o]
    C --> E[Link → .elf]
    D --> E
    E --> F[Convert → .hex]
    
    G[make upload] --> F
    F --> H[avrdude]
    H --> I[MCU Flash]
    
    J[make clean] --> K[Delete build/]
    
    style A fill:#4caf50,color:#fff
    style G fill:#2196f3,color:#fff
    style J fill:#f44336,color:#fff
    style I fill:#9c27b0,color:#fff
```

---

## Memory-Mapped I/O

```mermaid
graph LR
    subgraph IO["I/O Space (0x00-0x3F)"]
        A["0x03: PINB<br/>Input"]
        B["0x04: DDRB<br/>Direction"]
        C["0x05: PORTB<br/>Output"]
    end
    
    subgraph Extended["Extended I/O (0x40-0xFF)"]
        D["0x80: TIMSK0<br/>Timer mask"]
        E["0xC0: UDR0<br/>UART data"]
    end
    
    subgraph SRAM["SRAM (0x100-0x8FF)"]
        F["0x100: .data"]
        G["0x8FF: Stack"]
    end
    
    A -.->|in/out| H[Direct access]
    D -.->|lds/sts| I[Memory access]
    F -.->|ld/st| I
    
    style IO fill:#e1f5fe
    style Extended fill:#fff3e0
    style SRAM fill:#f3e5f5
```

### I/O Access Examples
```asm
; Direct I/O (0x00-0x3F)
sbi 0x04, 5        ; Set bit in DDRB
in r16, 0x05       ; Read PORTB

; Extended I/O (0x40-0xFF)
lds r16, 0x0080    ; Read TIMSK0
sts 0x0080, r16    ; Write TIMSK0

; SRAM
ld r16, X          ; Load from address in X
st X, r16          ; Store to address in X
```

---

## Tool Commands Summary

```mermaid
graph TD
    A[avr-gcc] --> B[Compile/Link]
    C[avr-as] --> D[Assemble only]
    E[avr-objcopy] --> F[Format conversion]
    G[avr-objdump] --> H[Disassemble]
    I[avr-nm] --> J[List symbols]
    K[avr-size] --> L[Section sizes]
    M[avrdude] --> N[Upload firmware]
    
    style A fill:#4caf50,color:#fff
    style C fill:#4caf50,color:#fff
    style E fill:#2196f3,color:#fff
    style G fill:#ff9800,color:#fff
    style I fill:#ff9800,color:#fff
    style K fill:#ff9800,color:#fff
    style M fill:#9c27b0,color:#fff
```

### Commands Reference

```bash
# Compile C to object
avr-gcc -c -mmcu=atmega328p -O2 src/main.c -o build/main.o

# Link to ELF
avr-gcc -mmcu=atmega328p build/main.o -o build/program.elf

# ELF to HEX
avr-objcopy -O ihex -R .eeprom build/program.elf build/program.hex

# Disassemble
avr-objdump -d build/program.elf

# List symbols
avr-nm build/program.elf

# Section sizes
avr-size -A build/program.elf

# Upload
avrdude -c avrisp2 -p atmega328p -P /dev/cu.usbserial-110 \
        -U flash:w:build/program.hex:i
```

---

## Debug Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GCC as avr-gcc
    participant GDB as avr-gdb
    participant MCU as ATmega328p
    
    Dev->>GCC: Compile with -g flag
    GCC-->>Dev: program.elf (with DWARF)
    Dev->>GDB: Load ELF
    GDB->>MCU: Set breakpoint
    Dev->>GDB: run
    GDB->>MCU: Execute until BP
    MCU-->>GDB: Stopped at 0x0123
    GDB-->>Dev: Show source line
    Dev->>GDB: print variable
    GDB-->>Dev: value = 42
```

### Debug Build
```bash
# Compile with debug symbols
avr-gcc -g -O0 -mmcu=atmega328p src/main.c -o build/main.elf

# Debugger (requires hardware debugger)
avr-gdb build/main.elf
(gdb) target remote :4242
(gdb) break main
(gdb) continue
```