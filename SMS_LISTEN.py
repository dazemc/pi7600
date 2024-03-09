#!/usr/bin/python

import serial
import time
import RPi.GPIO as GPIO

ser = serial.Serial("/dev/ttyUSB2", 115200)
ser.flushInput()

phone_number = '4253217245'  # ********** change it to the phone number you want to call
rec_buff = ''


def send_at(command, back, timeout):
    rec_buff = ''
    ser.write((command + '\r\n').encode())
    time.sleep(timeout)
    if ser.inWaiting():
        time.sleep(0.01)
        rec_buff = ser.read(ser.inWaiting())
    if back not in rec_buff.decode():
        print(command + ' ERROR')
        print(command + ' back:\t' + rec_buff.decode())
        return 0
    else:
        return rec_buff.decode()

def ReceiveShortMessage():
    rec_buff = ''
    answer = send_at('AT+CMGL="REC UNREAD"', 'OK', 3)
    if answer and 'UNREAD' in answer:
        print(answer)
    else:
        return False

while True:
    try:
        ReceiveShortMessage()
    except:
        if ser is not None:
            ser.close()
        GPIO.cleanup()

