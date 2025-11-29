# ATmega328P Memory Map (Complete):

```
┌─────────────────────────────────────┐
│  FLASH MEMORY (Program)             │  0x0000 - 0x7FFF (32KB)
│  - Your code                        │
│  - Bootloader                       │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  SRAM (Volatile)                    │  0x0100 - 0x08FF (2KB)
│  - Runtime variables                │
│  - Stack / Heap                     │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  EEPROM (Non-volatile)              │  0x000 - 0x3FF (1KB)
│  - User data storage                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  FUSE BITS (Configuration Memory)   │  3 bytes (separate space!)
│  - Low Fuse:      1 byte            │
│  - High Fuse:     1 byte            │
│  - Extended Fuse: 1 byte            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  LOCK BITS (Security Memory)        │  1 byte (separate space!)
│  - Memory protection                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  SIGNATURE BYTES (Factory ROM)      │  3 bytes (read-only!)
│  - 0x1E, 0x95, 0x0F (ATmega328P ID) │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│  CALIBRATION BYTE (Factory)         │  1 byte (factory calibrated)
│  - RC oscillator calibration        │
└─────────────────────────────────────┘
```

## Memory Address Space (Detailed)

The ATmega328P has **multiple address spaces** that don't overlap:

### 1. Program Memory Space (Flash)
```
Address bus: 14 bits (0x0000 - 0x3FFF words = 0x0000 - 0x7FFF bytes)
Access: Program Counter (PC), LPM instruction
```

### 2. Data Memory Space (SRAM)
```
Address bus: 11 bits (0x0000 - 0x08FF)
Includes:
  0x0000 - 0x001F: Registers R0-R31
  0x0020 - 0x005F: I/O registers
  0x0060 - 0x00FF: Extended I/O
  0x0100 - 0x08FF: SRAM (2KB)
Access: LD/ST instructions, stack pointer
```

### 3. EEPROM Space
```
Address bus: 10 bits (0x000 - 0x3FF)
Access: EEPROM registers (EEAR, EEDR, EECR)
```

### 4. Configuration Memory Space (Fuses)
```
NOT in normal address space!
Access: Only via ISP programming protocol
Addresses (logical, for programmer):
  Low Fuse:      Address 0
  High Fuse:     Address 1  
  Extended Fuse: Address 2
Physical location: Special memory cells
```

### 5. Signature Memory (Read-Only)
```
NOT in normal address space!
Access: Only via ISP programming protocol
Contains:
  Byte 0: 0x1E (Atmel manufacturer code)
  Byte 1: 0x95 (Part family)
  Byte 2: 0x0F (Part-specific)
```

---

## Visualizing Memory Spaces

```
┌─────────────────────────────────────────────────┐
│          ATmega328P Address Spaces              │
├─────────────────────────────────────────────────┤
│                                                 │
│  Program Space (PC + LPM instruction)           │
│  ┌───────────────────────────┐                  │
│  │ Flash: 0x0000 - 0x7FFF    │ ← 32KB           │
│  └───────────────────────────┘                  │
│                                                 │
│  Data Space (LD/ST instructions)                │
│  ┌───────────────────────────┐                  │
│  │ Registers: 0x00 - 0x1F    │ ← 32 bytes       │
│  │ I/O:       0x20 - 0x5F    │ ← 64 bytes       │
│  │ Ext I/O:   0x60 - 0xFF    │ ← 160 bytes      │
│  │ SRAM:      0x100 - 0x8FF  │ ← 2KB            │
│  └───────────────────────────┘                  │
│                                                 │
│  EEPROM Space (EEPROM registers)                │
│  ┌───────────────────────────┐                  │
│  │ EEPROM: 0x000 - 0x3FF     │ ← 1KB            │
│  └───────────────────────────┘                  │
│                                                 │
│  Configuration Space (ISP only!)                │
│  ┌───────────────────────────┐                  │
│  │ Fuses:    3 bytes         │ ← Special!       │
│  │ Lock:     1 byte          │ ← Special!       │
│  │ Signature: 3 bytes (ROM)  │ ← Read-only!     │
│  │ Calibration: 1 byte (ROM) │ ← Factory set!   │
│  └───────────────────────────┘                  │
│                                                 │
└─────────────────────────────────────────────────┘
```
