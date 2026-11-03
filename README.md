# Pi7600: SIM7600 modem library and REST API

Pi7600 is a Python library and FastAPI service for the
[Waveshare SIM7600G-H 4G HAT](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
on a Raspberry Pi. It exposes modem status, host information, SMS
send/read/delete, GPS, an admin-only raw AT command endpoint, and authenticated
WebSocket echo/video streams.

The repository contains:

- the FastAPI application (`main.py`, `Auth.py`, `Database.py`, `Camera.py`),
- the modem library in the `pi7600/` git submodule, and
- deployment and helper scripts in `deploy/` and `scripts/`.

## Requirements

- Python **3.13** (the app and CI target 3.13).
- [uv](https://docs.astral.sh/uv/) for dependency management.
- A SIM7600-series modem on `/dev/ttyUSB2` and a camera on `/dev/video*`.
- Membership in the `dialout` and `video` groups.

```bash
sudo usermod -aG dialout,video "$USER"
```

ModemManager can claim the serial ports. `scripts/setup.sh` disables it; review
the script before running it.

## Quick start

```bash
uv sync --python 3.13

# JWT signing keys (required by /token and WebSocket auth).
mkdir -p .keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out .keys/private.pem
openssl rsa -pubout -in .keys/private.pem -out .keys/public.pem

# Local configuration.
cp .env.example .env

# Apply the database schema.
uv run alembic upgrade head

# Create the first API user (add --admin for /at access).
uv run python scripts/create_user.py --admin

# Run the API.
uv run uvicorn main:app --reload
# or: ./start.sh
```

The service listens on `http://localhost:8000`; interactive docs are at `/docs`
and `/redoc`.

## Configuration

Settings are loaded from environment variables with the `PI7600_` prefix or from
`.env`. See `.env.example` and `deploy/pi7600.env.example`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PI7600_DATABASE_URL` | `sqlite+aiosqlite:///./cmgl.db` | Async SQLAlchemy URL |
| `PI7600_AT_COM` | `/dev/ttyUSB2` | Modem serial port |
| `PI7600_AT_BAUDRATE` | `115200` | Serial speed |
| `PI7600_AT_TIMEOUT` | `10` | Raw AT command timeout (seconds) |
| `PI7600_CAMERA_INDEX` | `-1` | OpenCV camera index |
| `PI7600_CAMERA_FPS` | `15` | Video stream frame rate |
| `PI7600_JWT_PRIVATE_KEY_PATH` | `.keys/private.pem` | JWT signing key |
| `PI7600_JWT_PUBLIC_KEY_PATH` | `.keys/public.pem` | JWT verification key |
| `PI7600_JWT_ISSUER` | `pi.daazed.dev` | JWT issuer claim |
| `PI7600_JWT_EXPIRE_MINUTES` | `30` | Access token lifetime |
| `PI7600_WEBSOCKET_AUTH_TIMEOUT` | `5` | Seconds to wait for the auth message |

## Authentication

`POST /token` uses the OAuth2 password form and returns an RS256 JWT:

```bash
curl -X POST http://localhost:8000/token \
  -d 'username=alice&password=secret'
```

```json
{"access_token": "...", "token_type": "bearer"}
```

Send the token as `Authorization: Bearer <token>` on HTTP requests. Invalid,
expired, and disabled-user tokens return `401`.

### WebSocket authentication

Browsers cannot set an `Authorization` header on a WebSocket handshake, so the
server accepts the connection and waits for a first JSON message:

```json
{"type": "auth", "token": "<jwt>"}
```

The socket is closed with code `1008` when authentication fails or the message
does not arrive within `PI7600_WEBSOCKET_AUTH_TIMEOUT` seconds. Only then does
`/wss` echo messages or `/wss/video` subscribe the client to JPEG frames.

```python
import asyncio
import json

import websockets


async def main() -> None:
    async with websockets.connect("ws://localhost:8000/wss") as ws:
        await ws.send(json.dumps({"type": "auth", "token": token}))
        await ws.send("hello")
        print(await ws.recv())


asyncio.run(main())
```

## API

All routes except `/token`, `/healthz`, and `/readyz` require a bearer token.

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/token` | Issue a JWT |
| `GET` | `/` | Modem/network/GPS status |
| `GET` | `/info` | Hostname, kernel, date, architecture |
| `GET` | `/sms` | Sync messages from the SIM and return the database rows |
| `POST` | `/sms` | Send an SMS |
| `DELETE` | `/sms/delete/{message_id}` | Delete by database `id` |
| `DELETE` | `/sms/cleanup/` | Delete all SIM-backed messages |
| `POST` | `/at` | Send a raw AT command (**admin only**, audit-logged) |
| `GET` | `/healthz` | Liveness |
| `GET` | `/readyz` | Readiness (database check) |
| `WS` | `/wss` | Authenticated echo |
| `WS` | `/wss/video` | Authenticated JPEG frame stream |

### Modem status

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/
```

```json
{
  "at": "OK",
  "cnum": "+15551234567",
  "csq": "+CSQ: 20,99",
  "cpin": "+CPIN: READY",
  "creg": "+CREG: 0,1",
  "cops": "+COPS: 0,0,\"Home\",7",
  "gpsinfo": "GPS is active but no signal was found",
  "data": "OK",
  "dns": "OK",
  "apn": "internet",
  "timezone": 0
}
```

### SMS

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/sms

curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"number":"+15551234567","msg":"Hello"}' \
  http://localhost:8000/sms
```

A successful send returns `201` with the stored message. If the row is stored
but the modem cannot send it, the API returns `502` and keeps the row with
`is_sent: false` for retry.

`DELETE /sms/delete/{message_id}` takes the **database** id. When the row came
from SIM storage, the API uses its stored `message_index` for the modem delete.

### Raw AT commands

`POST /at` is restricted to users with `is_admin` and logs the user, command,
and a truncated response:

```bash
curl -X POST -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"cmd":"AT+CSQ"}' \
  http://localhost:8000/at
