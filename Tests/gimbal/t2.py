#!/usr/bin/env python

gimbal_port = "/dev/ttyACM0"
baud = 115200

import time
import stormfront.control as ctrl
import stormfront.cmd_reference as cmdr

# Globals for static pose assumption
# Angles in degrees
pitch     = 0.0
roll      = 0.0
yaw       = 10.0


gimbal = ctrl.storm32(gimbal_port, baud, verbose=True)
# gimbal.set_angles(pitch, roll, yaw)
# gimbal.set_yaw(yaw)
gimbal.get_live_data(cmdr.live_data_ref.IMU2ANGLES.value)
gimbal.receive()
