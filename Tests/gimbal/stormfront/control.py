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

import struct
import ctypes

import serial

from .crc import x25crc
from .cmd_reference import cmd_ref, byte_ref, flag_ref, type_ref

class serial_man:
    def __init__(self, gimbal_port: str, baud: int):
        self.ser = serial.Serial(port=gimbal_port, baudrate=baud)
        self.ser.flush()
        return

    # Class methods ------------------------------------------------------------
    # --------------------------------------------------------------------------
    def send(
            self,
            cmd_byte: bytes,
            payload: bytes,
            payload_len: bytes,
            flags=b'',
            payload_type=b'',
            crc_type='d'
        ):
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
        if crc_type == "d":
            msg = byte_ref.byte_outgoing_start.value + payload_len + cmd_byte + payload + flags + payload_type + byte_ref.bytes_dummy_crc.value

        self.ser.write(msg)
        return msg

    def receive(self):
        return

    # Static methods -----------------------------------------------------------
    # --------------------------------------------------------------------------
    @staticmethod
    def format_cmd_string(command: str | bytes, hex_prefix=True):
        if type(command) == str:
            hex_str = bytes(command, "utf-8").hex()

        elif type(command) == bytes:
            hex_str = command.hex()

        # Make hex values uppercase
        formatted_command = hex_str.upper()

        if hex_prefix:
            formatted_command = "0x" + formatted_command

        return formatted_command

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
    def encode_to_ranged_uint16(num):
        # % 360 to get base angle
        # Map degrees to range [700, 2300]

        # Convert to int in range

        # Encode as uint16_t

        # Swap low byte and high byte
        return

    @staticmethod
    def calculate_msg_len():
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
    # --------------------------------------------------------------------------
    def get_firmware_version(self):
        return

    def get_imu_angles(self):
        return

    # Setters ------------------------------------------------------------------
    # --------------------------------------------------------------------------
    def set_angles(self, pitch: float, roll: float, yaw: float):

        # Encode floats into formatted payload bytes
        pitch_payload = serial_man.encode_angle(pitch)
        roll_payload  = serial_man.encode_angle(roll)
        yaw_payload   = serial_man.encode_angle(yaw)

        # Packing encoded floats into single payload
        payload = b''.join([
            pitch_payload,
            roll_payload,
            yaw_payload
        ])

        # Sending command to gimbal
        set_angles_msg = self.send(
            cmd_byte=cmd_ref.CMD_SETANGLES.value,
            payload=payload,
            payload_len=b'\x0E',
            flags=b'\x00',
            payload_type=b'\x00',
            crc_type='d'
        )

        if self.verbose:
            print("->", serial_man.format_cmd_string(set_angles_msg, hex_prefix=False))

        return

    def set_pitch(self, pitch: float):
        return

    def set_roll(self, roll: float):
        return

    def set_yaw(self, yaw: float):
        yaw_payload = serial_man.encode_angle(yaw)
        yaw_msg     = self.send(cmd_ref.CMD_SETYAW.value, yaw_payload, b'\x02', crc_type='d')

        if self.verbose:
            print("->", serial_man.format_cmd_string(yaw_msg, hex_prefix=False))

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
