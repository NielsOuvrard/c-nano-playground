# Linker Script Verification Guide

## Quick Start

```bash
# 1. Build project
make

# 2. Run complete analysis
make analyze

# 3. View specific details
make symbols
make sections
make memory
```

---

## Command Reference

### 1. Basic Memory Usage

```bash
# Quick summary (Flash + SRAM usage)
avr-size -C --mcu=atmega328p linker_tutorial.elf
```

**Output:**
```
AVR Memory Usage
----------------
Device: atmega328p

Program:    2048 bytes (6.3% Full)
(.text + .data + .bootloader)

Data:        512 bytes (25.0% Full)
(.data + .bss + .noinit)
```

**What to look for:**
- Program < 32256 bytes (31.5KB with bootloader reserved)
- Data < 2048 bytes (2KB SRAM)

---

### 2. Detailed Section Sizes

```bash
# Show all sections with sizes
avr-size -A linker_tutorial.elf
```

**Output:**
```
linker_tutorial.elf  :
section           size      addr
.text             1234         0
.data               64   8388864  (0x800100)
.bss               192   8388928  (0x800140)
.serial_buffers    256   8388992  (0x800180)
.fixed_memory      256   8389248  (0x800280)
.noinit              4   8389504  (0x800380)
.eeprom             34   8519680  (0x810000)
.comment            17         0
.debug_info        500         0
Total             2557
```

**What to check:**
- `.text` = your code in Flash
- `.data` = initialized variables (stored in Flash, copied to SRAM)
- `.bss` = uninitialized variables (only SRAM)
- `.serial_buffers` = at 0x800180 (matches linker script!)
- `.fixed_memory` = at 0x800280 (matches linker script!)
- `.noinit` = persistent variables
- `.eeprom` = EEPROM data

---

### 3. Section Headers (addresses and flags)

```bash
# Show section locations and attributes
avr-objdump -h linker_tutorial.elf
```

**Output:**
```
Sections:
Idx Name              Size      VMA       LMA       File off  Algn
  0 .text             000004d2  00000000  00000000  00000054  2**1
                      CONTENTS, ALLOC, LOAD, READONLY, CODE
  1 .data             00000040  00800100  000004d2  00000526  2**0
                      CONTENTS, ALLOC, LOAD, DATA
  2 .bss              000000c0  00800140  00000512  00000566  2**0
                      ALLOC
  3 .serial_buffers   00000100  00800180  00800180  00000566  2**0
                      ALLOC
  4 .fixed_memory     00000100  00800280  00800280  00000566  2**0
                      ALLOC
```

**Key columns:**
- **VMA** (Virtual Memory Address): Where it runs (SRAM address)
- **LMA** (Load Memory Address): Where it's stored (Flash address)
- **Size**: Section size in bytes
- **Flags**:
  - `CONTENTS` = has data in file
  - `ALLOC` = occupies memory
  - `LOAD` = loaded to chip
  - `READONLY` = can't be modified
  - `CODE` = executable code

**What to verify:**
- `.text` VMA = 0x0000 (Flash start)
- `.data` VMA = 0x800100 (SRAM start)
- `.data` LMA = after .text (initial values in Flash)
- `.serial_buffers` VMA = 0x800180 (our custom location!)
- `.fixed_memory` VMA = 0x800280 (our fixed address!)

---

### 4. All Symbols (variables and functions)

```bash
# List all symbols sorted by address
avr-nm -n linker_tutorial.elf
```

**Output:**
```
00000000 T __vectors
00000068 T __ctors_end
00000068 T __ctors_start
00000068 T __dtors_end
00000068 T __dtors_start
00000068 T __init
000000a4 T critical_function
000001c2 T main
00800100 D global_counter
00800104 D global_string
00800110 D global_array
00800140 B uninitialized_value
00800144 B uninitialized_buffer
00800180 B serial_tx_buffer
00800200 B serial_rx_buffer
00800280 B fixed_buffer
00800380 N reset_counter
00800382 N persistent_value
```

