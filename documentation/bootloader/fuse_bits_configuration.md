# ATmega328P Fuse Bits Configuration

Fuse bits are **one-time programmable configuration bits** (well, reprogrammable, but they persist across resets and power cycles). They configure how the chip operates at the **hardware level**.

---

## Overview: Three Fuse Bytes

```
ATmega328P Fuses:
┌─────────────┬──────────┬─────────────────────────┐
│ Fuse Byte   │ Address  │ Purpose                 │
├─────────────┼──────────┼─────────────────────────┤
│ Low Fuse    │ 0x00     │ Clock source/timing     │
│ High Fuse   │ 0x01     │ Boot/debug/reset config │
│ Extended    │ 0x02     │ Brown-out detection     │
└─────────────┴──────────┴─────────────────────────┘
```

**CRITICAL**: Fuses use **negative logic**: 
- `0` = **programmed** (active/enabled)
- `1` = **unprogrammed** (inactive/disabled)

---

# LOW FUSE (0xFF) - Clock Configuration

```
Bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │CKDIV8│CKOUT │ SUT1 │ SUT0 │CKSEL3│CKSEL2│CKSEL1│CKSEL0│
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
Value:    1      1      1      1      1      1      1      1    = 0xFF
```

---

## Bit 7: CKDIV8 (Clock Divide by 8)

**Value: 1 (unprogrammed) = Division DISABLED**

```
CKDIV8 = 0 (programmed):   Clock ÷ 8
CKDIV8 = 1 (unprogrammed): Clock ÷ 1 (full speed)
```

### Example:
```
16 MHz crystal:
  CKDIV8=0 → System runs at 2 MHz
  CKDIV8=1 → System runs at 16 MHz (what you want!)
```

### Purpose:
- Factory default is `0` (divided) for safety
- Arduino boards need full speed, so `1`

### Circuit Impact:
```
         ┌─────────┐
Crystal ─┤ 16 MHz  ├─→ Prescaler ─→ CPU
         └─────────┘        │
                            ├─ CKDIV8=0 → ÷8 → 2 MHz
                            └─ CKDIV8=1 → ÷1 → 16 MHz
```

---

## Bit 6: CKOUT (Clock Output)

**Value: 1 (unprogrammed) = Output DISABLED**

```
CKOUT = 0 (programmed):   PB0 outputs system clock
CKOUT = 1 (unprogrammed): PB0 normal GPIO
```

### When Enabled (CKOUT=0):
```
ATmega328P Pin 14 (PB0/D8)
         │
         └─→ Square wave at F_CPU frequency
```

### Use Cases:
- Debugging clock issues
- Driving external peripherals that need clock
- **Arduino doesn't use this** - wastes a GPIO pin

---

## Bits 5-4: SUT[1:0] (Start-Up Time)

**Value: 11 = Slowest startup (65ms)**

Controls delay from reset/power-on until code starts executing.

```
SUT1 SUT0 | Delay from Reset | Delay from Power-On
─────┼────┼──────────────────┼────────────────────
  0  | 0  | 6 CK             | 6 CK + 4.1ms
  0  | 1  | 6 CK + 4.1ms     | 6 CK + 65ms
  1  | 0  | 6 CK + 65ms      | Reserved
  1  | 1  | 6 CK + 4.1ms     | 6 CK + 4.1ms + 65ms  ← Arduino uses this
```

**CK = Clock cycles**

### Why This Matters:

```
Power supply rise time:
  
Voltage
  5V ┌────────────  ← Stable
     │        ╱
     │       ╱ ← Rise time (capacitors charging)
  0V └──────╱
     
     ├─────┤
      SUT delay - wait for stability
```

### Arduino's Choice (SUT=11):
- **Slowest startup** = safest
- Ensures crystal is stable
- Ensures power supply is clean
- Only happens once per power-on, so speed doesn't matter

---

## Bits 3-0: CKSEL[3:0] (Clock Source Select)

**Value: 1111 = External crystal oscillator, high frequency**

This is the **most important** setting - determines where the CPU gets its clock!

### All Possible Clock Sources:

```
CKSEL[3:0] | Clock Source                    | Frequency Range
───────────┼─────────────────────────────────┼─────────────────
 0000      | External clock on CLKI pin      | 0-20 MHz
 0001      | Reserved                        | -
 0010      | Calibrated internal RC osc      | 8 MHz
 0011      | Internal 128 kHz RC osc         | 128 kHz
 0100-0101 | Low-freq crystal (watch crystal)| 32.768 kHz
 0110-0111 | Full-swing crystal osc          | 0.4-20 MHz
 1000-1001 | Low-power crystal osc           | 0.4-0.9 MHz
 1010-1011 | Low-power crystal osc           | 0.9-3 MHz
 1100-1101 | Low-power crystal osc           | 3-8 MHz
 1110-1111 | Low-power crystal osc           | 8-20 MHz  ← Arduino
```

