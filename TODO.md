# TODO / Review Checklist

Code review notes for Pi7600. Priorities are suggestions, not commitments.
Check the items you want to tackle, and resolve the "Decisions needed" section
first where relevant.

Legend:

- **P0** — correctness or security bug; fix before production use.
- **P1** — reliability, maintainability, or behavior that will bite soon.
- **P2** — quality, tests, docs, and ops.
- **[submodule]** — the change belongs in the `pi7600/` submodule repo, not the
  parent repo.
- **[needs decision]** — blocked on a product/API choice.

---

## Decisions (resolved)

- [x] **Scope:** include the `pi7600/` submodule in this pass, with separate
      commits in the submodule plus a pointer bump in the parent.
- [x] **Tests/CI:** add the test harness and CI alongside the P0 fixes.
- [x] **WebSocket auth:** authenticate with a first message carrying the JWT;
      validate before subscribing or sending frames.
- [x] **`/at` endpoint:** keep it, add an `is_admin` flag, restrict it to
      admins, and audit every command/response.
- [x] **Camera/facial recognition:** keep both and fix the pipeline properly
      (shared capture thread, real embedding model, stable streaming).
- [x] **Breaking API changes:** allowed; fix contracts and document the changes.
- [x] **Deployment target:** systemd on the Raspberry Pi.
- [x] **SQLCipher + TOTP:** planned for P2; move the TOTP demo out of
      `scripts/` until it is integrated.
- [x] **Python version:** standardize on 3.13; update `requires-python`, CI, and
      the submodule version check.
- [x] **Dependency policy:** `uv` only; `uv.lock` is the source of truth.

## Review outcome (per-item)

- [x] **P0-1 Auth 401:** catch `ValueError`, return 401, add token tests.
- [x] **P0-2 `/token`:** raise 401s, add `TokenResponse`, check `is_disabled`.
- [x] **P0-3 + P0-11 AT/serial:** one combined refactor (timeout semantics,
      `asyncio.Lock`, drain input, remove dead queue/`send_at_sync`).
- [x] **P0-4 Settings init:** I/O-free `__init__` + `await settings.initialize()`.
- [x] **P0-5 Delete:** endpoint takes DB `id`; use `message_index` for SIM deletes.
- [x] **P0-6 `/at`:** admin-only + audit + serialized `AT.send_raw()`.
- [x] **P0-7 WebSocket auth:** first-message JWT, ~5s timeout, cleanup all exits.
- [x] **P0-8 SMS send:** persist row first; `502` on modem failure; keep row.
- [x] **P0-9 Keys:** lazy cached loader, env-configurable paths.
- [x] **P0-10 Artifacts:** untrack `.pyc`/embedding, add ignores, no history rewrite.
- [x] **P1-1 DB:** migrate to async SQLAlchemy + `aiosqlite`.
- [x] **P1-2 Config:** `pydantic-settings` + `.env` + `.env.example`.
- [x] **P1-3 Schema:** shared DB URL + unique username + Alembic now.
- [x] **P1-4 Parser:** fix loop return, handle unknown status, add fixtures.
- [x] **P1-5 SMS:** full fix (remove dead helpers, restore modem mode).
- [x] **P1-6 GPS:** full fix (success checks, bounded loop, return types).
- [x] **P1-7 Phone:** fix used methods, remove stubs.
- [x] **P1-8 Camera:** phase it — streaming first, recognition follow-up.
- [x] **P1-9 Status:** refactor, defensive parsing, subprocess timeouts.
- [x] **P1-10 Responses:** consistent response models and 400/404/502 codes.
- [x] **P1-11 Shutdown:** full cleanup (camera, serial, tasks, DB).
- [x] **P1-12 Imports/exceptions:** do after functional fixes.
- [x] **P1-13 Health:** add `/healthz` + `/readyz`.
- [x] **P2-1 Tests:** full harness (unit, API, WebSocket, parser, auth).
- [x] **P2-2 CI:** GitHub Actions (lint, format, pytest on 3.13).
- [x] **P2-3 Ruff:** config + fix parent and submodule.
- [x] **P2-4 Dependencies:** full cleanup, Python 3.13, dev group.
- [x] **P2-5 README:** patch now; refine after API changes.
- [x] **P2-6 Alembic:** covered by P1-3.
- [x] **P2-7 systemd:** full unit + hardening + env example.
- [x] **P2-8 TOTP/SQLCipher:** move demo to `examples/`, add roadmap notes.
- [x] **P2-9 Scripts:** pin versions, fix shebangs, document/move legacy.
- [x] **P2-10 AGENTS.md:** keep current (ongoing).
- [x] **Quick wins:** apply all as part of Ruff/dependency work.

