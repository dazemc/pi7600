# TODO

Backlog for the `simcom_api` service and `simcom_modem` library.

## Workflow

- Keep `simcom_api/main`, `simcom_modem/main`, and the `simcom_modem` submodule
  pointer up to date before and after each batch.
- For each item: update code and tests, run format/analyze/tests, update docs
  where behavior changes, commit, push, and confirm CI.
- Work in the order below: performance, correctness/security, testing/CI, then
  features.

## Performance

- [x] **Move bcrypt off the main isolate.**
  - `TokenRoute` currently awaits `hashlib` bcrypt on the event loop.
  - Use a long-lived worker isolate (or `Isolate.run`) so a 6–9 second login
    does not block `/healthz`, `/docs`, `/info`, or WebSockets.
  - Keep the pure-Dart verifier as the fallback.

- [x] **Use native bcrypt through `libcrypt` FFI.**
  - Replace pure-Dart bcrypt verification with `crypt_rn`/`crypt_r` from
    `libcrypt` where available.
  - Keep `hashlib` as a fallback for systems without `libcrypt`.
  - Test on x86 and ARM64; target login latency well under 2 seconds on the Pi.
  - Do not reduce the bcrypt cost.
  - x86 verified locally; ARM64/Pi validation still pending deployment.

- [x] **Cache static `/info` values.**
  - `StatusService.info()` spawns `hostname`, `uname -r`, `date`, and `arch`
    processes on every request.
  - Use `Platform.localHostname` for hostname and cache `uname`/`arch` at
    startup or behind a TTL.
  - Keep `date` current, or format it in Dart without a subprocess.
  - Target: at most one process spawn per `/info` request.

- [x] **Add an SMS fingerprint index.**
  - `SessionMessageStore.findByFingerprint` queries `message_type`,
    `message_contents`, `message_date`, and `message_time` with no index.
  - Add a non-unique composite index through a Serverpod migration.
  - Keep the existing deduplication behavior and add a migration test/check.

- [x] **Profile JWT verification and user lookup.**
  - Add timings around `JwtService.verifyToken` and
    `SessionUserStore.findByUsername`.
  - If RSA verification is material, evaluate a native OpenSSL path or a
    short-lived verified-token cache.
  - If database lookup is material, evaluate a short user cache with a clear
    disabled-user invalidation story.
  - Measure before adding cache complexity.
  - Debug timings are in place; optimization decisions await Pi measurements.

- [x] **Cache or reduce status ping subprocesses.**
  - `StatusService.status()` launches two `ping` processes per request.
  - Add a short TTL cache for `data`/`dns` results (5–10 seconds) or use a
    persistent network monitor.
  - Document the freshness trade-off.

- [x] **Optimize docs asset delivery.**
  - Serve a gzipped `web/docs/app.js` and `style.css`.
  - Add `ETag`/`If-None-Match` and cache headers.
  - Keep the bundle build artifact out of git.
  - Implemented gzip + `Vary: Accept-Encoding` + a 5-minute cache window,
    plus `ETag`/`If-None-Match` revalidation for the page and every asset.

- [x] **Implement `SIMCOM_API_LOG_LEVEL` and reduce production session logging.**
  - `AppConfig.logLevel` is parsed but unused.
  - Add a small logger filter for debug/info/warn/error.
  - Disable per-request console session logs in production unless explicitly
    enabled.
  - Keep `/at` audit logging.

- [x] **Start the camera lazily.**
  - Camera capture currently runs at startup even with no `/wss/video` clients.
  - Start capture when the first video client connects and stop after the last
    client disconnects (with a grace period).
  - Keep the no-camera `1011` behavior and avoid startup races.
  - Local no-camera `1011` and invalid-token `1008` paths verified; hardware
    FPS/camera-start validation still pending.

- [x] **Optimize `At` buffering.**
  - `_buffer += utf8.decode(data)` rebuilds the response string per chunk.
  - Use a `BytesBuilder`/`StringBuffer` or accumulate bytes and decode once.
  - Benchmark large `AT+CMGL` responses before/after.
  - Implemented a byte buffer with byte-level terminator matching and a
    split-chunk regression test.