### Arduino Nano Circuit:

```
                    ATmega328P
                    
        XTAL1 (Pin 9)  ┌────┐  XTAL2 (Pin 10)
              ├────────┤CHIP├────────┤
              │        └────┘        │
             22pF                   22pF
              │                      │
            ┌───┐                  ┌───┐
            │16 │ MHz Crystal      │GND│
            │MHz│                  └───┘
            └───┘
              │
            ┌───┐
            │GND│
            └───┘
```

### Why External Crystal?

**Internal RC Oscillator (CKSEL=0010):**
- ±10% accuracy (terrible!)
- Temperature dependent
- Would make serial communication **unreliable**

**External Crystal (CKSEL=1111):**
- ±50 ppm accuracy (0.005% error)
- Stable across temperature
- **Required for USB serial** (115200 baud needs precision)

### Calculation:
```
Serial communication error with internal RC:
  Expected: 115200 baud
  Actual (worst case): 115200 × 1.10 = 126720 baud
  Error: 10% → COMMUNICATION FAILS

With crystal:
  Expected: 115200 baud
  Actual: 115200 × 1.00005 = 115206 baud
  Error: 0.005% → WORKS PERFECTLY
```

---

# HIGH FUSE (0xDE) - Boot, Debug, Reset

```
Bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │RSTDIS│DWEN  │SPIEN │WDTON │EESAVE│BOOTSZ│BOOTSZ│BOOTRST│
      │  BL  │      │      │      │      │  1   │  0   │      │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
Value:    1      1      0      1      1      1      1      0    = 0xDE
```

---

## Bit 7: RSTDISBL (Reset Disable)

**Value: 1 (unprogrammed) = Reset pin ENABLED**

```
RSTDISBL = 0 (programmed):   Pin 1 becomes PC6 GPIO
RSTDISBL = 1 (unprogrammed): Pin 1 is RESET (normal)
```

### Circuit:

```
Normal (RSTDISBL=1):
  Pin 1 (RESET) ──┬── 10kΩ ──→ 5V (pull-up)
                  │
                  └── Button ──→ GND

Disabled (RSTDISBL=0):
  Pin 1 (PC6/GPIO) ──→ Available as I/O
```

### Why Arduino Keeps It Enabled:
- **Can't program chip** without RESET!
- Bootloader needs reset to activate
- Emergency reset button useful

### If You Disable It:
- ⚠️ **You BRICK the chip** (sort of)
- Can only reprogram via **High-Voltage Parallel Programming** (12V on RESET pin)
- Need special programmer ($$$)

---

## Bit 6: DWEN (debugWIRE Enable)

**Value: 1 (unprogrammed) = debugWIRE DISABLED**

```
DWEN = 0 (programmed):   debugWIRE protocol enabled on RESET pin
DWEN = 1 (unprogrammed): Normal operation
```

### What is debugWIRE?
Atmel's **single-wire debugging protocol** - allows:
- Real-time debugging
- Breakpoints
- Variable inspection
- Step-through execution

### Conflicts:
```
RESET pin can be:
  - Reset input (normal)
  - PC6 GPIO (if RSTDISBL=0)
  - debugWIRE interface (if DWEN=0)
  
Can only be ONE at a time!
```

### Arduino doesn't use this because:
- Requires expensive Atmel-ICE debugger
- Disables bootloader
- Most users don't need hardware debugging

---

## Bit 5: SPIEN (SPI Programming Enable)

**Value: 0 (programmed) = SPI Programming ENABLED**

```
SPIEN = 0 (programmed):   ISP programming works
SPIEN = 1 (unprogrammed): ISP programming DISABLED
```

### Critical Warning:

**IF YOU SET THIS TO 1, YOU BRICK THE CHIP!**

```
SPIEN=1 → Can't program via ISP
       → Can only use High-Voltage Programming
       → Need special equipment
```

### Why It Exists:
- Code protection for production devices
- Prevents reverse engineering
- **Never use on development boards!**

### How ISP Works (SPIEN=0):

```
Programmer ──→ RESET (pulled low)
            ┌──→ SCK  (clock)
            ├──→ MOSI (data to chip)
            └──→ MISO (data from chip)
```

---

## Bit 4: WDTON (Watchdog Timer Always On)

**Value: 1 (unprogrammed) = Watchdog OPTIONAL**

```
WDTON = 0 (programmed):   Watchdog always running (can't disable)
WDTON = 1 (unprogrammed): Watchdog controlled by software
```

### Watchdog Timer Explained:

