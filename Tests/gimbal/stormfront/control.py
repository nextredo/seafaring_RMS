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
# todo instead of superclassing, make the serial manager a subclass with its own functions
# todo fix angle ranging inconsistencies (should always be [-360, 360])
    # mainly functions like CMD_SETPITCH etc.
# todo pygame keyboard control
# todo functions to read min and maxes for axes
# todo figure out how to make
# todo serial response decoded

import struct
import time

import serial
from colorama import Fore
from colorama import Style

from .crc import x25crc
from .cmd_reference import *

# todo make these class vars that are acutally read from teh gimbal
MIN_ANGLE = -95
MAX_ANGLE = +95

# Used to increment colour in serial_man.format_byte_string()
colours = [
    Fore.BLACK,
    Fore.RED,
    Fore.GREEN,
    Fore.YELLOW,
    Fore.BLUE,
    Fore.MAGENTA,
    Fore.CYAN,
    Fore.WHITE,
]

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
            crc = byte_ref.bytes_dummy_crc.value
            start_byte = byte_ref.byte_outgoing_start.value

        msg = start_byte + payload_len + cmd_byte + payload + crc
        self.ser.write(msg)

        if self.verbose:
            print(f"Start byte: 0x{start_byte.hex()}")
            print(f"Payload len byte: 0x{payload_len.hex()}")
            print(f"Cmd byte: 0x{cmd_byte.hex()}")
            print(f"Payload: 0x{payload.hex()}")
            print(f"CRC: 0x{crc.hex()}")

        return msg

    def receive(self, seconds=2):
        """
        Method to receive a packet from the gimbal.
        Call after sending a message,

        Arguments:
            `seconds` - Time to wait before beginning reception. Allows serial buffer
            to collect data before decoding the packet (otherwise partial packets are decoded).
        """

        if self.verbose: print("---- receiving ----")

        time.sleep(seconds)
        available = self.ser.in_waiting
        if available > 0:
            # get packet as byte str, reading n bytes from serial interface
            received = self.ser.read(available)

            if self.verbose:
                received_formatted = serial_man.format_byte_string(received)
                print("<- ", received_formatted)

            # check startsign byte
            if bytes([received[0]]) == byte_ref.byte_incoming_start.value:

                # check command byte (using elif as match case only > Python 3.10)
                # sends packet to relevant decoding function
                if   bytes([received[2]]) == response_ref.CMD_ACK.value:
                    self.decode_ack(received)
                elif bytes([received[2]]) == response_ref.CMD_GETDATA.value:
                    self.decode_getdata(received)
                elif bytes([received[2]]) == response_ref.CMD_GETDATAFIELDS.value:
                    self.decode_getdatafields(received)
                elif bytes([received[2]]) == response_ref.CMD_GETPARAMETER.value:
                    self.decode_getparameter(received)
                elif bytes([received[2]]) == response_ref.CMD_GETVERSION.value:
                    self.decode_getversion(received)
                elif bytes([received[2]]) == response_ref.CMD_GETVERSIONSTR.value:
                    self.decode_getversionstr(received)

        # check if packet was fully decoded (that nothing is waiting in serial)
        if self.ser.in_waiting:
            print("Potential partial packet decode?")

        print("---- received ----\n")

        return

    def listen(self, seconds=3):
        """
        Method to read bytes from board (without decode) for `n` seconds.
        """

        time.sleep(0.1)
        t_end = time.time() + seconds
        while time.time() < t_end:
            available = self.ser.in_waiting
            if available > 0:
                c = self.ser.read(available)
                c_formatted = storm32.format_byte_string(c)
                print("<- ", c, "\t", c_formatted)
                # print("<- ", c)

    def check_crc(self, packet):
        # todo stub
        ...
        return True

    def decode_ack(self, packet: bytes):

        # ensure crc check passes
        if not self.check_crc(packet): return False

        # payload len should always be 1 for ACK message
        if packet[1] == 1:
            # print message received
            print(ack_ref.get(bytes([packet[3]]), "bad ack received"))

        return True

    def decode_getdata(self, packet: bytes):
        ...
        return

    def decode_getdatafields(self, packet: bytes):

        # ensure crc check passes
        if not self.check_crc(packet): return False

        # bytes 3 & 4 in reverse order = type of data being received here
        # bitmask_word = packet[4:2:-1]

        # bytes 3 & 4 in normal order = type of data being received here
        bitmask_word = packet[3:5:1]
        print(live_data_ref_decode[bitmask_word] + "\t")
        print("packet payload len:" + str(packet[2]))

        # loop over datastream in packet (from byte 5 until end (excl. last 2 bytes for CRC))
        # for i in range(5, 5 + packet[2]):
        #     print(packet[i])

        # print datastream as a big hex value
        print("data: " + serial_man.format_byte_string(packet[5:5+packet[2]]))

        return True

    def decode_getparameter(self, packet: bytes):
        ...
        return

    def decode_getversion(self, packet: bytes):
        ...
        return

    def decode_getversionstr(self, packet: bytes):
        ...
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
    def format_byte_string(command: str | bytes, hex_prefix=True, coloured=True):
        if type(command) == str:
            hex_str = bytes(command, "utf-8").hex()

        elif type(command) == bytes:
            hex_str = command.hex()

        # Make hex values uppercase
        formatted_command = hex_str.upper()

        if coloured:
            # turn string into list
            coloured_command = []
            current_colour_idx = 0
            for string_idx, char in enumerate(formatted_command):
                coloured_command.append(formatted_command[string_idx])

                # if index in string is even, increment colour
                if string_idx % 2:
                    current_colour_idx += 1
                    current_colour_idx = current_colour_idx % len(colours)
                    coloured_command.append(colours[current_colour_idx])

            # reset string colouring
            coloured_command.append(Style.RESET_ALL)
            formatted_command = "".join(coloured_command)

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

        if angle > MAX_ANGLE:
            mangle = MAX_ANGLE
            print("Angle > MAX_ANGLE, clipped to MAX_ANGLE")
        elif angle < MIN_ANGLE:
            mangle = MIN_ANGLE
            print("Angle < MIN_ANGLE, clipped to MIN_ANGLE")
        else:
            mangle = angle

        print(f"Angle: {angle} --> {mangle}")

        if payload_encoding == "float":
            return serial_man.float_to_bytes(mangle)

        elif payload_encoding == "mapped_int":
            mapped_int = int(serial_man.map_range(mangle, MIN_ANGLE, MAX_ANGLE, 700, 2300))
            print(f"mapped_int: {mapped_int}")
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
        ...
        return

    def get_live_data(self):

        if self.verbose:
            print("--------------------------")
            print(rc_cmd_ref.CMD_GETDATAFIELDS.name)

        payload = b''.join([

        ])

        data_msg = self.send(
            cmd_byte=rc_cmd_ref.CMD_GETDATAFIELDS.value,
            payload=live_data_ref.IMU1ANGLES.value,
            payload_len=b'\x02',
        )
        if self.verbose:
            print("->", serial_man.format_byte_string(data_msg))
            print("------ sent ------\n")


    def get_imu_angles(self):
        ...
        return

    # Setters ------------------------------------------------------------------
    # --------------------------------------------------------------------------
    def set_angles(self, pitch: float, roll: float, yaw: float):

        if self.verbose:
            print("--------------------------")
            print(rc_cmd_ref.CMD_SETANGLES.name)

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
            cmd_byte=rc_cmd_ref.CMD_SETANGLES.value,
            payload=payload,
            payload_len=int.to_bytes(len(payload)),
        )

        if self.verbose:
            print("->", serial_man.format_byte_string(set_angles_msg))
            print("------ sent ------\n")

        return

    def set_pitch(self, pitch: float):
        ...
        return

    def set_roll(self, roll: float):
        ...
        return

    def set_yaw(self, yaw: float):

        if self.verbose:
            print("--------------------------")
            print(rc_cmd_ref.CMD_SETYAW.name)

        yaw_payload = serial_man.encode_angle(yaw, "mapped_int")
        yaw_msg     = self.send(rc_cmd_ref.CMD_SETYAW.value, yaw_payload, b'\x02')

        if self.verbose:
            print("->", serial_man.format_byte_string(yaw_msg))
            print("------ sent ------\n")

        return

    def set_angle_limits(self):
        ...
        return

    def enable_motors(self):
        ...
        return

    def disable_motors(self):
        ...
        return

    def restart_gimbal(self):
        ...
        # Necessary as sometimes control loop can become baked from large disturbances
        return

    def center_gimbal(self):
        self.set_angles(self, 0.0, 0.0, 0.0)
        return
