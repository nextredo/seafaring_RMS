#!/usr/bin/env python3

import time

gimbal_port = "/dev/ttyACM1"
baud = 115200

import stormfront.control as ctrl

# Globals for static pose assumption
# Angles in degrees
pitch     = 0.0
roll      = 0.0
yaw       = -179.0


gimbal = ctrl.storm32(gimbal_port, baud, verbose=True)
# gimbal.set_angles(pitch, roll, yaw)
gimbal.set_yaw(yaw)

# Run loop (for 5 sec) looking for responses from the board
t_end = time.time() + 5
while time.time() < t_end:
    available = gimbal.ser.in_waiting
    # time.sleep(0.1)
    if available > 0:
        c = gimbal.ser.read(available)
        c_formatted = ctrl.storm32.format_cmd_string(c)
        print("<- ", c, "\t", c_formatted)
        # print("<- ", c)
