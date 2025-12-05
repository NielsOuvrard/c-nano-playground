# Your ATmega328P Memory Architecture

Let me break down everything about memory on your Arduino Nano (ATmega328P with 0.5KB bootloader):

## Flash Memory (Program Storage) - 32KB
- **Type**: NOR Flash (not NAND)
- **Size**: 32KB total, ~31.5KB available (after bootloader, 0.5KB used)
- **Purpose**: Stores your compiled program
- **Persistence**: Yes, survives power loss
- **Write cycles**: ~10,000 cycles
- **Access**: Read-only during execution (can't self-modify easily)

## EEPROM - 1KB
- **Type**: Electrically Erasable Programmable ROM
- **Size**: 1024 bytes
- **Purpose**: Persistent data storage (settings, calibration values, etc.)
- **Persistence**: Yes, survives power loss
- **Write cycles**: ~100,000 cycles
- **Access**: Via `EEPROM.h` library - slower than SRAM

## SRAM (Volatile Memory) - 2KB
This is where your heap and stack live:

- **Size**: 2048 bytes total
- **Persistence**: No - lost on power down
- **Purpose**: Runtime variables, function calls, dynamic allocation
- **Fast**: Directly accessible

### Stack (grows downward from high memory)
- Local variables
- Function parameters
- Return addresses
- Grows automatically with function calls

### Heap (grows upward from low memory)
- Dynamic allocations (`malloc()`, `new`)
- String objects
- Grows on demand

**Critical**: When stack and heap collide = **CRASH**

## Can You Manually Handle Buffer Sizes?

**Absolutely yes!** Here are your options:

### 1. **Static Allocation (Compile-time)**
```cpp
char buffer[128];           // Stack-allocated
uint8_t dataBuffer[256];    // Known size, fast
```

### 2. **Dynamic Allocation (Runtime)**
```cpp
char* buffer = (char*)malloc(128);
// Use it...
free(buffer);  // Always free!
```

### 3. **Global/Static (Outside functions)**
```cpp
static uint8_t bigBuffer[512];  // Won't use stack
```

### 4. **PROGMEM (Store in Flash)**
```cpp
const char text[] PROGMEM = "This lives in Flash, not SRAM!";
// Read with pgm_read_byte() or similar
```

## Practical Memory Management Tips

**Check available SRAM at runtime:**
```cpp
int freeRam() {
  extern int __heap_start, *__brkval;
  int v;
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval);
}
```

**Best practices for 2KB SRAM:**
- Avoid `String` class (uses heap unpredictably)
- Use `const` and `PROGMEM` for lookup tables
- Prefer static buffers over dynamic
- Use `F()` macro for serial strings: `Serial.println(F("Text"));`
- Disable unused libraries
- Use smaller data types (`uint8_t` vs `int`)

**Maximum buffer sizes:**
- **Safe single buffer**: ~1KB max (leave room for stack/other vars)
- **Aggressive**: 1.5KB (risky, monitor free RAM)
- **Total variables + buffers + stack**: Must stay under 2048 bytes

## Summary
- **No NAND** - you have NOR Flash + EEPROM + SRAM
- **Persistent**: Flash (32KB) + EEPROM (1KB)
- **Volatile**: SRAM (2KB) - heap and stack share this
- **Manual control**: Yes! Static allocation is your friend
- **Watch out**: 2KB SRAM fills up fast - measure usage!