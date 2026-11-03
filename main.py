"""FastAPI for SIMCOM 7600G-H."""

import asyncio
import logging
import subprocess
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Annotated

from fastapi import (
    Depends,
    FastAPI,
    HTTPException,
    Request,
    WebSocket,
    WebSocketDisconnect,
    status,
)
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import ValidationError
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from Auth import (
    authenticate_websocket,
    get_current_admin,
    get_current_user,
    get_user_by_username,
)
from Camera import FacialRecognition, VideoCaptureThread, VideoStreamManager
from Config import get_settings
from Database import close_db, get_db, run_migrations
from Models import (
    AtRequest,
    DeleteResponse,
    HealthResponse,
    InfoResponse,
    MessageCreate,
    Messages,
    SendMessageRequest,
    StatusResponse,
    TokenResponse,
    UserDB,
)
from pi7600 import GPS, SMS, TIMEOUT
from pi7600 import Settings as ModemSettings
from Utils import create_jwt, verify_password

logger = logging.getLogger("uvicorn.pi7600")


class SMSDeliveryError(Exception):
    """Raised when the modem reports that an SMS could not be sent."""

    def __init__(self, message: MessageCreate) -> None:
        self.message = message
        super().__init__("SMS delivery failed")


def _at_ok(response: str | None) -> bool:
    return bool(response) and "ERROR" not in response


def _response_line(response: str, index: int) -> str:
    lines = response.splitlines()
    return lines[index] if len(lines) > index else "ERROR"


async def run_async_subprocess(cmd: list[str], timeout_seconds: float = 5.0) -> str:
    """Run a subprocess without blocking the event loop."""
    process = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(
            process.communicate(), timeout=timeout_seconds
        )
    except TimeoutError:
        process.kill()
        await process.wait()
        return "ERROR: subprocess timed out"
    return stdout.decode(errors="ignore") if stdout else stderr.decode(errors="ignore")


async def run_ping(interface: str, target: str, timeout_seconds: float = 5.0) -> bool:
    """Return True when a single ping through ``interface`` succeeds."""
    process = await asyncio.create_subprocess_exec(
        "ping",
        "-I",
        interface,
        "-c",
        "1",
        "-W",
        "2",
        target,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        await asyncio.wait_for(process.wait(), timeout=timeout_seconds)
    except TimeoutError:
        process.kill()
        await process.wait()
        return False
    return process.returncode == 0


def get_modem(request: Request) -> ModemSettings:
    return request.app.state.modem


def get_sms(request: Request) -> SMS:
    return request.app.state.sms


def get_gps(request: Request) -> GPS:
    return request.app.state.gps


def get_video_manager(websocket: WebSocket) -> VideoStreamManager:
    return websocket.app.state.video_manager


def get_video_capture(websocket: WebSocket) -> VideoCaptureThread | None:
    return websocket.app.state.video_capture


def get_face_recognition(request: Request) -> FacialRecognition:
    return request.app.state.face_recognition


async def create_message(
    db: AsyncSession,
    message: Messages,
    sms: SMS,
) -> MessageCreate:
    """Persist a message, sending it first when it is an outgoing SMS."""
    existing = (
        await db.execute(
            select(MessageCreate).where(
                MessageCreate.message_type == message.message_type,
                MessageCreate.message_contents == message.message_contents,
                MessageCreate.message_date == message.message_date,
                MessageCreate.message_time == message.message_time,
            )
        )
    ).scalar_one_or_none()

    if existing is not None:
        if existing.in_sim_memory != message.in_sim_memory:
            existing.in_sim_memory = message.in_sim_memory
            await db.commit()
            await db.refresh(existing)
        return existing

    data = message.model_dump()
    data.pop("id", None)
    db_message = MessageCreate(**data)
    db.add(db_message)
    await db.commit()
    await db.refresh(db_message)

    if message.message_type == "SENT" and not message.is_sent:
        try:
            sent = await sms.send_message(
                message.message_destination_address,
                message.message_contents,
            )
        except Exception as exc:
            logger.error("SMS send failed: %s", exc)
            sent = False
        if not sent:
            raise SMSDeliveryError(db_message)
        db_message.is_sent = True
        await db.commit()
        await db.refresh(db_message)

    return db_message


async def messages_from_db(db: AsyncSession) -> list[Messages]:
    result = await db.execute(select(MessageCreate).order_by(MessageCreate.id))
    return [Messages.model_validate(message) for message in result.scalars().all()]


async def messages_to_delete(db: AsyncSession, sms: SMS) -> None:
    result = await db.execute(
        select(MessageCreate).where(MessageCreate.in_sim_memory.is_(True))
    )
    for message in result.scalars().all():
        if message.message_index is not None:
            logger.info("Deleting message at modem index %s", message.message_index)
            response = await sms.delete_message(int(message.message_index))
            if response.get("response") != "Success":
                logger.error(
                    "Unable to delete modem message %s: %s",
                    message.message_index,
                    response,
                )
                continue
        message.in_sim_memory = False
        await db.commit()
        await db.refresh(message)


async def delete_db_message(
    db: AsyncSession,
    message_id: int,
    sms: SMS,
) -> bool:
    message = await db.get(MessageCreate, message_id)
    if message is None:
        return False
    if message.in_sim_memory and message.message_index is not None:
        response = await sms.delete_message(int(message.message_index))
        if response.get("response") != "Success":
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Modem could not delete message {message.message_index}",
            )
    await db.delete(message)
    await db.commit()
    logger.info("Message id %s deleted", message_id)
    return True


