# pi7600_server

Serverpod server for the Pi7600 SIM7600 modem service. See the repository
[`README.md`](../README.md) for setup, API, and deployment documentation.

Run locally from this directory:

```bash
dart pub get
dart run bin/main.dart --apply-migrations
```

The development configuration uses an embedded PostgreSQL instance under
`.serverpod/` and listens on `http://localhost:8082`.
