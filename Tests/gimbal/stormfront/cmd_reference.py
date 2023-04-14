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
    Enum of miscellaneous byte references
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
    CMD_ACK = b'\x96' #150

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
