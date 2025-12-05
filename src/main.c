#define F_CPU 16000000UL
#define BAUD 9600
#define MYUBRR F_CPU/16/BAUD-1

#include <avr/io.h>
#include <util/delay.h>
#include <avr/boot.h>
#include <string.h>
#include "uart_com.h"

// void malloc(void) __attribute__((error("malloc is forbidden on this platform")));
// void free(void) __attribute__((error("free is forbidden on this platform")));
// void realloc(void) __attribute__((error("realloc is forbidden on this platform")));
// void calloc(void) __attribute__((error("calloc is forbidden on this platform")));

void print_signature(uint8_t sig[]);


// Define buffers directly with section attributes
#ifdef BUFFER_SECTION_ATTRIBUTE
uint8_t buffer_128[128] __attribute__((section(".buffer_128")));
uint8_t buffer_256[256] __attribute__((section(".buffer_256")));
uint8_t buffer_640[640] __attribute__((section(".buffer_640")));
#else
uint8_t buffer_128[128];
uint8_t buffer_256[256];
uint8_t buffer_640[640];
#endif

void fill_buffers()
{
    for (int i = 0; i < 128; i++) {
        buffer_128[i] = (uint8_t)i;
    }
    for (int i = 0; i < 256; i++) {
        buffer_256[i] = (uint8_t)(i + 128);
    }
    for (int i = 0; i < 640; i++) {
        buffer_640[i] = (uint8_t)(i + 384);
    }
}

// ---
// Device Signature: 2X 2X 2X
// pointers: a= b= c=
// Buffer random values: buf128[10]=10 buf256[200]=72 buf640[500]=116
// ---
int main(void)
{
    int a;
    int b = 1;
    int c = 0;
    uart_init(MYUBRR);
    
    uint8_t sig[3];
    print_signature(sig);

    fill_buffers();

    uart_print("Starting main loop...\r\n");

    while (1) {
        uprintf("Device Signature: %X %X %X\r\n", sig[0], sig[1], sig[2]);
        uprintf("pointers:\r\n");
        uprintf("- a=%p\r\n- b=%p\r\n- c=%p\r\n",
            (void*)&a, (void*)&b, (void*)&c);
        uprintf("pointers buffers:\r\n");
        uprintf("- buffer_128=%p\r\n- buffer_256=%p\r\n- buffer_640=%p\r\n",
                (void*)buffer_128, (void*)buffer_256, (void*)buffer_640);
        uprintf("Buffer random values: buf128[10]=%u buf256[200]=%u buf640[500]=%u\r\n",
                buffer_128[10], buffer_256[200], buffer_640[500]);
        _delay_ms(1000);
    }

    return 0;
}
