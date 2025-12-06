# Static Buffer Partitioning for ATmega328P

## Overview

This document describes the static buffer partitioning system implemented in `minimum.ld` for the ATmega328P microcontroller. The traditional heap-based dynamic memory allocation has been replaced with **strictly-sized static buffer sections** to provide predictable memory usage and prevent runtime memory allocation errors.

## Motivation

### Why Remove the Heap?

1. **Deterministic Memory Usage**: Static buffers eliminate unpredictable heap fragmentation
2. **No Runtime Allocation Failures**: Memory layout is known at compile/link time
3. **Embedded System Best Practice**: Avoid `malloc()`/`free()` in resource-constrained systems
4. **Stack Overflow Protection**: Clear boundaries prevent stack-heap collisions
5. **Compile-Time Verification**: Linker asserts catch memory overflows before deployment

## Memory Layout

### ATmega328P SRAM: 2048 bytes (0x800100 - 0x8008FF)

The 2KB SRAM is partitioned into the following regions:

```
┌─────────────────────────────────────────┐ 0x800100
│  .buffer_128 (128 bytes)                │
├─────────────────────────────────────────┤ 0x800180
│  .buffer_256 (256 bytes)                │
├─────────────────────────────────────────┤ 0x800280
│  .buffer_640 (640 bytes)                │
├─────────────────────────────────────────┤ 0x800500
│  .data (initialized variables)          │
│  .bss (uninitialized variables)         │
│  .noinit (no-init variables)            │
├─────────────────────────────────────────┤ Variable (after .noinit)
│                                         │
│  Stack (grows downward)                 │
│                                         │
└─────────────────────────────────────────┘ 0x8008FF
```

### Buffer Partitioning Strategy

Three fixed-size buffer sections are defined at the start of SRAM:

| Buffer Section       | Size          | Memory Range        | Purpose                         |
| -------------------- | ------------- | ------------------- | ------------------------------- |
| `.buffer_128`        | 128 bytes     | 0x800100 - 0x80017F | Small temporary operations      |
| `.buffer_256`        | 256 bytes     | 0x800180 - 0x80027F | Medium data processing          |
| `.buffer_640`        | 640 bytes     | 0x800280 - 0x8004FF | Large buffers (UART, SPI, etc.) |
| `.data/.bss/.noinit` | Variable size | 0x800500 - 0x800??? | Global/static variables         |
| `stack`              | Variable size | 0x800??? - 0x8008FF | Function call stack             |

**Data sections** (.data, .bss, .noinit) follow immediately after at 0x800500.

### Stack Region

- **Stack Pointer**: Initialized to `0x8008FF` (top of SRAM)
- **Stack Growth**: Downward (decreasing addresses)
- **Available Stack Space**: Depends on buffer + data section usage

## Linker Script Implementation

### Memory Regions Definition

```ld
MEMORY
{
  text        (rx)   : ORIGIN = 0x000000, LENGTH = 32K
  eeprom      (rw!x) : ORIGIN = 0x810000, LENGTH = 1K

  /* Static buffer partitions - strict memory boundaries (buffers first) */
  buffer_128  (rw!x) : ORIGIN = 0x800100, LENGTH = 128
  buffer_256  (rw!x) : ORIGIN = 0x800180, LENGTH = 256
  buffer_640  (rw!x) : ORIGIN = 0x800280, LENGTH = 640

  /* Data section follows buffers */
  data        (rw!x) : ORIGIN = 0x800500, LENGTH = 0x4A0
}
```

### Buffer Sections with Assertions

Each buffer section includes:

1. **Start/End Symbols**: `__buffer_<size>_start` and `__buffer_<size>_end`
2. **Strict Sizing**: Forces exact allocation of the defined length
3. **NOLOAD Attribute**: Prevents initialization (BSS-like behavior)
4. **Compile-Time Assertions**: Linker fails if section exceeds its limit

Example for `.buffer_128`:

