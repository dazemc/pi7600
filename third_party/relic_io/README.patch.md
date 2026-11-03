# Local `relic_io` patch

This directory is a copy of `relic_io` 2.0.0-rc.2 from pub.dev with one
change: `_checkCloseCode` in `lib/src/adapter/io_relic_web_socket.dart` now
accepts the RFC 6455 close codes **1008** (policy violation) and **1011**
(internal error).

The published package follows `package:web_socket` and only allows `1000` or
`3000-4999`. The Pi7600 API contract requires `1008` when WebSocket
authentication fails and `1011` when `/wss/video` is opened while no camera is
available. `dart:io` itself accepts both codes.

The override is declared in the repository root `pubspec.yaml`. Remove this
directory and the override once upstream allows the codes (or if the contract
is changed to application-specific `4xxx` codes).
