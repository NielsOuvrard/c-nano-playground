#!/bin/bash
# Burn the Optiboot bootloader onto an ATmega328P using avrdude
exit 1

avrdude \
    -C/opt/homebrew/etc/avrdude.conf \
    -v \
    -patmega328p \
    -cstk500v1 \
    -P /dev/cu.usbserial-10 \
    -b19200 \
    -Uflash:w:/Users/nielsouvrard/Downloads/Optiboot-8.0/bootloaders/optiboot/optiboot_atmega328.hex:i \
    -Ulock:w:0x0F:m \
    -Uhfuse:w:0xDE:m \
    -Ulfuse:w:0xFF:m