---

## P0 — Correctness and security

- [ ] **Auth errors return 500 instead of 401.**
      `Utils.verify_jwt` raises `ValueError` for expired/invalid tokens, but
      `main.get_current_user` only checks for a falsy payload, so the exception
      escapes as a 500. Catch it and raise `HTTPException(401)`.
      Files: `Utils.py:28-35`, `main.py:88-96`.

- [ ] **`/token` returns an integer body instead of a 401 response.**
      On bad credentials it does `return status.HTTP_401_UNAUTHORIZED` (the
      integer `401`), and a missing user falls through to `None`/200. Raise a
      proper 401, use a response model, and check `UserDB.is_disabled`.
      File: `main.py:185-199`.

- [ ] **AT timeouts are treated as success everywhere.**
      `send_at` returns `"ERROR: Timeout..."` on timeout, which is truthy. All
      `if await send_at(...)` checks in `Settings`, `GPS`, `SMS`, and `Phone`
      therefore report success on failure. Add an explicit `ok`/`is_error`
      helper and check the expected response token.
      Files: `pi7600/AT.py:20-73`, `pi7600/Settings.py`, `pi7600/GPS.py`,
      `pi7600/SMS.py`, `pi7600/Phone.py`. **[submodule]**

- [ ] **`Settings.pdu_mode` is an un-awaited coroutine.**
      `self.pdu_mode = self.get_data_mode()` in `__init__`, but
      `get_data_mode` is `async`. Move the query into the lifespan/async init,
      or make it synchronous. File: `pi7600/Settings.py:17`. **[submodule]**

- [ ] **Delete-by-index is inconsistent and deletes the wrong modem message.**
      The route documents a modem index, but `delete_db_message` filters
      `MessageCreate.id` and then passes that database `id` to
      `sms.delete_message()`. Decide the contract and use
      `message_index` for modem deletes. Files: `main.py:157-165`,
      `main.py:343-359`. **[needs decision]**

- [ ] **`/at` blocks the event loop and bypasses the library.**
      `subprocess.run` is synchronous inside `async def`, has no timeout, and
      opens a second serial port via `scripts/catcmd` (`/dev/ttyUSB3`) instead
      of the library's `/dev/ttyUSB2`. Use an async subprocess or
      `asyncio.to_thread`, add a timeout, and serialize access to the modem.
      Files: `main.py:417-433`, `scripts/catcmd`.

- [ ] **WebSockets are unauthenticated.**
      `/wss` and `/wss/video` have auth commented out and accept anyone. Add
      token validation, close unauthorized sockets, and remove connections on
      all exit paths. Files: `main.py:436-474`.

- [ ] **Failed SMS sends return `null` with HTTP 201.**
      `create_message` returns early on send failure without inserting, then
      `send_msg` queries for a row that does not exist and returns `None`.
      Return a proper error and a typed `Messages` response.
      File: `main.py:372-414`.

- [ ] **Key files are read at import time.**
      `Utils.py` opens `.keys/*.pem` at module import, so the app and even
      `scripts/create_user.py` fail before doing anything useful if keys are
      absent. Load lazily or through settings, and let password hashing work
      without JWT keys. File: `Utils.py:11-15`.

- [ ] **Committed artifacts and missing ignores.**
      `scripts/__pycache__/totp.cpython-312.pyc` is tracked, and
      `ml/embeddings/me_embedding.npy` is committed biometric data. Remove both
      from git. Add `*.db`, `users_oop.db`, `.env`, `*.pyc`, `.pytest_cache/`,
      `.ruff_cache/`, and `ml/embeddings/` (or document why it is kept).
      Files: `.gitignore`, `scripts/__pycache__/`, `ml/embeddings/`.

- [ ] **Serial access races and stale buffers.**
      `AT.send_at` creates a queue-processing task but never enqueues commands;
      concurrent requests write to the same serial port and share
      `rec_buff`. `clear_buffer()` calls `ser.flush()` (output flush) instead
      of draining input. Add a real lock/queue and use
      `reset_input_buffer()`/read-and-discard.
      File: `pi7600/AT.py:20-107`. **[submodule]**

