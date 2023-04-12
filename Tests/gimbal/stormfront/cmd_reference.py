"""
File containing a reference for STorM32 serial command bytes, such as:
- command bytes
- miscellaneous bytes like;
    - start / stop bytes
    - dummy / test bytes
- flag bytes
- payload type bytes
Makes the codebase more readable
"""
from enum import Enum

class cmd_ref(Enum):
    """
    Enum of command reference bytes
    """
    CMD_SETPITCH = b'\x0A'
    CMD_SETROLL  = b'\x0B'
    CMD_SETYAW   = b'\x0C'

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
