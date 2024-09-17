import os
import subprocess
from SMS import SMS
from GPS import GPS
from Phone import Phone
from Settings import Settings
from Globals import *
from fastapi import FastAPI


app = FastAPI()
cwd = os.getcwd()


# SETTINGS
# settings = Settings()
# settings.set_data_mode(1)
# print(settings.get_config)
# settings.enable_verbose_logging()  # Only needs to be enabled once
# settings.set_sms_storage("SM")


# GPS
# gps = GPS()
# gps_cor = gps.get_gps_position()
# print(gps_cor)

# SMS
# contact_number = "+11234567890"  # Number you are sending to, +CC (Country Code)
# message = "Hey"
# buffer = messaging.read_message(message_type="ALL")
# print("Sending messages...")
# print(buffer)

# Execute script from most recent text, can iterate through all and look for header('pw')
# TODO: TOTP
# message = buffer[-1]["message_contents"]
# if message[:2] == "pw":
#     if message[2:8] == '123456':  # can be encrypted just keep 559 char limit
#         script = message[8:]  # TODO: add method to execute based off file type
#         subprocess.call(f"{cwd}/scripts/{script}")  # don't forget to chmod +x
# Send message, returns True on success
# messaging.send_message(contact_number, message)

# PHONE
# phone = Phone()
# phone.call(contact_number)
# phone.close_serial()


# API 

@app.get("/")
async def root():
    return {"message": "py zero sim api"}


@app.get("/sms")
async def sms():
    messaging = SMS()
    # Read message lists, by message type ("ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT")
    buffer = messaging.read_message(message_type="ALL")
    messaging.close_serial()
    return {"response": buffer}