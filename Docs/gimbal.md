# Gimbal Documentation

- This document details the gimbal and everything you should need to know about it

## Common Gimbals

- [List of common gimbals from the Ardupilot website](https://ardupilot.org/copter/docs/common-cameras-and-gimbals.html#common-cameras-and-gimbals)
- [List of gimbals from the STorM32 wiki](http://www.olliw.eu/storm32bgc-wiki/Example_Setups)

## Stock Gimbal Configuration

- [Link to AliExpress listing for the gimbal](https://www.aliexpress.com/item/1005002165612156.html)
- [Pinout](http://www.olliw.eu/storm32bgc-wiki/Pins_and_Connectors)
  - [Pin functions](http://www.olliw.eu/storm32bgc-wiki/Ports_and_Pins_by_Function)

### Gimbal Default Parameters & Factory Setup

```text
Factory defaults:
-----------------------
Hardware Version: v1.30 F103RC
Firmware Version: v0.90

Baud rate: 115200
```

## Gimbal GUI Controller

[**Important Link - Getting Started with the gimbal**](http://www.olliw.eu/storm32bgc-wiki/Getting_Started)

- Releases for Olliw42's [`o323BGCTool GUI Tool`](https://github.com/olliw42/storm32bgc/tree/master/firmware%20binaries%20%26%20gui)
- Need to use the `v0.90` release for this tool (for the factory default firmware)
  - Just use whatever release corresponds to the firmware on your board (can check with Arduino serial monitor, sending a "v" character)

### GUI use

- Experts Only menu
  - Expert Tool
    - Can set Mavlink heartbeat config here
  - RC Command Tool
    - Use to manually control gimbal

### GUI on Linux

- [Install Wine](https://wiki.winehq.org/Ubuntu)
- [Add a serial port symlink](https://superuser.com/questions/619528/converting-the-dev-ttyusb-to-com-port-to-use-it-with-wine-in-linux)
  - `cd ~/.wine/dosdevices/`
  - `ln -sf /dev/ttyACM0 com1`
    - Overwrites com1 symlink to point to gimbal
    - Do this every time you start the program
- Run through Wine

## Gimbal Control

### Motion Scripting

[**See this Wiki page**](http://www.olliw.eu/storm32bgc-wiki/STorM32_Scripts)

- The following types exist:

```text
.scr = STorM32 on-board script (uploaded to gimbal, ran on-board)
.mcs = Motion Control script (ran on PC, sent to gimbal via USB)
.py  = Mission Planner Python script (ran on PC, sent to gimbal via USB)
```

#### `.mcs`

- `.mcs` scripts are a modified form of PERL code

#### Raw Python Control

- The GitHub repo contains a simplistic [python library](https://github.com/olliw42/storm32bgc/tree/master/py-library)
- See [this wiki page](http://www.olliw.eu/storm32bgc-wiki/Serial_Communication#Serial_Communication_-_RC_Commands) for details on serial comms with the gimbal control board
  - See [this wiki page](http://www.olliw.eu/storm32bgc-wiki/Code_Examples#Serial_Communication) for code examples

#### `.py` (Ardupilot Control)

- Uses [Ardupilot Planner](https://ardupilot.org/planner/)
- Could potentially use the following instead:
  - ROS
  - [DroneKit](https://dronekit-python.readthedocs.io/en/latest/)