**Symbol types:**
- **T** = Text (code in Flash)
- **D** = Data (initialized, in SRAM)
- **B** = BSS (uninitialized, in SRAM)
- **N** = .noinit (persistent)
- **R** = Read-only data (Flash)

**Verify:**
- `critical_function` is in Flash (.text)
- `global_counter` at 0x800100 (start of .data)
- `serial_tx_buffer` at 0x800180 (our serial region!)
- `fixed_buffer` at 0x800280 (our fixed region!)
- `reset_counter` is in .noinit

---

### 5. Memory Map File Analysis

```bash
# View complete memory map
cat linker_tutorial.map
```

**Look for these sections:**

#### Memory Configuration
```
Memory Configuration

Name             Origin             Length             Attributes
text             0x0000000000000000 0x0000000000007e00 xr
bootloader       0x0000000000007e00 0x0000000000000200 xr
sys_vars         0x0000000000800100 0x0000000000000080 rw !x
serial_buf       0x0000000000800180 0x0000000000000100 rw !x
fixed_mem        0x0000000000800280 0x0000000000000100 rw !x
app_data         0x0000000000800380 0x0000000000000380 rw !x
stack_area       0x0000000000800700 0x0000000000000200 rw !x
```

**Verify:** All regions match your linker script!

#### Cross Reference Table
```
Symbol                              File
__bss_end                           linker_tutorial.elf
__bss_start                         linker_tutorial.elf
__data_end                          linker_tutorial.elf
__data_start                        linker_tutorial.elf
__serial_start                      linker_tutorial.elf
__serial_end                        linker_tutorial.elf
critical_function                   main.o
global_counter                      main.o
```

---

### 6. Disassembly (view actual assembly code)

```bash
# Show disassembled code with C source interleaved
avr-objdump -S linker_tutorial.elf > disassembly.txt
```

**View specific function:**
```bash
avr-objdump -S linker_tutorial.elf | grep -A 20 "critical_function"
```

**Output:**
```asm
000000a4 <critical_function>:
  a4:   25 9a           sbi     0x04, 5    ; Turn on LED (PORTB |= (1<<PB5))
  a6:   08 95           ret
```

**What this shows:**
- Function starts at address 0x00A4 (Flash)
- Takes only 4 bytes (very small!)
- Actual assembly instructions

---

### 7. Verify Custom Section Placement

```bash
# Check if symbols are at expected addresses
avr-nm linker_tutorial.elf | grep -E "serial|fixed|__serial|__fixed"
```

**Output:**
```
00800180 B serial_tx_buffer
00800200 B serial_rx_buffer
00800280 B fixed_buffer
00800180 A __serial_start
00800280 A __serial_end
00800280 A __fixed_start
00800380 A __fixed_end
```

**Verify:**
- `__serial_start` = 0x800180 ✓
- `__serial_end` = 0x800280 ✓ (256 bytes later)
- `__fixed_start` = 0x800280 ✓
- `__fixed_end` = 0x800380 ✓ (256 bytes later)

---

### 8. Check Stack and Heap Addresses

```bash
# Find stack and heap symbols
avr-nm linker_tutorial.elf | grep -E "stack|heap"
```

**Output:**
```
00800380 A __heap_start
00800700 A __heap_end
00800700 A __stack_start
00800900 A __stack_end
00800900 A __stack
```

**Verify:**
- Heap: 0x800380 - 0x800700 (896 bytes available)
- Stack: 0x800700 - 0x800900 (512 bytes)
- No overlap!

---

### 9. Intel HEX File Inspection

```bash
# View hex file structure
cat linker_tutorial.hex | head -20
```

**Output:**
```
:100000000C945D000C9485000C9485000C94850084
:100010000C9485000C9485000C9485000C9485004C
:100020000C9485000C9485000C9485000C9485003C
:100030000C9485000C9485000C9485000C9485002C
...
```

