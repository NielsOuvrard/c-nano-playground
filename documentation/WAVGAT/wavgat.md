# WAVGAT UNO-R3 Board with LGT8F328P MCU

This is an Arduino UNO-compatible clone with some significant differences from the standard Arduino UNO. Here's a comprehensive breakdown:

## **MCU: LGT8F328P**

The LGT8F328P is a Chinese-made microcontroller from LogicGreen Technologies that serves as an enhanced, pin-compatible alternative to the ATmega328P.

### **Key Specifications:**
- **Architecture**: 8-bit AVR-compatible RISC
- **Clock Speed**: Typically 16 MHz or 32 MHz (can run at double speed internally)
- **Flash Memory**: 32KB (vs 32KB on ATmega328P)
- **SRAM**: 2KB (same as ATmega328P)
- **EEPROM**: 1KB (same as ATmega328P)
- **I/O Pins**: 22 (compatible with ATmega328P pinout)

### **Enhanced Features vs ATmega328P:**

1. **12-bit ADC** (instead of 10-bit)
   - Resolution: 4096 levels vs 1024 levels
   - **Quantum (q)**: 805.66 µV at 3.3V reference
   - More precise analog readings

2. **Computational DAC** (Digital-to-Analog Converter)
   - 8-bit DAC output capability
   - Not available on standard ATmega328P

3. **Differential Amplifier**
   - Built-in programmable gain amplifier
   - Useful for sensor applications

4. **Internal Temperature Sensor**

5. **Higher Speed Capability**
   - Can operate at 32 MHz internally
   - Faster execution than standard Arduino UNO

## **Critical Voltage Differences**

⚠️ **IMPORTANT**: This board operates at **3.3V logic levels**, not 5V like standard Arduino UNO!

- **MCU Vcc**: 3.3V (pin 4 of the chip)
- **Analog Inputs (A0-A5)**: Maximum 3.3V input
- **Digital I/O**: 3.3V logic levels
- **Risk**: Applying 5V signals could damage the MCU

### **ADC Configuration:**

- **Resolution**: 12-bit (0-4095 range)
- **Reference Voltage**: 3.3V (Vcc) by default
- **Quantum**: 3.3V ÷ 4096 = **805.66 µV per step**
- **AREF Pin**: Can use external reference voltage (<3.3V) with `analogReference(EXTERNAL)`

```cpp
// For external reference
analogReference(EXTERNAL);
// Connect your reference voltage to AREF pin
```

## **Programming the Board**

### **Arduino IDE Setup:**

The LGT8F328P requires special board support. Install via:

1. Add to Board Manager URLs:
   ```
   https://raw.githubusercontent.com/dbuezas/lgt8fx/master/package_lgt8fx_index.json
   ```

2. Install "LGT8Fx Boards" package

3. Select: **Tools → Board → LGT8F328P**

4. Configure clock speed (16MHz or 32MHz)

### **Compatibility:**

- **High compatibility** with Arduino UNO sketches
- Most standard Arduino libraries work
- 12-bit ADC requires code adjustment: `analogRead()` returns 0-4095 instead of 0-1023

## **Practical Considerations**

### **Advantages:**
✓ Better ADC resolution (12-bit vs 10-bit)  
✓ Faster processing capability  
✓ Built-in DAC and differential amplifier  
✓ Lower cost than genuine Arduino  
✓ Pin-compatible with UNO shields (with voltage caution)

### **Disadvantages/Cautions:**
✗ 3.3V logic - incompatible with 5V shields/sensors without level shifting  
✗ Less community support than ATmega328P  
✗ Some Arduino libraries may have compatibility issues  
✗ Documentation primarily in Chinese  
✗ Requires special board package installation

## **Using the Enhanced ADC**

```cpp
void setup() {
  Serial.begin(9600);
  // Optional: use external reference
  // analogReference(EXTERNAL);
}

void loop() {
  int raw = analogRead(A0); // Returns 0-4095
  
  // Convert to voltage (3.3V reference)
  float voltage = raw * (3.3 / 4095.0);
  
  Serial.print("Raw: ");
  Serial.print(raw);
  Serial.print(" | Voltage: ");
  Serial.println(voltage, 4); // 4 decimal places
  
  delay(1000);
}
```

## **Shield Compatibility Warning**

Many Arduino UNO shields are designed for 5V operation. Using them with this 3.3V board requires:
- **Level shifters** for digital signals
- **Voltage dividers** for analog inputs exceeding 3.3V
- Check shield power requirements

## **Power Supply**

- Can typically be powered via USB (5V, regulated down to 3.3V)
- External power through barrel jack (usually 7-12V, regulated to 3.3V)
- Check your specific board's voltage regulator specifications

This board offers excellent value with enhanced features, but requires careful attention to the 3.3V operating voltage to avoid damaging components.