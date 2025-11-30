################################################################################
# Makefile for ATmega328P Linker Tutorial
################################################################################

# Project name
PROJECT = linker_tutorial

# MCU settings
MCU = atmega328p
F_CPU = 16000000UL

# Compiler and tools
CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size
NM = avr-nm
AVRDUDE = avrdude

# Compiler flags
CFLAGS = -mmcu=$(MCU) \
         -DF_CPU=$(F_CPU) \
         -Os \
         -Wall \
         -Wextra \
         -std=gnu99

# Linker flags
LDFLAGS = -mmcu=$(MCU) \
          -T custom.ld \
          -Wl,-Map=$(PROJECT).map,--cref \
          -Wl,--gc-sections

# Source files
SRC = main.c

# Object files
OBJ = $(SRC:.c=.o)

# Output files
ELF = $(PROJECT).elf
HEX = $(PROJECT).hex
LST = $(PROJECT).lst
MAP = $(PROJECT).map

################################################################################
# Build targets
################################################################################

.PHONY: all clean size analyze disasm memory symbols sections headers hex \
        flash fuses help

# Default target
all: $(HEX) size

# Compile C to object file
%.o: %.c
	@echo "Compiling $<..."
	$(CC) $(CFLAGS) -c -o $@ $<

# Link object files to ELF
$(ELF): $(OBJ) custom.ld
	@echo "Linking $(ELF)..."
	$(CC) $(LDFLAGS) -o $@ $(OBJ)
	@echo "Build complete!"

# Convert ELF to HEX for programming
$(HEX): $(ELF)
	@echo "Creating $(HEX)..."
	$(OBJCOPY) -O ihex -R .eeprom $< $@

# Create disassembly listing
$(LST): $(ELF)
	@echo "Creating disassembly listing..."
	$(OBJDUMP) -h -S $< > $@

# Clean build files
clean:
	@echo "Cleaning..."
	rm -f $(OBJ) $(ELF) $(HEX) $(LST) $(MAP)
	@echo "Clean complete!"

################################################################################
# Analysis targets
################################################################################

# Show memory usage
size: $(ELF)
	@echo ""
	@echo "=========================================="
	@echo "Memory Usage Summary"
	@echo "=========================================="
	$(SIZE) -C --mcu=$(MCU) $<
	@echo ""
	$(SIZE) -A $<
	@echo ""

# Full analysis report
analyze: $(ELF) $(LST)
	@echo ""
	@echo "=========================================="
	@echo "COMPLETE MEMORY ANALYSIS"
	@echo "=========================================="
	@$(MAKE) --no-print-directory size
	@$(MAKE) --no-print-directory sections
	@$(MAKE) --no-print-directory memory
	@echo ""
	@echo "Detailed map file: $(MAP)"
	@echo "Disassembly listing: $(LST)"

# Show disassembly
disasm: $(ELF)
	@echo "Disassembly (first 100 lines):"
	$(OBJDUMP) -d $< | head -100

# Show detailed memory map from map file
memory: $(ELF)
	@echo ""
	@echo "=========================================="
	@echo "Memory Configuration"
	@echo "=========================================="
	@grep -A 30 "Memory Configuration" $(MAP) || echo "Map file not found"
	@echo ""
	@echo "=========================================="
	@echo "Linker Script Memory Regions"
	@echo "=========================================="
	@grep -A 30 "Linker script and memory map" $(MAP) | head -50 || echo "Map file not found"

# Show all symbols with addresses
symbols: $(ELF)
	@echo ""
	@echo "=========================================="
	@echo "All Symbols (sorted by address)"
	@echo "=========================================="
	$(NM) -n $< | head -50
	@echo "... (showing first 50, see full list with: avr-nm -n $(ELF))"

# Show section information
sections: $(ELF)
	@echo ""
	@echo "=========================================="
	@echo "Section Headers"
	@echo "=========================================="
	$(OBJDUMP) -h $<
	@echo ""
	@echo "=========================================="
	@echo "Section Sizes (detailed)"
	@echo "=========================================="
	$(SIZE) -A -x $<

# Show ELF headers
headers: $(ELF)
	@echo ""
	@echo "=========================================="
	@echo "ELF File Headers"
	@echo "=========================================="
	$(OBJDUMP) -f $<
	@echo ""
	$(OBJDUMP) -p $<

# Show hex file
hex: $(HEX)
	@echo ""
	@echo "=========================================="
	@echo "Intel HEX File (first 20 lines)"
	@echo "=========================================="
	@head -20 $(HEX)

################################################################################
# Programming targets
################################################################################

# Flash program to chip (adjust programmer settings)
flash: $(HEX)
	$(AVRDUDE) -p $(MCU) -c arduino -P /dev/ttyUSB0 -b 115200 -U flash:w:$<:i

# Set fuses for new bootloader
fuses:
	$(AVRDUDE) -p $(MCU) -c arduino -P /dev/ttyUSB0 -b 115200 \
		-U lfuse:w:0xFF:m \
		-U hfuse:w:0xDE:m \
		-U efuse:w:0xFD:m

################################################################################
# Help
################################################################################

help:
	@echo "Available targets:"
	@echo "  make              - Build project (default)"
	@echo "  make clean        - Remove build files"
	@echo "  make size         - Show memory usage"
	@echo "  make analyze      - Complete memory analysis"
	@echo "  make disasm       - Show disassembly"
	@echo "  make memory       - Show memory map"
	@echo "  make symbols      - Show all symbols"
	@echo "  make sections     - Show section details"
	@echo "  make headers      - Show ELF headers"
	@echo "  make hex          - Show hex file contents"
	@echo "  make flash        - Program chip"
	@echo "  make fuses        - Set fuse bits"
	@echo ""
	@echo "Analysis workflow:"
	@echo "  1. make           - Build"
	@echo "  2. make analyze   - Complete analysis"
	@echo "  3. make disasm    - View assembly code"
