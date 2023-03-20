# Gimbal Documentation

- This document details the gimbal and everything you should need to know about it

## Stock Gimbal Configuration

- [Link to AliExpress listing for the gimbal](https://www.aliexpress.com/item/1005002165612156.html)

### Gimbal Default Parameters & Factory Setup

```text
Factory defaults:
-----------------------
Hardware Version: v1.30 F103RC
Firmware Version: v0.90

Baud rate: 115200
```

### Updated Parameters

```text

```

### Gimbal GUI Controller

- Releases for Olliw42's [`o323BGCTool GUI Tool`](https://github.com/olliw42/storm32bgc/tree/master/firmware%20binaries%20%26%20gui)
- Need to use the `v0.90` release for this tool (for the factory defaults)
  - Just use whatever release corresponds to the firmware on your board (can check with Arduino serial monitor, sending a "v" character)
  - Windows-only tool (haven't tried with Wine)

#### Flashing New Firmware

- [ ] Try `0.90` --> `0.96` upgrade through STLink
