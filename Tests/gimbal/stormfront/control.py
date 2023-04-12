"""
Simplistic class to interface with the STorM32 over a USB serial connection

Class construction based off the following:
- Python implementation from the STorM32 repo
- Script from RCGroups
- [Wiki page on serial comms with the gimbal](http://www.olliw.eu/storm32bgc-wiki/Serial_Communication)
- `o323BCGTool` GUI source code
"""

# todo implement serial commands
# todo implement RC commands
# todo lookup table for commands (CMD_SETPITCH = b'\x0A' etc.)
# todo instead of superclassing, make the serial manager a subclass with it's own functions
    # mainly functions like CMD_SETPITCH etc.

from builtins import object
import serial
import struct
import ctypes

import crc

class serial_man:
    """
    Serial manager class
    """
    # Static class variables ---------------------------------------------------

    # command bytes
    CMD_DSDDDDDDDSDSDASDSADDASS = b'\x22'
    CMD_SETPITCH = b'\x0A'
    CMD_SETROLL  = b'\x0B'
    CMD_SETYAW   = b'\x0C'

    # message bytes
    byte_incoming_start             = b'\xFB'
    byte_outgoing_start             = b'\xFA'
    byte_outgoing_start_no_response = b'\xF9'
    bytes_dummy_crc                 = b'\x33\x34'

    # message flags
    flag_unlimited_angles   = b'\x00'
    flag_all_limited_angles = b'\x07'

    # message payload data types
    type_gimbal_frame_euler_angles = b'\x00'

    def __init__(self, gimbal_port: str, baud: int,):
        self.ser = serial.Serial(port=gimbal_port, baudrate=baud)
        self.ser.flush()
        return

    # Class methods ------------------------------------------------------------

    def send(self, cmd_byte, payload, payload_len, crc_type='d'):
        """
        Constructs and sends a message to the gimbal.
        See [the serial comms wiki page](http://www.olliw.eu/storm32bgc-wiki/Serial_Communication)
        for info on packets.

        Arguments:
            `data_len`: Length of data / payload to send for the command type
            `crc_type`: Type of CRC to send with the command.
            `n` for no CRC, `h` for the lower byte of the CRC, `f` for the full CRC
            `d` for dummy CRC.
        """
        # b'\0xFA' = out startsign
        # x25crc(msg) ensure to strip first bit
        # msg = startsign + payload length + command byte + payload / data + crc word
        if crc_type == "d":
            msg = serial_man.byte_outgoing_start + payload_len + cmd_byte + payload + serial_man.bytes_dummy_crc

        self.ser.write(msg)

    def receive(self):
        return

    # Static methods -----------------------------------------------------------
    @staticmethod
    def float_to_bytes(num: float):
        return struct.pack("f", num)

    @staticmethod
    def encode_angle(angle: float):
        # Normalising angle to the range of [0, 360]
        angle = angle % 360

        # Encoding python angle int to C uint16_t type (with correct ranges)
        # todo unsure if necessary, not putting it in for the mean time

        # Float to bytes
        return serial_man.float_to_bytes(angle)

    @staticmethod
    def encode_to_ranged_uint16(self, num):
        # % 360 to get base angle
        # Map degrees to
        return

    @staticmethod
    def calculate_msg_len(self):
        return


class storm32(serial_man):
    def __init__(
            self,
            gimbal_port,
            baud,
            verbose=False,
            gimbal_response=True,
            request_resends=True,
        ):
        self.verbose         = verbose
        self.gimbal_response = gimbal_response
        self.request_resends = request_resends

        # Initialising subclass for serial comms
        super().__init__(gimbal_port, baud)

    # Getters ------------------------------------------------------------------
    def get_firmware_version(self):
        return

    def get_imu_angles(self):
        return

    # Setters ------------------------------------------------------------------
    def set_angles(self, pitch: float, roll: float, yaw: float):

        # Encode floats into formatted payload bytes
        pitch_payload = serial_man.encode_angle(pitch)
        roll_payload  = serial_man.encode_angle(roll)
        yaw_payload   = serial_man.encode_angle(yaw)

        # Sending commands to gimbal
        self.send(b'\x0A', pitch_payload, b'\x02', crc_type='d') # CMD_SETPITCH
        self.send(b'\x0B', roll_payload , b'\x02', crc_type='d') # CMD_SETROLL
        self.send(b'\x0C', yaw_payload  , b'\x02', crc_type='d') # CMD_SETYAW

        # self.send(self, b'\x11', payload, b'\x0E', crc_type='d') # CMD_SETANGLES
        return

    def set_angle_limits(self):
        return

    def enable_motors(self):
        return

    def disable_motors(self):
        return

    def center_gimbal(self):
        self.set_angles(self, 0.0, 0.0, 0.0)
        return
