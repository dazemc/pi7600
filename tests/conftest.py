import os
from collections.abc import AsyncIterator, Iterator

os.environ.setdefault("PI7600_DATABASE_URL", "sqlite+aiosqlite:///./test_cmgl.db")

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

import Utils
from Camera import VideoStreamManager
from Config import get_settings
from Database import get_db
from Models import Base, UserDB
from Utils import create_jwt, hash_password


class FakeModem:
    timezone = 0

    def __init__(self) -> None:
        self.commands: list[str] = []

    async def send_at(self, command: str, back: str, timeout_seconds: int = 3) -> str:
        self.commands.append(command)
        responses = {
            "AT": "AT\r\n\r\nOK\r\n",
            "AT+CNUM": (
                'AT+CNUM\r\n\r\n+CNUM: "line","+15551234567",145\r\n\r\nOK\r\n'
            ),
            "AT+CSQ": "AT+CSQ\r\n\r\n+CSQ: 20,99\r\n\r\nOK\r\n",
            "AT+CPIN?": "AT+CPIN?\r\n\r\n+CPIN: READY\r\n\r\nOK\r\n",
            "AT+CREG?": "AT+CREG?\r\n\r\n+CREG: 0,1\r\n\r\nOK\r\n",
            "AT+COPS?": 'AT+COPS?\r\n\r\n+COPS: 0,0,"Test",7\r\n\r\nOK\r\n',
            "AT+CGDCONT?": (
                'AT+CGDCONT?\r\n\r\n+CGDCONT: 1,"IP","internet"\r\n\r\nOK\r\n'
            ),
        }
        return responses.get(command, "OK\r\n")

    async def send_raw(self, command: str, timeout_seconds: int = 10) -> str:
        self.commands.append(command)
        return f"{command}\r\nOK\r\n"

    async def close(self) -> None:
        return None


class FakeSMS:
    def __init__(self) -> None:
        self.messages: list = []
        self.sent: list[tuple[str, str]] = []
        self.deleted: list[int] = []
        self.fail_send = False

    async def receive_messages(self) -> list:
        return list(self.messages)

    async def send_message(self, phone_number: str, text_message: str) -> bool:
        self.sent.append((phone_number, text_message))
        return not self.fail_send

    async def delete_message(self, msg_idx: int) -> dict:
        self.deleted.append(msg_idx)
        return {"response": "Success"}


class FakeGPS:
    async def get_gps_position(self) -> str | None:
        return "GPS is active but no signal was found"


@pytest.fixture(scope="session")
def jwt_keys(tmp_path_factory) -> tuple[str, str]:
    directory = tmp_path_factory.mktemp("keys")
    private_path = directory / "private.pem"
    public_path = directory / "public.pem"

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_path.write_bytes(
        key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption(),
        )
    )
    public_path.write_bytes(
        key.public_key().public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        )
    )
    return str(private_path), str(public_path)


@pytest.fixture(autouse=True)
def configure_jwt_keys(jwt_keys, monkeypatch) -> Iterator[None]:
    settings = get_settings()
    monkeypatch.setattr(settings, "jwt_private_key_path", jwt_keys[0])
    monkeypatch.setattr(settings, "jwt_public_key_path", jwt_keys[1])
    Utils._load_keys.cache_clear()
    yield
    Utils._load_keys.cache_clear()


@pytest.fixture
async def db_engine(tmp_path) -> AsyncIterator[AsyncEngine]:
    url = f"sqlite+aiosqlite:///{tmp_path / 'test.db'}"
    engine = create_async_engine(url)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
def session_factory(
    db_engine: AsyncEngine,
) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(db_engine, expire_on_commit=False)


@pytest.fixture
async def db_session(session_factory) -> AsyncIterator[AsyncSession]:
    async with session_factory() as session:
        yield session


@pytest.fixture
async def user(db_session: AsyncSession) -> UserDB:
    record = UserDB(
        user_name="alice",
        user_password=hash_password("secret"),
        is_disabled=False,
        is_admin=False,
    )
    db_session.add(record)
    await db_session.commit()
    await db_session.refresh(record)
    return record


@pytest.fixture
async def admin(db_session: AsyncSession) -> UserDB:
    record = UserDB(
        user_name="admin",
        user_password=hash_password("secret"),
        is_disabled=False,
        is_admin=True,
    )
    db_session.add(record)
    await db_session.commit()
    await db_session.refresh(record)
    return record


@pytest.fixture
async def disabled_user(db_session: AsyncSession) -> UserDB:
    record = UserDB(
        user_name="disabled",
        user_password=hash_password("secret"),
        is_disabled=True,
        is_admin=False,
    )
    db_session.add(record)
    await db_session.commit()
    await db_session.refresh(record)
    return record


@pytest.fixture
def app(session_factory):
    from main import create_app

    application = create_app()
    application.state.modem = FakeModem()
    application.state.sms = FakeSMS()
    application.state.gps = FakeGPS()
    application.state.video_manager = VideoStreamManager()
    application.state.video_capture = None

    async def override_get_db():
        async with session_factory() as session:
            yield session

    application.dependency_overrides[get_db] = override_get_db
    yield application
    application.dependency_overrides.clear()


@pytest.fixture
async def client(app) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as http:
        yield http


@pytest.fixture
def auth_headers(user: UserDB) -> dict[str, str]:
    token = create_jwt({"sub": user.user_name})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin_headers(admin: UserDB) -> dict[str, str]:
    token = create_jwt({"sub": admin.user_name})
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def disabled_headers(disabled_user: UserDB) -> dict[str, str]:
    token = create_jwt({"sub": disabled_user.user_name})
    return {"Authorization": f"Bearer {token}"}
