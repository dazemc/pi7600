# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this project is

Pi7600 is a FastAPI service plus a Python library for controlling a SIM7600-series
4G HAT (Waveshare SIM7600G-H) on a Raspberry Pi. It exposes modem status, host
info, SMS send/read/delete, admin-only raw AT commands, GPS, authenticated
WebSocket echo, and an authenticated camera/video stream.

The repository is split:

- **Parent repo (this one):** FastAPI app, auth, async database, Alembic
  migrations, camera/WebSocket code, tests, deployment files, helper scripts.
- **`pi7600/` (git submodule):** the modem library (`AT`, `Settings`, `SMS`,
  `GPS`, `Phone`, `ParserSMS`). It is a **separate git repository** with its own
  Ruff config.

## Quick start

Requirements: Python **3.13**, [uv](https://docs.astral.sh/uv/), a SIM7600
modem, and a camera.

```bash
uv sync --python 3.13

# Generate the RS256 key pair used for JWTs.
mkdir -p .keys
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out .keys/private.pem
openssl rsa -pubout -in .keys/private.pem -out .keys/public.pem

# Local configuration and schema.
cp .env.example .env
uv run alembic upgrade head

# Create an API user (add --admin for /at access). Run from the repo root.
uv run python scripts/create_user.py --admin

# Run the API.
uv run uvicorn main:app --reload
# or, for the scripted/logging setup:
./start.sh
```

Common commands:

```bash
uv run ruff check .                              # lint parent
uv run ruff format .                             # format parent
uv run ruff check pi7600 --config pi7600/ruff.toml
uv run ruff format --check pi7600 --config pi7600/ruff.toml
uv run pytest -q                                 # hardware-free tests
uv run alembic revision --autogenerate -m "..."  # new migration
uv run alembic upgrade head                      # apply migrations
```

## Repository map

| Path | Purpose |
| --- | --- |
| `main.py` | FastAPI app factory, lifespan, all HTTP/WebSocket routes |
| `Config.py` | `pydantic-settings` configuration (`PI7600_*` env vars) |
| `Database.py` | Async engine/session, `init_db`, `run_migrations` |
| `Models.py` | SQLAlchemy ORM models and Pydantic request/response models |
| `Auth.py` | Bearer-token dependency, admin dependency, WebSocket auth |
| `Utils.py` | Lazy JWT key loading, token create/verify, bcrypt helpers |
| `Camera.py` | Capture thread, shared video broadcaster, YuNet/SFace recognition |
| `Websockets.py` | Small generic `ConnectionManager` (echo endpoint) |
| `pi7600/` | Git submodule: modem library |
| `tests/` | Pytest suite with fake hardware and temporary SQLite |
| `alembic/` | Migration environment and versions |
| `deploy/` | systemd unit and environment example |
| `scripts/` | Operational scripts (`create_user.py`, `catcmd`, `download_models.py`, RNDIS, setup) |
| `examples/` | Standalone demos (TOTP), not runtime code |
| `docs/roadmap.md` | SQLCipher, TOTP, and recognition follow-up notes |
| `ml/` | OpenCV face models (embeddings are gitignored) |
| `start.sh`, `log.yaml` | Uvicorn startup and logging configuration |
| `cmgl.db` | SQLite database created at runtime (gitignored) |

## Architecture

- **Startup (`main.py` lifespan):** creates `Settings`, awaits
  `settings.initialize()` (which opens the serial port), then creates `SMS`,
  `GPS`, the capture thread, the video broadcaster, and runs Alembic
  migrations. Shutdown stops the broadcaster, releases the camera, closes the
  modem, and disposes the DB engine.
- **Database:** async SQLAlchemy over `sqlite+aiosqlite`; URL comes from
  `PI7600_DATABASE_URL`. `create_all` is only for tests/bootstrap; production
  schema changes go through Alembic.
- **Auth:** `POST /token` issues a 30-minute RS256 JWT. HTTP routes use
  `get_current_user`; `/at` uses `get_current_admin`. WebSockets accept a first
  JSON message `{"type": "auth", "token": "<jwt>"}` within a timeout and close
  with code `1008` on failure.
- **Modem I/O:** all library commands go through `AT.send_at` over
  `/dev/ttyUSB2`. `AT.send_raw` is used by `/at`. The serial lock serializes
  callers.
- **Video:** one capture thread stores the latest JPEG; one broadcaster pushes
  frames to all authenticated `/wss/video` clients. Recognition runs separately
  (see roadmap).

## Conventions

- Target Python 3.13; prefer `X | None` over `Optional[X]` and built-in
  generics (`list`, `dict`) over `typing.List`/`typing.Dict`.
- Use Pydantic v2 APIs: `model_validate`, `model_dump`, `model_config`.
  Do not add `.dict()`/`.parse_obj()`.
- Keep async endpoints non-blocking. Never call blocking serial I/O, OpenCV,
  `subprocess.run`, or `input()` directly from an `async def`; use
  `asyncio.to_thread`, async subprocesses, or an executor.
- Use the app logger (`logging.getLogger("uvicorn.pi7600")`) rather than
  `print()` in application code.
- Keep formatting and import order consistent with Ruff. The submodule has its
  own `pi7600/ruff.toml`; do not mass-format it as part of an unrelated change.
- Do not commit secrets, databases, caches, biometric data, or generated
  artifacts: `.keys/`, `.env`, `*.db`, `__pycache__/`, `.pytest_cache/`,
  `.ruff_cache/`, `data/`, `ml/embeddings/`.
- Keep `README.md`, `AGENTS.md`, and `docs/roadmap.md` in sync with behavior
  changes.

## Critical gotchas

1. **Submodule scope.** `pi7600/` is its own repo. Changes there need a commit
   in the submodule and a pointer bump in the parent.
2. **`send_at` returns truthy errors.** Timeouts return
   `"ERROR: Timeout while waiting for response..."`. Always use
   `AT.is_error(response)` (or compare the expected token); never use
   `if await send_at(...)` as a success check.
3. **Settings I/O is explicit.** `Settings.__init__` is hardware-free. Call
   `await settings.initialize()` before using modem state; it opens the serial
   port and loads `pdu_mode`, `datetime`, and `timezone`.
4. **Serial access is serialized.** `AT` holds an `asyncio.Lock` and drains
   input before each command. Do not write to `ser` directly outside `AT`.
5. **Database `id` is not the modem index.** `MessageCreate.id` is the SQLite
   primary key; `MessageCreate.message_index` is the index on the SIM. The
   delete endpoint takes the DB id and uses `message_index` internally.
6. **Migrations matter.** `create_all` will not add columns to an existing
   database. Add an Alembic revision for schema changes.
7. **Hardware-dependent code.** A full run requires serial devices
   (`/dev/ttyUSB2`) and a camera (`/dev/video*`). Tests must mock these; do not
   assume hardware is present in CI.
8. **Biometric data is untracked.** Embeddings belong in `data/embeddings/`
   (gitignored). Do not add personal data to the repo.
9. **`/at` is privileged.** Keep it admin-only and audited; do not log
   credentials or secrets.
10. **Two WebSocket managers exist.** `Websockets.ConnectionManager` handles the
    echo endpoint; `Camera.VideoStreamManager` owns video clients and the
    broadcaster. Pick one deliberately rather than adding a third.

## Testing

```bash
uv run pytest -q
```

The suite uses `pytest` + `pytest-asyncio` + `httpx.AsyncClient` (ASGI
transport). `tests/conftest.py` provides fake modem/SMS/GPS objects, temporary
SQLite, generated JWT keys, and hardware-free fixtures. Cover auth
success/failure/expiry, `/token`, SMS create/read/delete/cleanup, PDU and text
parsing, AT timeout/error handling, WebSocket auth, and health endpoints.

CI (`.github/workflows/ci.yml`) runs `uv sync`, Ruff lint/format for both repos,
and `pytest` on Python 3.13 without hardware.

## Definition of done

- `uv run ruff check .` and `uv run ruff format --check .` pass.
- `uv run ruff check pi7600 --config pi7600/ruff.toml` and the matching format
  check pass when the submodule changed.
- `uv run pytest -q` passes without hardware.
- New behavior is covered by tests.
- `README.md` is updated for user-visible changes.
- No secrets, DB files, caches, biometric data, or generated artifacts are
  committed.
- If `pi7600/` changed, the submodule pointer is updated and both repos are
  committed separately.

## References

- `README.md` — setup, API, deployment, and security notes.
- `docs/roadmap.md` — SQLCipher, TOTP, recognition, and API changes.
- `docs/AT-Commands.pdf` — SIM7600 AT command manual.
- [Waveshare SIM7600G-H wiki](https://www.waveshare.com/wiki/SIM7600G-H_4G_HAT_(B))
