import asyncio

import pytest

from pi7600.AT import AT


class FakeSerial:
    def __init__(self, chunks: list[bytes] | None = None) -> None:
        self.chunks = list(chunks or [])
        self.written = b""
        self.reset_calls = 0
        self.closed = False
        self.is_open = True

    @property
    def in_waiting(self) -> int:
        return len(self.chunks[0]) if self.chunks else 0

    def read(self, size: int) -> bytes:
        return self.chunks.pop(0) if self.chunks else b""

    def write(self, data: bytes) -> int:
        self.written += data
        return len(data)

    def reset_input_buffer(self) -> None:
        self.reset_calls += 1

    def close(self) -> None:
        self.closed = True
        self.is_open = False


def make_at(chunks: list[bytes] | None = None) -> AT:
    at = AT.__new__(AT)
    at.com = "fake"
    at.baudrate = 115200
    at.ser = FakeSerial(chunks)
    at.rec_buff = ""
    at._lock = asyncio.Lock()
    return at


def test_is_error():
    assert AT.is_error(None) is True
    assert AT.is_error("") is True
    assert AT.is_error("OK\r\n") is False
    assert AT.is_error("+CME ERROR: 10\r\n") is True


async def test_send_at_success():
    at = make_at([b"AT\r\nOK\r\n"])
    response = await at.send_at("AT", "OK", 1)
    assert "OK" in response
    assert at.ser.written == b"AT\r\n"


async def test_send_at_reports_modem_error():
    at = make_at([b"ERROR\r\n"])
    response = await at.send_at("AT+BAD", "OK", 1)
    assert AT.is_error(response)


async def test_send_at_timeout():
    at = make_at([])
    response = await at.send_at("AT", "OK", 0)
    assert "ERROR: Timeout" in response


async def test_send_raw_returns_response():
    at = make_at([b"AT+CSQ\r\n+CSQ: 20,99\r\nOK\r\n"])
    response = await at.send_raw("AT+CSQ", 1)
    assert "+CSQ: 20,99" in response
    assert at.ser.written == b"AT+CSQ\r\n"


async def test_write_data():
    at = make_at()
    await at.write_data(b"hello\x1a")
    assert at.ser.written == b"hello\x1a"


async def test_clear_buffer_resets_input_and_buffer():
    at = make_at()
    at.rec_buff = "stale"
    at.clear_buffer()
    assert at.rec_buff == ""
    assert at.ser.reset_calls == 1


async def test_close_serial_is_idempotent():
    at = make_at()
    await at.close()
    assert at.ser is None
    await at.close()


async def test_send_at_requires_open_port():
    at = AT("fake", 115200)
    with pytest.raises(RuntimeError):
        await at.send_at("AT", "OK", 1)
