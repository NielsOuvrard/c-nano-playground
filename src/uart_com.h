#ifndef UART_COM_H
#define UART_COM_H

#define F_CPU 16000000UL
#define BAUD 9600
#define MYUBRR F_CPU/16/BAUD-1

#include <avr/io.h>
#include <stdint.h>

/**
 * Initialize UART with given baud rate
 * @param ubrr Baud rate setting
 */
void uart_init(unsigned int ubrr);

/**
 * Print a null-terminated string via UART
 * @param str Pointer to string to print
 */
void uart_print(const char* str);

/**
 * Formatted print function via UART
 * @param format Format string
 * @param ... Additional arguments
 * @return Number of characters printed
 */
int uprintf(const char* format, ...);

#endif /* UART_COM_H */