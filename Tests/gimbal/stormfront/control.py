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
# todo fix angle ranging inconsistencies (should always be [-360, 360])
    # mainly functions like CMD_SETPITCH etc.

import struct

import serial

from .crc import x25crc
from .cmd_reference import cmd_ref, byte_ref, flag_ref, type_ref


MIN_ANGLE = -180
MAX_ANGLE =  180

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
        if crc_type == 'd':
            msg = byte_ref.byte_outgoing_start.value + payload_len + cmd_byte + payload + byte_ref.bytes_dummy_crc.value

        self.ser.write(msg)
        return msg

    def receive(self):
        return

    # Static methods -----------------------------------------------------------
    # --------------------------------------------------------------------------

    @staticmethod
    def map_range(
            x: float | int,
            in_min: float | int,
            in_max: float | int,
            out_min: float | int,
            out_max: float | int
        ):
        """
        From this link: [Arduino map function - python equivalent](https://stackoverflow.com/questions/70643627/python-equivalent-for-arduinos-map-function)
        """
        return (x - in_min) * (out_max - out_min) // (in_max - in_min) + out_min

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
    def int_to_bytes(num: int):
        # encode as unsigned 2 bit (ushort) int, with reversed byte order
        return num.to_bytes(length=2)[::-1]

    @staticmethod
    def encode_angle(angle: float | int, payload_encoding: str):
        """
        Parameters:
            `payload_encoding`: Either `mapped_int` or `float`
        """
        # Normalising angle (degrees) to the range of [MIN_ANGLE, MAX_ANGLE]
        if   angle >= 0: mangle = angle % MAX_ANGLE
        else:            mangle = angle % MIN_ANGLE
        print("mapped angle: ", mangle)

        if payload_encoding == "float":
            return serial_man.float_to_bytes(mangle)

        elif payload_encoding == "mapped_int":
            mapped_int = int(serial_man.map_range(mangle, MIN_ANGLE, MAX_ANGLE, 700, 2300))
            return serial_man.int_to_bytes(mapped_int)


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
        pitch_payload = serial_man.encode_angle(pitch, "float")
        roll_payload  = serial_man.encode_angle(roll,  "float")
        yaw_payload   = serial_man.encode_angle(yaw,   "float")

        # Packing encoded floats (+ flags + payload type) into single payload
        payload = b''.join([
            pitch_payload,                                # Encoded pitch float
            roll_payload,                                 # Encoded roll float
            yaw_payload,                                  # Encoded yaw float
            flag_ref.flag_unlimited_angles.value,         # Flags
            type_ref.type_gimbal_frame_euler_angles.value # Payload type
        ])

        # Sending command to gimbal
        set_angles_msg = self.send(
            cmd_byte=cmd_ref.CMD_SETANGLES.value,
            payload=payload,
            payload_len=int.to_bytes(len(payload)),
            crc_type='d'
        )

        if self.verbose:
            print(cmd_ref.CMD_SETANGLES.name)
            print(f"{pitch}, {roll}, {yaw} degrees")
            print("->", serial_man.format_cmd_string(set_angles_msg, hex_prefix=False))

        return

    def set_pitch(self, pitch: float):
        return

    def set_roll(self, roll: float):
        return

    def set_yaw(self, yaw: float):
        yaw_payload = serial_man.encode_angle(yaw, "mapped_int")
        yaw_msg     = self.send(cmd_ref.CMD_SETYAW.value, yaw_payload, b'\x02', crc_type='d')

        if self.verbose:
            print(cmd_ref.CMD_SETYAW.name)
            print(f"{yaw} degrees")
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
