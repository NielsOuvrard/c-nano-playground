# AVR Assembly Language

**Architecture:** RISC (Reduced Instruction Set Computer)
- **Manufacturer:** Microchip (formerly Atmel)
- **Chip:** ATmega328p
- **Instruction set:** AVR (8-bit)

**Key characteristics:**

1. **Register-based** (32 general purpose registers: r0-r31)
```asm
ldi r16, 42     ; Load immediate 42 into r16
mov r17, r16    ; Copy r16 to r17
add r18, r17    ; r18 = r18 + r17
```

2. **Harvard architecture** (separate program and data memory)
```
Program Memory (Flash): 32KB
Data Memory (SRAM): 2KB
EEPROM: 1KB
```

3. **Fixed instruction width** (16-bit or 32-bit instructions)
```asm
nop             ; 16-bit: 0x0000
call function   ; 32-bit: includes full address
```

4. **Memory-mapped I/O**
```asm
; I/O registers are accessed directly
out PORTB, r16  ; Write to port B
in r16, PINB    ; Read from port B

; Or via memory addresses
sts 0x0025, r16 ; Store to PORTB memory address
```

## AVR Instruction Categories

**1. Arithmetic/Logic**
```asm
add r16, r17    ; r16 = r16 + r17
sub r16, r17    ; r16 = r16 - r17
and r16, r17    ; r16 = r16 & r17
or r16, r17     ; r16 = r16 | r17
com r16         ; r16 = ~r16 (complement)
neg r16         ; r16 = -r16 (two's complement)
```

**2. Branch/Jump**
```asm
rjmp label      ; Relative jump
call function   ; Call subroutine
ret             ; Return from subroutine
brne label      ; Branch if not equal
breq label      ; Branch if equal
```

**3. Bit Operations**
```asm
sbi PORTB, 5    ; Set bit 5 in PORTB
cbi PORTB, 5    ; Clear bit 5 in PORTB
lsl r16         ; Logical shift left
lsr r16         ; Logical shift right
```

**4. Data Transfer**
```asm
ldi r16, 42     ; Load immediate (only r16-r31)
mov r17, r16    ; Copy register
ld r16, X       ; Load from memory (X pointer)
st X, r16       ; Store to memory
push r16        ; Push to stack
pop r16         ; Pop from stack
```

**5. I/O**
```asm
in r16, PINB    ; Read from I/O port
out PORTB, r16  ; Write to I/O port
sbi DDRB, 5     ; Set bit in I/O register
cbi DDRB, 5     ; Clear bit in I/O register
```

---

## Advanced: Pure Assembly Program

**src/blink.S** (complete standalone program):

```asm
; AVR Assembly for ATmega328p
; Blinks LED on PB5 (Arduino pin 13)

#include <avr/io.h>

; Entry point
.section .text
.global main

main:
    ; Initialize stack pointer
    ldi r16, lo8(RAMEND)
    out _SFR_IO_ADDR(SPL), r16
    ldi r16, hi8(RAMEND)
    out _SFR_IO_ADDR(SPH), r16
    
    ; Set PB5 as output
    sbi _SFR_IO_ADDR(DDRB), DDB5
    
main_loop:
    ; Turn LED on
    sbi _SFR_IO_ADDR(PORTB), PORTB5
    rcall delay_500ms
    
    ; Turn LED off
    cbi _SFR_IO_ADDR(PORTB), PORTB5
    rcall delay_500ms
    
    rjmp main_loop

; Delay approximately 500ms at 16MHz
delay_500ms:
    ldi r18, 41        ; Outer loop: 41 iterations
outer_loop:
    ldi r19, 200       ; Middle loop: 200 iterations
middle_loop:
    ldi r20, 250       ; Inner loop: 250 iterations
inner_loop:
    dec r20            ; 1 cycle
    brne inner_loop    ; 2 cycles when taken, 1 when not
    dec r19
    brne middle_loop
    dec r18
    brne outer_loop
    ret

; Interrupt vector table (if needed)
.section .vectors
    rjmp main          ; Reset vector
```

**Compile and upload:**

```bash
avr-gcc -mmcu=atmega328p -nostartfiles src/blink.S -o build/blink.elf
avr-objcopy -O ihex build/blink.elf build/blink.hex
avrdude -c avrisp2 -p atmega328p -P /dev/cu.usbserial-110 -b 19200 -U flash:w:build/blink.hex:i
```
