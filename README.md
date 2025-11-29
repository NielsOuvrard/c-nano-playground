# C-Nano-Playground

## Description
C implementation on an ATmega328P-based Nano boards. This project provides a foundation for developing C programs that run on Arduino Nano boards using the ATmega328P microcontroller.

## Prerequisites
- AVR-GCC toolchain
- AVRDUDE for flashing
- Make build system
- Arduino Nano board with ATmega328P

## Building

Use the Makefile:
```bash
make
```

## Why
This project serves as an educational platform for experimenting with deep microcontroller manipulation, enabling byte-by-byte control of Flash, EEPROM, and SRAM.

## Vscode Integration

To set up VSCode for this project, create a `.vscode` folder in the project root and add the following configuration files:
Inside `c_cpp_properties.json`:

```json
{
    "configurations": [
        {
            "name": "AVR GCC",
            "includePath": [
                "${workspaceFolder}/**",
                "/opt/homebrew/Cellar/avr-gcc@9/9.5.0/avr/include"
            ],
            "defines": [
                "F_CPU=16000000UL",
                "__AVR_ATmega328P__"
            ],
            "compilerPath": "/opt/homebrew/bin/avr-gcc",
            "cStandard": "c11",
            "cppStandard": "c++11",
            "intelliSenseMode": "gcc-x64"
        }
    ],
    "version": 4
}
```