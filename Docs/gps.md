# GPS

- This document explains the following with relation to the GPS module in this project
  - Module & RS232 adapter details
  - Setup
  - Configuration
  - Interfacing (through a USB port)
  - Python bindings
  - Usage in `seafaring_RMS`

## Modules

### NEO-6M GPS Module

`GY-NEO6MV2 GPS Module`

- Supposedly `3.3v - 5v`
- `RS232-TTL` interface
  - `9600 baud` default
- `MS621FE` battery
- EEPROM for config data
-

### CP2102 RS232 Module

- Without solder bridges
  - `VCC` outputs `5.10v` on my daily laptop
  - `VCC` outputs `5.09v` on Borealis
  - `VCC` outputs `4.96v` on Borealis w/ 1m USB 3.0 extension & hub
