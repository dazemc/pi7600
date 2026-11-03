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

Implemented:

- `totp_secret`, `totp_enabled`, and `totp_recovery_codes` on the `users` model,
  with a Serverpod migration.
- `POST /totp/setup` returns a base32 secret, an `otpauth://` provisioning URI,
  and ten recovery codes. TOTP stays disabled until `POST /totp/enable`
  verifies the first code.
- `/token` keeps the OAuth2 password form and accepts an optional `otp` field.
  TOTP codes allow one adjacent 30-second window; recovery codes are
  single-use.
- Recovery codes are stored as SHA-256 hashes in the user row and consumed on
  use; TOTP secrets and codes are never logged.
- Password and code guesses on the TOTP endpoints use the login rate limiter.

Follow-ups:

- Render the provisioning URI as a QR code in the docs page.
- Encrypt TOTP secrets at rest together with the rest of the database.

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
  `simcom_modem` submodule; the service consumes it through a path dependency.
