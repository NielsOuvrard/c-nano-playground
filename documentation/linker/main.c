/******************************************************************************
 * main.c - Comprehensive Linker Script Tutorial
 * ATmega328P Memory Layout Demonstration
 *****************************************************************************/

#include <avr/io.h>
#include <avr/pgmspace.h>
#include <avr/interrupt.h>
#include <avr/eeprom.h>
#include <util/delay.h>

/******************************************************************************
 * SECTION 1: Normal Global Variables (.data - initialized in SRAM)
 *****************************************************************************/

// These are stored in Flash AND copied to SRAM at startup
int global_counter = 0;
char global_string[] = "Hello";
uint8_t global_array[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

/******************************************************************************
 * SECTION 2: Uninitialized Variables (.bss - zeroed in SRAM)
 *****************************************************************************/

// These only exist in SRAM, no Flash storage needed
int uninitialized_value;
char uninitialized_buffer[64];
static uint16_t static_uninit;

/******************************************************************************
 * SECTION 3: Constant Data (.rodata - Flash only, read with normal access)
 *****************************************************************************/

// Modern AVR-GCC automatically puts const data in Flash
const char error_message[] = "Error occurred";
const uint16_t lookup_table[] = {100, 200, 300, 400, 500};

/******************************************************************************
 * SECTION 4: PROGMEM Data (.progmem - Flash, needs special access)
 *****************************************************************************/

// Explicitly stored in Flash, requires pgm_read_* functions
const char progmem_string[] PROGMEM = "This is in Flash";
const uint8_t progmem_data[] PROGMEM = {0xAA, 0xBB, 0xCC, 0xDD};

/******************************************************************************
 * SECTION 5: Custom Section - Serial Buffers
 *****************************************************************************/

// Place in specific memory region defined in linker script
uint8_t serial_tx_buffer[128] __attribute__((section(".serial_buffers")));
uint8_t serial_rx_buffer[128] __attribute__((section(".serial_buffers")));

/******************************************************************************
 * SECTION 6: Custom Section - Fixed Address Buffer
 *****************************************************************************/

// Goes to specific address (0x0500) via linker script
uint8_t fixed_buffer[256] __attribute__((section(".fixed_memory")));

/******************************************************************************
 * SECTION 7: NOINIT Section (survives resets)
 *****************************************************************************/

// Not zeroed at startup, retains value across resets
uint8_t reset_counter __attribute__((section(".noinit")));
uint16_t persistent_value __attribute__((section(".noinit")));

/******************************************************************************
 * SECTION 8: EEPROM Data
 *****************************************************************************/

// Stored in EEPROM, persists across power cycles
uint8_t EEMEM eeprom_settings[32];
uint16_t EEMEM eeprom_calibration;

/******************************************************************************
 * SECTION 9: Function in Custom Section
 *****************************************************************************/

// Place specific function in known location
void critical_function(void) __attribute__((section(".critical_code")));

void critical_function(void) {
    PORTB |= (1 << PB5);  // Turn on LED
}

/******************************************************************************
 * SECTION 10: Access Linker Symbols
 *****************************************************************************/

// These are defined by the linker script
extern uint8_t __data_start;
extern uint8_t __data_end;
extern uint8_t __bss_start;
extern uint8_t __bss_end;
extern uint8_t __heap_start;
extern uint8_t __serial_start;
extern uint8_t __serial_end;
extern uint8_t __fixed_start;
extern uint8_t __fixed_end;

/******************************************************************************
 * Helper Functions
 *****************************************************************************/

// Calculate free SRAM (between heap and stack)
int get_free_ram(void) {
    extern int __heap_start, *__brkval;
    int v;
    return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval);
}

// Print memory layout (requires UART setup)
void print_memory_map(void) {
    // In real application, send this via UART
    volatile uint16_t data_size = (uint16_t)&__data_end - (uint16_t)&__data_start;
    volatile uint16_t bss_size = (uint16_t)&__bss_end - (uint16_t)&__bss_start;
    volatile uint16_t serial_size = (uint16_t)&__serial_end - (uint16_t)&__serial_start;
    volatile uint16_t fixed_size = (uint16_t)&__fixed_end - (uint16_t)&__fixed_start;
    
    // Use volatile to prevent optimization
    (void)data_size;
    (void)bss_size;
    (void)serial_size;
    (void)fixed_size;
}

/******************************************************************************
 * Interrupt Service Routine Example
 *****************************************************************************/

// ISR goes to .text section
ISR(TIMER0_OVF_vect) {
    global_counter++;
}

/******************************************************************************
 * Main Function
 *****************************************************************************/

int main(void) {
    // Initialize
    DDRB |= (1 << PB5);  // LED pin as output
    
    // Increment reset counter (survives resets!)
    reset_counter++;
    
    // Use .data variables
    global_counter = 42;
    
    // Use .bss variables
    uninitialized_value = 100;
    for (int i = 0; i < 64; i++) {
        uninitialized_buffer[i] = i;
    }
    
    // Access const data (automatically from Flash)
    volatile uint16_t val = lookup_table[2];  // 300
    (void)val;
    
    // Access PROGMEM data (requires pgm_read)
    uint8_t byte_from_flash = pgm_read_byte(&progmem_data[0]);  // 0xAA
    (void)byte_from_flash;
    
    // Use custom section buffers
    serial_tx_buffer[0] = 0x55;
    serial_rx_buffer[0] = 0xAA;
    
    // Use fixed address buffer
    fixed_buffer[0] = 0xFF;
    fixed_buffer[255] = 0x00;
    
    // Access EEPROM
    uint8_t eeprom_val = eeprom_read_byte(&eeprom_settings[0]);
    eeprom_write_byte(&eeprom_settings[0], eeprom_val + 1);
    
    // Call function in custom section
    critical_function();
    
    // Print memory map
    print_memory_map();
    
    // Main loop
    while (1) {
        PORTB ^= (1 << PB5);  // Toggle LED
        _delay_ms(1000);
        
        // Use various memory types
        global_counter++;
        uninitialized_value++;
    }
    
    return 0;
}
