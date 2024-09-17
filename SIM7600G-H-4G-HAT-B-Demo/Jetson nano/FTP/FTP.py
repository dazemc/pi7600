#!/usr/bin/python
import serial
import time

ser = serial.Serial("/dev/ttyUSB2",115200)
ser.flushInput()
rec_buff = ''
ftp_user_name = 'aly'
ftp_user_password = 'root'
ftp_server = '120.79.2.0'
download_file_name = 'hello.py'
upload_file_name = 'hello.py'

def send_at(command,back,timeout):
	rec_buff = ''
	ser.write((command+'\r\n').encode())
	time.sleep(timeout)
	if ser.inWaiting():
		time.sleep(0.1 )
		rec_buff = ser.read(ser.inWaiting())
	if rec_buff != '':
		if back not in rec_buff.decode():
			print(command + ' ERROR')
			print(command + ' back:\t' + rec_buff.decode())
			return 0
		else:
			print(rec_buff.decode())
			return 1
	else:
		print(command + ' no responce')

def configureFTP(server,u_name,u_password):
#        send_at('AT+CFTPSLOGOUT','OK',1)
#        send_at('AT+CFTPSSTOP','OK',1)
	send_at('AT+CFTPSSTART','OK',1)
	send_at('AT+CFTPSSINGLEIP=1','OK',1)
	#login to a FTP server
	send_at('AT+CFTPSLOGIN=\"'+ftp_server+'\",21,\"'+ftp_user_name+'\",\"'+ftp_user_password+'\",0','OK',3)
	#list all items of directory
	send_at('AT+CFTPSLIST=\"/\"','OK',1)
	send_at('AT+FSCD=F:/','OK',1)
	send_at('AT+FSLS','OK',1)

def uploadToFTP(upload_file_name):
        print('upload file from FTP...')
	# creat the uploadfile 
        send_at('AT+CFTRANRX=\"E:/'+upload_file_name+'\",12','OK',1) 
        send_at('1314xal1314','OK',3)
	# update the uploadfile
        send_at('AT+CFTPSPUTFILE=\"'+upload_file_name+'\"','OK',1)

def downloadFromFTP(download_file_name):
	print('Download file from FTP...')
 	send_at('AT+CFTPSGETFILE=\"'+download_file_name+'\"','OK',1)

try:
	configureFTP(ftp_server,ftp_user_name,ftp_user_password)
	time.sleep(2)
	print('Uploading file to \"'+ftp_server+'\"...')
	uploadToFTP(upload_file_name)
        time.sleep(3)
        print('Downloading file form \"'+ftp_server+'\"...')
        downloadFromFTP(download_file_name)
        send_at('AT+CFTPSLOGOUT','OK',1)
        send_at('AT+CFTPSSTOP','OK',1)

except :
	if ser != None:
		ser.close()
