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

class cmd_ref(Enum):
    """
    Enum of command reference bytes
    """
    CMD_SETPITCH  = b'\x0A' #10
    CMD_SETROLL   = b'\x0B' #11
    CMD_SETYAW    = b'\x0C' #12
    CMD_SETANGLES = b'\x11' #17

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
