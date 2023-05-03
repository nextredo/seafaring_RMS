gimbal_port = "/dev/ttyACM0"
baud = 115200

import time
import stormfront.control as ctrl

# Globals for static pose assumption
# Angles in degrees
pitch     = 0.0
roll      = 0.0
yaw       = 10.0


gimbal = ctrl.storm32(gimbal_port, baud, verbose=True)
# gimbal.set_angles(pitch, roll, yaw)
# gimbal.set_yaw(yaw)
gimbal.get_live_data()
gimbal.receive()
