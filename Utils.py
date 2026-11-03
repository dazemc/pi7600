from datetime import UTC, datetime, timedelta
from functools import lru_cache
from pathlib import Path

import bcrypt
import jwt

from Config import get_settings


class TokenError(Exception):
    """Raised when a JWT is missing, malformed, expired, or invalid."""


@lru_cache(maxsize=1)
def _load_keys() -> tuple[str, str]:
    settings = get_settings()
    private_key = Path(settings.jwt_private_key_path).read_text(encoding="utf-8")
    public_key = Path(settings.jwt_public_key_path).read_text(encoding="utf-8")
    return private_key, public_key


def create_jwt(data: dict, expires_delta: timedelta | None = None) -> str:
    settings = get_settings()
    private_key, _ = _load_keys()
    now = datetime.now(UTC)
    payload = data.copy()
    payload["exp"] = now + (
        expires_delta
        if expires_delta is not None
        else timedelta(minutes=settings.jwt_expire_minutes)
    )
    payload["iat"] = now
    payload["iss"] = settings.jwt_issuer
    return jwt.encode(payload, private_key, algorithm="RS256")


def verify_jwt(token: str) -> dict:
    settings = get_settings()
    _, public_key = _load_keys()
    try:
        return jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            issuer=settings.jwt_issuer,
        )
    except jwt.ExpiredSignatureError as exc:
        raise TokenError("token expired") from exc
    except jwt.InvalidTokenError as exc:
        raise TokenError("invalid token") from exc


def verify_password(password: str, hashed_password: bytes) -> bool:
    return bcrypt.checkpw(password.encode("utf-8"), hashed_password)


def hash_password(password: str) -> bytes:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt())
