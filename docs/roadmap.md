# Roadmap and design notes

## SQLCipher database encryption

Goal: encrypt `cmgl.db` at rest without exposing the key in the repository.

Design notes:

- Use `sqlcipher3-binary` (or `pysqlcipher3`) and pass the key through
  `PRAGMA key` immediately after opening the connection.
- Read the key from an environment variable or a root-owned file referenced by
  `PI7600_DB_KEY_PATH`; never commit it.
- SQLCipher uses a synchronous driver. If the app stays on async SQLAlchemy,
  either run SQLCipher access through a threadpool or keep the async driver for
  unencrypted development and use a separate sync path for encrypted
  deployments.
- Plan a migration: create the encrypted database, copy rows, verify counts,
  then swap the file. Keep a backup until verification succeeds.
- Add a startup check that fails closed when the key is missing in production.

## TOTP two-factor authentication

Goal: optional second factor for API logins.

Design notes:

- Add `totp_secret` and `totp_enabled` to `users` via Alembic.
- Enrollment: generate a secret, show a provisioning URI/QR code once, require a
  valid code before enabling.
- Login: after password verification, require `otp` in the token form when the
  user has TOTP enabled. Keep `/token` OAuth2-compatible by accepting an
  optional `otp` form field.
- Recovery: issue single-use recovery codes (hashed at rest) during enrollment.
- Rate-limit failed TOTP attempts and never log secrets or codes.
- `examples/totp_demo.py` is only a demonstration; runtime dependencies
  (`pyotp`, `qrcode`, `pillow`) are intentionally not part of the app.

## Face recognition follow-up

The current pass fixes camera capture, sharing, and streaming. Recognition is
phased in next:

- Run inference in a threadpool so it never blocks the event loop.
- Use YuNet for detection and SFace for embeddings (already wired in
  `Camera.FacialRecognition`).
- Download models with a script instead of committing large binaries.
- Enroll embeddings into `data/embeddings/` (gitignored) with a small
  enrollment command.
- Add tests with synthetic frames and mocked inference.

## API changes in this pass

- `DELETE /sms/delete/{message_id}` now takes the database `id`; the modem index
  is used internally when the message lives on the SIM.
- SMS responses use typed models and include `id`, `is_sent`, and partial-message
  fields.
- `POST /token` returns a `TokenResponse` and raises `401` on failure.
- `/at` is admin-only and audit-logged.
- WebSockets require a first message of
  `{"type": "auth", "token": "<jwt>"}`.
- `/healthz` and `/readyz` are unauthenticated.
