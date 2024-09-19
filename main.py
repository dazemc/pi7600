"""FastAPI for SIMCOM 7600G-H"""

import logging
import os
import subprocess
from typing import List, Optional

from fastapi import FastAPI, status
from pydantic import BaseModel, ValidationError

from AT import AT
from Globals import *
from GPS import GPS
from Settings import Settings
from SMS import SMS

# Integrate into uvicorn logger
logger = logging.getLogger("uvicorn")
logger.info("Initializing Sim Modules")

app = FastAPI()
cwd = os.getcwd()
sms = SMS()
gps = GPS()
settings = Settings()
com_watch = AT(
    com=WATCHER_COM, baudrate=BAUDRATE
)  # Might separate this into systemd, just polls serial and reacts.

logger.info("Ready")


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
    cnum: str
    csq: str
    cpin: str
    creg: str
    cops: str
    gpsinfo: str
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
    """Parses out modem and network information

    Returns:
        dict: Various network and device checks
    """
    logger.info("Compiling modem status information")
    # .send_at() returns False on error, so tern to val or err
    # COM check
    at_check = settings.send_at("AT", "OK", TIMEOUT)
    at = at_check.splitlines()[2] if at_check else "ERROR"
    # Modem number
    cnum_check = settings.send_at("AT+CNUM", "+CNUM:", TIMEOUT)
    cnum = (
        cnum_check.splitlines()[2].split(",")[1].replace('"', "")
        if cnum_check
        else "ERROR"
    )
    # Signal quality
    csq_check = settings.send_at("AT+CSQ", "OK", TIMEOUT)
    csq = csq_check.splitlines()[2] if csq_check else "ERROR"
    # PIN check
    cpin_check = settings.send_at("AT+CPIN?", "READY", TIMEOUT)
    cpin = cpin_check.splitlines()[2] if cpin_check else "ERROR"
    # Network registration
    creg_check = settings.send_at("AT+CREG?", "OK", TIMEOUT)
    creg = creg_check.splitlines()[2] if creg_check else "ERROR"
    # Provider information
    cops_check = settings.send_at("AT+COPS?", "OK", TIMEOUT)
    cops = cops_check.splitlines()[2] if cops_check else "ERROR"
    # GPS coordinates
    gps_check = gps.get_gps_position()
    gpsinfo = gps_check if gps_check else "ERROR"
    # Data connectivity
    data_check = subprocess.run(
        ["ping", "-I", "usb0", "-c", "3", "1.1.1.1"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout.splitlines()
    data = "ERROR" if "Unreachable" in data_check else "OK"
    # DNS
    dns_check = subprocess.run(
        ["ping", "-I", "usb0", "-c", "3", "www.google.com"],
        capture_output=True,
        text=True,
        check=False,
    ).stdout
    dns = "ERROR" if "Unreachable" in dns_check else "OK"
    # APN
    apn_check = settings.send_at("AT+CGDCONT?", "OK", TIMEOUT)
    apn = ",".join(apn_check.splitlines()[2].split(",")[3:]) if apn_check else "ERROR"

    return StatusResponse(
        at=at,
        cnum=cnum,
        csq=csq,
        cpin=cpin,
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
    logger.info("Compiling host device information")
    hostname = "".join(
        subprocess.run(
            ["hostname"], capture_output=True, text=True, check=False
        ).stdout.splitlines()
    )
    uname = "".join(
        subprocess.run(
            ["uname", "-r"], capture_output=True, text=True, check=False
        ).stdout.splitlines()
    )
    date = "".join(
        subprocess.run(
            ["date"], capture_output=True, text=True, check=False
        ).stdout.splitlines()
    )
    arch = "".join(
        subprocess.run(
            ["arch"], capture_output=True, text=True, check=False
        ).stdout.splitlines()
    )
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
    logger.info(f"Reading {msg_query} messages")
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
    logger.info(f"DELETED_SMS: {msg_idx}")
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
    logger.info(f"Sending {request.msg} to {request.number}")
    resp = sms.send_message(phone_number=request.number, text_message=request.msg)
    return {"response": resp}


@app.post("/at", status_code=status.HTTP_202_ACCEPTED)
async def catcmd(request: AtRequest) -> str:
    r"""Sends raw AT commands to modem and returns raw stdout, will not work with commands that require input, return response

    Args:
        cmd (str, optional): Defaults to "AT".

    Returns:
        str: raw stdout response if "OK" or "ERROR" if "\r\n" is returned
    """
    logger.info(f"Sending AT cmd: {request.cmd}")
    cmd_sanitized = request.cmd
    resp = subprocess.run(
        ["./scripts/catcmd", cmd_sanitized], capture_output=True, text=True, check=False
    ).stdout
    return resp


# SETTINGS for persistent modem configs
# settings.set_data_mode(1)
# print(settings.get_config)
# settings.enable_verbose_logging()  # Only needs to be enabled once
# settings.set_sms_storage("SM")

# PHONE
# phone = Phone()
# phone.call(contact_number)
# phone.close_serial()
