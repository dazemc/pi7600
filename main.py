# TODO: ! sqlcipher, totp, api key, websocket !
"""FastAPI for SIMCOM 7600G-H"""

import logging
import os
import asyncio
import subprocess
from typing import List, Optional

from fastapi import FastAPI, status
from pydantic import BaseModel, ValidationError

from pi7600 import GPS, SMS, TIMEOUT, Settings

# Integrate into uvicorn logger
logger = logging.getLogger("uvicorn.pi7600")
logger.info("Initializing sim modules")

app = FastAPI()
cwd = os.getcwd()
sms = SMS()
gps = GPS()
settings = Settings()

logger.info("Sim modules ready")


class Messages(BaseModel):
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

    # Ensure to await all asynchronous calls
    at_check = await settings.send_at("AT", "OK", TIMEOUT)
    at = at_check.splitlines()[2] if at_check else "ERROR"

    cnum_check = await settings.send_at("AT+CNUM", "+CNUM:", TIMEOUT)
    cnum = (
        cnum_check.splitlines()[2].split(",")[1].replace('"', "")
        if cnum_check
        else "ERROR"
    )

    csq_check = await settings.send_at("AT+CSQ", "OK", TIMEOUT)
    csq = csq_check.splitlines()[2] if csq_check else "ERROR"

    cpin_check = await settings.send_at("AT+CPIN?", "READY", TIMEOUT)
    cpin = cpin_check.splitlines()[2] if cpin_check else "ERROR"

    creg_check = await settings.send_at("AT+CREG?", "OK", TIMEOUT)
    creg = creg_check.splitlines()[2] if creg_check else "ERROR"

    cops_check = await settings.send_at("AT+COPS?", "OK", TIMEOUT)
    cops = cops_check.splitlines()[2] if cops_check else "ERROR"

    # Await the GPS position asynchronously
    gps_check = await gps.get_gps_position()  # Await the GPS position
    gpsinfo = gps_check if gps_check else "ERROR"

    # Asynchronously run subprocess commands using asyncio.create_subprocess_exec
    data_check = await run_async_subprocess(
        ["ping", "-I", "usb0", "-c", "1", "1.1.1.1"]
    )
    data = "ERROR" if "Unreachable" in data_check else "OK"

    dns_check = await run_async_subprocess(
        ["ping", "-I", "usb0", "-c", "1", "www.google.com"]
    )
    dns = "ERROR" if "Unreachable" in dns_check else "OK"

    apn_check = await settings.send_at("AT+CGDCONT?", "OK", TIMEOUT)
    apn = (
        ",".join(apn_check.splitlines()[2].split(",")[2:3])[1:-1]
        if apn_check
        else "ERROR"
    )

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


async def run_async_subprocess(cmd: List[str]) -> str:
    """Runs a subprocess command asynchronously and captures its output."""
    proc = await asyncio.create_subprocess_exec(
        *cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    stdout, stderr = await proc.communicate()
    return stdout.decode() if stdout else stderr.decode()


@app.get("/info", response_model=InfoResponse, status_code=status.HTTP_200_OK)
async def info() -> InfoResponse:
    """Host device information

    Returns:
        dict: hostname, uname, date, arch
    """
    logger.info("Compiling host device information")

    hostname = await run_async_subprocess(["hostname"])
    uname = await run_async_subprocess(["uname", "-r"])
    date = await run_async_subprocess(["date"])
    arch = await run_async_subprocess(["arch"])

    return InfoResponse(
        hostname=hostname.strip(),
        uname=uname.strip(),
        date=date.strip(),
        arch=arch.strip(),
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

    # Await the receive_message function to ensure async execution
    raw_messages = await sms.receive_message(message_type=msg_query)

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
    resp = await sms.delete_message(msg_idx)  # Await the async delete_message call
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
    resp = await sms.send_message(
        phone_number=request.number, text_message=request.msg
    )  # Await the async send_message call
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
    # Run command asynchronously if possible, otherwise handle it synchronously
    resp = subprocess.run(
        ["./scripts/catcmd", request.cmd], capture_output=True, text=True, check=False
    ).stdout
    return resp