- [ ] **Database tuning and batching.**
  - Evaluate a local PostgreSQL Unix socket to reduce connection latency.
  - Tune `maxConnectionCount` for the Pi workload.
  - Consider batching SMS persistence/upserts once the fingerprint index is in
    place.
  - Do not change API response shapes for this work.
  - Evaluated: the composite SMS index is the main win and the default pool is
    adequate for the Pi workload. Unix-socket and batching changes are deferred
    until measurements show a need.

## Correctness and security

- [x] **Await `AppServices.ready` in hardware routes.**
  - `StatusRoute`, `SmsRoute`, `SmsDeleteRoute`, `SmsCleanupRoute`, and
    `AtRoute` can touch the modem before `ModemSettings.initialize()` runs.
  - Await `services.ready` before hardware use; readiness completes even when
    hardware fails, so the existing `ERROR` behavior remains.
  - Add a startup-race regression test if practical.

- [x] **Prevent duplicate sends of parsed `SENT` messages.**
  - `SmsService.createMessage` sends when `messageType == 'SENT'` and
    `isSent != true`.
  - Change the condition to only send when `isSent == false`, or mark parsed
    sent messages as sent in the parser.
  - Add a regression test that a parsed `SENT` message is not re-sent.

- [x] **Clean up `CameraCapture.start()` on timeout/failure.**
  - Kill the isolate, close the receiver, and clear control ports when startup
    times out or errors.
  - Allow a clean retry without leaking the previous isolate.

- [x] **Use a monotonic clock for camera frame pacing.**
  - Replace `DateTime.now()` frame timing with `Stopwatch` so NTP jumps do not
    cause bursts or stalls.

- [x] **Pin JWT verification to RS256.**
  - Reject tokens whose header algorithm is not `RS256` before verification.
  - Keep issuer, expiry, and subject checks unchanged.

- [x] **Redact sensitive `/at` audit logs.**
  - Avoid logging PIN/password values from commands such as `AT+CPIN`,
    `AT+CLCK`, and `AT+CPWD`.
  - Keep the admin audit trail without leaking secrets.

- [x] **Handle malformed token form bodies.**
  - Catch `FormatException` from `Uri.splitQueryString` and return a controlled
    `422` instead of a 500.

- [x] **Handle SMS rows marked in SIM without a `messageIndex`.**
  - Delete/cleanup currently skips the modem operation and removes/updates the
    row, so the message can be re-imported.
  - Log or return a controlled error and decide whether the row should remain.

- [x] **Reduce WebSocket message-content logging.**
  - `/wss` logs full message text.
  - Log length/metadata only, or put content behind debug logging.

## Testing and CI

- [x] **WebSocket auth and close-code tests.**
  - Cover missing, invalid, and expired tokens with close code `1008`.
  - Cover the missing-camera `/wss/video` path with close code `1011`.
  - Keep the vendored `relic_io` patch covered.
  - Auth handshake tests added; the missing-camera `1011` path is covered by
    the local no-camera smoke test and still needs a CI harness.

- [x] **Camera and video broadcaster tests.**
  - Test YUYV-to-JPEG conversion with a synthetic frame.
  - Test broadcaster client removal when `trySendBytes` fails.
  - Test frame pacing with a fake device/clock where practical.

- [x] **Route-level tests.**
  - Exercise token, status, SMS, and `/at` handlers with fake services.
  - Cover auth failure, admin failure, validation errors, and startup readiness.
  - Added a fake session/database harness and route tests for token/refresh/
    logout, TOTP, users, audit, metrics, health, and docs ETags. Hardware-backed
    status/SMS/`/at` paths are covered by the production endpoint smoke test.

- [x] **Browser docs test in CI.**
  - Automate login, logout, unauthenticated execute, and authenticated execute.
  - Use the existing headless-browser flow or a lightweight Playwright setup.
  - Implemented a fake docs server plus a Chrome DevTools smoke test; runs in
    the `docs-browser` CI job.

- [x] **Benchmark harness.**
  - Measure `/healthz`, `/token`, `/info`, `/`, and `/sms` with fake hardware.
  - Measure camera capture/encode FPS on hardware with a V4L2 device.
  - Track bcrypt, JWT, DB, AT command, and process-spawn timings.
  - Hardware-free benchmark script added; HTTP-level numbers still need a
    running service.