**Format:** `:LLAAAATT[DD...]CC`
- LL = byte count
- AAAA = address
- TT = record type (00=data, 01=EOF)
- DD = data bytes
- CC = checksum

---

### 10. Compare .data Flash vs SRAM Addresses

```bash
# Show .data section details
avr-objdump -h linker_tutorial.elf | grep -A 1 "\.data"
```

**Output:**
```
  1 .data         00000040  00800100  000004d2  00000526  2**0
                  CONTENTS, ALLOC, LOAD, DATA
```

**Meaning:**
- Size: 0x40 (64 bytes)
- VMA: 0x800100 (runs in SRAM)
- LMA: 0x4D2 (stored in Flash after .text)
- Startup code copies from 0x4D2 (Flash) → 0x800100 (SRAM)

---

### 11. Check for Warnings/Errors

```bash
# Rebuild with verbose output
make clean
make 2>&1 | tee build.log
```

**Look for:**
- ❌ "section will not fit in region"
- ❌ "region overflowed by"
- ✅ No warnings = good!

---

### 12. Calculate Actual Memory Usage

```bash
# Calculate total SRAM used
avr-nm linker_tutorial.elf | awk '
  /__data_start/ {data_start = strtonum("0x"$1)}
  /__bss_end/ {bss_end = strtonum("0x"$1)}
  END {
    sram_start = 0x800100
    used = bss_end - sram_start
    total = 2048
    free = total - used
    printf "SRAM Used: %d bytes (%.1f%%)\n", used, used*100/total
    printf "SRAM Free: %d bytes (%.1f%%)\n", free, free*100/total
  }
'
```

---

### 13. Verify Linker Script Assertions

Assertions are checked at link time. If they fail:

```
/opt/homebrew/bin/../lib/gcc/avr/14.2.0/../../../../avr/bin/ld: 
  custom.ld:248: assertion failed: Code overflows into bootloader region!
```

**If no errors = all assertions passed!**

---

## Complete Verification Workflow

```bash
# Step 1: Build
make clean
make

# Step 2: Basic check
make size

# Step 3: Verify sections are where expected
avr-nm -n linker_tutorial.elf | grep -E "serial|fixed|__heap|__stack"

# Step 4: Check memory map
grep "Memory Configuration" -A 20 linker_tutorial.map

# Step 5: Verify no overflow
avr-size -C --mcu=atmega328p linker_tutorial.elf

# Step 6: View disassembly of critical function
avr-objdump -d linker_tutorial.elf | grep -A 10 "critical_function"

# Step 7: Full analysis report
make analyze > analysis_report.txt
cat analysis_report.txt
```

---

## What Success Looks Like

✅ **Program fits in Flash:** < 31.5KB  
✅ **Data fits in SRAM:** < 2KB  
✅ **Custom sections at expected addresses:**
   - `serial_tx_buffer` @ 0x800180
   - `fixed_buffer` @ 0x800280  
✅ **No overlap:** heap_start < heap_end  
✅ **Stack has space:** 512 bytes reserved  
✅ **No linker errors or warnings**

---

## Common Issues and Solutions

### Issue: "section will not fit in region"
**Solution:** Reduce variable sizes or optimize code with `-Os`

### Issue: Heap/Stack collision
**Solution:** Reduce buffer sizes or increase stack_area

### Issue: Custom section not at expected address
**Solution:** Check MEMORY region definitions in linker script

### Issue: Undefined reference to `__heap_start`
**Solution:** Ensure linker script defines the symbol

---

## Advanced: Visual Memory Map

Create a visual representation:

```bash
# Generate memory usage chart
avr-nm -n linker_tutorial.elf | awk '
BEGIN {
  print "Address  | Symbol"
  print "---------|------------------------"
}
/^008/ {
  addr = strtonum("0x"$1)
  printf "0x%06X | %s %s\n", addr, $2, $3
}
' | head -30
```

This shows you exactly where everything is in memory!
