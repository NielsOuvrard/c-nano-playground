# AVR Bare-Metal: Memory Map & Linker Script Exploration

This project is a deep dive into the internal memory architecture of the ATmega328P. Moving away from the abstraction of the Arduino IDE, this project uses pure C (`avr-gcc`), a custom Makefile, and—most importantly—a **custom linker script** to manually control memory layout.

The primary goal was to enforce deterministic memory usage by forbidding the heap and manually mapping static buffers to specific SRAM regions.

## 🎯 Project Philosophy

- **No Heap:** `malloc` and `free` are explicitly forbidden to prevent fragmentation and ensure deterministic runtime behavior.
- **Manual Memory Control:** Instead of letting the linker place variables arbitrarily, I defined custom sections (`.buffer_128`, `.buffer_256`, `.buffer_640`) to map data to exact physical addresses.
- **Bare Metal:** No Arduino core libraries. Direct register manipulation for UART and hardware setup.

## 🛠 Technical Deep Dive

### 1. Custom Linker Script (`minimum.ld`)

The standard AVR linker script places all data sequentially. I wrote a custom script to segment the 2KB SRAM of the ATmega328P into specific regions.

**The Memory Map:**

```text
Physical Address   Section Name       Description
----------------   ------------       -----------
0x0000 - 0x001F    Registers          General Purpose Registers
0x0020 - 0x005F    I/O                I/O Registers
0x0060 - 0x00FF    Ext I/O            Extended I/O
----------------   ------------       -----------
0x0100 - 0x017F    .buffer_128        Custom 128B Buffer
0x0180 - 0x027F    .buffer_256        Custom 256B Buffer
0x0280 - 0x04FF    .buffer_640        Custom 640B Buffer
0x0500 - ...       .data / .bss       Global variables & Static data
...                ...                Free Space
... - 0x08FF       Stack              Grows downwards from RAMEND
```

### 2. The "SRAM Offset" Challenge

During development, I encountered a critical issue where buffers placed at `0x800060` were failing. Through debugging, I learned that while the AVR data address space maps SRAM to `0x800100`, the linker treats `0x800000` as the data segment offset.

- **Initial (Buggy) Map:** Placed buffers at `0x800060` (Physical `0x0060`), colliding with Extended I/O registers.
- **Fix:** Adjusted linker origin to `0x800100` (Physical `0x0100`), the actual start of internal SRAM.

### 3. Flash vs. SRAM (.rodata)

I implemented a custom `uprintf` function. Initially, string literals (stored in `.rodata`) were printing as garbage.

- **Root Cause:** The linker was placing `.rodata` in the `.text` (Flash) section, but the code was accessing it using `LD` (Load from SRAM) instructions instead of `LPM` (Load from Program Memory).
- **Solution:** Modified the linker script to group `.rodata` with `.data`, ensuring string constants are copied from Flash to SRAM during the C runtime startup (`crt`) phase.

### Code Snippet: Section Attributes

I use GCC attributes to force variables into my custom linker sections:

```c
#ifdef BUFFER_SECTION_ATTRIBUTE
uint8_t buffer_128[128] __attribute__((section(".buffer_128")));
uint8_t buffer_256[256] __attribute__((section(".buffer_256")));
uint8_t buffer_640[640] __attribute__((section(".buffer_640")));
#endif
```

## 🚀 How to Build & Flash

**Prerequisites:** `avr-gcc`, `avr-libc`, `avrdude`.

1.  **Compile and Link:**

    ```bash
    make
    ```

    _This uses the minimum.ld script and defines `-DBUFFER_SECTION_ATTRIBUTE`._

2.  **Flash to Device:**

    ```bash
    make flash
    ```

3.  **Verify Output:**
    The program prints the memory addresses of the buffers via UART (9600 baud) to prove they reside in the custom-defined memory regions.

## 🧠 Key Learnings

- **Stack vs. Static:** Local variables (stack) are unaffected by linker script data placement. They always grow down from `RAMEND` (`0x08FF`), regardless of where `.data` sits.
- **Linker Mechanics:** Understanding `AT>` (Load Address) vs `>` (Virtual Address) is crucial for embedded systems where code lives in Flash but runs in RAM.
- **Debugging without a Debugger:** Using UART and memory inspection to diagnose linker misconfigurations.

---

## Vscode Integration

To set up VSCode for this project, create a `.vscode` folder in the project root and add the following configuration files:
Inside `c_cpp_properties.json`:

```json
{
  "configurations": [
    {
      "name": "AVR GCC",
      "includePath": [
        "${workspaceFolder}/**",
        "/opt/homebrew/Cellar/avr-gcc@9/9.5.0/avr/include"
      ],
      "defines": ["F_CPU=16000000UL", "__AVR_ATmega328P__"],
      "compilerPath": "/opt/homebrew/bin/avr-gcc",
      "cStandard": "c11",
      "cppStandard": "c++11",
      "intelliSenseMode": "gcc-x64"
    }
  ],
  "version": 4
}
```

---

_This project represents a step away from "it just works" libraries towards understanding "how it actually works."_
