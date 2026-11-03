# Roadmap and design notes

## Database encryption

The service moved from SQLite to PostgreSQL, so SQLCipher no longer applies.
Encryption at rest is now handled by PostgreSQL or the host:

- Enable storage encryption on the Pi (for example LUKS) or use a managed
  PostgreSQL instance with encryption at rest.
- Keep `SERVERPOD_DATABASE_PASSWORD` out of the repository. Use the systemd
  `EnvironmentFile` (`/etc/pi7600/pi7600.env`, mode `0600`) or a secret manager.
- Require TLS for remote database connections with `requireSsl: true` in
  `config/production.yaml`.
- Back up the database with `pg_dump` and keep backups encrypted; verify
  restores before relying on them.

## TOTP two-factor authentication

Goal: optional second factor for API logins.

Design notes:

- Add `totp_secret` and `totp_enabled` to the `users` model and a Serverpod
  migration.
- Enrollment: generate a secret, show a provisioning URI/QR code once, require a
  valid code before enabling.
- Login: after password verification, require `otp` in the token form when the
  user has TOTP enabled. Keep `/token` OAuth2-compatible by accepting an
  optional `otp` form field.
- Recovery: issue single-use recovery codes (hashed at rest) during enrollment.
- Rate-limit failed TOTP attempts and never log secrets or codes.

## Face recognition follow-up

Camera capture, frame sharing, and `/wss/video` streaming are implemented in
pure Dart. Recognition is kept behind the `RecognitionBackend` interface:

- Implement an inference backend (for example ONNX Runtime via FFI) and keep it
  off the main isolate.
- Use YuNet for detection and SFace for embeddings.
- Download models with `scripts/download_models.sh` instead of committing large
  binaries.
- Enroll embeddings into `data/embeddings/` (gitignored) with a small
  enrollment command.
- Add tests with synthetic frames and mocked inference.

## API changes in this pass

- `DELETE /sms/delete/{message_id}` takes the database `id`; the modem index is
  used internally when the message lives on the SIM.
- SMS responses use typed models and include `id`, `is_sent`, and
  partial-message fields.
- `POST /token` returns an OAuth2 bearer token and raises `401` on failure.
- `/at` is admin-only and audit-logged.
- WebSockets require a first message of
  `{"type": "auth", "token": "<jwt>"}` and close with `1008` on failure.
- `/healthz` and `/readyz` are unauthenticated.
- `/docs` is a server-rendered Jaspr API explorer driven by the same endpoint
  catalog as `/openapi.json`; its interactive client is also Dart/Jaspr,
  compiled by `tool/build_docs_client.dart`. It logs in through `POST /token`,
  and both routes are public and can be disabled with
  `PI7600_DOCS_ENABLED=false`.
- The modem library is the standalone `simcom_modem` Dart package in the
  `pi7600` submodule (`pi7600-lib`); the service consumes it through a path
  dependency.