---

## P1 — Reliability and architecture

- [ ] **Synchronous SQLAlchemy in async routes.**
      `get_db`/`db.query` block the event loop. Move to SQLAlchemy async or run
      DB work in a threadpool. Files: `main.py:67-165`.

- [ ] **Centralize configuration.**
      Serial ports, camera index, DB URL, key paths, JWT issuer, and token
      lifetime are hardcoded across modules. Introduce settings (for example
      `pydantic-settings` + `.env`) and update `AGENTS.md`.
      Files: `main.py:68`, `pi7600/Globals.py`, `Utils.py`, `Camera.py`.

- [ ] **Database path is inconsistent.**
      `main.py` uses `sqlite:///./cmgl.db`; `scripts/create_user.py` uses
      `sqlite:///../cmgl.db`, which only works from `scripts/`. Share one
      config value. Add a `UNIQUE` constraint on `UserDB.user_name` and handle
      the race. Files: `main.py:68`, `scripts/create_user.py:11`,
      `Models.py:52-60`.

- [ ] **Text-mode parser returns only the first message.**
      `ParserSMS.parse_sms` has `return message_list` inside the `for` loop.
      Move it after the loop. Handle unknown `status()` values (currently
      `None`, which fails validation) and add parser fixtures.
      File: `pi7600/ParserSMS.py:28-80`. **[submodule]**

- [ ] **SMS helpers are broken or unused.**
      `read_message` and `loop_for_messages` call async `receive_messages()`
      without awaiting; `send_message` switches the modem back to PDU mode after
      every send; `pdu_mode` semantics are inverted/confusing. Fix or remove the
      dead paths. File: `pi7600/SMS.py:32-84`. **[submodule]**

- [ ] **GPS session logic always reports success.**
      `if await send_at(...) and await send_at(...)` is truthy for error
      strings. The recursive retry path can loop and does not decrement
      retries. Fix return types and add a bounded retry.
      File: `pi7600/GPS.py:30-76`. **[submodule]**

- [ ] **Phone module blocks and calls the wrong command.**
      `Phone.call` uses `input()` inside an async method, does not await
      `hangup_call`, and `active_calls` uses `AT+CLCC?` instead of `AT+CLCC`.
      File: `pi7600/Phone.py`. **[submodule]**

- [ ] **Camera/streaming needs a cleanup pass.**
      `VideoCaptureThread.reader` is never started; `release()` does not release
      the capture or join a thread; `/wss/video` reads the camera in the event
      loop and once per client; broadcast failures are unhandled; the two
      WebSocket managers duplicate each other; `FacialRecognition` is created
      per connection; `recognize_face` returns after the first face;
      `store_emeddings` is misspelled and saves to the wrong path; the YuNet
      detector is being used as an embedding model.
      Files: `Camera.py`, `main.py:454-474`, `Websockets.py`.

- [ ] **Root/status endpoint is slow and fragile.**
      `/` runs ~10 sequential modem commands and two pings, with no subprocess
      timeout, and parses responses with `splitlines()[2]` (IndexError on
      unexpected output). Parallelize with `asyncio.gather`, add timeouts, and
      parse defensively. `settings.timezone` can also be `None`, which fails
      `StatusResponse` validation. Files: `main.py:213-289`.

- [ ] **Response models and status codes.**
      `POST /sms` has no `response_model` and returns an ORM object;
      `DELETE` endpoints return `"Ok"` even when nothing was deleted. Add
      `response_model`, 404s, and consistent error bodies.
      Files: `main.py:343-414`.

- [ ] **Shutdown cleanup.**
      The lifespan releases the camera but not the serial port, and does not
      cancel the AT queue task. Close serial and cancel tasks on shutdown.
      Files: `main.py:38-59`, `pi7600/AT.py`.

- [ ] **Remove wildcard imports and bare excepts.**
      `from Models import *`, `from Utils import *`, `from .Globals import *`,
      and several `except Exception`/bare `except` blocks make behavior hard to
      trace. Use explicit imports and specific exceptions.
      Files: `main.py:26-30`, `Models.py`, `Utils.py`, `pi7600/*.py`.

- [ ] **Add a hardware-free health endpoint.**
      Add `/healthz` (or similar) that reports app/DB status without touching
      the modem, so supervisors and CI can probe the service.

---

## P2 — Quality, tests, docs, and ops

