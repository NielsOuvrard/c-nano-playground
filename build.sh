# build
avr-gcc -mmcu=atmega328p -DF_CPU=16000000UL -Os -o hello.elf hello.c
avr-objcopy -O ihex hello.elf hello.hex

# flash
avrdude -c arduino -p atmega328p -P /dev/cu.usbserial-110 -b 57600 -U flash:w:hello.hex:i