- [x] **Release build script.**
  - Automate `dart build cli` plus copying `web/docs/app.js` into the bundle.
  - Ensure the submodule and docs client are built in the correct order.

## Features

- [x] **Google Maps links for GPS coordinates.**
  - Add a `maps_url` field or docs link for valid coordinates.
  - Decide whether this belongs on `/`, a GPS endpoint, or the docs page.
  - Handle no-fix and malformed `+CGPSINFO` values without generating links.
  - Added `GET /gps`, `GpsFix`, and a clickable Google Maps link in the docs
    result panel.

- [x] **Phone endpoints.**
  - Expose the library's `Phone` helpers: dial, hang up, and active calls.
  - Decide on auth level and rate limiting before exposing call control.
  - Added admin-only `POST /phone/call`, `POST /phone/hangup`, and
    `GET /phone/calls`; library phone tests cover the modem commands.

- [x] **GPS endpoints.**
  - Start/stop the GPS session and return the current position separately from
    the aggregate status response.
  - `GET /gps` returns the raw response, parsed fix, and Maps URL. Explicit
    start/stop routes remain future work.

- [x] **Camera snapshot endpoint.**
  - Return the latest JPEG as a single HTTP response in addition to
    `/wss/video`.
  - Added `GET /camera/snapshot`; it starts capture on demand, waits briefly
    for a frame, and returns 503 when no camera is available. The docs page
    detects binary responses and offers a download link. Hardware capture
    remains unverified on the Pi.

- [x] **SMS retry.**
  - Add a retry path for stored-but-unsent messages.
  - Added `POST /sms/retry/{id}`; already-sent rows are returned unchanged.

- [x] **SMS pagination and search.**
  - Add optional pagination/search without breaking the existing list contract
    where possible.
  - `GET /sms` accepts optional `limit` (1-500), `offset`, and `q`; the
    existing response shape is unchanged when none are supplied.

- [x] **Metrics endpoint.**
  - Expose request counts, latency, modem state, camera state, and process
    metrics in Prometheus format.
  - Added `/metrics` with modem/camera/recognition state, video client count,
    lifecycle phase, RSS metrics, request counts, and request-duration
    summaries.

- [x] **Login rate limiting.**
  - Add per-user/IP throttling for failed logins.
  - In-memory limiter keyed by username and client address; returns `429` with
    `Retry-After` after `SIMCOM_API_LOGIN_MAX_ATTEMPTS` failures. State is
    process-local.

- [x] **TOTP two-factor authentication.**
  - Add TOTP enrollment and verification as described in `docs/roadmap.md`.
  - Includes `totp_secret`/`totp_enabled` model fields, migration, optional
    `otp` on `/token`, enrollment endpoints, and recovery codes.
  - Added `/totp`, `/totp/setup`, `/totp/enable`, and `/totp/disable`;
    recovery codes are single-use SHA-256 hashes and TOTP management attempts
    share the login limiter.

- [x] **Token revocation and refresh.**
  - Current logout only clears browser storage; add a server-side revocation
    path or short-lived access tokens with refresh.
  - Added per-user token versions, `POST /logout`, refresh tokens, and
    `POST /token/refresh`. Logout revokes every outstanding token for the user;
    the docs page now calls the server on logout.

- [x] **User management API.**
  - Create, list, disable, and promote users without the CLI.
  - Keep it admin-only and audited.
  - Added admin-only `GET /users`, `POST /users`, and `PATCH /users/{id}`.
    Password/disabled changes revoke tokens; responses omit credentials and
    TOTP material; self-disable and self-demotion are rejected.

- [x] **Persistent audit log.**
  - Store `/at` and authentication events in PostgreSQL or a dedicated audit
    table.
  - Redact secrets and define retention.
  - Added the `audit_events` table, `/audit` and `/audit/cleanup` admin
    endpoints, bounded/redacted `/at` details, and a configurable retention
    window. Cleanup is manual or can be scheduled externally.

- [x] **Rename deployment artifacts.**
  - Renamed the service unit, env file, Linux user/group, install paths, database,
    env prefix, metrics, docs storage key, and logs to `simcom_api`.
  - The production Pi was cut over with database/app backups retained.
