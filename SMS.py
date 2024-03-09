#!/usr/bin/python

import time
from Settings import *


# import RPi.GPIO as GPIO


class SMS(Settings):
    def __init__(self):
        Settings.__init__(self)
        self.phone_number = ""  # Number you are contacting
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
        answer = self.send_at(f'AT+CMGL={message_type}', 'OK', 3)
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