```ld
.buffer_128 (NOLOAD) :
{
  PROVIDE(__buffer_128_start = .);
  *(.buffer_128)
  *(.buffer_128*)
  . = ORIGIN(buffer_128) + LENGTH(buffer_128);
  PROVIDE(__buffer_128_end = .);
} > buffer_128

ASSERT(SIZEOF(.buffer_128) <= 128, "ERROR: .buffer_128 exceeds 128 bytes")
```

### Removed Symbols

- **`__heap_start`**: No longer provided (heap removed)
- Dynamic memory allocation functions (`malloc`, `free`) should not be used

## Usage in C Code

### Declaring Buffers in Specific Sections

Use GCC's `__attribute__` to place buffers in specific sections:

```c
// 128-byte buffer
uint8_t uart_rx_buffer[128] __attribute__((section(".buffer_128")));

// 256-byte buffer
char string_buffer[256] __attribute__((section(".buffer_256")));

// 640-byte buffer
uint8_t spi_transfer_buffer[640] __attribute__((section(".buffer_640")));
```

### Accessing Buffer Boundaries (Optional)

You can reference the linker symbols to check buffer sizes at runtime:

```c
extern uint8_t __buffer_128_start;
extern uint8_t __buffer_128_end;

// Calculate buffer size
size_t buffer_128_size = (size_t)(&__buffer_128_end - &__buffer_128_start);
```

### Example Application Code

```c
#include <stdint.h>
#include <string.h>

// Define buffers in specific sections
uint8_t temp_buffer[128] __attribute__((section(".buffer_128")));
char message_queue[256] __attribute__((section(".buffer_256")));
uint8_t data_cache[640] __attribute__((section(".buffer_640")));

void process_data(void) {
    // Use buffers directly - no malloc needed
    memset(temp_buffer, 0, sizeof(temp_buffer));
    strcpy(message_queue, "Hello from static buffers!");

    // Process data using pre-allocated buffers
    for (int i = 0; i < sizeof(data_cache); i++) {
        data_cache[i] = i & 0xFF;
    }
}

int main(void) {
    process_data();
    while(1);
    return 0;
}
```

## Compile-Time Verification

### Linker Assertions

The linker will **fail** if any buffer section exceeds its allocated size:

```
ld: ERROR: .buffer_128 exceeds 128 bytes
```

This prevents accidental memory overflow at compile time.

### Checking Section Sizes

After compilation, verify section sizes using:

```bash
avr-size -A your_program.elf | grep buffer
```

Example output:

```
.buffer_128          100         0
.buffer_256          250         0
.buffer_640          600         0
```

## Best Practices

### 1. Size Buffers Appropriately

- **128-byte Buffer**: Temporary calculations, small strings, status flags
- **256-byte Buffer**: Command parsing, medium data processing
- **640-byte Buffer**: Communication buffers (UART, SPI, I2C), sensor data arrays

### 2. Avoid Buffer Overflow

Even though sections are strictly sized, ensure your code doesn't write beyond array bounds:

```c
// GOOD: Respects array bounds
uint8_t buf[100] __attribute__((section(".buffer_128")));
memset(buf, 0, sizeof(buf));  // Safe

// BAD: Could overflow
memset(buf, 0, 128);  // Dangerous if buf is smaller!
```

### 3. Monitor Stack Usage

Calculate remaining stack space:

```
Stack Space = 0x8008FF - (data_section_end)
            = Depends on size of .data, .bss, and .noinit sections
```

Buffers are now placed first (0x800100 - 0x8004FF), followed by data sections.

### 4. Adjust Buffer Sizes as Needed

If your application needs different buffer sizes, modify the `MEMORY` section in `minimum.ld`:

```ld
buffer_128  (rw!x) : ORIGIN = 0x800100, LENGTH = 192   /* Increased */
buffer_256  (rw!x) : ORIGIN = 0x8001C0, LENGTH = 256   /* Same */
buffer_640  (rw!x) : ORIGIN = 0x8002C0, LENGTH = 512   /* Decreased */
```

