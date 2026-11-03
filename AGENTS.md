# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this project is

Pi7600 is a Dart service built on [Serverpod 4](https://serverpod.dev/) and
PostgreSQL for controlling a SIM7600-series 4G HAT (Waveshare SIM7600G-H) on a
Raspberry Pi. It exposes modem status, host info, SMS send/read/delete,
admin-only raw AT commands, GPS, authenticated WebSocket echo, and an
authenticated camera/video stream.

The repository was ported from Python/FastAPI. The API contract (routes,
payloads, status codes, JWT format, WebSocket auth) is intentionally unchanged.
There is no Python runtime, SQLAlchemy, Alembic, or OpenCV dependency anymore.

The repository is split:

- **`pi7600_server/`:** Serverpod server, modem library, camera/V4L2 capture,
  REST and WebSocket routes, models, migrations, and tests.
- **`pi7600_client/`:** generated Serverpod protocol client package. It is not a
  Flutter app and has no UI.
- **`third_party/relic_io/`:** vendored `relic_io` with a patch that allows RFC
  6455 close codes `1008` and `1011`.

## Quick start

Requirements: Dart **3.13**, PostgreSQL **16+**, `libserialport` (set
`LIBSERIALPORT_PATH=libserialport.so.0` on Debian, whose runtime package omits
the unversioned `.so` symlink), a SIM7600
modem, and a V4L2 camera.

```bash
dart pub get

# Development JWT keys, resolved relative to pi7600_server/.
mkdir -p pi7600_server/.keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out pi7600_server/.keys/private.pem
openssl rsa -pubout -in pi7600_server/.keys/private.pem \
  -out pi7600_server/.keys/public.pem

cd pi7600_server
dart run bin/main.dart --apply-migrations   # embedded PostgreSQL, port 8082
dart run bin/create_user.dart --username alice --admin
```

Common commands:

```bash
dart format pi7600_server pi7600_client
dart analyze pi7600_server
dart analyze pi7600_client
cd pi7600_server && dart test
cd pi7600_server && serverpod create-migration
```

## Repository map

| Path | Purpose |
| --- | --- |
| `pi7600_server/bin/main.dart` | Server entry point |
| `pi7600_server/bin/create_user.dart` | Create API users in PostgreSQL |
| `pi7600_server/lib/server.dart` | Serverpod construction and startup |
| `pi7600_server/lib/src/bootstrap.dart` | Route and middleware registration |
| `pi7600_server/lib/src/app_services.dart` | Process-wide services and async startup |
| `pi7600_server/lib/src/config/app_config.dart` | `PI7600_*` environment configuration |
| `pi7600_server/lib/src/auth/` | JWT (RS256) and bcrypt helpers |
| `pi7600_server/lib/src/data/` | Session-bound user/message stores |
| `pi7600_server/lib/src/models/` | Serverpod model definitions (`*.spy.yaml`) |
| `pi7600_server/lib/src/generated/` | Generated Serverpod models and repositories |
| `pi7600_server/lib/src/modem/` | `At`, stream-based serial transport, settings, SMS/PDU, GPS, phone |
| `pi7600_server/lib/src/camera/` | V4L2 capture, video broadcaster, recognition interface |
| `pi7600_server/lib/src/services/` | SMS/status business logic and service status Bloc |
| `pi7600_server/lib/src/web/` | REST routes, WebSocket routes, `/readyz` middleware |
| `pi7600_server/migrations/` | PostgreSQL migrations |
| `pi7600_server/test/` | Hardware-free tests and fake serial transport |
| `deploy/` | systemd unit and environment example |
| `scripts/` | `setup.sh` and model download helper |
| `docs/` | Roadmap and SIM7600 AT command manual |
| `ml/` | Optional face models (embeddings are gitignored) |

## Architecture

- **Startup (`lib/server.dart` / `AppServices`):** `Serverpod` is constructed
  with an anonymous authentication handler, because Pi7600 authenticates REST
  and WebSocket requests itself. `configureServer` wires routes and starts
  `AppServices` asynchronously. Routes that need hardware await
  `AppServices.ready`. Failures are logged and recorded in
  `ServiceStatusCubit` instead of aborting the process.
- **REST and WebSockets:** custom Relic routes are registered on
  `pod.webServer`. In production the web server port is `8000`; the Serverpod
  API/Insights ports are unused by the Pi7600 contract.
- **Database:** PostgreSQL through Serverpod's database layer. Schema changes
  are Serverpod migrations, not `create_all`. The development config launches
  an embedded PostgreSQL under `pi7600_server/.serverpod/`.
- **Auth:** `POST /token` issues a 30-minute RS256 JWT via
  `dart_jsonwebtoken`. HTTP routes validate the bearer token and load the user
  from PostgreSQL. `/at` additionally requires `is_admin`. WebSockets accept a
  first JSON message `{"type": "auth", "token": "<jwt>"}` within
  `PI7600_WEBSOCKET_AUTH_TIMEOUT` and close with `1008` on failure.
- **Modem I/O:** all commands go through `At.sendAt` / `At.sendRaw` over
  `/dev/ttyUSB2`. `LibSerialPortTransport` uses `SerialPortReader` in an
  isolate and publishes chunks on a broadcast stream; `At` subscribes to that
  stream and waits for data instead of polling. An `AsyncLock` serializes
  callers.
- **Video:** one `CameraCapture` isolate stores the latest JPEG; one
  `VideoBroadcaster` pushes frames to all authenticated `/wss/video` clients.
  MJPEG frames pass through; YUYV frames are converted with `package:image`.
- **Recognition:** `FacialRecognition` is a pluggable `RecognitionBackend`
  interface. No inference backend is currently enabled; see
  `docs/roadmap.md`.

## Conventions

- Target Dart 3.13; prefer `final`, `const`, records, and pattern matching where
  they clarify the code.
- Keep async endpoints non-blocking. Never call blocking serial I/O, FFI, file
  I/O, or `Process.run` directly from an async route without offloading.
- Use `dart:developer` `log` (or Serverpod logging) rather than `print` in
  application code.
- Use `X | None` equivalents (`T?`) and avoid unnecessary nullable fields.
- Keep formatting and imports consistent with `dart format` and
  `dart analyze`. Do not mass-format `third_party/relic_io`.
- Do not edit generated files under `lib/src/generated/`; change the
  `*.spy.yaml` models and run `serverpod generate`.
- Keep `README.md`, `AGENTS.md`, and `docs/roadmap.md` in sync with behavior
  changes.

## Critical gotchas

1. **One Relic route per path.** `WebServer.addRoute` cannot attach two routes
   at the same path, even for different methods. Combine methods in a single
   `Route` and dispatch on `request.method` (see `SmsRoute`).
2. **Routes live on `webServer`.** Custom REST/WebSocket routes are registered
   on `pod.webServer`, so `webServer.port` is the public API port. Do not add
   them to the Serverpod API server.
3. **Serverpod auth hook.** Serverpod initializes an authentication handler for
   every web session. Keep the anonymous handler in `lib/server.dart` unless
   Pi7600 switches to Serverpod's auth modules.
4. **`send_at` returns truthy errors.** Timeouts and modem failures are
   returned as strings containing `ERROR`. Always use `At.isError(response)`
   or compare the expected token; never treat any non-empty string as success.
5. **Serial access is stream-based and serialized.** `At` subscribes to
   `SerialTransport.received`; do not read the port directly or add a polling
   loop. `At.reopen()` cancels and resubscribes.
6. **Settings I/O is explicit.** `ModemSettings.initialize()` opens the serial
   port and loads `pduMode`, `datetime`, and `timezone`. Do not assume modem
   state before it runs.
7. **Database `id` is not the modem index.** `Message.id` is the PostgreSQL
   primary key; `Message.messageIndex` is the SIM index. The delete endpoint
   takes the database id and uses `messageIndex` internally.
8. **Migrations matter.** `create_all` is not used. Add a Serverpod migration
   for schema changes and apply it with `--apply-migrations`.
9. **Hardware-dependent code.** A full run requires `/dev/ttyUSB2` and a V4L2
   camera. Tests must use `test/support/fake_transport.dart` and fake stores;
   do not assume hardware is present in CI.
10. **`/at` is privileged.** Keep it admin-only and audited; do not log
    credentials or secrets.
11. **WebSocket close codes need the vendored patch.** The published
    `relic_io` rejects `1008`/`1011`. The root `dependency_overrides` points to
    `third_party/relic_io`; do not remove it without re-testing WebSocket auth
    and the missing-camera path.
12. **Biometric data is untracked.** Embeddings belong in `data/embeddings/`
    (gitignored). Do not add personal data to the repo.
13. **Secrets stay out of git.** Do not commit `.keys/`, `.env`,
    `config/passwords.yaml`, databases, caches, or generated artifacts.

## Testing

```bash
cd pi7600_server && dart test
```

The suite is hardware-free and covers PDU parsing, AT timeout/error handling,
JWT/bcrypt auth, and SMS persistence/deletion. Add tests for new behavior and
keep them runnable without a modem, camera, or database.

CI (`.github/workflows/ci.yml`) installs the stable Dart SDK and
`libserialport0`, then runs `dart format --set-exit-if-changed`,
`dart analyze`, and `dart test`.

## Definition of done

- `dart format --output=none --set-exit-if-changed pi7600_server pi7600_client`
  passes.
- `dart analyze pi7600_server` and `dart analyze pi7600_client` pass.
- `cd pi7600_server && dart test` passes without hardware.
- New behavior is covered by tests.
- `README.md` is updated for user-visible changes.
- Generated files are regenerated from models, not hand-edited.
- No secrets, databases, caches, biometric data, or generated artifacts are
  committed.

## References

- `README.md` — setup, API, deployment, and security notes.
- `docs/roadmap.md` — database encryption, TOTP, recognition, and API notes.
- `docs/AT-Commands.pdf` — SIM7600 AT command manual.
- [Waveshare SIM7600G-H wiki](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
