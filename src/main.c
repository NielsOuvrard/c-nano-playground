#define F_CPU 16000000UL
#define BAUD 9600
#define MYUBRR F_CPU/16/BAUD-1

#include <avr/io.h>
#include <util/delay.h>

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

void uart_transmit(unsigned char data)
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

int main(void)
{
    uart_init(MYUBRR);

    while (1) {
        uart_print("hello world\r\n");
        _delay_ms(1000);
    }

    return 0;
}