- [ ] **Add a test suite.**
      `pytest` + `pytest-asyncio` + `httpx.AsyncClient`; fake serial/AT,
      generated camera frames, temporary SQLite. Cover auth, `/token`, SMS
      CRUD, parsers, AT timeout/error handling, and WebSocket disconnect.
      Add a `[dependency-groups]` dev section.

- [ ] **Add CI.**
      GitHub Actions: `uv sync`, `ruff check`, `ruff format --check`, `pytest`.
      Run on Linux without hardware; mocks only.

- [ ] **Add Ruff configuration.**
      Add `[tool.ruff]` (target `py311`, line length, exclude `pi7600/`,
      selected rule families) and make the parent repo clean. Current state:
      47 findings in parent files (26 auto-fixable), 92 including the submodule.
      Fix `main.py` formatting (`ruff format` would reformat it).

- [ ] **Clean up `pyproject.toml`.**
      Remove unused/duplicate dependencies (`opencv-python` and
      `opencv-python-headless` conflict; `passlib` is unused because code uses
      `bcrypt` directly), move `ruff` to dev, add missing direct dependencies
      (`pytz` is only transitive via `smspdudecoder`; `pyotp`, `qrcode`, and
      `Pillow` are needed if `scripts/totp.py` stays), and decide whether
      `package = false` is intentional. File: `pyproject.toml`.

- [ ] **Update the README.**
      It predates auth, `/token`, `/sms/cleanup`, WebSockets, camera, and the
      current response shapes. Add setup (keys, serial permissions, camera),
      environment variables, auth flow, and security notes. File: `README.md`.

- [ ] **Add database migrations.** *(Covered by P1-3: Alembic now.)*
      `Base.metadata.create_all` cannot evolve schemas. Add Alembic (or
      document that `cmgl.db` is disposable and must be recreated).
      File: `main.py:168`.

- [ ] **Deployment artifacts (systemd).**
      Add a systemd unit, environment file, and hardening. Make `start.sh` use
      `uv run` and `exec` so signals propagate. Files: `start.sh`, `log.yaml`,
      `deploy/`.

- [ ] **Move the TOTP demo and document the roadmap.**
      `main.py` still has the `sqlcipher, totp` TODO; `scripts/totp.py` is a
      standalone demo with hardcoded `alice` and undeclared dependencies. Move it
      to `examples/`, add SQLCipher/TOTP design notes, and keep runtime deps
      lean. Files: `main.py:1`, `scripts/totp.py`.

- [ ] **Review helper scripts.**
      `scripts/buildpy.sh` builds an unpinned latest Python and rewrites swap;
      `scripts/rssh_*.sh` contain placeholders; `scripts/rndis.py` and
      `scripts/totp.py` are executable without shebangs. Document or remove.
      Files: `scripts/*`.

- [ ] **Keep `AGENTS.md` current.**
      Update it whenever architecture, commands, or invariants change.

---

## Quick wins (small, low-risk)

- [ ] Run `uv run ruff check --fix --exclude pi7600 .`, then
      `uv run ruff format main.py`.
- [ ] Remove unused imports/variables in `main.py`: `StreamingResponse`,
      `threading`, `asyncio` (if unused after refactor), `lock`, `cwd`,
      `websocket_manager`, and the `ouput` typo in `video_stream`.
- [ ] Remove unused imports in `Camera.py`: `WebSocketDisconnect`, `threading`,
      `asyncio`, and the unused `app = FastAPI()`.
- [ ] `Models.py`: import `declarative_base` from `sqlalchemy.orm` (not
      `sqlalchemy.ext.declarative`) and use `X | None`.
- [ ] `Utils.py`: use `datetime.UTC`; change `tokenUrl="token"` to
      `tokenUrl="/token"`.
- [ ] Guard `Websockets.ConnectionManager.disconnect` against a missing socket
      (currently `list.remove` raises `ValueError`).
- [ ] Add the missing `.gitignore` entries listed in P0.
- [ ] Remove the executable bit or add shebangs to `scripts/rndis.py` and
      `scripts/totp.py`.

---

## Suggested order

1. Resolve the decisions above.
2. P0 auth, AT-success, delete-index, `/at`, WebSocket auth, and artifact
   cleanup.
3. Add the test harness and CI so the P0 fixes stay fixed.
4. P1 reliability work, starting with serial concurrency and camera streaming.
5. P2 docs/ops/dependency cleanup.