**Important**: Ensure origins don't overlap and adjust data section origin accordingly.

## Memory Layout Visualization

```
FLASH (32KB)                    SRAM (2KB)
┌────────────────┐              ┌────────────────────────┐ 0x800100
│ .text          │              │ .buffer_128 (128B)     │
│ .rodata        │              ├────────────────────────┤ 0x800180
│ .init*         │              │ .buffer_256 (256B)     │
│ .fini*         │              ├────────────────────────┤ 0x800280
│                │              │ .buffer_640 (640B)     │
│                │              ├────────────────────────┤ 0x800500
│                │              │ .data (initialized)    │
│                │              │ .bss (zero-init)       │
│                │              │ .noinit (no-init)      │
│                │              ├────────────────────────┤
│                │              │        ↕               │
│                │              │   Free Space/Stack     │
│                │              │        ↕               │
└────────────────┘              │ Stack (grows downward) │
                                └────────────────────────┘ 0x8008FF

EEPROM (1KB)
┌────────────────┐
│ .eeprom        │
└────────────────┘
```

## Troubleshooting

### Error: Buffer Section Exceeds Size

**Problem**:

```
ld: ERROR: .buffer_256 exceeds 256 bytes
```

**Solution**:

- Reduce buffer sizes in your code, OR
- Increase the buffer section size in `minimum.ld`

### Undefined Reference to `malloc`/`free`

**Problem**: Code tries to use dynamic memory allocation

**Solution**: Replace with static buffers:

```c
// OLD (don't use)
uint8_t *buf = malloc(256);
free(buf);

// NEW (use this)
uint8_t buf[256] __attribute__((section(".buffer_256")));
```

### Stack Overflow

**Problem**: Program crashes or behaves erratically

**Solution**:

- Reduce buffer sizes to free more stack space
- Reduce function call depth / local variable usage
- Monitor stack usage with debugger

## Advanced Configuration

### Dynamic Origin Calculation

With buffers placed first in SRAM, the data section origin is fixed at 0x800500 (after all buffers). This provides:

- **Predictable buffer addresses**: Always start at 0x800100
- **Fixed data section start**: Always at 0x800500
- **No dependency on data section size** for buffer placement

### Multiple Buffer Pools

For more granular control, create additional buffer sections:

```ld
buffer_uart   (rw!x) : ORIGIN = 0x800100, LENGTH = 256
buffer_spi    (rw!x) : ORIGIN = 0x800200, LENGTH = 256
buffer_i2c    (rw!x) : ORIGIN = 0x800300, LENGTH = 256
buffer_temp   (rw!x) : ORIGIN = 0x800400, LENGTH = 256
data          (rw!x) : ORIGIN = 0x800500, LENGTH = 0x4A0
```

## Summary

The static buffer partitioning system provides:

✅ **Predictable memory usage** - No heap fragmentation  
✅ **Compile-time verification** - Linker catches overflows  
✅ **Three fixed-size pools** - 128B, 256B, 640B (total: 1024 bytes)  
✅ **Buffers-first layout** - Fixed addresses starting at 0x800100  
✅ **Stack protection** - Clear boundaries prevent collisions  
✅ **Embedded-friendly** - No dynamic allocation overhead

By removing `__heap_start` and using strictly-sized buffer sections placed first in SRAM, you gain deterministic memory behavior critical for reliable embedded systems.

## References

- [ATmega328P Datasheet](https://ww1.microchip.com/downloads/en/DeviceDoc/Atmel-7810-Automotive-Microcontrollers-ATmega328P_Datasheet.pdf)
- [GNU LD Linker Scripts](https://sourceware.org/binutils/docs/ld/Scripts.html)
- [AVR-GCC Memory Sections](https://gcc.gnu.org/wiki/avr-gcc)
