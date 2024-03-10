import time
import serial
from Globals import *


class AT:
    def __init__(self, com: str, baudrate: int) -> None:
        super().__init__()
        self.com = com
        self.baudrate = baudrate
        self.ser = serial.Serial(self.com, self.baudrate)
        self.ser.flushInput()
        self.rec_buff = ''

    def send_at(self, command: str, back: str, timeout: int) -> bool | str:
        """
        Send AT commands over serial. Returns 'False' on error or str on success.
        :param command: str
        :param back: str
        :param timeout: int
        :return: bool | str
        """
        self.ser.write((command + '\r\n').encode())
        time.sleep(timeout)
        if self.ser.inWaiting():
            time.sleep(BUFFER_WAIT_TIME)
            self.rec_buff = self.ser.read(self.ser.inWaiting())
        if back not in self.rec_buff.decode():
            print(command + ' ERROR')
            print(command + ' back:\t' + self.rec_buff.decode())
            return False
        else:
            return self.rec_buff.decode()
