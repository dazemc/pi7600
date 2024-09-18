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
from AT import AT

app = FastAPI()
cwd = os.getcwd()
sms = SMS()
com_watch = AT(
    com=WATCHER_COM, baudrate=BAUDRATE
)  # Might separate this into systemd, just polls serial and reacts.


# API
@app.get("/", status_code=status.HTTP_200_OK)
async def root() -> dict:
    """Modem information and status

    Returns:
        dict: Various network and device checks
    """
    # TODO: Placeholders
    return {
        "AT": "OK",
        "CSQ?": "OK",
        "CSPIN?": "OK",
        "CREG?": "OK",
        "COPS?": "OK",
        "GPS": "OK",
        "DATA": "OK",
        "DNS": "OK",
    }


@app.get("/info", status_code=status.HTTP_200_OK)
async def info() -> dict:
    """Host device information

    Returns:
        dict: hostname, uname, date, arch
    """
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
async def sms_root(msg_query: str = "ALL") -> dict | None:
    """Read messages from modem


    Args:
        msg_query (str, optional): ["ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT"]. Defaults to "ALL".

    Returns:
        dict: {"response": Messages} | {"response": "null"}
    """
    resp = sms.read_message(message_type=msg_query)
    return resp


@app.get("/sms/delete/{msg_idx}", status_code=status.HTTP_202_ACCEPTED)
async def delete_msg(msg_idx: int) -> dict:
    """Delete sms message by MODEM index

    Args:
        msg_idx (int): MODEM message index

    Returns:
        dict: {"response": "Success"} | False
    """
    resp = sms.delete_message(msg_idx)
    return resp


@app.post("/sms", status_code=status.HTTP_201_CREATED)
async def send_msg(msg: str, number: str) -> dict:
    """POST SMS Message to destination number

    Args:
        msg (str): sms text body
        number (str): sms destination number

    Returns:
        dict: {"response": True}
    """
    resp = sms.send_message(phone_number=number, text_message=msg)
    return {"response": resp}


@app.post("/at", status_code=status.HTTP_202_ACCEPTED)
async def catcmd(cmd: str = "AT") -> str:
    """Sends raw AT commands to modem, will not work with commands that require input, return response

    Args:
        cmd (str, optional): Defaults to "AT".

    Returns:
        str: raw stdout response if "OK" or "ERROR" if "\r\n" is returned
    """
    resp = subprocess.run(
        ["./scripts/catcmd", cmd], capture_output=True, text=True, check=False
    ).stdout
    return resp


# SETTINGS for persistent modem configs
# settings = Settings()
# settings.set_data_mode(1)
# print(settings.get_config)
# settings.enable_verbose_logging()  # Only needs to be enabled once
# settings.set_sms_storage("SM")


# GPS
# gps = GPS()
# gps_cor = gps.get_gps_position()
# print(gps_cor)

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
