# Tool Commands Summary

```mermaid
graph LR
    A[avr-gcc] --> B[Compile/Link]
    C[avr-as] --> D[Assemble only]
    E[avr-objcopy] --> F[Format conversion]
    G[avr-objdump] --> H[Disassemble]
    I[avr-nm] --> J[List symbols]
    K[avr-size] --> L[Section sizes]
    M[avrdude] --> N[Upload firmware]
    
    style A fill:#333,color:#fff
    style C fill:#333,color:#fff
    style E fill:#333,color:#fff
    style G fill:#333,color:#fff
    style I fill:#333,color:#fff
    style K fill:#333,color:#fff
    style M fill:#333,color:#fff
```

## Commands Reference

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

# Debug Flow

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

## Debug Build
```bash
# Compile with debug symbols
avr-gcc -g -O0 -mmcu=atmega328p src/main.c -o build/main.elf

# Debugger (requires hardware debugger)
avr-gdb build/main.elf
(gdb) target remote :4242
(gdb) break main
(gdb) continue
```