```c
// With WDTON=1 (normal Arduino):
void setup() {
    wdt_enable(WDTO_2S);  // Enable, 2-second timeout
}

void loop() {
    wdt_reset();  // Pat the dog - prevents reset
    // Do work...
}

// If loop hangs, watchdog resets chip after 2 seconds
```

### With WDTON=0 (always on):
- Watchdog **cannot be disabled** in software
- Must reset it periodically or chip resets
- Used in safety-critical applications

### Arduino's Choice (WDTON=1):
- Flexibility - enable when needed
- Bootloader uses it for timeout
- Can disable for low-power sleep

---

## Bit 3: EESAVE (EEPROM Preserve)

**Value: 1 (unprogrammed) = EEPROM ERASED on chip erase**

```
EESAVE = 0 (programmed):   EEPROM preserved during chip erase
EESAVE = 1 (unprogrammed): EEPROM erased with Flash
```

### Behavior:

```
Chip Erase Command:

EESAVE=0:
  Flash → Erased (0xFF)
  EEPROM → Preserved (keeps data!)

EESAVE=1:
  Flash → Erased (0xFF)
  EEPROM → Erased (0xFF)
```

### Use Cases:

**EESAVE=0 (preserved):**
- Production devices with calibration data in EEPROM
- Firmware updates shouldn't erase settings
- User preferences stored in EEPROM

**EESAVE=1 (erased) - Arduino default:**
- Clean slate on every upload
- No leftover data from previous programs
- Easier for beginners (no surprises)

---

## Bits 2-1: BOOTSZ[1:0] (Boot Loader Size)

**Value: 11 = Smallest bootloader (512 bytes / 256 words)**

Determines how much Flash is reserved for bootloader:

```
BOOTSZ1 BOOTSZ0 | Size (words) | Size (bytes) | Start Address | App Space
────────┼────────┼──────────────┼──────────────┼───────────────┼──────────
   0       0    |    2048      |    4096      |    0x7000     | 28 KB
   0       1    |    1024      |    2048      |    0x7800     | 30 KB  ← Old
   1       0    |     512      |    1024      |    0x7C00     | 31 KB
   1       1    |     256      |     512      |    0x7E00     | 31.5 KB ← New
```

### Memory Map Visualization:

```
BOOTSZ = 01 (Old Bootloader):
0x0000 ┌─────────────────────┐
       │                     │
       │   Application       │
       │   30 KB             │
       │                     │
0x7800 ├─────────────────────┤ ← Bootloader starts
       │   Bootloader        │
       │   2 KB              │
0x7FFF └─────────────────────┘

BOOTSZ = 11 (New Bootloader):
0x0000 ┌─────────────────────┐
       │                     │
       │   Application       │
       │   31.5 KB           │
       │                     │
0x7E00 ├─────────────────────┤ ← Bootloader starts
       │   Bootloader        │
       │   512 bytes         │
0x7FFF └─────────────────────┘
```

### How CPU Knows Where Bootloader Is:

```asm
; Reset vector behavior:
; If BOOTRST=0, jump to bootloader address

.org 0x0000
    jmp BOOTLOADER_START  ; Set by BOOTSZ fuses

; BOOTSZ determines BOOTLOADER_START:
; 00 → 0x7000
; 01 → 0x7800
; 10 → 0x7C00
; 11 → 0x7E00
```

---

## Bit 0: BOOTRST (Boot Reset Vector)

**Value: 0 (programmed) = Boot from BOOTLOADER**

```
BOOTRST = 0 (programmed):   Reset → Jump to bootloader
BOOTRST = 1 (unprogrammed): Reset → Jump to 0x0000 (application)
```

### Reset Behavior:

```
Power-On or RESET pin pulled LOW
         ↓
    Check BOOTRST fuse
         ↓
    ┌─────────────────┐
    │  BOOTRST = 0?   │
    └────┬────────┬───┘
        YES      NO
         │        │
         ↓        ↓
   Bootloader   Application
   (0x7E00)     (0x0000)
```

### With Bootloader (BOOTRST=0):

```c
// Bootloader pseudo-code at 0x7E00:
void bootloader() {
    if (serial_upload_requested()) {
        receive_new_program();
        write_to_flash();
    }
    
    // Jump to application
    asm("jmp 0x0000");
}
```

### Without Bootloader (BOOTRST=1):

```
Direct execution from 0x0000
  - Faster boot (no bootloader delay)
  - Can't upload via serial
  - Need ISP programmer for all uploads
```

---

# EXTENDED FUSE (0xFD) - Brown-Out Detection

```
Bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │  -   │  -   │  -   │  -   │  -   │BODLEVEL BODLEVEL│
      │      │      │      │      │      │  2   │  1   │  0  │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
Value:    1      1      1      1      1      1      0      1    = 0xFD
```

## Bits 2-0: BODLEVEL[2:0] (Brown-Out Detection Level)

