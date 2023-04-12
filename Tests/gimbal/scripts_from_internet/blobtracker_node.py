#!/usr/bin/env python

# From https://cdn.hackaday.io/files/1592126811726208/blobtracker_node.py
# OpenCV blob tracking ROS node
# input is image msgs, outputs twist messages,
# and directly controls gimbal over serial
# TODO: separate gimbal control into another node
# relies on camera node (picamera_node) and base controller node (mmdriver_node)
# Wes Freeman 2018


import binascii
import time
import imutils
import cv2
from cv_bridge import CvBridge, CvBridgeError
import serial
import crc16
import rospy
from geometry_msgs.msg import Twist
from sensor_msgs.msg import CameraInfo, Image

# serial to STorM32
ser = serial.Serial(
   port='/dev/ttyAMA0', # was ttyS0
   baudrate = 115200,
   parity=serial.PARITY_NONE,
   stopbits=serial.STOPBITS_ONE,
   bytesize=serial.EIGHTBITS,
   timeout=1
)

class globs():
    blobYaw = 0.0
    blobPitch = 0.0
    blobFound = False
    blobRadius = 0 # pixels
    frametimer=time.time()

# intToBytes func splits a 16b integer into 2 8bit hex,
# strips off the "0x" part,
# and makes sure there's 2 digits; "0f" not "f"
# used to help construct serial commands for gimbal controller
def intToBytes(num):
    high = hex(num >> 8)
    high = high[2:] # trim off 0x
    if len(high) < 2: # if just one char
            high = '0' + high # add leading zero
    low = hex(num & 0xFF)
    low = low[2:]
    if len(low) < 2: # if just one char
            low = '0' + low # add leading zero
    return high, low

# limit values to a safe range
def clamp(value, upper, lower):
    if value > upper:
        out = upper
    elif value < lower:
        out = lower
    else:
        out = value
    return out

# MOVE BODY
# based on blob position, by sending twist msgs on cmd_vel
# needs to be compatible with joystick node and move_base node
# mmdriver_node expects float 0...1, default for Twist anyway?

# init twist message
vel_msg = Twist()

# init values. (no strafing implemented)
vel_msg.linear.x = 0
vel_msg.linear.y = 0
vel_msg.linear.z = 0
vel_msg.angular.x = 0
vel_msg.angular.y = 0
vel_msg.angular.z = 0

def move_body():

    if globs.blobFound == True:
        # if blob too far away, walk toward, if blob too close, walk backward:
        if(globs.blobRadius < 10):
            vel_msg.linear.y = 0.5
            #print 'forward'
        elif(globs.blobRadius > 40):
            vel_msg.linear.y = -0.5
            #print 'back'
        else:
            vel_msg.linear.y = 0.0

        # if gimbal at its yaw limit, turn robot to bring blob back in view
        # with wide cameras, FOV can be bigger than gimbal range:
        if(globs.blobYaw < -45):
            #print 'right \r'
            vel_msg.angular.z = 0.2 # arbitrarily chosen low value
        elif (globs.blobYaw > 45):
            #print 'left \r'
            vel_msg.angular.z = -0.2
        else:
            vel_msg.angular.z = 0.0

    else:
        vel_msg.linear.y = 0.0
        vel_msg.angular.z = 0.0

    velocity_publisher.publish(vel_msg)

# GIMBAL CONTROL

# angle range represented by servo range depends on mapping in STorM32.
# values from 700 to 2300, range 1600, centre 700+800 = 1500
# increases CCWise??
# currently yaw is set to  -45 to +45 in STorM32 firmware.
# pitch is -45 to +45
# so +45 deg should equal servo 2300

# TODO - CHECK CONTROLLER SETTINGS

yawRatio = 800/45
pitchRatio = 800/45

scaling = 0.3 # trying to combat overshoot. Controller already has accel curve.

# Storm commands:
# CMD_SETYAW (#12)
# 0xFA 0x02 0x0C data-low-byte data-high-byte crc-low-byte crc-high-byte
CMD_SETYAW='020C' # 16b command without CRC part

# CMD_SETPITCH (#10)
# 0xFA 0x02 0x0A data-low-byte data-high-byte crc-low-byte crc-high-byte
CMD_SETPITCH='020A' # 16b command without CRC part


#  funcs gimbal() and yawpitch() send Yaw and Pitch command to gimbal controller
def gimbal():

    # convert to servo val:
    # from 700 to 2300, range 1600,
    # centre 700+800 = 1500
    yawServo = int(1500 + (globs.blobYaw * yawRatio * scaling))
    pitchServo = int(1500 + (globs.blobPitch * pitchRatio * scaling))

    # clamp
    yawServo = clamp(yawServo, 2300, 700)
    pitchServo = clamp(pitchServo, 2300, 700)

    YawPitch(CMD_SETYAW, yawServo)
    YawPitch(CMD_SETPITCH, pitchServo)


