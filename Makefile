# MCU settings
MCU = atmega328p
F_CPU = 16000000UL

# Programmer settings
PROGRAMMER = arduino
PORT = /dev/cu.usbserial-110
BAUD = 57600

# Compiler settings
CC = avr-gcc
OBJCOPY = avr-objcopy
AVRDUDE = avrdude
CFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -Os

# Project files
SRC = src/main.c
TARGET = hello

all: $(TARGET).hex

$(TARGET).elf: $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET).elf $(SRC)

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $(TARGET).elf $(TARGET).hex

flash: $(TARGET).hex
	$(AVRDUDE) -c $(PROGRAMMER) -p $(MCU) -P $(PORT) -b $(BAUD) -U flash:w:$(TARGET).hex:i

clean:
	rm -f $(TARGET).elf $(TARGET).hex

.PHONY: all flash clean
