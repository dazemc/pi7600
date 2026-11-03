import 'package:pi7600_server/src/bootstrap.dart';
import 'package:pi7600_server/src/generated/endpoints.dart';
import 'package:pi7600_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';

/// The starting point of the Pi7600 Serverpod server.
void run(List<String> args) async {
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    // Pi7600 authenticates REST and WebSocket requests itself, so Serverpod's
    // built-in authentication hook only needs to accept anonymous sessions.
    authenticationHandler: (session, token) async => null,
  );
  configureServer(pod);
  await pod.start();
}
