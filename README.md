# Simcom API: SIM7600 modem service

Simcom API is a [Serverpod 4](https://serverpod.dev/) service for the
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
| `simcom_api_server/` | Serverpod server, camera/V4L2 capture, REST and WebSocket routes |
| `simcom_api_client/` | Generated Serverpod protocol client package (not a Flutter app) |
| `simcom_modem/` | Git submodule: standalone Dart `simcom_modem` library |
| `simcom_api_server/lib/src/camera/` | V4L2 capture, JPEG broadcaster, recognition interface |
| `simcom_api_server/lib/src/web/` | REST routes and WebSocket upgrade handlers |
| `simcom_api_server/migrations/` | PostgreSQL schema migrations |
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
git submodule update --init --recursive
dart pub get

# JWT signing keys. The development server resolves these relative to
# simcom_api_server/, so create them there.
mkdir -p simcom_api_server/.keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out simcom_api_server/.keys/private.pem
openssl rsa -pubout -in simcom_api_server/.keys/private.pem \
  -out simcom_api_server/.keys/public.pem

cd simcom_api_server

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
cd simcom_api_server
dart run bin/create_user.dart --username alice --admin
```

Without a modem or camera the process still starts; hardware failures are
logged, reflected in the service status Bloc, and surfaced as `ERROR` values in
the API rather than aborting the process.

### Modem library

The modem stack is the `simcom_modem` Dart package in the `simcom_modem/`
submodule ([`simcom_modem`](https://github.com/dazemc/simcom_modem)). The server
consumes it through a path dependency:

```yaml
dependencies:
  simcom_modem:
    path: ../simcom_modem
```

It contains `At`, `LibSerialPortTransport`, `ModemSettings`, `Sms`/`SmsParser`,
`Gps`, and `Phone`. See `simcom_modem/README.md` for direct usage and the
hardware-free test helpers.

## Configuration

Simcom API settings are read from `SIMCOM_API_*` environment variables or
from a `.env` file in the server working directory. Serverpod settings live in
`simcom_api_server/config/<runMode>.yaml`; the database password comes from
`SERVERPOD_DATABASE_PASSWORD` or `simcom_api_server/config/passwords.yaml`.

| Variable | Default | Purpose |
| --- | --- | --- |
| `SIMCOM_API_AT_COM` | `/dev/ttyUSB2` | Modem serial port |
| `SIMCOM_API_AT_BAUDRATE` | `115200` | Serial speed |
| `SIMCOM_API_AT_TIMEOUT` | `10` | Raw AT command timeout (seconds) |
| `SIMCOM_API_CAMERA_DEVICE` | unset | Explicit V4L2 device; probes `/dev/video0`-`/dev/video31` when unset |
| `SIMCOM_API_CAMERA_INDEX` | `-1` | Prefer `/dev/video<index>` during probing |
| `SIMCOM_API_CAMERA_FPS` | `15` | Video stream frame rate |
| `SIMCOM_API_CAMERA_WIDTH` | `640` | Requested capture width |
| `SIMCOM_API_CAMERA_HEIGHT` | `480` | Requested capture height |
| `SIMCOM_API_JWT_PRIVATE_KEY_PATH` | `.keys/private.pem` | JWT signing key |
| `SIMCOM_API_JWT_PUBLIC_KEY_PATH` | `.keys/public.pem` | JWT verification key |
| `SIMCOM_API_JWT_ISSUER` | `pi.daazed.dev` | JWT issuer claim |
| `SIMCOM_API_JWT_EXPIRE_MINUTES` | `30` | Access token lifetime |
| `SIMCOM_API_JWT_REFRESH_DAYS` | `7` | Refresh token lifetime |
| `SIMCOM_API_WEBSOCKET_AUTH_TIMEOUT` | `5` | Seconds to wait for the auth message |
| `SIMCOM_API_LOGIN_MAX_ATTEMPTS` | `5` | Failed logins per username or client address before throttling |
| `SIMCOM_API_LOGIN_WINDOW_SECONDS` | `300` | Window used to count failed logins |
| `SIMCOM_API_LOGIN_BLOCK_SECONDS` | `300` | How long a throttled key stays blocked |
| `SIMCOM_API_AUDIT_RETENTION_DAYS` | `90` | Persistent audit-event retention |
| `SIMCOM_API_LOG_LEVEL` | `INFO` | Minimum application log level (`debug`, `info`, `warn`, `error`) |
| `SIMCOM_API_PING_INTERFACE` | `usb0` | Interface used for `data`/`dns` checks |
| `SIMCOM_API_PING_TARGETS` | `1.1.1.1,www.google.com` | Ping targets for `data` and `dns` |
| `SIMCOM_API_DOCS_ENABLED` | `true` | Serve the interactive `/docs` page and `/openapi.json` |
| `SIMCOM_API_DOCS_CLIENT_PATH` | auto | Override the compiled `/docs/app.js` path |
| `SERVERPOD_RUN_MODE` | `development` | Serverpod run mode (`development`, `test`, `production`) |
| `SERVERPOD_DATABASE_PASSWORD` | from `passwords.yaml` | PostgreSQL password |

See `deploy/simcom_api.env.example` for a production template.

## Authentication

`POST /token` uses the OAuth2 password form and returns an RS256 JWT:

```bash
curl -X POST http://localhost:8082/token \
  -d 'username=alice&password=secret'
```

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "token_type": "bearer",
  "expires_in": 1800
}
```

Send the access token as `Authorization: Bearer <token>` on HTTP requests.
Invalid, expired, revoked, and disabled-user tokens return `401` with
`WWW-Authenticate: Bearer`. Access tokens expire after
`SIMCOM_API_JWT_EXPIRE_MINUTES`; exchange the refresh token at
`POST /token/refresh` for a new pair. `POST /logout` increments the user's
token version, revoking every outstanding access and refresh token for that
user.

Repeated failed logins are throttled per username and client address. After
`SIMCOM_API_LOGIN_MAX_ATTEMPTS` failures inside
`SIMCOM_API_LOGIN_WINDOW_SECONDS`, the endpoint returns `429` with
`Retry-After` for `SIMCOM_API_LOGIN_BLOCK_SECONDS`.
Throttle state is process-local and resets on restart.

### TOTP two-factor authentication

TOTP is optional per user. `POST /totp/setup` takes the current password and
returns a base32 secret, an `otpauth://` provisioning URI, and one-time
recovery codes. The secret is stored immediately, but TOTP stays disabled until
`POST /totp/enable` verifies the first authenticator code. Once enabled,
`POST /token` also requires the `otp` form field:

```bash
curl -X POST http://localhost:8082/token \
  -d 'username=alice&password=secret&otp=123456'
```

Recovery codes work in the same `otp` field and are consumed on use.
`GET /totp` reports the current status, and `POST /totp/disable` requires the
password plus a current TOTP or recovery code. Secrets and codes are never
logged.

Administrators can list, create, and update users through `/users`. Updates can
change the password, full name, email, disabled state, and administrator flag;
changing the password or disabled state revokes that user's outstanding tokens.
User responses never include password hashes, TOTP secrets, or recovery codes.

Logins, WebSocket authentication, logout, `/at` commands, TOTP changes, and
user administration are written to PostgreSQL. Administrators can read the
newest events with `GET /audit?limit=100` and delete expired rows with
`DELETE /audit/cleanup`; the configured `/at` response previews are bounded and
sensitive commands are redacted before storage. Events older than
`SIMCOM_API_AUDIT_RETENTION_DAYS` are removed only when cleanup is invoked.

### WebSocket authentication

Browsers cannot set an `Authorization` header on a WebSocket handshake, so the
server accepts the connection and waits for a first JSON message:

```json
{"type": "auth", "token": "<jwt>"}
```

The socket is closed with code `1008` when authentication fails or the message
does not arrive within `SIMCOM_API_WEBSOCKET_AUTH_TIMEOUT` seconds. Only then
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

All routes except `/token`, `/token/refresh`, `/healthz`, `/readyz`, `/docs`,
`/docs/*`, and `/openapi.json` require a bearer token.

| Method | Path | Description |
| --- | --- | --- |
| `POST` | `/token` | Issue access and refresh tokens (optional `otp` when TOTP is enabled) |
| `POST` | `/token/refresh` | Exchange a refresh token for a new pair |
| `POST` | `/logout` | Revoke all tokens for the current user |
| `GET` | `/users` | List users (**admin only**) |
| `POST` | `/users` | Create a user (**admin only**) |
| `PATCH` | `/users/{user_id}` | Update a user (**admin only**) |
| `GET` | `/audit` | Recent persistent audit events (**admin only**) |
| `DELETE` | `/audit/cleanup` | Delete expired audit events (**admin only**) |
| `GET` | `/totp` | TOTP status for the current user |
| `POST` | `/totp/setup` | Start TOTP enrollment |
| `POST` | `/totp/enable` | Enable TOTP with the first code |
| `POST` | `/totp/disable` | Disable TOTP |
| `GET` | `/modem` | Modem status summary plus full settings/status report |
| `PATCH` | `/modem` | Apply modem settings and optionally save them (**admin only**) |
| `GET` | `/info` | Hostname, kernel, date, architecture |
| `GET` | `/gps` | Current GPS fix and Google Maps link |
| `GET` | `/camera/snapshot` | Latest camera frame as JPEG |
| `GET` | `/metrics` | Prometheus service metrics (bearer token) |
| `POST` | `/phone/call` | Place a voice call (**admin only**) |
| `POST` | `/phone/hangup` | Hang up the active call (**admin only**) |
| `GET` | `/phone/calls` | List active calls (**admin only**) |
| `GET` | `/sms` | Sync messages from the SIM and return the database rows (`limit`, `offset`, `q` optional) |
| `POST` | `/sms` | Send an SMS |
| `POST` | `/sms/retry/{message_id}` | Retry an unsent outgoing message |
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
protocol are unchanged.

### Complete modem report

`GET /modem` is the modem status and diagnostics endpoint. Top-level fields
include the fast summary: `at`, `cnum`, `csq`, `cpin`, `creg`, `cops`,
`gpsinfo`, `data`, `dns`, `apn`, and `timezone`. It also queries the full modem
catalog: identity and firmware, SIM state, signal and registration, packet-data
contexts, SMS/audio settings, power, GPS, active calls, and the complete `AT&V`
settings dump.

The response contains parsed core values under `parsed`, raw responses grouped
under `sections`, and every command response under `raw`. Unsupported commands
are reported with their error response instead of being omitted.

### Changing modem settings

`PATCH /modem` applies settings in order. Keys are AT command bases without
`=`, and values are the text after `=`:

```bash
curl -X PATCH -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "settings": {
      "AT+CMGF": "1",
      "AT+CSCS": "\"GSM\"",
      "AT+CMEE": "2"
    },
    "save": true
  }' \
  http://localhost:8082/modem
```

The response reports success and the raw response for every command. `save`
runs `AT&W`. Use `/at` for arbitrary AT actions or commands outside the setting
syntax. Settings are admin-only and audited.

### AT command reference

`GET /modem` returns raw responses for every command below. `PATCH /modem`
writes settings by sending the command base with a value, for example
`{"AT+CMGF": "0"}` sends `AT+CMGF=0`. A trailing `?` means "read the current
value"; the write form drops the `?` and appends `=value`.

#### Identity and SIM

| Command | What it does | Example use |
| --- | --- | --- |
| `AT` | Checks that the AT command channel responds. | Liveness check; `/modem` reports `at: "OK"`. |
| `ATI` | Returns product identification: manufacturer, model, and revision. | Quick inventory or support snapshot. |
| `AT+CGMI` | Returns the manufacturer name. | Confirm you are talking to a SimTech/SIMCom modem. |
| `AT+CGMM` | Returns the modem model. | Detect `SIMCOM_SIM7600G-H` in an asset registry. |
| `AT+CGMR` | Returns the firmware revision. | Compare against a known-good firmware build. |
| `AT+CGSN` | Returns the IMEI. | Register the radio in an inventory without reading the label. |
| `AT+CIMI` | Returns the IMSI from the SIM. | Verify the inserted SIM is the expected subscription. Treat as personal data. |
| `AT+CCID` | Returns the SIM ICCID. | Match the physical SIM card to the account record. |
| `AT+CNUM` | Returns the subscriber number stored on the SIM. | Show the modem's phone number; some SIMs leave it blank. |
| `AT+CPIN?` | Reports SIM PIN state, normally `+CPIN: READY`. | Readiness check before SMS, calls, or data. |
| `AT+CPINR?` | Reports remaining PIN/PUK retry counts where supported. | Warn before a SIM becomes permanently locked. |
| `AT+CPAS` | Reports modem activity: ready, unavailable, ringing, call in progress, or asleep. | Detect whether a call is active without parsing call state. |
| `AT+CFUN?` | Reports radio functionality mode. | Confirm the radio is in full mode (`1`) rather than airplane/minimum mode. Write `AT+CFUN=1` to restore full mode; `AT+CFUN=4` disables the radio. |
| `AT+CPBS?` | Reports the selected phonebook storage. | Audit whether contacts are stored on the SIM or modem. Write `AT+CPBS="SM"` to select SIM storage. |
| `AT+CPMS?` | Reports SMS storage used/total for read, write, and receive. | Check SIM inbox capacity before bulk SMS work. Write `AT+CPMS="SM","SM","SM"` to use SIM storage. |

#### Network and packet data

| Command | What it does | Example use |
| --- | --- | --- |
| `AT+CSQ` | Returns RSSI (0-31, or 99 unknown) and bit-error rate. | Dashboard signal strength; `99,99` means no usable signal. |
| `AT+CESQ` | Returns extended signal quality (RSRP, RSRQ, SINR where supported). | Diagnose LTE quality beyond RSSI. |
| `AT+CREG?` | Reports circuit-switched network registration and location. | Distinguish home (`0,1`), searching (`0,2`), denied (`0,3`), and roaming (`0,5`). |
| `AT+CGREG?` | Reports GPRS/packet-switched registration. | Verify the modem is registered for data. |
| `AT+CEREG?` | Reports LTE/EPS registration. | Check LTE attach state separately from legacy registration. |
| `AT+COPS?` | Reports the selected operator and access technology. | Confirm `Tello`/T-Mobile LTE instead of an unintended carrier. Write `AT+COPS=0` for automatic selection, or `AT+COPS=1,2,"310260",7` to force a numeric operator and LTE. |
| `AT+CGATT?` | Reports whether the modem is attached to a packet domain. | Data-session health check; `1` means attached. |
| `AT+CPSI?` | Returns SIM7600 system information such as mode, band, cell, and channel. | RF/cell-site diagnostics when signal quality is poor. |
| `AT+CGACT?` | Reports which PDP contexts are active. | See whether the data bearer is actually up. Write `AT+CGACT=1,1` to activate context 1 or `AT+CGACT=0,1` to deactivate it. |
| `AT+CGPADDR` | Returns the IP address assigned to each PDP context. | Confirm the modem obtained an IPv4/IPv6 address. |
| `AT+CGCONTRDP` | Returns dynamic context parameters: APN, addresses, DNS servers, MTU, and more. | Verify DNS and MTU after a data session comes up. |
| `AT+CGDCONT?` | Lists configured PDP contexts and APNs. | Audit which APN the modem will use. Write `AT+CGDCONT=1,"IPV4V6","wholesale"` to set the primary APN. |

#### SMS and audio

| Command | What it does | Example use |
| --- | --- | --- |
| `AT+CMGF?` | Reports SMS mode: `0` PDU, `1` text. | Keep the service in PDU mode (`0`) unless you deliberately need text commands. Write `AT+CMGF=0` or `AT+CMGF=1`. |
| `AT+CNMI?` | Reports how new SMS indications are routed to the terminal. | Tune unsolicited `+CMTI` notifications. Write `AT+CNMI=2,1,0,0,0` to notify and store incoming messages. |
| `AT+CSMP?` | Reports text-mode SMS parameters: validity period, protocol ID, and data coding. | Debug text-mode SMS encoding. Write `AT+CSMP=17,167,0,0` for a common GSM 7-bit setup. |
| `AT+CSCA?` | Reports the SMS service-center address. | Verify SMSC before troubleshooting SMS delivery. Write `AT+CSCA="+15551234567",145`. |
| `AT+CSDH?` | Controls whether text-mode `+CMGL`/`+CMGR` include detailed headers. | Enable (`AT+CSDH=1`) when debugging text-mode SMS metadata. |
| `AT+CSMS?` | Reports supported SMS service types and stored-message support. | Capability check before selecting an SMS workflow. Write `AT+CSMS=0` for GSM 03.40. |
| `AT+CSCS?` | Reports the terminal character set (`IRA`, `GSM`, `UCS2`, etc.). | Fix garbled non-ASCII SMS text. Write `AT+CSCS="GSM"` or `AT+CSCS="UCS2"`. |
| `AT+CMUT?` | Reports microphone mute state during a call. | Privacy control for voice calls. Write `AT+CMUT=1` to mute and `AT+CMUT=0` to unmute. |
| `AT+CLVL?` | Reports the audio volume level. | Adjust speaker/headset loudness. Write `AT+CLVL=3` (range depends on firmware). |
| `AT+CSDVC?` | Reports the selected audio device/path. | Route call audio to handset, headset, or speaker. Write `AT+CSDVC=1` after checking the model's device mapping. |

#### Settings, time, and call presentation

| Command | What it does | Example use |
| --- | --- | --- |
| `AT&V` | Dumps the active modem profile and all current S-register/command settings. | Configuration snapshot before and after a change; compare profiles. |
| `AT+CMEE?` | Reports error-reporting mode: disabled, numeric, or verbose. | Turn on `+CME ERROR` details. Write `AT+CMEE=2` for verbose errors. |
| `AT+CRC?` | Reports whether incoming calls use extended `+CRING` indications. | Distinguish voice/data/fax call types. Write `AT+CRC=1` to enable. |
| `AT+CLIP?` | Reports calling-line identification presentation. | Show the caller's number on incoming calls. Write `AT+CLIP=1` to enable. |
| `AT+CLIR?` | Reports outgoing caller-ID restriction. | Hide or present the modem's number. Write `AT+CLIR=1` to restrict, `AT+CLIR=0` to present, subject to network support. |
| `AT+COLP?` | Reports connected-line identification presentation. | Show the number that actually answered. Write `AT+COLP=1` to enable. |
| `AT+CCWA?` | Reports call-waiting state. | Enable a second-call notification. Write `AT+CCWA=1` to enable and `AT+CCWA=0` to disable. |
| `AT+CUSD?` | Reports USSD support/result-code configuration. | Run carrier USSD codes such as balance checks. Write `AT+CUSD=1` to enable result codes. |
| `AT+CTZU?` | Reports automatic timezone updating from the network. | Keep the modem clock aligned after travel. Write `AT+CTZU=1` to enable. |
| `AT+CTZR?` | Reports timezone-change event reporting. | Receive unsolicited timezone updates. Write `AT+CTZR=1` to enable. |
| `AT+CLTS?` | Reports network time synchronization. | Get time from the carrier instead of the host. Write `AT+CLTS=1` to enable. |
| `AT+CCLK?` | Reads the modem real-time clock. | Display modem time or set it with `AT+CCLK="26/11/03,12:34:56-32"` (quarter-hour offset). |

#### Power, GPS, and calls

| Command | What it does | Example use |
| --- | --- | --- |
| `AT+CBC` | Reports battery charge state, percent, and voltage where supported. | Battery/UPS monitoring on a portable build. |
| `AT+CPMUTEMP?` | Reports the modem temperature on SIM7600 firmware that supports it. | Thermal monitoring in an enclosure. |
| `AT+CGPS?` | Reports GPS session state and mode. | Check whether GPS is powered/running. Write `AT+CGPS=1` to start or `AT+CGPS=0` to stop. |
| `AT+CGPSINFO` | Returns the current GPS fix. | Feed `/gps` and the Google Maps link. |
| `AT+CGPSSTATUS?` | Reports GPS fix status. | Troubleshoot "GPS active but no signal" by distinguishing searching from fixed. |
| `AT+CGPSAUTO?` | Reports whether GPS starts automatically. | Configure a tracker to acquire GPS after boot. Write `AT+CGPSAUTO=1` to enable. |
| `AT+CLCC` | Lists active calls with direction, state, mode, and number. | Build call-control UIs or verify that a dial reached alerting/active state. |

The write examples above are accepted by `PATCH /modem`. `save: true` adds
`AT&W` to persist the active profile. Commands outside this settings pattern,
or actions such as dialing and sending SMS, still belong on the admin-only
`/at` endpoint.

### Interactive API explorer

`GET /docs` serves a server-rendered Jaspr page that lists every HTTP and
WebSocket endpoint. Sign in with a Simcom API username and password: the page
exchanges them for a JWT with `POST /token` and keeps only the token in
`localStorage` for the current browser. Expand an endpoint to edit path
parameters, JSON bodies, or form fields, then press **Execute** to send the
request. **Logout** clears the stored token. The page never bypasses the normal
bearer/admin checks.

`GET /openapi.json` returns the same endpoint catalog as an OpenAPI 3.1
document, so the page and schema cannot drift apart. Both routes, and the
`/docs/style.css` and `/docs/app.js` assets, are disabled with
`SIMCOM_API_DOCS_ENABLED=false`.

The interactive app is written in Dart with Jaspr. Its browser entrypoint is
`lib/src/web/docs/docs_app.client.dart`; compile it with:

```bash
cd simcom_api_server
dart run tool/build_docs_client.dart
```

The output, `web/docs/app.js`, is a build artifact and is not committed. If it
is missing, `/docs/app.js` returns `503` and the server-rendered page remains
read-only. The native bundle looks for the file at
`/opt/simcom_api/web/docs/app.js`.

The docs page and assets are gzipped when requested and carry `ETag` headers.
Clients can send `If-None-Match` to get `304 Not Modified` instead of a full
response.

### Metrics

`GET /metrics` returns Prometheus text with modem, camera, recognition, video
client, lifecycle, and process-memory gauges, plus per-method/path/status
request counts and duration summaries. It requires a bearer token.

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
`simcom_api_server/migrations/`. `--apply-migrations` applies pending migrations at
startup. To create a migration after changing a model:

```bash
cd simcom_api_server
serverpod create-migration
```

### Creating users

`bin/create_user.dart` reads the active Serverpod configuration, so it works
against the embedded development database while the server is running:

```bash
cd simcom_api_server
dart run bin/create_user.dart --username alice --admin
```

In production, set `SERVERPOD_RUN_MODE=production` and
`SERVERPOD_DATABASE_PASSWORD`, then run the same command from `/opt/simcom_api`.

## Deployment with systemd

The Pi runs a cross-compiled native executable. Build it on a development
machine:

```bash
git submodule update --init --recursive
cd simcom_api_server
dart pub get
dart run tool/build_release.dart
```

`build_release.dart` compiles the docs client, runs `dart build cli` for
Linux/ARM64, and copies `web/docs/app.js` into the bundle. Use
`--target-arch=x64` or `--output=...` for a different target.

The bundle is written to `simcom_api_server/build/pi/bundle/`. It contains
`bin/main`, the runtime libraries, and `web/docs/app.js`.

1. Install runtime dependencies on the Pi:

   ```bash
   sudo apt-get update
   sudo apt-get install -y libserialport0 postgresql
   sudo systemctl enable --now postgresql
   ```

On systems where the modem's `ttyUSB` numbering changes after a USB reset,
install the optional udev rule and point `SIMCOM_API_AT_COM` at
`/dev/simcom-at`:

```bash
sudo cp deploy/99-simcom-at.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=tty
```

2. Create the database and role:

   ```bash
   sudo -u postgres psql <<'SQL'
   CREATE ROLE simcom_api LOGIN PASSWORD 'change-me';
   CREATE DATABASE simcom_api OWNER simcom_api;
   SQL
   ```

3. Create the service user and directories:

   ```bash
   sudo useradd --system --home /opt/simcom_api --shell /usr/sbin/nologin simcom_api
   sudo usermod -aG dialout,video simcom_api
   sudo mkdir -p /opt/simcom_api /var/lib/simcom_api /etc/simcom_api/keys
   sudo chown -R simcom_api:simcom_api /opt/simcom_api /var/lib/simcom_api
   ```

4. Copy the bundle, configuration, and migrations:

   ```bash
   sudo cp -a build/pi/bundle/. /opt/simcom_api/
   sudo cp -a config migrations /opt/simcom_api/
   sudo chown -R simcom_api:simcom_api /opt/simcom_api
   ```

5. Generate keys in `/etc/simcom_api/keys`, copy
   `deploy/simcom_api.env.example` to `/etc/simcom_api/simcom_api.env`, and set the database
   password, `LIBSERIALPORT_PATH=libserialport.so.0`, and any host-specific
   paths.

6. Install and start the unit:

   ```bash
   sudo cp deploy/simcom_api.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now simcom_api
   sudo journalctl -u simcom_api -f
   ```

The unit runs `/opt/simcom_api/bin/main --apply-migrations`, so existing databases
are migrated automatically.

## Development

```bash
git submodule update --init --recursive
dart pub get
dart format simcom_api_server simcom_api_client simcom_modem
dart analyze simcom_api_server
dart analyze simcom_api_client
dart analyze simcom_modem
cd simcom_api_server && dart test
cd simcom_modem && dart test
```

Tests use `FakeTransport` from `package:simcom_modem/testing.dart` and in-memory
stores, so they do not require a modem, camera, or database. CI checks out
submodules and runs the same commands on the stable Dart SDK.

Hardware-free performance checks:

```bash
cd simcom_api_server
dart run tool/benchmark.dart
```

The harness measures AT command round trips, SMS PDU parsing, bcrypt
verification (native and worker-isolate), JWT verification, and YUYV-to-JPEG
conversion.

A browser smoke test covers the docs login and try-it-out flow without a
database or modem. It requires Node.js 22+ and Chrome/Chromium:

```bash
cd simcom_api_server
dart run tool/build_docs_client.dart
dart run tool/docs_test_server.dart &
node tool/docs_browser_test.mjs
```

Stop the fake server after the test. CI runs the same flow in the
`docs-browser` job.

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
