# Quick Guide: LOCK, SIGNATURE, and CALIBRATION

---

## LOCK BITS (1 byte) - Memory Protection

**Purpose**: Prevent reading/modifying Flash and EEPROM

```
Bit:     7      6      5      4      3      2      1      0
      ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐
      │  -   │  -   │ BLB12│ BLB11│ BLB02│ BLB01│  LB2 │  LB1 │
      └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘
```

### Bits 1-0: LB (Memory Lock Bits)

```
LB2 LB1 | Protection Mode
────┴───┴──────────────────────────────
 1   1  | No memory lock (default, programmable)
 1   0  | Further programming disabled
 0   0  | Further programming AND verify disabled (max lock)
```

**Use case**: Protect your code from being copied via ISP

### Bits 5-4: BLB0 (Boot Loader Protection)

```
BLB02 BLB01 | Protection
──────┴─────┴──────────────────────────────────────
  1     1   | No protection
  1     0   | SPM not allowed to write to Boot section
  0     0   | SPM not allowed to write, LPM not allowed to read
```

**Prevents bootloader from modifying itself**

### Bits 3-2: BLB1 (Application Protection)

```
BLB12 BLB11 | Protection
──────┴─────┴──────────────────────────────────────
  1     1   | No protection
  1     0   | SPM not allowed to write to Application
  0     0   | SPM not allowed, LPM reading Application → Boot jumps to Boot
```

**Prevents bootloader from reading your app code**

### Example: Arduino Default Lock Bits

```
Lock Bits = 0x0F (00001111)
  All bits = 1 → No protection (fully programmable)
```

### Example: Production Lock (Code Protection)

```
Lock Bits = 0x0C (00001100)
  LB = 00 → Can't read Flash via ISP
  BLB0 = 11 → Bootloader unprotected
  BLB1 = 11 → Application unprotected
  
Result: Code is locked, can't extract firmware!
```

### Read Lock Bits:

```c
#include <avr/boot.h>

uint8_t locks = boot_lock_fuse_bits_get(GET_LOCK_BITS);
Serial.print("Lock: 0x");
Serial.println(locks, HEX);
```

### Write Lock Bits (ISP only):

```bash
# Lock the chip (can't read Flash anymore!)
avrdude -c avrispmkii -p m328p -U lock:w:0x0C:m

# Unlock (requires chip erase - ERASES ALL FLASH!)
avrdude -c avrispmkii -p m328p -e -U lock:w:0x0F:m
```

⚠️ **Warning**: Setting LB bits to non-0xFF **locks the chip**. To unlock, you must **erase all Flash**!

---

## SIGNATURE BYTES (3 bytes, Read-Only) - Device ID

**Purpose**: Identify the exact chip model

```
Address | Value | Meaning
────────┼───────┼─────────────────────────
  0x00  │ 0x1E  │ Atmel manufacturer code
  0x01  │ 0x95  │ Part family (mega, 32KB)
  0x02  │ 0x0F  │ Specific part (ATmega328P)
```

### ATmega328P Signature:
```
0x1E 0x95 0x0F
```

### ATmega328 (non-P) Signature:
```
0x1E 0x95 0x14  ← Different last byte!
```

### Other Common Signatures:

```
ATmega168:  0x1E 0x94 0x06
ATmega8:    0x1E 0x93 0x07
ATmega2560: 0x1E 0x98 0x01
ATtiny85:   0x1E 0x93 0x0B
```

### Reading Signature:

```c
#include <avr/boot.h>

void print_signature() {
    uint8_t sig[3];
    sig[0] = boot_signature_byte_get(0x0000);
    sig[1] = boot_signature_byte_get(0x0002);
    sig[2] = boot_signature_byte_get(0x0004);
    
    Serial.print("Signature: ");
    for (int i = 0; i < 3; i++) {
        if (sig[i] < 0x10) Serial.print("0");
        Serial.print(sig[i], HEX);
        Serial.print(" ");
    }
    Serial.println();
    
    // Identify chip
    if (sig[0] == 0x1E && sig[1] == 0x95 && sig[2] == 0x0F) {
        Serial.println("Device: ATmega328P");
    } else if (sig[0] == 0x1E && sig[1] == 0x95 && sig[2] == 0x14) {
        Serial.println("Device: ATmega328");
    } else {
        Serial.println("Device: Unknown");
    }
}
```

