#!/usr/bin/env python3

import time

gimbal_port = "/dev/ttyACM0"
baud = 115200

import stormfront.control as ctrl

# Globals for static pose assumption
# Angles in degrees
pitch     = 0.0
roll      = 0.0
yaw       = -360.0


gimbal = ctrl.storm32(gimbal_port, baud, verbose=True)
# gimbal.set_angles(pitch, roll, yaw)
# gimbal.set_yaw(yaw)

t1Hz_last = time.perf_counter()

# loop over various yaw values
while True:

    t_now = time.perf_counter()
    if t_now - t1Hz_last > 2.0:
        print("---------------------------")
        t1Hz_last += 2.0
        print('-- 0.5Hz --')

        gimbal.set_yaw(yaw)
        if yaw >= 360.0: yaw_dir = -1.0
        if yaw <= -360.0: yaw_dir = 1.0
        yaw += yaw_dir * 7.5

    available = gimbal.ser.in_waiting
    # time.sleep(0.1)
    if available > 0:
        c = gimbal.ser.read(available)
        c_formatted = ctrl.storm32.format_byte_string(c)
        print("<- ", c_formatted)
        # print("<- ", c)
