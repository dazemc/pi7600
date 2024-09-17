#!/usr/bin/python

import serial
import time

ser = serial.Serial("/dev/ttyUSB2", 115200)
# ser.flushInput()

phone_number = "10010"
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
    while True:
        send_at("AT+CSQ", "OK", 1)
        send_at("AT+CREG?", "OK", 1)
        send_at("AT+CPSI?", "OK", 1)
        send_at("ATD" + phone_number + ";", "OK", 1)
        time.sleep(20)
        ser.write("AT+CHUP\r\n".encode())
        print("Call disconnected")
except:
    ser.close()