### Via ISP:

```bash
avrdude -c avrispmkii -p m328p -U signature:r:-:h
```

Output:
```
avrdude: Device signature = 0x1e950f
```

### Why It Exists:

1. **Programmer verification**: Ensures correct chip is connected
2. **Software detection**: Your code can determine which chip it's running on
3. **Factory set**: Programmed at manufacturing, **cannot be changed**

---

## CALIBRATION BYTE (1 byte, Read-Only) - RC Oscillator Tuning

**Purpose**: Factory calibration for internal 8 MHz RC oscillator

```
Address | Value    | Meaning
────────┼──────────┼────────────────────────────
  0x01  │ 0x00-0xFF│ OSCCAL register value
```

### What It Does:

The internal RC oscillator has **±10% tolerance** from manufacturing variations. The calibration byte fine-tunes it to **±1%**.

```
Without calibration:
  Target: 8.0 MHz
  Actual: 7.2 - 8.8 MHz (±10%)
  
With calibration:
  Target: 8.0 MHz
  Actual: 7.92 - 8.08 MHz (±1%)
```

### Reading Calibration:

```c
#include <avr/boot.h>

uint8_t cal = boot_signature_byte_get(0x0001);
Serial.print("Calibration: 0x");
Serial.println(cal, HEX);
```

### Applying Calibration:

```c
void setup() {
    // Read factory calibration
    uint8_t cal = boot_signature_byte_get(0x0001);
    
    // Apply to oscillator
    OSCCAL = cal;
    
    // Now internal 8 MHz RC is accurate!
    Serial.begin(9600);  // Will work correctly
}
```

### OSCCAL Register:

```
OSCCAL (0x66):
  Bit 7-0: Oscillator calibration value
  
  0x00 = Slowest frequency (~7.2 MHz)
  0x80 = Mid-range (~8.0 MHz) ← Factory cal usually near this
  0xFF = Fastest frequency (~8.8 MHz)
```

### Manual Tuning (Advanced):

```c
void tune_oscillator() {
    // Start with factory calibration
    uint8_t cal = boot_signature_byte_get(0x0001);
    OSCCAL = cal;
    
    // Fine-tune if needed (measure against external reference)
    OSCCAL += 5;  // Slightly faster
    // or
    OSCCAL -= 3;  // Slightly slower
}
```

### Via ISP:

```bash
avrdude -c avrispmkii -p m328p -U calibration:r:-:h
```

Output:
```
avrdude: reading calibration memory:
avrdude: writing output file "<stdout>"
:0100000099
```

The `99` is the calibration value (hex).

### Why It Matters:

**With external crystal (Arduino)**: Not used, chip uses precise 16 MHz crystal

**With internal RC (standalone AVR)**: 
```c
// MUST apply calibration for reliable serial communication
void setup() {
    OSCCAL = boot_signature_byte_get(0x0001);  // Apply factory cal
    Serial.begin(9600);  // Now accurate enough for UART
}
```

Without calibration:
```
9600 baud with 10% error:
  Actual: 8640 - 10560 baud
  Result: SERIAL COMMUNICATION FAILS!
```

With calibration:
```
9600 baud with 1% error:
  Actual: 9504 - 9696 baud
  Result: Works reliably
```

---

## Quick Comparison Table

| Feature | Lock Bits | Signature | Calibration |
|---------|-----------|-----------|-------------|
| **Size** | 1 byte | 3 bytes | 1 byte |
| **Writable?** | Yes (ISP) | No (factory) | No (factory) |
| **Purpose** | Security | Device ID | RC tuning |
| **Default** | 0x0F (unlocked) | 0x1E 0x95 0x0F | ~0x80 (varies) |
| **Read from code?** | Yes | Yes | Yes |
| **Changes after programming?** | Yes (if you set) | Never | Never |

