# Fuse Bits Technology

## Physical Implementation

Fuse bits are stored in **EEPROM-like cells**, but in a **physically separate** memory array from the user EEPROM.

```
Silicon Die Layout (simplified):

┌─────────────────────────────────────┐
│                                     │
│   ┌──────────┐    ┌──────────┐      │
│   │  FLASH   │    │   SRAM   │      │
│   │  Array   │    │  Array   │      │
│   └──────────┘    └──────────┘      │
│                                     │
│   ┌──────────┐    ┌──────────┐      │
│   │ EEPROM   │    │  FUSES   │ ← Separate area!
│   │  Array   │    │  Array   │      │
│   └──────────┘    └──────────┘      │
│                                     │
│   ┌──────────┐    ┌──────────┐      │
│   │   CPU    │    │   I/O    │      │
│   │   Core   │    │  Ports   │      │
│   └──────────┘    └──────────┘      │
│                                     │
└─────────────────────────────────────┘
```

### Why Separate?

1. **Read before boot**: Fuses must be readable **before** any other memory initializes
2. **Hardware configuration**: Control clock source, reset behavior (needed at power-on)
3. **Security**: Isolated from application access
4. **Write protection**: Special programming voltage/protocol required

---

## How Fuses Are Read by the Chip

### Power-On Sequence:

```
Power Applied (VCC rises)
         ↓
   Power-On Reset Circuit
         ↓
   Read FUSE BITS from configuration memory
         ↓
   Configure hardware based on fuses:
     ├─ Set clock source (CKSEL)
     ├─ Set clock divider (CKDIV8)
     ├─ Enable brown-out detector (BODLEVEL)
     ├─ Determine reset vector (BOOTRST)
     └─ Configure RESET pin (RSTDISBL)
         ↓
   Start executing code
     ├─ If BOOTRST=0 → Jump to bootloader
     └─ If BOOTRST=1 → Jump to 0x0000
```

---

## Accessing Fuses from Software

### You Can Read Fuses Using Special Instructions:

```c
#include <avr/boot.h>

uint8_t read_low_fuse() {
    return boot_lock_fuse_bits_get(GET_LOW_FUSE_BITS);
}

uint8_t read_high_fuse() {
    return boot_lock_fuse_bits_get(GET_HIGH_FUSE_BITS);
}

uint8_t read_extended_fuse() {
    return boot_lock_fuse_bits_get(GET_EXTENDED_FUSE_BITS);
}

void setup() {
    Serial.begin(115200);
    Serial.print("Low Fuse: 0x");
    Serial.println(read_low_fuse(), HEX);
    Serial.print("High Fuse: 0x");
    Serial.println(read_high_fuse(), HEX);
    Serial.print("Extended Fuse: 0x");
    Serial.println(read_extended_fuse(), HEX);
}
```

## How Are Fuses Programmed?

### Method 1: ISP Programming (AVRISP mkII)

When you use a programmer, it uses **Serial Peripheral Interface** with special commands:

```
Programmer Command Sequence:

1. Enter Programming Mode:
   - Pull RESET low
   - Send: 0xAC 0x53 0x00 0x00
   - Chip responds: 0x53 (sync)

2. Read Low Fuse:
   - Send: 0x50 0x00 0x00 0x00
   - Chip responds: [low_fuse_value]

3. Write Low Fuse:
   - Send: 0xAC 0xA0 0x00 [new_value]
   - Wait 4.5ms for write

4. Leave Programming Mode:
   - Pull RESET high
```

---

## Fuse Bits: Physical Storage Technology

### EEPROM-Like Cells

Fuse bits use **floating-gate technology** similar to EEPROM:

```
Single Fuse Bit Cell (cross-section):

         Control Gate
              │
    ┌─────────┴─────────┐
    │  Floating Gate    │ ← Stores charge
    │   (insulated)     │
    └─────────┬─────────┘
              │
         Oxide Layer (insulator)
              │
    ┌─────────┴──────────┐
    │   Silicon Channel  │
    └────────────────────┘
         │         │
       Source    Drain

Programmed (0): Floating gate HAS charge → bit reads as 0
Unprogrammed (1): Floating gate NO charge → bit reads as 1
```

### Programming Process:

```
Write Fuse Bit = 0 (programmed):
  1. Apply high voltage (~12V) to control gate
  2. Electrons tunnel through oxide into floating gate
  3. Charge trapped for decades
  
Erase Fuse Bit = 1 (unprogrammed):
  1. Apply high voltage with opposite polarity
  2. Electrons tunnel OUT of floating gate
  3. Floating gate becomes neutral
```

### Retention:

- **Data retention**: 20+ years at room temperature
- **Write endurance**: ~100,000 cycles (but you rarely change fuses!)
- **Read endurance**: Unlimited (reading doesn't wear them out)

---

## Comparison Table: Where Different Data Lives

| Data Type | Storage | Volatile? | Size | Access Method | Speed |
|-----------|---------|-----------|------|---------------|-------|
| **Program code** | Flash | No | 32KB | PC, LPM | Fast |
| **Variables** | SRAM | Yes | 2KB | LD/ST | Very Fast |
| **Saved data** | EEPROM | No | 1KB | EEAR/EEDR | Slow |
| **Fuse bits** | Config Memory | No | 3 bytes | ISP only | N/A |
| **Lock bits** | Config Memory | No | 1 byte | ISP only | N/A |
| **Signature** | Factory ROM | No | 3 bytes | ISP only | N/A |
| **Cal byte** | Factory ROM | No | 1 byte | ISP only | N/A |

---

## Reading Signature and Calibration

### Signature Bytes (Device ID):

```c
#include <avr/boot.h>

void read_signature() {
    uint8_t sig0 = boot_signature_byte_get(0x0000);  // 0x1E
    uint8_t sig1 = boot_signature_byte_get(0x0002);  // 0x95
    uint8_t sig2 = boot_signature_byte_get(0x0004);  // 0x0F
    
    Serial.print("Device: ");
    Serial.print(sig0, HEX);
    Serial.print(" ");
    Serial.print(sig1, HEX);
    Serial.print(" ");
    Serial.println(sig2, HEX);
    // Prints: "Device: 1E 95 0F" = ATmega328P
}
```

### Calibration Byte (RC Oscillator):

```c
uint8_t read_calibration() {
    return boot_signature_byte_get(0x0001);
}

void apply_calibration() {
    OSCCAL = read_calibration();  // Tune internal RC oscillator
}
```

---

## Summary

**About fuse bits**

✅ **Separate configuration memory** (not Flash, EEPROM, or SRAM)  
✅ **EEPROM-like floating-gate cells** on the same silicon die  
✅ **Read at power-on** before any code executes  
✅ **Configure hardware** (clock, reset, brown-out)  
✅ **Only writable via ISP** (not from running program)  
✅ **3 bytes total** (Low, High, Extended fuses)  
✅ **Persistent** across power cycles (non-volatile)  
✅ **100,000+ write cycles** (but you rarely change them)  

The chip essentially has **7 separate memory systems**:
1. Flash (code)
2. SRAM (runtime)
3. EEPROM (saved data)
4. **Fuse memory** (configuration)
5. **Lock bits** (security)
6. **Signature bytes** (device ID, read-only)
7. **Calibration byte** (factory tuning, read-only)
