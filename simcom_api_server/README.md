# simcom_api_server

Serverpod API for the SIMCom modem, SMS, GPS, and camera service. See the
repository [`README.md`](../README.md) for setup, API, and deployment
documentation.

Run locally from this directory:

```bash
dart pub get
dart run bin/main.dart --apply-migrations
```

The development configuration uses an embedded PostgreSQL instance under
`.serverpod/` and listens on `http://localhost:8082`.
