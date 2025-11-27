# ATmega328P Bootloader Documentation

## Flash Memory Layout Comparison

### WITHOUT Bootloader (bare chip)
```
0x0000 ┌─────────────────────┐
       │                     │
       │   YOUR PROGRAM      │
       │   (32KB available)  │
       │                     │
0x7FFF └─────────────────────┘
```
**Programming method**: ICSP (In-Circuit Serial Programming) with AVRISP mkII

---

### Bootloader Optiboot 8.0 (2018+)
```
0x0000 ┌─────────────────────┐
       │                     │
       │   YOUR PROGRAM      │
       │   (~31.5KB)         │
       │                     │
0x7E00 ├─────────────────────┤ ← Bootloader starts here
       │   BOOTLOADER        │
       │   (~512 bytes)      │
0x7FFF └─────────────────────┘
```
**Programming method**: Serial

#### features:
- Occupies **512 bytes** (0x7E00 to 0x7FFF)
- Takes about **2 seconds** to upload
- Uses **115200 baud**

---

## How the Bootloader Works (Step-by-Step)

### 1. **Power On / Reset Sequence**

```
Power ON or RESET pin pulled LOW
         ↓
   Reset Vector Jumps
         ↓
   Check BOOTRST fuse
         ↓
   Execute bootloader at 0x7800
```

The **BOOTRST fuse** tells the chip where to start executing after reset:
- If BOOTRST = 0 (programmed), start at bootloader address
- If BOOTRST = 1 (unprogrammed), start at 0x0000 (no bootloader)

---

### 2. **Bootloader Decision Tree**

```c
// Pseudo-code of what bootloader does
void bootloader_main() {
    // 1. Check if serial programming is requested
    if (watchdog_triggered || DTR_pulse_detected) {
        // Wait for STK500 protocol commands
        wait_for_upload();  // Timeout ~1 second
    }
    
    // 2. If no upload request, jump to user program
    if (timeout_reached || no_serial_activity) {
        jump_to_application(0x0000);
    }
    
    // 3. Handle upload if requested
    while (serial_active) {
        process_stk500_command();
        write_to_flash();
    }
    
    // 4. Upload complete, jump to new program
    jump_to_application(0x0000);
}
```

---

### 3. **DTR (Data Terminal Ready) Trigger**

When Arduino IDE clicks "Upload":

```
PC (Arduino IDE)
    ↓
  USB-Serial Chip (CH340/FTDI/etc)
    ↓
  DTR pin pulses LOW for ~100ms
    ↓
  Capacitor + RESET circuit
    ↓
  ATmega328P RESET pin goes LOW
    ↓
  Chip resets, bootloader starts
    ↓
  Bootloader listens on Serial (RX/TX)
```

**Circuit on your board:**
```
DTR ──┤|─── RESET pin
     100nF
      │
     GND
```
This capacitor creates a **pulse** (AC coupling) rather than holding reset forever.

---

### 4. **STK500 Protocol (How PC Talks to Bootloader)**

