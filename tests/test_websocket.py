import asyncio
import json
from types import SimpleNamespace

import pytest
from fastapi import WebSocketDisconnect
from starlette.testclient import TestClient

import Auth
import main
from Auth import authenticate_websocket
from Camera import VideoStreamManager
from Database import get_db
from Utils import create_jwt


class FakeWebSocket:
    def __init__(self, message: str | None = None, delay: bool = False) -> None:
        self.message = message
        self.delay = delay
        self.accepted = False
        self.closed_code: int | None = None

    async def accept(self) -> None:
        self.accepted = True

    async def receive_text(self) -> str:
        if self.delay:
            await asyncio.sleep(1)
        if self.message is None:
            raise RuntimeError("no message")
        return self.message

    async def close(self, code: int = 1000) -> None:
        self.closed_code = code


@pytest.fixture
def fake_user(monkeypatch):
    async def get_user_by_username(db, username):
        return type(
            "User",
            (),
            {"user_name": username, "is_disabled": False, "is_admin": False},
        )()

    monkeypatch.setattr(Auth, "get_user_by_username", get_user_by_username)


async def test_websocket_auth_success(fake_user, user):
    token = create_jwt({"sub": user.user_name})
    websocket = FakeWebSocket(json.dumps({"type": "auth", "token": token}))
    result = await authenticate_websocket(websocket, None, 1.0)
    assert result is not None
    assert result.user_name == user.user_name
    assert websocket.accepted is True
    assert websocket.closed_code is None


async def test_websocket_auth_invalid_token(fake_user):
    websocket = FakeWebSocket(json.dumps({"type": "auth", "token": "invalid"}))
    result = await authenticate_websocket(websocket, None, 1.0)
    assert result is None
    assert websocket.closed_code == 1008


async def test_websocket_auth_missing_token(fake_user):
    websocket = FakeWebSocket(json.dumps({"type": "auth"}))
    result = await authenticate_websocket(websocket, None, 1.0)
    assert result is None
    assert websocket.closed_code == 1008


async def test_websocket_auth_malformed_json(fake_user):
    websocket = FakeWebSocket("not json")
    result = await authenticate_websocket(websocket, None, 1.0)
    assert result is None
    assert websocket.closed_code == 1008


async def test_websocket_auth_non_object_json(fake_user):
    websocket = FakeWebSocket(json.dumps(["not", "an", "object"]))
    result = await authenticate_websocket(websocket, None, 1.0)
    assert result is None
    assert websocket.closed_code == 1008


async def test_websocket_auth_timeout(fake_user):
    websocket = FakeWebSocket(delay=True)
    result = await authenticate_websocket(websocket, None, 0.01)
    assert result is None
    assert websocket.closed_code == 1008


class FakeVideoSocket:
    def __init__(self) -> None:
        self.frames: list[bytes] = []
        self.closed = False

    async def send_bytes(self, frame: bytes) -> None:
        self.frames.append(frame)

    async def close(self) -> None:
        self.closed = True


async def test_video_manager_broadcast_and_remove():
    manager = VideoStreamManager()
    first = FakeVideoSocket()
    second = FakeVideoSocket()
    await manager.add(first)
    await manager.add(second)

    await manager.broadcast(b"frame")
    assert first.frames == [b"frame"]
    assert second.frames == [b"frame"]

    await manager.remove(first)
    await manager.broadcast(b"next")
    assert first.frames == [b"frame"]
    assert second.frames == [b"frame", b"next"]


async def test_video_manager_drops_dead_connections():
    manager = VideoStreamManager()

    class BrokenSocket(FakeVideoSocket):
        async def send_bytes(self, frame: bytes) -> None:
            raise RuntimeError("closed")

    broken = BrokenSocket()
    await manager.add(broken)
    await manager.broadcast(b"frame")
    assert broken not in manager.connections


async def test_video_manager_stop_closes_connections():
    manager = VideoStreamManager()
    socket = FakeVideoSocket()
    await manager.add(socket)
    await manager.stop()
    assert socket.closed is True
    assert manager.connections == []


def test_video_route_closes_without_camera(app, monkeypatch):
    async def fake_auth(websocket, db, auth_timeout):
        await websocket.accept()
        return SimpleNamespace(user_name="tester")

    async def fake_db():
        yield None

    monkeypatch.setattr(main, "authenticate_websocket", fake_auth)
    app.dependency_overrides[get_db] = fake_db
    app.state.video_manager = VideoStreamManager()
    app.state.video_capture = None

    client = TestClient(app)
    with pytest.raises(WebSocketDisconnect) as exc:
        with client.websocket_connect("/wss/video") as websocket:
            websocket.receive_bytes()
    assert exc.value.code == 1011
