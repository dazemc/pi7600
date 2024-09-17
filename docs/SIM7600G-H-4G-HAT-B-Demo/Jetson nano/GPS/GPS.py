#!/usr/bin/python

import serial
import time
ser = serial.Serial("/dev/ttyUSB2",115200)
#ser.flushInput()

rec_buff = ''

def send_at(command,back,timeout):
        rec_buff = ''
        ser.write((command+'\r\n').encode())
        time.sleep(timeout)
        if ser.inWaiting():
                time.sleep(0.01 )
                rec_buff = ser.read(ser.inWaiting())
        if back not in rec_buff.decode():
                print(command + ' ERROR')
                print(command + ' back:\t' + rec_buff.decode())
                return 0
        else:
                print(rec_buff.decode())
                return 1

def get_gps_position():
        rec_null = True
        answer = 0
        print('Start GPS session...')
        rec_buff = ''
	send_at('AT+CGPS=0','OK',1)
        send_at('AT+CGPS=1','OK',1)
        time.sleep(2)
        while rec_null:
                answer = send_at('AT+CGPSINFO','+CGPSINFO: ',1)
                if 1 == answer:
                        answer = 0
                        if ',,,,,,' in rec_buff:
                                print('GPS is not ready')
                                rec_null = False
                                time.sleep(1)
                else:
                        print('error %d'%answer)
                        rec_buff = ''
                        send_at('AT+CGPS=0','OK',1)
                        return False
                time.sleep(1.5)

try:
        get_gps_position()

except :
        ser.close()