The bootloader speaks **STK500v1 protocol** (Atmel's standard).

**Example upload session:**

```
PC → Arduino: 0x30 0x20  (Get Sync command)
Arduino → PC: 0x14 0x10  (In Sync response)

PC → Arduino: 0x41       (Read signature)
Arduino → PC: 0x1E 0x95 0x0F (ATmega328P signature)

PC → Arduino: 0x55 <addr> <data[128]>  (Write page)
Arduino → PC: 0x14 0x10                (OK)

... (repeat for all pages) ...

PC → Arduino: 0x51       (Leave programming mode)
Arduino → PC: 0x14 0x10  (OK, jumping to app)
```

---

## Fuse Bits Configuration

> See [fuse_bits_configuration.md](fuse_bits_configuration.md) for detailed fuse settings.

---

## Flash Memory Protection (Lock Bits)

The bootloader section has **special privileges**:

### SPM (Self-Programming Mode) Access
```
                    | Read | Write | Execute
────────────────────┼──────┼───────┼─────────
Application Section |  ✓   |  ✗    |   ✓
Bootloader Section  |  ✓   |  ✓    |   ✓
```

**Only the bootloader can write to Flash!**

This is controlled by **Lock Bits**:
```
BLB12 BLB11 | Bootloader protection
    1     1 | No protection
    1     0 | SPM prohibited to write to Boot section
    0     0 | SPM prohibited, LPM prohibited from App
```

---

## Detailed Bootloader Source Code Analysis

Here's the actual **Optiboot 4.4** core loop (simplified):

```c
// Entry point after reset
int main(void) __attribute__ ((OS_main)) __attribute__ ((section (".init9")));

int main(void) {
    uint8_t ch;
    
    // 1. Set up watchdog as timeout
    watchdog_config(WATCHDOG_1S);
    
    // 2. Initialize UART at 115200 baud
    UART_SRA = _BV(U2X0); // Double speed mode
    UART_SRB = _BV(RXEN0) | _BV(TXEN0);
    UART_SRC = _BV(UCSZ00) | _BV(UCSZ01);
    UART_SRL = (uint8_t)( (F_CPU + BAUD_RATE * 4L) / (BAUD_RATE * 8L) - 1 );
    
    // 3. Check if we should enter bootloader mode
    ch = MCUSR; // Read reset cause
    MCUSR = 0;  // Clear it
    
    if (!(ch & _BV(EXTRF))) {
        // Not external reset, jump to app
        app_start();
    }
    
    // 4. Wait for STK500 'Get Sync' (0x30 0x20)
    for(;;) {
        ch = getch(); // Blocking wait for byte
        
        if (ch == STK_GET_SYNC) {
            // Verify next byte is CRC_EOP
            if (getch() == CRC_EOP) {
                putch(STK_INSYNC);
                putch(STK_OK);
            }
        }
        else if (ch == STK_LOAD_ADDRESS) {
            // Get 16-bit address
            uint16_t addr = getch() | (getch() << 8);
            addr <<= 1; // Convert word address to byte
            address = addr;
            putch(STK_INSYNC);
            putch(STK_OK);
        }
        else if (ch == STK_PROG_PAGE) {
            // Write a page to flash
            uint16_t length = (getch() << 8) | getch();
            uint8_t memtype = getch();
            
            // Read data into buffer
            for (uint16_t i = 0; i < length; i++) {
                buff[i] = getch();
            }
            
            if (getch() != CRC_EOP) continue;
            
            // Erase page
            boot_page_erase(address);
            boot_spm_busy_wait();
            
            // Write page
            for (uint16_t i = 0; i < length; i += 2) {
                uint16_t word = buff[i] | (buff[i+1] << 8);
                boot_page_fill(address + i, word);
            }
            boot_page_write(address);
            boot_spm_busy_wait();
            
            putch(STK_INSYNC);
            putch(STK_OK);
        }
        else if (ch == STK_LEAVE_PROGMODE) {
            // Exit bootloader
            watchdog_config(WATCHDOG_16MS);
            putch(STK_INSYNC);
            putch(STK_OK);
            while(1); // Watchdog will reset us → app starts
        }
    }
}

// Jump to application
void app_start(void) {
    watchdog_disable();
    __asm__ __volatile__ (
        "clr r1\n"           // Zero register
        "jmp 0x0000\n"       // Jump to application start
    );
}
```

---

## Assembly-Level Bootloader Entry

```asm
; Reset vector (when BOOTRST fuse = 0)
.org 0x7800
bootloader_start:
    ; Save SREG and registers
    cli                     ; Disable interrupts
    
    ; Check MCUSR (reset cause)
    in r24, MCUSR
    out MCUSR, r1           ; Clear it
    
    ; Check for external reset (EXTRF bit)
    sbrs r24, EXTRF
    rjmp app_start          ; Not external → jump to app
    
    ; Initialize stack
    ldi r24, lo8(RAMEND)
    out SPL, r24
    ldi r24, hi8(RAMEND)
    out SPH, r24
    
    ; Initialize UART
    ldi r24, (1<<U2X0)
    sts UCSR0A, r24
    
    ; ... rest of bootloader ...
    
app_start:
    ; Jump to application
    clr r1
    ldi r30, 0x00
    ldi r31, 0x00
    ijmp                    ; Indirect jump to Z register (0x0000)
```

---

## Bootloader Memory Access During Upload

```
Upload Process:

1. Bootloader receives page data (128 bytes)
   ↓
2. Stores temporarily in SRAM buffer (0x0100+)
   ↓
3. Erases Flash page at target address
   ↓
4. Writes buffer to Flash page
   ↓
5. Verifies write (optional)
   ↓
6. Repeat for next page
```

**Critical**: During this, your SRAM is used by bootloader! This is why it's at 0x0100+.

---

## Bootloader Debugging

Want to see what's happening?

```c
// In your sketch, read the reset cause
void setup() {
    Serial.begin(115200);
    
    uint8_t mcusr = MCUSR;
    MCUSR = 0;
    
    Serial.print("Reset cause: 0x");
    Serial.println(mcusr, HEX);
    
    if (mcusr & _BV(PORF))  Serial.println("Power-on");
    if (mcusr & _BV(EXTRF)) Serial.println("External");
    if (mcusr & _BV(BORF))  Serial.println("Brown-out");
    if (mcusr & _BV(WDRF))  Serial.println("Watchdog");
}
```

---

## Summary

| Feature | Old Bootloader | New Bootloader |
|---------|----------------|----------------|
| Size | 2KB (0x7800) | 512B (0x7E00) |
| Your Flash | 30.5KB | 31.5KB |
| Upload Speed | ~8 sec | ~2 sec |
| Protocol | STK500v1 | STK500v1 |
| Baud Rate | 115200 | 115200 |
| Year | ~2011 | ~2018 |

The bootloader is **self-contained firmware** that:
1. Runs on every reset
2. Checks for upload request
3. Writes new code to Flash
4. Jumps to your program