# serialise for STorM32
def YawPitch(command, servo):

    cmdStart = 'FA' # standard startsign, not included in CRC!

    cmd = command

    # convert to hex bytes format:
    servoHigh, servoLow = intToBytes(servo)

    # add angle bytes to control hex string
    cmd += servoLow
    cmd += servoHigh

    # get CRC of control string
    cmd = str.encode(cmd) # to bytes format
    crc = crc16.crc16xmodem(cmd) # CRC-CCITT (XModem) format
    crcHigh, crcLow = intToBytes(crc)

    # build complete control string:
    serialOut = cmdStart+cmd+crcLow+crcHigh
    serialOut = serialOut.upper() # uppercase
    serialOut = str.encode(serialOut) # convert to bytes
    #print 'to gimbal:', serialOut, '\r'

    # reformat from "0f" to "\x0f" and send
    ser.write(binascii.unhexlify(serialOut))



# BLOB DETECTION

# blob colour definition
# define the lower and upper boundaries of the object colour in HSV
#
# colour pickers tend to use 0-360 for H, 0-100 for S & V
# OpenCV uses  H: 0 - 180, S: 0 - 255, V: 0 - 255.
# convert H: * 180/360; 0.5
# convert S & V: * 255/100; 2.55
#
# some preset colour ranges:
greenLower = (39, 86, 6)
greenUpper = (80, 255, 255)
orangeLower = (5, 80, 6)
orangeUpper = (22, 255, 255)
#blueLower = (85, 128, 128) # using android color picker app on real object
#blueUpper = (105, 255, 255)
blueLower = (95, 79, 23) # using gpick on Ubuntu on camera feed
blueUpper = (105, 255, 189)
# choose colour to use:
colourLower = blueLower
colourUpper = blueUpper

FOV_x = 120 # camera FOV, degrees
FOV_y = 106

bridge = CvBridge()



def image_received_callback(frame):

    # convert ROS image format to openCV image format
    try:
        cv_image = bridge.imgmsg_to_cv2(frame, "bgr8")
    except CvBridgeError as e:
        print(e)

    (resY,resX,channels) = cv_image.shape

    # convert frame to HSV colour, leaving original
    hsv = cv2.cvtColor(cv_image, cv2.COLOR_BGR2HSV)

    # mask the colour, then dilations and erosions to remove any small
    # blobs left in the mask
    mask = cv2.inRange(hsv, colourLower, colourUpper)
    mask = cv2.erode(mask, None, iterations=2)
    mask = cv2.dilate(mask, None, iterations=2)

    # find contours in the mask and initialize the current
    # (x, y) center of the ball
    cnts = cv2.findContours(mask.copy(), cv2.RETR_EXTERNAL,
            cv2.CHAIN_APPROX_SIMPLE)[-2]
    center = None

    # only proceed if at least one contour was found
    if len(cnts) > 0:

        globs.blobFound = True

        # find the largest contour in the mask, then use
        # it to compute the minimum enclosing circle and centroid
        c = max(cnts, key=cv2.contourArea)
        ((x, y), globs.blobRadius) = cv2.minEnclosingCircle(c)
        M = cv2.moments(c)
        center = (int(M["m10"] / M["m00"]), int(M["m01"] / M["m00"]))

        # draw circle and centroid on frame, then update list of tracked points
        cv2.circle(cv_image, (int(x), int(y)), int(globs.blobRadius), (0, 255, 255), 2)
        cv2.circle(cv_image, center, 5, (0, 0, 255), -1)

        # split location of object:
        objX, objY = center

        # convert to approx angle
        # x is 0-320 px, offset so centre is 0,0: runs from -160 to +160
        objX = int(objX-(resX/2))
        objY = int(objY-(resY/2))

        # convert position to degrees
        globs.blobYaw = -1*(float(objX * FOV_x/resX))  # reversed
        globs.blobPitch = float(objY * FOV_y/resY)


    else:
        globs.blobFound = False
        # reset gimbal to centre if no object:
        globs.blobYaw = 0.0
        globs.blobPitch = 0.0

    # Gimbal control
    gimbal()

    # body control
    move_body()


    # publish CV-modified image
    #print 'publishing CV image'
    try:
        cv_publisher.publish(bridge.cv2_to_imgmsg(cv_image, "bgr8"))
    except CvBridgeError as e:
        print(e)

    # console info
    if time.time() > globs.frametimer +1.0:
        globs.frametimer=time.time()
        if globs.blobFound == True:
            print 'Blob centre:', objX, objY, 'yaw, pitch:', globs.blobYaw, globs.blobPitch ,'radius:', globs.blobRadius, '\r'
        else:
            print 'cam: no blob found \r'

# 'MAIN'

# startup ros node:

rospy.init_node('blobtracker')

# Setup subscriber for camera images
rospy.Subscriber('/stereo_camera/left/image_raw', Image, image_received_callback)

# setup publisher for motion twist
velocity_publisher = rospy.Publisher('/cmd_vel', Twist, queue_size=10)

# setup publisher for CV result
cv_publisher = rospy.Publisher('image_blob', Image, queue_size=1)

# loop
try:
    rospy.spin()

except KeyboardInterrupt:
    print "Shutting down"
    globs.blobYaw = 0
    blobPitch = 0
    gimbal()
    move_body()