```

### Health checks

`/healthz` is a process liveness check. `/readyz` additionally runs a database
query and returns `503` when the database is unavailable.

## Deployment with systemd

1. Create a service user and directories:

   ```bash
   sudo useradd --system --home /opt/pi7600 --shell /usr/sbin/nologin pi7600
   sudo usermod -aG dialout,video pi7600
   sudo mkdir -p /opt/pi7600 /var/lib/pi7600 /etc/pi7600/keys
   sudo chown -R pi7600:pi7600 /opt/pi7600 /var/lib/pi7600
   ```

2. Copy the repository to `/opt/pi7600` and install dependencies as that user:

   ```bash
   cd /opt/pi7600
   sudo -u pi7600 uv sync --python 3.13 --frozen
   ```

3. Generate keys in `/etc/pi7600/keys`, copy
   `deploy/pi7600.env.example` to `/etc/pi7600/pi7600.env`, and adjust paths.

4. Install and start the unit:

   ```bash
   sudo cp deploy/pi7600.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now pi7600
   sudo journalctl -u pi7600 -f
   ```

The unit runs `alembic upgrade head` before starting the API, so existing
databases are migrated automatically.

## Development

```bash
uv sync --python 3.13
uv run ruff check .
uv run ruff format --check .
uv run pytest -q
```

Tests use fake modem, SMS, GPS, camera, and temporary SQLite fixtures, so they
do not require hardware. CI runs the same commands on Python 3.13.

See `docs/roadmap.md` for SQLCipher, TOTP, and face-recognition follow-up work.

### Optional face models

The face detector and recognizer models are not committed. Download them into
`ml/` when you want recognition enabled:

```bash
uv run python scripts/download_models.py
```

Embeddings are written to `data/embeddings/`, which is gitignored.

## Security notes

- Treat `/at` as a privileged administration endpoint; keep admin accounts
  limited.
- Keep `.keys/`, `.env`, databases, and `data/embeddings/` out of version
  control.
- Put the service behind HTTPS (for example a reverse proxy) when exposing it
  beyond a trusted network.
- The modem and camera device permissions are granted through the `dialout` and
  `video` groups; do not run the API as root.

## Resources

- [SIM7600G-H 4G HAT product page](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
- [SIM7600 AT command manual](https://www.waveshare.net/w/upload/6/68/SIM7500_SIM7600_Series_AT_Command_Manual_V2.00.pdf)

## License

MIT
