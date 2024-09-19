"""FastAPI for SIMCOM 7600G-H"""

import os
import subprocess
from typing import List, Optional

from fastapi import FastAPI, status
from pydantic import BaseModel, ValidationError

from AT import AT
from Globals import *
from SMS import SMS
from GPS import GPS
from Settings import Settings

app = FastAPI()
cwd = os.getcwd()
sms = SMS()
gps = GPS()
settings = Settings()
com_watch = AT(
    com=WATCHER_COM, baudrate=BAUDRATE
)  # Might separate this into systemd, just polls serial and reacts.


class Messages(BaseModel):
    """Pydantic model for SMS messages

    Args:
        BaseModel (_type_): _description_
    """

    message_index: str
    message_type: str
    message_originating_address: Optional[str]
    message_destination_address: Optional[str]
    message_date: str
    message_time: str
    message_contents: str


class InfoResponse(BaseModel):
    hostname: str
    uname: str
    date: str
    arch: str


class StatusResponse(BaseModel):
    at: str
    csq: str
    cspin: str
    creg: str
    cops: str
    gps: str
    data: str
    dns: str
    apn: str


class SendMessageRequest(BaseModel):
    number: str
    msg: str


class AtRequest(BaseModel):
    cmd: str = "AT"


# API
@app.get("/", response_model=StatusResponse, status_code=status.HTTP_200_OK)
async def root() -> StatusResponse:
    """Modem information and status

    Returns:
        dict: Various network and device checks
    """
    # .send_at() returns False on error, so tern to val or err
    # TODO: Parse response for some
    # COM check
    at_check = settings.send_at("AT", "OK", TIMEOUT)
    at = at_check if at_check else "ERROR"
    # Signal quality
    csq_check = settings.send_at("AT+CSQ", "OK", TIMEOUT)
    csq = csq_check if csq_check else "ERROR"
    # PIN check
    cspin_check = settings.send_at("AT+CSPIN?", "OK", TIMEOUT)
    cspin = cspin_check if cspin_check else "ERROR"
    # Network registration
    creg_check = settings.send_at("AT+CREG?", "OK", TIMEOUT)
    creg = creg_check if creg_check else "ERROR"
    # Provider information
    cops_check = settings.send_at("AT+COPS?", "OK", TIMEOUT)
    cops = cops_check if cops_check else "ERROR"
    # GPS coordinates
    gps_check = gps.get_gps_position()
    gpsinfo = gps_check if gps_check else "ERROR"
    # Data connectivity
    data_check = subprocess.run(
        ["ping", "-I", "usb0", "-c", "1", "8.8.8.8"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    data = data_check if data_check else "ERROR"
    # DNS
    dns_check = subprocess.run(
        ["ping", "-I", "usb0", "-c", "1", "www.google.com"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.strip()
    dns = dns_check if dns_check else "ERROR"
    # APN
    apn_check = settings.send_at("AT+CGDCONT?", "OK", TIMEOUT)
    apn = apn_check if apn_check else "ERROR"

    return StatusResponse(
        at=at,
        csq=csq,
        cspin=cspin,
        creg=creg,
        cops=cops,
        gpsinfo=gpsinfo,
        data=data,
        dns=dns,
        apn=apn,
    )


@app.get("/info", response_model=InfoResponse, status_code=status.HTTP_200_OK)
async def info() -> InfoResponse:
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
    return InfoResponse(
        hostname=hostname,
        uname=uname,
        date=date,
        arch=arch,
    )


@app.get("/sms", response_model=List[Messages], status_code=status.HTTP_200_OK)
async def sms_root(msg_query: str = "ALL") -> List[Messages]:
    """Read messages from modem
    Args:
        msg_query (str, optional): ["ALL", "REC READ", "REC UNREAD", "STO UNSENT", "STO SENT"]. Defaults to "ALL".

    Returns:
        List<dict>: [{Messages}, {Messages}]
    """
    raw_messages = sms.read_message(message_type=msg_query)
    messages = []
    for raw_msg in raw_messages:
        try:
            message = Messages(**raw_msg)
            messages.append(message)
        except ValidationError as e:
            print(f"Validation error: {e}")
            continue
    return messages


@app.delete("/sms/delete/{msg_idx}", status_code=status.HTTP_202_ACCEPTED)
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
async def send_msg(request: SendMessageRequest) -> dict:
    """POST SMS Message to destination number

    Args:
        msg (str): sms text body
        number (str): sms destination number

    Returns:
        dict: {"response": True}
    """
    resp = sms.send_message(phone_number=request.number, text_message=request.msg)
    return {"response": resp}


@app.post("/at", status_code=status.HTTP_202_ACCEPTED)
async def catcmd(request: AtRequest) -> str:
    r"""Sends raw AT commands to modem, will not work with commands that require input, return response

    Args:
        cmd (str, optional): Defaults to "AT".

    Returns:
        str: raw stdout response if "OK" or "ERROR" if "\r\n" is returned
    """
    cmd_sanitized = request.cmd
    resp = subprocess.run(
        ["./scripts/catcmd", cmd_sanitized], capture_output=True, text=True, check=False
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
