#include "uart_com.h"

#include <avr/io.h>
#include <util/delay.h>
#include <avr/boot.h>
#include <string.h>
#include <stdarg.h>

void uart_init(unsigned int ubrr)
{
    // Set baud rate
    UBRR0H = (unsigned char)(ubrr>>8);
    UBRR0L = (unsigned char)ubrr;
    // Enable transmitter
    UCSR0B = (1<<TXEN0);
    // Set frame format: 8 data bits, 1 stop bit
    UCSR0C = (1<<UCSZ01) | (1<<UCSZ00);
}

static void uart_transmit(unsigned char data)
{
    // Wait for empty transmit buffer
    while (!(UCSR0A & (1<<UDRE0)));
    // Put data into buffer, sends the data
    UDR0 = data;
}

void uart_print(const char* str)
{
    while (*str) {
        uart_transmit(*str++);
    }
}

int uprintf(const char* format, ...)
{
    char buffer[128]; // Use stack-based buffer instead of heap
    va_list args;
    va_start(args, format);
    
    int buf_idx = 0;
    const char* p = format;
    
    while (*p && buf_idx < 127) {
        if (*p == '%') {
            p++;
            if (*p == 'd' || *p == 'i') {
                // Integer
                int val = va_arg(args, int);
                int is_negative = val < 0;
                if (is_negative) val = -val;
                
                // Convert to string (reverse order)
                char temp[12];
                int temp_idx = 0;
                if (val == 0) {
                    temp[temp_idx++] = '0';
                } else {
                    while (val > 0) {
                        temp[temp_idx++] = '0' + (val % 10);
                        val /= 10;
                    }
                }
                if (is_negative) temp[temp_idx++] = '-';
                
                // Copy reversed
                while (temp_idx > 0 && buf_idx < 127) {
                    buffer[buf_idx++] = temp[--temp_idx];
                }
            } else if (*p == 'u') {
                // Unsigned integer
                unsigned int val = va_arg(args, unsigned int);
                char temp[12];
                int temp_idx = 0;
                if (val == 0) {
                    temp[temp_idx++] = '0';
                } else {
                    while (val > 0) {
                        temp[temp_idx++] = '0' + (val % 10);
                        val /= 10;
                    }
                }
                while (temp_idx > 0 && buf_idx < 127) {
                    buffer[buf_idx++] = temp[--temp_idx];
                }
            } else if (*p == 'x' || *p == 'X') {
                // Hexadecimal
                unsigned int val = va_arg(args, unsigned int);
                const char* hex_digits = (*p == 'X') ? "0123456789ABCDEF" : "0123456789abcdef";
                char temp[9];
                int temp_idx = 0;
                if (val == 0) {
                    temp[temp_idx++] = '0';
                } else {
                    while (val > 0) {
                        temp[temp_idx++] = hex_digits[val & 0xF];
                        val >>= 4;
                    }
                }
                while (temp_idx > 0 && buf_idx < 127) {
                    buffer[buf_idx++] = temp[--temp_idx];
                }
            } else if (*p == 's') {
                // String
                const char* str = va_arg(args, const char*);
                while (*str && buf_idx < 127) {
                    buffer[buf_idx++] = *str++;
                }
            } else if (*p == 'c') {
                // Character
                buffer[buf_idx++] = (char)va_arg(args, int);
            } else if (*p == 'p') {
                // Pointer
                void* ptr = va_arg(args, void*);
                unsigned long val = (unsigned long)ptr;
                buffer[buf_idx++] = '0';
                buffer[buf_idx++] = 'x';
                
                char temp[9];
                int temp_idx = 0;
                if (val == 0) {
                    temp[temp_idx++] = '0';
                } else {
                    while (val > 0) {
                        temp[temp_idx++] = "0123456789abcdef"[val & 0xF];
                        val >>= 4;
                    }
                }
                while (temp_idx > 0 && buf_idx < 127) {
                    buffer[buf_idx++] = temp[--temp_idx];
                }
            } else if (*p == '%') {
                // Literal %
                buffer[buf_idx++] = '%';
            }
            p++;
        } else {
            buffer[buf_idx++] = *p++;
        }
    }
    
    buffer[buf_idx] = '\0';
    va_end(args);
    
    uart_print(buffer);
    return buf_idx;
}
