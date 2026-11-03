# Pi7600: SIM7600 modem service

Pi7600 is a [Serverpod 4](https://serverpod.dev/) service for the
[Waveshare SIM7600G-H 4G HAT](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
on a Raspberry Pi. It exposes modem status, host information, SMS
send/read/delete, GPS, an admin-only raw AT command endpoint, and authenticated
WebSocket echo/video streams.

The implementation is Dart end to end: the modem library, SMS PDU decoder,
camera capture, WebSocket handling, authentication, and database access all run
on the Dart VM with PostgreSQL. There is no Python runtime.

## Repository layout

| Path | Purpose |
| --- | --- |
| `pi7600_server/` | Serverpod server, modem library, camera/V4L2 capture, REST and WebSocket routes |
| `pi7600_client/` | Generated Serverpod protocol client package (not a Flutter app) |
| `pi7600_server/lib/src/modem/` | AT client, stream-based serial transport, settings, SMS/PDU, GPS, phone |
| `pi7600_server/lib/src/camera/` | V4L2 capture, JPEG broadcaster, recognition interface |
| `pi7600_server/lib/src/web/` | REST routes and WebSocket upgrade handlers |
| `pi7600_server/migrations/` | PostgreSQL schema migrations |
| `third_party/relic_io/` | Vendored `relic_io` with RFC 6455 close-code support for 1008/1011 |
| `deploy/` | systemd unit and environment example |
| `scripts/` | Helper scripts (`setup.sh`, model downloads) |
| `docs/` | Roadmap and the SIM7600 AT command manual |
| `ml/` | Optional face detection/recognition models (embeddings are gitignored) |

## Requirements

- Dart **3.13** (the workspace targets `^3.12.2`).
- PostgreSQL **16+**.
- `libserialport` (`libserialport0` on Debian). Debian's runtime package ships
  only `libserialport.so.0`; set `LIBSERIALPORT_PATH=libserialport.so.0` so the
  Dart FFI loader does not look for the unversioned `.so` symlink.
- A SIM7600-series modem on `/dev/ttyUSB2` and a V4L2 camera on `/dev/video*`.
- Membership in the `dialout` and `video` groups.

```bash
sudo usermod -aG dialout,video "$USER"
```

ModemManager can claim the serial ports. `scripts/setup.sh` disables it; review
the script before running it.

## Quick start (development)

```bash
dart pub get

# JWT signing keys. The development server resolves these relative to
# pi7600_server/, so create them there.
mkdir -p pi7600_server/.keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out pi7600_server/.keys/private.pem
openssl rsa -pubout -in pi7600_server/.keys/private.pem \
  -out pi7600_server/.keys/public.pem

cd pi7600_server

# Build the interactive /docs client. This compiles the Jaspr browser app to
# web/docs/app.js; the generated file is not committed.
dart run tool/build_docs_client.dart

# The development config launches an embedded PostgreSQL instance under
# .serverpod/ and applies migrations.
dart run bin/main.dart --apply-migrations
```

The development server listens on `http://localhost:8082`. Leave it running and
create an API user in another terminal:

```bash
cd pi7600_server
dart run bin/create_user.dart --username alice --admin
```

Without a modem or camera the process still starts; hardware failures are
logged, reflected in the service status Bloc, and surfaced as `ERROR` values in
the API rather than aborting the process.

## Configuration

Pi7600 settings are read from `PI7600_*` environment variables or from a `.env`
file in the server working directory. Serverpod settings live in
`pi7600_server/config/<runMode>.yaml`; the database password comes from
`SERVERPOD_DATABASE_PASSWORD` or `pi7600_server/config/passwords.yaml`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `PI7600_AT_COM` | `/dev/ttyUSB2` | Modem serial port |
| `PI7600_AT_BAUDRATE` | `115200` | Serial speed |
| `PI7600_AT_TIMEOUT` | `10` | Raw AT command timeout (seconds) |
| `PI7600_CAMERA_DEVICE` | unset | Explicit V4L2 device; probes `/dev/video0`-`/dev/video31` when unset |
| `PI7600_CAMERA_INDEX` | `-1` | Prefer `/dev/video<index>` during probing |
| `PI7600_CAMERA_FPS` | `15` | Video stream frame rate |
| `PI7600_CAMERA_WIDTH` | `640` | Requested capture width |
| `PI7600_CAMERA_HEIGHT` | `480` | Requested capture height |
| `PI7600_JWT_PRIVATE_KEY_PATH` | `.keys/private.pem` | JWT signing key |
| `PI7600_JWT_PUBLIC_KEY_PATH` | `.keys/public.pem` | JWT verification key |
| `PI7600_JWT_ISSUER` | `pi.daazed.dev` | JWT issuer claim |
| `PI7600_JWT_EXPIRE_MINUTES` | `30` | Access token lifetime |
| `PI7600_WEBSOCKET_AUTH_TIMEOUT` | `5` | Seconds to wait for the auth message |
| `PI7600_PING_INTERFACE` | `usb0` | Interface used for `data`/`dns` checks |
| `PI7600_PING_TARGETS` | `1.1.1.1,www.google.com` | Ping targets for `data` and `dns` |
| `PI7600_DOCS_ENABLED` | `true` | Serve the interactive `/docs` page and `/openapi.json` |
| `PI7600_DOCS_CLIENT_PATH` | auto | Override the compiled `/docs/app.js` path |
| `SERVERPOD_RUN_MODE` | `development` | Serverpod run mode (`development`, `test`, `production`) |
| `SERVERPOD_DATABASE_PASSWORD` | from `passwords.yaml` | PostgreSQL password |

See `deploy/pi7600.env.example` for a production template.

## Authentication

`POST /token` uses the OAuth2 password form and returns an RS256 JWT:

```bash
curl -X POST http://localhost:8082/token \
  -d 'username=alice&password=secret'
```

```json
{"access_token": "...", "token_type": "bearer"}
```

Send the token as `Authorization: Bearer <token>` on HTTP requests. Invalid,
expired, and disabled-user tokens return `401` with `WWW-Authenticate: Bearer`.

### WebSocket authentication

Browsers cannot set an `Authorization` header on a WebSocket handshake, so the
server accepts the connection and waits for a first JSON message:

```json
{"type": "auth", "token": "<jwt>"}
```

The socket is closed with code `1008` when authentication fails or the message
does not arrive within `PI7600_WEBSOCKET_AUTH_TIMEOUT` seconds. Only then does
`/wss` echo messages or `/wss/video` subscribe the client to JPEG frames. If no
camera is streaming, `/wss/video` closes with code `1011`.

```dart
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final socket = await WebSocket.connect('ws://localhost:8082/wss');
  socket.add(jsonEncode({'type': 'auth', 'token': token}));
  socket.add('hello');
  await for (final message in socket) {
    print(message);
    break;
  }
  await socket.close();
}
```

## API

All routes except `/token`, `/healthz`, `/readyz`, `/docs`, `/docs/*`, and
`/openapi.json` require a bearer token.

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
| `GET` | `/docs` | Interactive API explorer (FastAPI-style) |
| `GET` | `/openapi.json` | OpenAPI 3.1 schema for the HTTP API |
| `WS` | `/wss` | Authenticated echo |
| `WS` | `/wss/video` | Authenticated JPEG frame stream |

The REST payloads, status codes, JWT claims, and WebSocket authentication
protocol match the previous Python service.

### Interactive API explorer

`GET /docs` serves a server-rendered Jaspr page that lists every HTTP and
WebSocket endpoint. Sign in with a Pi7600 username and password: the page
exchanges them for a JWT with `POST /token` and keeps only the token in
`localStorage` for the current browser. Expand an endpoint to edit path
parameters, JSON bodies, or form fields, then press **Execute** to send the
request. **Logout** clears the stored token. The page never bypasses the normal
bearer/admin checks.

`GET /openapi.json` returns the same endpoint catalog as an OpenAPI 3.1
document, so the page and schema cannot drift apart. Both routes, and the
`/docs/style.css` and `/docs/app.js` assets, are disabled with
`PI7600_DOCS_ENABLED=false`.

The interactive app is written in Dart with Jaspr. Its browser entrypoint is
`lib/src/web/docs/docs_app.client.dart`; compile it with:

```bash
cd pi7600_server
dart run tool/build_docs_client.dart
```

The output, `web/docs/app.js`, is a build artifact and is not committed. If it
is missing, `/docs/app.js` returns `503` and the server-rendered page remains
read-only. The native bundle looks for the file at
`/opt/pi7600/web/docs/app.js`.

### Modem status

```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8082/
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
curl -H "Authorization: Bearer $TOKEN" http://localhost:8082/sms

curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"number":"+15551234567","msg":"Hello"}' \
  http://localhost:8082/sms
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
  http://localhost:8082/at
```

### Health checks

`/healthz` is a process liveness check. `/readyz` additionally runs a database
query and returns `503` when the database is unavailable.

## Database and migrations

The schema is managed by Serverpod migrations under
`pi7600_server/migrations/`. `--apply-migrations` applies pending migrations at
startup. To create a migration after changing a model:

```bash
cd pi7600_server
serverpod create-migration
```

### Creating users

`bin/create_user.dart` reads the active Serverpod configuration, so it works
against the embedded development database while the server is running:

```bash
cd pi7600_server
dart run bin/create_user.dart --username alice --admin
```

In production, set `SERVERPOD_RUN_MODE=production` and
`SERVERPOD_DATABASE_PASSWORD`, then run the same command from `/opt/pi7600`.

## Deployment with systemd

The Pi runs a cross-compiled native executable. Build it on a development
machine:

```bash
cd pi7600_server
dart pub get
dart run tool/build_docs_client.dart
dart build cli --target bin/main.dart \
  --target-os linux --target-arch arm64 \
  --output build/pi

# Include the compiled docs client in the native bundle.
mkdir -p build/pi/bundle/web/docs
cp web/docs/app.js build/pi/bundle/web/docs/app.js
```

The bundle is written to `pi7600_server/build/pi/bundle/`. It contains
`bin/main`, the runtime libraries, and `web/docs/app.js`.

1. Install runtime dependencies on the Pi:

   ```bash
   sudo apt-get update
   sudo apt-get install -y libserialport0 postgresql
   sudo systemctl enable --now postgresql
   ```

2. Create the database and role:

   ```bash
   sudo -u postgres psql <<'SQL'
   CREATE ROLE pi7600 LOGIN PASSWORD 'change-me';
   CREATE DATABASE pi7600 OWNER pi7600;
   SQL
   ```

3. Create the service user and directories:

   ```bash
   sudo useradd --system --home /opt/pi7600 --shell /usr/sbin/nologin pi7600
   sudo usermod -aG dialout,video pi7600
   sudo mkdir -p /opt/pi7600 /var/lib/pi7600 /etc/pi7600/keys
   sudo chown -R pi7600:pi7600 /opt/pi7600 /var/lib/pi7600
   ```

4. Copy the bundle, configuration, and migrations:

   ```bash
   sudo cp -a build/pi/bundle/. /opt/pi7600/
   sudo cp -a config migrations /opt/pi7600/
   sudo chown -R pi7600:pi7600 /opt/pi7600
   ```

5. Generate keys in `/etc/pi7600/keys`, copy
   `deploy/pi7600.env.example` to `/etc/pi7600/pi7600.env`, and set the database
   password, `LIBSERIALPORT_PATH=libserialport.so.0`, and any host-specific
   paths.

6. Install and start the unit:

   ```bash
   sudo cp deploy/pi7600.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now pi7600
   sudo journalctl -u pi7600 -f
   ```

The unit runs `/opt/pi7600/bin/main --apply-migrations`, so existing databases
are migrated automatically.

## Development

```bash
dart pub get
dart format pi7600_server pi7600_client
dart analyze pi7600_server
dart analyze pi7600_client
cd pi7600_server && dart test
```

Tests use fake serial transports and in-memory stores, so they do not require a
modem, camera, or database. CI runs the same commands on the stable Dart SDK.

See `docs/roadmap.md` for SQLCipher/PostgreSQL encryption notes, TOTP, and
face-recognition follow-up work.

### Optional face models

The face detector and recognizer models are not all committed. Download them
into `ml/` when you want recognition enabled:

```bash
./scripts/download_models.sh
```

Embeddings are written to `data/embeddings/`, which is gitignored. The
recognition backend is currently a pluggable interface with inference disabled
by default; see `docs/roadmap.md`.

## Security notes

- Treat `/at` as a privileged administration endpoint; keep admin accounts
  limited.
- Keep `.keys/`, `.env`, `config/passwords.yaml`, and `data/embeddings/` out of
  version control.
- Put the service behind HTTPS (for example a reverse proxy) when exposing it
  beyond a trusted network.
- The modem and camera device permissions are granted through the `dialout` and
  `video` groups; do not run the API as root.

## Resources

- [SIM7600G-H 4G HAT product page](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
- [SIM7600 AT command manual](https://www.waveshare.net/w/upload/6/68/SIM7500_SIM7600_Series_AT_Command_Manual_V2.00.pdf)

## License

MIT
