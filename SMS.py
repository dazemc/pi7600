#!/usr/bin/python

import serial
import time
import os
import sys


# import RPi.GPIO as GPIO

try:
    if float(sys.version[:sys.version[2:].find('.') + 2]) < 3.10:
        print("Python version must be 3.10 or greater, buildpy.sh will build latest release from source")
        print("\nExiting...")
        sys.exit(1)
except:
    if input("Python version check failed. Depends on 3.10 or greater, continue anyways(y/N?") == "":
        print("\nExiting...")
        sys.exit(1)

class SMS:
    def __init__(self) -> None:
        self.ser = serial.Serial("/dev/ttyUSB2", 115200)  # pi zero w should always be USB2@115200
        self.ser.flushInput()

        self.phone_number = os.environ.get(
            'CELL',  # Can be hardcoded as str, but environment variable is best practice.
        )
        self.rec_buff = ''

    def send_at(self, command: str, back: str, timeout: int) -> bool | str:
        """
        Send AT commands over serial. Returns 'False' on error or str on success.
        :param command: str
        :param back: str
        :param timeout: int
        :return: bool | str
        """
        self.rec_buff = ''
        self.ser.write((command + '\r\n').encode())
        time.sleep(timeout)
        if self.ser.inWaiting():
            time.sleep(0.01)
            self.rec_buff = self.ser.read(self.ser.inWaiting())
        if back not in self.rec_buff.decode():
            print(command + ' ERROR')
            print(command + ' back:\t' + self.rec_buff.decode())
            return False
        else:
            return self.rec_buff.decode()

    def receive_message(self, message_type: str) -> str:
        """
        Sends SMS command to AT
        :param message_type: str
        :return: str
        """
        answer = self.send_at('AT+CMGL="REC UNREAD"', 'OK', 3)
        if answer and message_type in answer:
            return answer

    def read_message(self, message_type: str) -> str:
        """
        Reads message from specified message type.
        :param message_type: str
        :return: str
        """
        try:
            return self.receive_message(message_type)
        except:
            if self.ser is not None:
                self.ser.close()

    def listen_message(self, message_type: str) -> str:
        """
                Starts a loop that reads message(s) from specified message type.
                :param message_type: str
                :return: str
                """
        while True:
            try:
                return self.receive_message(message_type)
            except:
                if self.ser is not None:
                    self.ser.close()
                # GPIO.cleanup()
