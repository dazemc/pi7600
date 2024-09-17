#!/usr/bin/python

import serial
import time

ser = serial.Serial("/dev/ttyUSB2", 115200)
# ser.flushInput()

rec_buff = ""


def send_at(command, back, timeout):
    rec_buff = ""
    ser.write((command + "\r\n").encode())
    time.sleep(timeout)
    if ser.inWaiting():
        time.sleep(0.01)
        rec_buff = ser.read(ser.inWaiting())
    if back not in rec_buff.decode():
        print(command + " ERROR")
        print(command + " back:\t" + rec_buff.decode())
        return 0
    else:
        print(rec_buff.decode())
        return 1


try:
    # while True:
    while True:
        command_input = raw_input("Please input the AT command:")
        ser.write((command_input + "\r\n").encode())
        time.sleep(0.1)
        if ser.inWaiting():
            rec_buff = ser.read(ser.inWaiting())
        if rec_buff != "":
            print(rec_buff.decode())
            rec_buff = ""
except:
    ser.close()
