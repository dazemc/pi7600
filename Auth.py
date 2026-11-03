import asyncio
import json
import logging

from fastapi import Depends, HTTPException, WebSocket, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from Database import get_db
from Models import UserDB
from Utils import TokenError, verify_jwt

logger = logging.getLogger("uvicorn.pi7600")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/token")


async def get_user_by_username(db: AsyncSession, username: str) -> UserDB | None:
    result = await db.execute(select(UserDB).where(UserDB.user_name == username))
    return result.scalar_one_or_none()


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> UserDB:
    try:
        payload = verify_jwt(token)
    except TokenError as exc:
        logger.warning("Rejected token: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    username = payload.get("sub")
    if not username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = await get_user_by_username(db, username)
    if user is None or user.is_disabled:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User is unavailable",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


async def get_current_admin(user: UserDB = Depends(get_current_user)) -> UserDB:
    if not user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Administrator access required",
        )
    return user


async def authenticate_websocket(
    websocket: WebSocket,
    db: AsyncSession,
    auth_timeout: float,
) -> UserDB | None:
    """Accept a socket and authenticate it from its first JSON message.

    The client must send ``{"type": "auth", "token": "<jwt>"}`` within
    ``auth_timeout`` seconds. Returns the user on success, otherwise closes the
    socket with policy-violation code 1008 and returns ``None``.
    """
    await websocket.accept()
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=auth_timeout)
        data = json.loads(raw)
        token = data.get("token")
        if not isinstance(token, str) or not token:
            raise TokenError("missing token")
        payload = verify_jwt(token)
        username = payload.get("sub")
        if not username:
            raise TokenError("missing subject")
        user = await get_user_by_username(db, username)
        if user is None or user.is_disabled:
            raise TokenError("user unavailable")
        return user
    except (
        TimeoutError,
        json.JSONDecodeError,
        TokenError,
        AttributeError,
        KeyError,
        TypeError,
    ) as exc:
        logger.warning("WebSocket authentication failed: %s", exc)
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None
