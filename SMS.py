#!/usr/bin/python

import serial
import time


# import RPi.GPIO as GPIO


class SMS:
    def __init__(self):
        self.ser = serial.Serial("/dev/ttyUSB2", 115200)
        self.ser.flushInput()

        self.phone_number = '4253217245'  # ********** change it to the phone number you want to call
        self.rec_buff = ''

    def send_at(self, command, back, timeout):
        self.rec_buff = ''
        self.ser.write((command + '\r\n').encode())
        time.sleep(timeout)
        if self.ser.inWaiting():
            time.sleep(0.01)
            self.rec_buff = self.ser.read(self.ser.inWaiting())
        if back not in self.rec_buff.decode():
            print(command + ' ERROR')
            print(command + ' back:\t' + self.rec_buff.decode())
            return 0
        else:
            return self.rec_buff.decode()

    def receive_message(self):
        self.rec_buff = ''
        answer = self.send_at('AT+CMGL="REC UNREAD"', 'OK', 3)
        if answer and 'UNREAD' in answer:
            print(answer)
        else:
            return False

    def read_message(self):
        try:
            self.receive_message()
        except:
            if self.ser is not None:
                self.ser.close()

    def listen_message(self):
        while True:
            try:
                self.receive_message()
            except:
                if self.ser is not None:
                    self.ser.close()
                # GPIO.cleanup()
