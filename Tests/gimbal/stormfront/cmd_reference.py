"""
File containing a reference for STorM32 serial command bytes, such as:
- command bytes
- miscellaneous bytes like;
    - start / stop bytes
    - dummy / test bytes
- flag bytes
- payload type bytes
Makes the codebase more readable

See [Serial Communication](http://www.olliw.eu/storm32bgc-wiki/Serial_Communication) on the wiki
[The STorM32 C control library](https://github.com/olliw42/storm32bgc/blob/master/c-library/STorM32_lib.h) is also VERY helpful
"""

from enum import Enum
from builtins import object

class simple_cmd_ref(Enum):
    PING                   = b't'
    VERSION                = b'v'
    GET_PARAMETERS         = b'g'
    SET_PARAMETERS         = b'p'
    GET_CURRENT_DATA       = b'd'
    GET_CURRENT_DATA_SHORT = b's'

class rc_cmd_ref(Enum):
    """
    Enum of command reference bytes
    """
    CMD_GETVERSION             = b'\x01' #1
    CMD_GETVERSIONSTR          = b'\x02' #2
    CMD_GETPARAMETER           = b'\x03' #3
    CMD_SETPARAMETER           = b'\x04' #4
    CMD_GETDATA                = b'\x05' #5
    CMD_GETDATAFIELDS          = b'\x06' #6
    CMD_SETPITCH               = b'\x0A' #10
    CMD_SETROLL                = b'\x0B' #11
    CMD_SETYAW                 = b'\x0C' #12
    CMD_SETPANMODE             = b'\x0D' #13
    CMD_SETSTANDBY             = b'\x0E' #14
    CMD_DOCAMERA               = b'\x0F' #15
    CMD_SETSCRIPTCONTROL       = b'\x10' #16
    CMD_SETANGLES              = b'\x11' #17
    CMD_SETPITCHROLLYAW        = b'\x12' #18
    CMD_SETPWMOUT              = b'\x13' #19
    CMD_RESTOREPARAMETER       = b'\x14' #20
    CMD_RESTOREALLPARAMETER    = b'\x15' #21
    CMD_SETINPUTS              = b'\x16' #22
    # CMD_SETHOMELOCATION        = b'\x17' #23 DEPRECATED
    # CMD_SETTARGETLOCATION      = b'\x18' #24 DEPRECATED
    CMD_SETINPUTCHANNEL        = b'\x19' #25
    CMD_SETCAMERA              = b'\x1A' #26
    CMD_SENDCAMERACOMMAND      = b'\x1B' #27
    CMD_SETANGLES_UNRESTRICTED = b'\x1C' #28
    CMD_ACTIVEPANMODESETTING   = b'\x64' #100
    # CMD_CONNECT                = b'\xD2' #210 DEPRECATED
    # CMD_GETDATADISPLAY         = b'\xD5' #213 DEPRECATED
    # CMD_WIFICONNECTEDPING      = b'\xD7' #215 DEPRECATED
    # CMD_STORM32LINK_V1         = b'\xD9' #217 DEPRECATED
    # CMD_STORM32LINK_V2         = b'\xDA' #218 SPECIAL

class byte_ref(Enum):
    """
    Enum of miscellaneous byte references.
    `incoming` / `outgoing` are from Python's point of view.
    """
    byte_incoming_start             = b'\xFB'
    byte_outgoing_start             = b'\xFA'
    byte_outgoing_start_no_response = b'\xF9'
    bytes_dummy_crc                 = b'\x33\x34'

class flag_ref(Enum):
    """
    Enum of flags references
    """
    flag_unlimited_angles   = b'\x00'
    flag_all_limited_angles = b'\x07'

class type_ref(Enum):
    """
    Enum of payload type references
    """
    type_gimbal_frame_euler_angles = b'\x00'

class response_ref(Enum):
    CMD_GETVERSION    = b'\x00' #1
    CMD_GETVERSIONSTR = b'\x02' #2
    CMD_GETPARAMETER  = b'\x03' #3
    CMD_GETDATA       = b'\x05' #5
    CMD_GETDATAFIELDS = b'\x06' #6
    CMD_ACK           = b'\x96' #150

# STorM32 states
class state_ref(Enum):
    STARTUP_MOTORS         = b'\x00\x00'
    STARTUP_SETTLE         = b'\x00\x01'
    STARTUP_CALIBRATE      = b'\x00\x02'
    STARTUP_LEVEL          = b'\x00\x03'
    STARTUP_MOTORDIRDETECT = b'\x00\x04'
    STARTUP_RELEVEL        = b'\x00\x05'
    NORMAL                 = b'\x00\x06'
    STARTUP_FASTLEVEL      = b'\x00\x07'

# flags for reading live data from the STorM32, requested with CMD_GETDATAFIELDS (#6)

class live_data_ref(Enum):
    STATUS_V1         = b'\x00\x01'
    TIMES             = b'\x00\x02'
    IMU1GYRO          = b'\x00\x04'
    IMU1ACC           = b'\x00\x08'
    IMU1R             = b'\x00\x10'
    IMU1ANGLES        = b'\x00\x20'
    PIDCTRL           = b'\x00\x40'
    INPUTS            = b'\x00\x80'
    IMU2ANGLES        = b'\x01\x00'
    MAGANGLES         = b'\x02\x00'
    STORM32LINK       = b'\x04\x00'
    IMUACCCONFIDENCE  = b'\x08\x00'
    # ATTITUDE_RELATIVE = b'\x10\x00' # only available in firmwares >v0.96 (T-STorM-32)
    # STATUS_V2         = b'\x20\x00' # only available in firmwares >v0.96 (T-STorM-32)
    # ENCODERANGLES     = b'\x40\x00' # only available in firmwares >v0.96 (T-STorM-32)
    # IMUACCABS         = b'\x80\x00' # only available in firmwares >v0.96 (T-STorM-32)

