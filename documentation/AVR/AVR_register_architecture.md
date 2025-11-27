# AVR Register Architecture

## General Purpose Registers (32 registers)

| Register Range | Purpose | Special Instructions |
|----------------|---------|---------------------|
| **r0 - r15** | General purpose use | Most instructions |
| **r16 - r31** | General purpose use | Can use `ldi` (load immediate) |
| **r26-r27** | **X pointer register** (XL:XH) | Indirect addressing |
| **r28-r29** | **Y pointer register** (YL:YH) | Indirect with displacement |
| **r30-r31** | **Z pointer register** (ZL:ZH) | Program memory access |

## Special Function Registers

| Register | Name | Purpose | Bits |
|----------|------|---------|------|
| **SREG** | Status Register | Processor flags | C Z N V S H T I |
| **SP** | Stack Pointer | SPH:SPL - points to top of stack | 16-bit |
| **PC** | Program Counter | Points to next instruction | 22-bit (megaAVR) |

## Status Register (SREG) Flags

| Flag | Bit | Meaning |
|------|-----|---------|
| **C** | 0 | Carry Flag |
| **Z** | 1 | Zero Flag |
| **N** | 2 | Negative Flag |
| **V** | 3 | Two's Complement Overflow |
| **S** | 4 | N ⊕ V - Sign Flag |
| **H** | 5 | Half Carry Flag |
| **T** | 6 | Transfer Bit |
| **I** | 7 | Global Interrupt Enable |

## Pointer Registers Detail

| Register | Low Byte | High Byte | Primary Use |
|----------|----------|-----------|-------------|
| **X** | r26 (XL) | r27 (XH) | General pointer, stack frame |
| **Y** | r28 (YL) | r29 (YH) | Pointer with displacement |
| **Z** | r30 (ZL) | r31 (ZH) | Program memory, ELPM/SPM |

## Key Features:
- **8-bit architecture** with 32 general purpose registers
- **Pointer registers** are dedicated pairs within the register file
- **Limited register addressing**: Many instructions only work with r16-r31
- **Memory-mapped I/O**: All peripherals accessed via register addresses