#!/usr/bin/env python3

import STorM32_ctrl as ctrl
import time

gimbal = ctrl.STorM32("/dev/ttyACM0", 115200)
gimbal.set_angles(20.0, 20.0, 20.0)

# Run loop (for 5 sec) looking for responses from the board
t_end = time.time() + 5
while time.time() < t_end:
    available = gimbal.ser.in_waiting
    if available > 0:
        c = gimbal.ser.read(available)
        print("<- ", c)