**Value: 101 = 2.7V threshold**

Resets chip if voltage drops below threshold.

```
BODLEVEL[2:0] | VCC Threshold | Use Case
──────────────┼───────────────┼─────────────────────
    111       | Disabled      | No protection
    110       | 1.8V          | Battery (1.8-2.7V)
    101       | 2.7V          | Arduino (5V ±10%)  ← Default
    100       | 4.3V          | Strict 5V systems
    011       | Reserved      | -
    010       | Reserved      | -
    001       | Reserved      | -
    000       | Reserved      | -
```

### How Brown-Out Detection Works:

```
VCC voltage over time:
  
  5V ─────┐              ┌─────
          │              │
  2.7V ───┼──────┐   ┌───┼─── ← BOD threshold
          │      │   │   │
  0V  ────┴──────┴───┴───┴────
          
          ↑      ↑   ↑   ↑
          │      │   │   │
        Power  RESET  │  Power
         ON    (BOD)  │  restored
                   RESET
                   (BOD)
```

### Why Arduino Uses 2.7V:

```
5V USB power can drop to:
  5.0V - 10% = 4.5V  ← Normal variation, OK
  5.0V - 20% = 4.0V  ← Bad USB cable
  5.0V - 46% = 2.7V  ← Critical! Reset chip!

If voltage drops below 2.7V:
  - Flash writes could corrupt
  - EEPROM writes could fail
  - CPU could execute random instructions
  - Better to RESET than corrupt data!
```

### Disabling BOD (BODLEVEL=111):
```c
// Saves ~20µA in sleep mode
// But risk data corruption!

// Only disable if:
// - No EEPROM writes
// - No Flash writes
// - Power supply very stable
```

---

# Complete Fuse Examples

## Arduino Nano (New Bootloader):
```
Low Fuse:  0xFF (11111111)
  ├─ CKDIV8  = 1 (full speed, no division)
  ├─ CKOUT   = 1 (no clock output)
  ├─ SUT     = 11 (slow startup, 65ms)
  └─ CKSEL   = 1111 (external crystal, 8-20MHz)

High Fuse: 0xDE (11011110)
  ├─ RSTDISBL = 1 (reset enabled - DON'T CHANGE!)
  ├─ DWEN     = 1 (debugWIRE disabled)
  ├─ SPIEN    = 0 (SPI programming enabled - DON'T CHANGE!)
  ├─ WDTON    = 1 (watchdog software controlled)
  ├─ EESAVE   = 1 (EEPROM erased on chip erase)
  ├─ BOOTSZ   = 11 (512 bytes, 0x7E00 start)
  └─ BOOTRST  = 0 (boot to bootloader)

Extended:  0xFD (11111101)
  └─ BODLEVEL = 101 (2.7V brown-out)
```

## Bare Chip (No Bootloader, 8MHz Internal):
```
Low Fuse:  0x62 (01100010)
  ├─ CKDIV8  = 0 (÷8 = 1MHz from 8MHz RC)
  └─ CKSEL   = 0010 (internal 8MHz RC)

High Fuse: 0xDF (11011111)
  └─ BOOTRST = 1 (boot to 0x0000, no bootloader)

Extended:  0xFF (11111111)
  └─ BODLEVEL = 111 (disabled)
```

---

# Reading/Writing Fuses

### Read current fuses:
```bash
avrdude -c stk500v1 -P COM5 -b 19200 -p atmega328p \
  -U lfuse:r:-:h \
  -U hfuse:r:-:h \
  -U efuse:r:-:h
```

Output:
```
lfuse reads as FF
hfuse reads as DE
efuse reads as FD
```

### Write fuses (DANGEROUS!):
```bash
avrdude -c stk500v1 -P COM5 -b 19200 -p atmega328p \
  -U lfuse:w:0xFF:m \
  -U hfuse:w:0xDE:m \
  -U efuse:w:0xFD:m
```

---

# ⚠️ FUSE BIT SAFETY WARNINGS ⚠️

### NEVER SET THESE TO WRONG VALUES:

1. **SPIEN = 1** → Bricks chip (can't program via ISP)
2. **RSTDISBL = 0** → Loses reset pin (need HV programmer)
3. **CKSEL = wrong** → Wrong clock, won't run
4. **BOOTSZ + BOOTRST** → Mismatched = no boot

### SAFE TO CHANGE:
- BODLEVEL (brown-out voltage)
- WDTON (watchdog always-on)
- EESAVE (EEPROM preservation)

### IF YOU BRICK IT:
Need **High-Voltage Parallel Programmer** to recover:
- Applies 12V to RESET pin
- Special programming mode
- Can fix RSTDISBL and SPIEN errors
- Costs $50-200

---

Want me to explain how to calculate custom fuse values for a specific application?