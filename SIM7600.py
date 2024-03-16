import os
from SMS import SMS
from GPS import GPS
from Phone import Phone
from Settings import Settings
from Globals import *
import subprocess

# SETTINGS
# settings = Settings()
# settings.enable_verbose_logging()  # Only needs to be enabled once
# settings.set_sms_storage("SM")

# GPS
# gps = GPS()
# gps_cor = gps.get_gps_position(GPS_RETRY)
# print(gps_cor)

# SMS
# contact_number = "******"  # Number you sending to
# message = "Hello, world!"
messaging = SMS()

# Read message lists, by message type ("ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT")
buffer = messaging.read_message(message_type="ALL")
print(buffer)
message = buffer[-1]["message_contents"]
# I'll add this to the parser
print(message)
# Do something cleaner for password
if message[:2] == "pw":
    if message[1:8] == '123456':
        script = message[8:]
        subprocess.call(".venv/bin/activate")
        subprocess.call(f"scripts/{script}")


# Send message, returns True on success
# messaging.send_message(contact_number, message)

# PHONE
# phone = Phone()
# phone.call(contact_number, 0)
# phone.close_serial()

