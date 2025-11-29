#include <avr/boot.h>

void print_signature(uint8_t sig[])
{
    sig[0] = boot_signature_byte_get(0x0000);
    sig[1] = boot_signature_byte_get(0x0002);
    sig[2] = boot_signature_byte_get(0x0004);
}
