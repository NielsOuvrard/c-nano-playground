# Complete Linker Script Tutorial for ATmega328P

I'll create a comprehensive example with various memory sections, custom placements, and all the tools to verify everything.

---

## Project Structure

```
linker_tutorial/
├── main.c              (C program with various memory types)
├── custom.ld           (Custom linker script)
├── Makefile            (Build automation)
└── README.md           (This guide)
```

---

## Step 1: The C Program (main.c)---

## Step 2: Custom Linker Script (custom.ld)---

## Step 3: Makefile---

## Step 4: CLI Commands and Verification Guide---

## Quick Start Guide

### 1. Create Project Directory

```bash
mkdir linker_tutorial
cd linker_tutorial
```

### 2. Create Files

Copy the three artifacts above:
- `main.c` - The C program
- `custom.ld` - The linker script
- `Makefile` - Build automation

### 3. Build and Analyze

```bash
# Build everything
make

# View memory usage
make size

# Complete analysis
make analyze

# View symbols
make symbols

# View memory map
make memory
```

### 4. Expected Output

**After `make size`:**
```
==========================================
Memory Usage Summary
==========================================
AVR Memory Usage
----------------
Device: atmega328p

Program:    1456 bytes (4.5% Full)
(.text + .data + .bootloader)

Data:        704 bytes (34.4% Full)
(.data + .bss + .noinit)

section           size      addr
.text             1234         0
.data               40   8388864
.bss               152   8388904
.serial_buffers    256   8389056
.fixed_memory      256   8389312
.noinit              4   8389568
```

**Key Verifications:**

1. ✅ `.text` starts at address 0 (Flash)
2. ✅ `.data` at 0x800100 (SRAM start)
3. ✅ `.serial_buffers` at 0x800180 (our custom location!)
4. ✅ `.fixed_memory` at 0x800280 (256 bytes later)
5. ✅ Total usage within limits

---

## Understanding the Output

### Symbol Addresses

```bash
avr-nm -n linker_tutorial.elf | grep -A 5 "serial\|fixed"
```

You should see:
```
00800180 B serial_tx_buffer    ← At 0x0180 offset (384 in decimal)
00800200 B serial_rx_buffer    ← 128 bytes later
00800280 B fixed_buffer        ← At our fixed address!
```

This proves the linker script worked - variables are exactly where we told them to be!

---

## Troubleshooting

### If build fails with "undefined reference"

Add to linker script:
```ld
PROVIDE(__do_copy_data = 1);
PROVIDE(__do_clear_bss = 1);
```

### If sections aren't where expected

Check `avr-objdump -h` output and compare VMA addresses to your linker script ORIGIN values.

### If getting memory overflow

Reduce buffer sizes in `main.c` or adjust memory regions in `custom.ld`.

---

This complete tutorial gives you:
- ✅ Real C code using all memory types
- ✅ Custom linker script with organized memory
- ✅ Build automation with Makefile
- ✅ Complete verification commands
- ✅ Tools to inspect every aspect of the binary

Try it and experiment by modifying the memory regions in `custom.ld` - you'll see exactly how the linker places everything! 🎯