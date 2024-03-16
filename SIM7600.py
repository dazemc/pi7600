import os
import subprocess
from SMS import SMS
from GPS import GPS
from Phone import Phone
from Settings import Settings
from Globals import *


cwd = os.getcwd()

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

# Execute script from most recent text, can iterate through all and look for header('pw')
message = buffer[-1]["message_contents"]
if message[:2] == "pw":
    if message[2:8] == '123456':  # can be encrypted just keep 559 char limit
        script = message[8:]  # TODO: add method to execute based off file type
        subprocess.call(f"{cwd}/scripts/{script}")  # don't forget to chmod +x

# Send message, returns True on success
# messaging.send_message(contact_number, message)

# PHONE
# phone = Phone()
# phone.call(contact_number, 0)
# phone.close_serial()