---

## Complete Memory Map with All Special Areas

```
┌─────────────────────────────────────────┐
│ Flash Memory        0x0000 - 0x7FFF     │ 32KB
│   ├─ Application    0x0000 - 0x7DFF     │ 31.5KB
│   └─ Bootloader     0x7E00 - 0x7FFF     │ 512B
├─────────────────────────────────────────┤
│ SRAM               0x0100 - 0x08FF      │ 2KB
├─────────────────────────────────────────┤
│ EEPROM             0x000 - 0x3FF        │ 1KB
├─────────────────────────────────────────┤
│ Fuse Bits          (ISP address space)  │ 3 bytes
│   ├─ Low Fuse      0x00                 │ 0xFF
│   ├─ High Fuse     0x01                 │ 0xDE
│   └─ Extended Fuse 0x02                 │ 0xFD
├─────────────────────────────────────────┤
│ Lock Bits          (ISP address space)  │ 1 byte
│   └─ Lock Byte     0x00                 │ 0x0F
├─────────────────────────────────────────┤
│ Signature          (ISP address space)  │ 3 bytes
│   ├─ Manufacturer  0x00                 │ 0x1E (READ-ONLY)
│   ├─ Part Family   0x02                 │ 0x95 (READ-ONLY)
│   └─ Part Number   0x04                 │ 0x0F (READ-ONLY)
├─────────────────────────────────────────┤
│ Calibration        (ISP address space)  │ 1 byte
│   └─ OSCCAL Value  0x01                 │ varies (READ-ONLY)
└─────────────────────────────────────────┘
```

---

## Practical Example: Read All Special Bytes

```c
#include <avr/boot.h>

void print_chip_info() {
    Serial.println("=== ATmega328P Info ===");
    
    // Signature
    Serial.print("Signature: ");
    for (int i = 0; i < 3; i++) {
        uint8_t sig = boot_signature_byte_get(i * 2);
        if (sig < 0x10) Serial.print("0");
        Serial.print(sig, HEX);
        Serial.print(" ");
    }
    Serial.println();
    
    // Calibration
    uint8_t cal = boot_signature_byte_get(0x0001);
    Serial.print("Calibration: 0x");
    Serial.println(cal, HEX);
    
    // Fuses
    uint8_t lfuse = boot_lock_fuse_bits_get(GET_LOW_FUSE_BITS);
    uint8_t hfuse = boot_lock_fuse_bits_get(GET_HIGH_FUSE_BITS);
    uint8_t efuse = boot_lock_fuse_bits_get(GET_EXTENDED_FUSE_BITS);
    Serial.print("Fuses: L=0x");
    Serial.print(lfuse, HEX);
    Serial.print(" H=0x");
    Serial.print(hfuse, HEX);
    Serial.print(" E=0x");
    Serial.println(efuse, HEX);
    
    // Lock bits
    uint8_t lock = boot_lock_fuse_bits_get(GET_LOCK_BITS);
    Serial.print("Lock: 0x");
    Serial.println(lock, HEX);
    if (lock == 0x0F) {
        Serial.println("  Status: UNLOCKED (fully programmable)");
    } else {
        Serial.println("  Status: LOCKED (protected)");
    }
}
```

Output:
```
=== ATmega328P Info ===
Signature: 1E 95 0F 
Calibration: 0x99
Fuses: L=0xFF H=0xDE E=0xFD
Lock: 0x0F
  Status: UNLOCKED (fully programmable)
```

---

**Summary:**
- **LOCK**: Security (1 byte, writable, default 0x0F)
- **SIGNATURE**: Device ID (3 bytes, read-only, 0x1E 0x95 0x0F)
- **CALIBRATION**: RC tuning (1 byte, read-only, ~0x80-0x99 range)

All stored in **separate configuration memory**, not Flash/EEPROM/SRAM!