live_data_ref_decode = {
    b'\x00\x01': 'STATUS_V1',
    b'\x00\x02': 'TIMES',
    b'\x00\x04': 'IMU1GYRO',
    b'\x00\x08': 'IMU1ACC',
    b'\x00\x10': 'IMU1R',
    b'\x00\x20': 'IMU1ANGLES',
    b'\x00\x40': 'PIDCTRL',
    b'\x00\x80': 'INPUTS',
    b'\x01\x00': 'IMU2ANGLES',
    b'\x02\x00': 'MAGANGLES',
    b'\x04\x00': 'STORM32LINK',
    b'\x08\x00': 'IMUACCCONFIDENCE',
}

class pan_mode_ref(Enum):
    OFF            = b'\x00'
    HOLD_HOLD_PAN  = b'\x01'
    HOLD_HOLD_HOLD = b'\x02'
    PAN_PAN_PAN    = b'\x03'
    PAN_HOLD_HOLD  = b'\x04'
    PAN_HOLD_PAN   = b'\x05'
    HOLD_PAN_PAN   = b'\x06'


class do_camera_ref(Enum):
    STORM32DOCAMERA_OFF      = b'\x00'
    STORM32DOCAMERA_SHUTTER  = b'\x01'
    STORM32DOCAMERA_VIDEOON  = b'\x03'
    STORM32DOCAMERA_VIDEOOFF = b'\x04'


class link_fc_status_ref(Enum):
    AP_AHRS_HEALTHY     = b'\x01' # => Q ok, ca. 15 secs
    AP_AHRS_INITIALIZED = b'\x02' # => vz ok, ca. 32 secs
    AP_GPS_3DFIX        = b'\x04' # ca 60-XXs
    AP_NAVHORIZVEL      = b'\x08' # comes very late, after GPS fix and few secs after position_ok()
    AP_ARMED            = b'\x40' # tells when copter is about to take-off
    IS_ARDUPILOT        = b'\x80' # permanently set if it's ArduPilot, so STorM32 knows about and can act accordingly


class len_ref(Enum):
    header_len = 3
    crc_len    = 2
    frame_len  = 5
    max_response_len = 77


# class ack_ref(Enum):
#     ACK_OK                = b'\x00'
#     ACK_ERR_FAIL          = b'\x01'
#     ACK_ERR_ACCESS_DENIED = b'\x02'
#     ACK_ERR_NOT_SUPPORTED = b'\x03'
#     ACK_ERR_TIMEOUT       = b'\x96' # 150 in decimal
#     ACK_ERR_CRC           = b'\x97' # 151 in decimal
#     ACK_ERR_PAYLOADLEN    = b'\x98' # 152 in decimal

ack_ref = {
    b'\x00': 'ACK_OK',
    b'\x01': 'ACK_ERR_FAIL',
    b'\x02': 'ACK_ERR_ACCESS_DENIED',
    b'\x03': 'ACK_ERR_NOT_SUPPORTED',
    b'\x96': 'ACK_ERR_TIMEOUT',
    b'\x97': 'ACK_ERR_CRC',
    b'\x98': 'ACK_ERR_PAYLOADLEN'
}

# todo shouldn't need these. Just embed the values as part of the methods the
# user calls to do stuff to / get stuff from the gimbal
#define STORM32RCCMD_GET_VERSIONSTR_OUTLEN       0x00
#define STORM32RCCMD_GET_DATAFIELDS_OUTLEN       0x02
#define STORM32RCCMD_SET_PANMODE_OUTLEN          0x01
#define STORM32RCCMD_DO_CAMERA_OUTLEN            0x06
#define STORM32RCCMD_SET_ANGLES_OUTLEN           0x0E
#define STORM32RCCMD_SET_PITCHROLLYAW_OUTLEN     0x06
#define STORM32RCCMD_SET_PWMOUT_OUTLEN           0x02
#define STORM32RCCMD_SET_INPUTS_OUTLEN           0x17
#define STORM32RCCMD_SET_HOMELOCATION_OUTLEN     0x0E
#define STORM32RCCMD_SET_TARGETLOCATION_OUTLEN   0x0E
#define STORM32RCCMD_SET_INPUTCHANNEL_OUTLEN     0x04
#define STORM32RCCMD_SET_SETCAMERA_OUTLEN        0x04
#define STORM32RCCMD_ACTIVEPANMODESETTING_OUTLEN 0x01
#define STORM32RCCMD_STORM32LINKV2               0x21

# class parameter_ref(Enum):
#     d = "d"

# todo change enums to the below
# class command():
#     def __init__(self,cmd_string, cmd_byte: bytes, payload_len: bytes):
#         self.cmd_string = cmd_string
#         self.cmd_byte = cmd_byte
#         self.payload_len = payload_len

# class cmd_ref_v2(Enum):
#     CMD_SETPITCH = command("CMD_SETPITCH", b'\x0A', b'\x02')
#     CMD_SETROLL  = command("CMD_SETROLL", b'\x0B', b'\x02')
#     CMD_SETYAW   = command("CMD_SETYAW", b'\x0C', b'\x02')


# test = command(b"\x33", b"\xdd")
# test.cmd_byte
# cmd_ref_v2.CMD_SETPITCH.cmd_byte

"""
Storage:
cmds = {
    "CONNECTION_CHECK": {
        "cmd_byte":   't',
        "payload_len": 2 ,
        "crc_type":   'n',
    },
}
"""