def create_app() -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        settings = get_settings()
        logger.info("Initializing services")

        modem = ModemSettings(com=settings.at_com, baudrate=settings.at_baudrate)
        await modem.initialize()
        app.state.modem = modem
        app.state.sms = SMS()
        app.state.gps = GPS()
        app.state.video_manager = VideoStreamManager()

        app.state.video_capture = None
        try:
            capture = VideoCaptureThread(settings.camera_index, settings.camera_fps)
            capture.start()
            app.state.video_capture = capture
            await app.state.video_manager.start(capture, settings.camera_fps)
        except Exception as exc:
            logger.warning("Camera unavailable: %s", exc)

        app.state.face_recognition = FacialRecognition(
            settings.face_detector_model,
            settings.face_recognizer_model,
            settings.face_embeddings_dir,
            settings.face_match_threshold,
        )

        await asyncio.to_thread(run_migrations)
        logger.info("Services ready")
        try:
            yield
        finally:
            try:
                await app.state.video_manager.stop()
                if app.state.video_capture is not None:
                    await asyncio.to_thread(app.state.video_capture.release)
                await modem.close()
                await close_db()
            except Exception:
                logger.exception("Error during shutdown")

    app = FastAPI(lifespan=lifespan)

    @app.post("/token", response_model=TokenResponse, status_code=status.HTTP_200_OK)
    async def generate_token(
        form_data: Annotated[OAuth2PasswordRequestForm, Depends()],
        db: Annotated[AsyncSession, Depends(get_db)],
    ) -> TokenResponse:
        user = await get_user_by_username(db, form_data.username)
        if (
            user is None
            or user.is_disabled
            or not verify_password(form_data.password, user.user_password)
        ):
            logger.warning("Failed login for %r", form_data.username)
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect username or password",
                headers={"WWW-Authenticate": "Bearer"},
            )
        token = create_jwt({"sub": user.user_name})
        return TokenResponse(access_token=token)

    @app.get("/", response_model=StatusResponse, status_code=status.HTTP_200_OK)
    async def root(
        user: Annotated[UserDB, Depends(get_current_user)],
        modem: Annotated[ModemSettings, Depends(get_modem)],
        gps: Annotated[GPS, Depends(get_gps)],
    ) -> StatusResponse:
        logger.info("/ GET: Accessed by %s", user.user_name)
        gps_task = asyncio.create_task(gps.get_gps_position())
        data_task = asyncio.create_task(run_ping("usb0", "1.1.1.1"))
        dns_task = asyncio.create_task(run_ping("usb0", "www.google.com"))

        at_check = await modem.send_at("AT", "OK", TIMEOUT)
        at = _response_line(at_check, 2) if _at_ok(at_check) else "ERROR"

        cnum_check = await modem.send_at("AT+CNUM", "+CNUM:", TIMEOUT)
        cnum = "ERROR"
        if _at_ok(cnum_check):
            parts = _response_line(cnum_check, 2).split(",")
            if len(parts) > 1:
                cnum = parts[1].replace('"', "")

        csq_check = await modem.send_at("AT+CSQ", "OK", TIMEOUT)
        csq = _response_line(csq_check, 2) if _at_ok(csq_check) else "ERROR"

        cpin_check = await modem.send_at("AT+CPIN?", "READY", TIMEOUT)
        cpin = _response_line(cpin_check, 2) if _at_ok(cpin_check) else "ERROR"

        creg_check = await modem.send_at("AT+CREG?", "OK", TIMEOUT)
        creg = _response_line(creg_check, 2) if _at_ok(creg_check) else "ERROR"

        cops_check = await modem.send_at("AT+COPS?", "OK", TIMEOUT)
        cops = _response_line(cops_check, 2) if _at_ok(cops_check) else "ERROR"

        apn_check = await modem.send_at("AT+CGDCONT?", "OK", TIMEOUT)
        apn = "ERROR"
        if _at_ok(apn_check):
            for line in apn_check.splitlines():
                if "+CGDCONT:" in line:
                    parts = [part.strip().strip('"') for part in line.split(",")]
                    if len(parts) > 2:
                        apn = parts[2]
                    break

        gpsinfo = await gps_task or "ERROR"
        data = "OK" if await data_task else "ERROR"
        dns = "OK" if await dns_task else "ERROR"

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
            timezone=modem.timezone,
        )

    @app.get("/info", response_model=InfoResponse, status_code=status.HTTP_200_OK)
    async def info(
        user: Annotated[UserDB, Depends(get_current_user)],
    ) -> InfoResponse:
        logger.info("/info GET: Accessed by %s", user.user_name)
        hostname, uname, date, arch = await asyncio.gather(
            run_async_subprocess(["hostname"]),
            run_async_subprocess(["uname", "-r"]),
            run_async_subprocess(["date"]),
            run_async_subprocess(["arch"]),
        )
        return InfoResponse(
            hostname=hostname.strip(),
            uname=uname.strip(),
            date=date.strip(),
            arch=arch.strip(),
        )

    @app.get("/sms", response_model=list[Messages], status_code=status.HTTP_200_OK)
    async def sms_root(
        db: Annotated[AsyncSession, Depends(get_db)],
        sms: Annotated[SMS, Depends(get_sms)],
        user: Annotated[UserDB, Depends(get_current_user)],
    ) -> list[Messages]:
        logger.info("/sms GET: Accessed by %s", user.user_name)
        messages = await sms.receive_messages()
        if messages is None:
            messages = []
        for message in messages:
            try:
                await create_message(db, message, sms)
            except ValidationError as exc:
                logger.error("Validation error: %s for raw message: %s", exc, message)
        return await messages_from_db(db)

    @app.delete(
        "/sms/delete/{message_id}",
        response_model=DeleteResponse,
        status_code=status.HTTP_202_ACCEPTED,
    )
    async def delete_msg(
        message_id: int,
        db: Annotated[AsyncSession, Depends(get_db)],
        sms: Annotated[SMS, Depends(get_sms)],
        user: Annotated[UserDB, Depends(get_current_user)],
    ) -> DeleteResponse:
        logger.info("/sms/delete DELETE: Accessed by %s", user.user_name)
        deleted = await delete_db_message(db, message_id, sms)
        if not deleted:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Message {message_id} not found",
            )
        return DeleteResponse(response="Ok")

    @app.delete(
        "/sms/cleanup/",
        response_model=DeleteResponse,
        status_code=status.HTTP_202_ACCEPTED,
    )
    async def clear_sim_memory(
        db: Annotated[AsyncSession, Depends(get_db)],
        sms: Annotated[SMS, Depends(get_sms)],
        user: Annotated[UserDB, Depends(get_current_user)],
    ) -> DeleteResponse:
        logger.info("/sms/cleanup DELETE: Accessed by %s", user.user_name)
        await messages_to_delete(db, sms)
        return DeleteResponse(response="Ok")

    @app.post(
        "/sms",
        response_model=Messages,
        status_code=status.HTTP_201_CREATED,
    )
    async def send_msg(
        request: SendMessageRequest,
        db: Annotated[AsyncSession, Depends(get_db)],
        sms: Annotated[SMS, Depends(get_sms)],
        user: Annotated[UserDB, Depends(get_current_user)],
    ) -> Messages:
        logger.info("/sms POST: Accessed by %s", user.user_name)
        current_time = datetime.now()
        message = Messages(
            message_index=None,
            message_type="SENT",
            message_originating_address=None,
            message_destination_address=request.number,
            message_date=current_time.strftime("%Y-%m-%d"),
            message_time=current_time.strftime("%H:%M:%S"),
            message_contents=request.msg,
            in_sim_memory=False,
            is_sent=False,
            is_partial=False,
        )
        try:
            db_message = await create_message(db, message, sms)
        except SMSDeliveryError as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Message was stored but the modem could not send it",
            ) from exc
        return Messages.model_validate(db_message)

    @app.post("/at", response_model=str, status_code=status.HTTP_202_ACCEPTED)
    async def catcmd(
        request: AtRequest,
        admin: Annotated[UserDB, Depends(get_current_admin)],
        modem: Annotated[ModemSettings, Depends(get_modem)],
    ) -> str:
        logger.info("AT audit: user=%s cmd=%r", admin.user_name, request.cmd)
        response = await modem.send_raw(
            request.cmd, timeout_seconds=get_settings().at_timeout
        )
        logger.info(
            "AT audit: user=%s cmd=%r response=%r",
            admin.user_name,
            request.cmd,
            response[:500],
        )
        return response

    @app.websocket("/wss")
    async def websocket_end(
        websocket: WebSocket,
        db: Annotated[AsyncSession, Depends(get_db)],
    ) -> None:
        user = await authenticate_websocket(
            websocket, db, get_settings().websocket_auth_timeout
        )
        if user is None:
            return
        logger.info("WebSocket authenticated for %s", user.user_name)
        try:
            while True:
                data = await websocket.receive_text()
                logger.info("/wss message from %s: %s", user.user_name, data)
                await websocket.send_text(f"Message received: {data}")
        except WebSocketDisconnect:
            logger.info("WebSocket disconnected for %s", user.user_name)

    @app.websocket("/wss/video")
    async def video_stream(
        websocket: WebSocket,
        db: Annotated[AsyncSession, Depends(get_db)],
        manager: Annotated[VideoStreamManager, Depends(get_video_manager)],
        capture: Annotated[VideoCaptureThread | None, Depends(get_video_capture)],
    ) -> None:
        user = await authenticate_websocket(
            websocket, db, get_settings().websocket_auth_timeout
        )
        if user is None:
            return
        if capture is None:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
            return

        await manager.add(websocket)
        logger.info("Video stream authenticated for %s", user.user_name)
        try:
            while True:
                # The shared broadcaster pushes frames; wait for a disconnect.
                await websocket.receive_text()
        except WebSocketDisconnect:
            logger.info("Video stream disconnected for %s", user.user_name)
        finally:
            await manager.remove(websocket)

    @app.get("/healthz", response_model=HealthResponse)
    async def healthz() -> HealthResponse:
        return HealthResponse(status="ok")

    @app.get("/readyz", response_model=HealthResponse)
    async def readyz(
        db: Annotated[AsyncSession, Depends(get_db)],
    ) -> HealthResponse:
        try:
            await db.execute(text("SELECT 1"))
        except Exception as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Database unavailable",
            ) from exc
        return HealthResponse(status="ok")

    return app


app = create_app()
