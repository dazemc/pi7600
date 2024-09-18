import os
import subprocess

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from starlette import status

from Globals import *
from GPS import GPS
from Phone import Phone
from Settings import Settings
from SMS import SMS

app = FastAPI()
cwd = os.getcwd()
sms = SMS()


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


@app.get("/info", status_code=status.HTTP_200_OK)
async def root():
    hostname = subprocess.run(
        ["hostname"], capture_output=True, text=True, check=False
    ).stdout.strip()
    uname = subprocess.run(
        ["uname", "-r"], capture_output=True, text=True, check=False
    ).stdout.strip()
    date = subprocess.run(
        ["date"], capture_output=True, text=True, check=False
    ).stdout.strip()
    arch = subprocess.run(
        ["arch"], capture_output=True, text=True, check=False
    ).stdout.strip()
    return {
        "hostname": hostname,
        "uname": uname,
        "date": date,
        "arch": arch,
    }


@app.get("/sms", status_code=status.HTTP_200_OK)
async def sms_root(msg_query: str = "ALL"):
    # Read message lists, by message type ("ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT")
    resp = sms.read_message(message_type=msg_query)
    return resp


@app.get("/sms/delete/{msg_idx}", status_code=status.HTTP_202_ACCEPTED)
async def delete_msg(msg_idx: int):
    resp = sms.delete_message(msg_idx)
    return resp


@app.post("/sms", status_code=status.HTTP_201_CREATED)
async def send_msg(msg: str, number: str):
    resp = sms.send_message(phone_number=number, text_message=msg)
    return resp


@app.get("/at", status_code=status.HTTP_202_ACCEPTED)
async def catcmd(cmd: str = "AT"):
    resp = subprocess.run(
        ["./scripts/catcmd", cmd], capture_output=True, text=True, check=False
    ).stdout
    return resp
