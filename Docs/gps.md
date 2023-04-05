# GPS

- This document explains the following with relation to the GPS module in this project
  - Module & RS232 adapter details
  - Setup
  - Configuration
  - Interfacing (through a USB port)
  - Python bindings
  - Usage in `seafaring_RMS`

## Software

### [u-blox u-center](https://www.u-blox.com/en/product/u-center)

[<img src="./images/u-center2_web.png" width="450"/>](./images/u-center2_web.png)

- GUI tool for u-blox chips
- Highly useful

## Modules

### NEO-6M GPS Module

`GY-NEO6MV2 GPS Module`

- Supposedly `3.3v - 5v`
- `RS232-TTL` interface
  - `9600 baud` default
- `MS621FE` battery
  - Nominal `3v`
  - Mine's at `2.14v`
  - Replaced battery with `CR2032`
    - Battery had nominal `3v`
    - Measured `2.6v` when connected to module
- EEPROM for config data

### NEO-7M GPS Module

- ROM, so no firmware updates

### CP2102 RS232 Module

- Without solder bridges
  - `VCC` outputs `5.10v` on my daily laptop
  - `VCC` outputs `5.09v` on Borealis
  - `VCC` outputs `4.96v` on Borealis w/ 1m USB 3.0 extension & hub

### Further Notes

- External Antenna
- Hacky SNR Improvements
  - [Anti-static bag usage](https://portal.u-blox.com/s/question/0D52p00008JOmGUCA1/so-i-laid-an-antistatic-bag-under-a-receiverantenna-and-it-improved-snr)
