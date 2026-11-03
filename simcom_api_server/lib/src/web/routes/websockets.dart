import 'dart:async';
import 'dart:convert';

import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_api_server/src/util/app_log.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:serverpod/serverpod.dart';
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;

class _WebSocketAuthResult {
  _WebSocketAuthResult.success(this.user, this.events) : failed = false;

  _WebSocketAuthResult.failed(this.events) : user = null, failed = true;

  final User? user;
  final StreamIterator<WebSocketEvent> events;
  final bool failed;
}

Future<_WebSocketAuthResult> _authenticate(
  RelicWebSocket socket,
  AppServices services,
) async {
  final events = StreamIterator<WebSocketEvent>(socket.events);
  try {
    final timeout = Duration(
      milliseconds: (services.config.websocketAuthTimeout * 1000).round(),
    );
    final hasEvent = await events.moveNext().timeout(timeout);
    if (!hasEvent) {
      throw TimeoutException('No authentication message received');
    }

    final event = events.current;
    if (event is! TextDataReceived) {
      throw const FormatException('Expected a text authentication message');
    }

    final decoded = jsonDecode(event.text);
    if (decoded is! Map) {
      throw const FormatException('Invalid authentication payload');
    }
    final token = decoded['token'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing token');
    }

    final user = await services
        .authService(Serverpod.instance.internalSession)
        .authenticateToken(token);
    if (user == null || user.isDisabled) {
      throw const FormatException('User is unavailable');
    }
    return _WebSocketAuthResult.success(user, events);
  } on Object catch (error) {
    AppLog.warning(
      'WebSocket authentication failed: $error',
      name: 'pi7600.websocket',
    );
    await events.cancel();
    await _close(socket, 1008);
    return _WebSocketAuthResult.failed(events);
  }
}

Future<void> _close(RelicWebSocket socket, int code) async {
  try {
    await socket.close(code);
  } on Object {
    // The peer may already be gone.
  }
}

/// `/wss` authenticated echo endpoint.
class EchoWebSocketRoute extends Route {
  EchoWebSocketRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    return WebSocketUpgrade((socket) async {
      final auth = await _authenticate(socket, services);
      if (auth.failed) return;

      final user = auth.user!;
      AppLog.info(
        'WebSocket authenticated for ${user.userName}',
        name: 'pi7600.websocket',
      );
      try {
        while (await auth.events.moveNext()) {
          final event = auth.events.current;
          if (event is TextDataReceived) {
            AppLog.debug(
              '/wss message from ${user.userName}: '
              '${event.text.length} chars',
              name: 'pi7600.websocket',
            );
            socket.trySendText('Message received: ${event.text}');
          } else if (event is CloseReceived) {
            break;
          }
        }
      } finally {
        await auth.events.cancel();
      }
    });
  }
}

/// `/wss/video` authenticated JPEG frame stream.
class VideoWebSocketRoute extends Route {
  VideoWebSocketRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    return WebSocketUpgrade((socket) async {
      final auth = await _authenticate(socket, services);
      if (auth.failed) return;

      final user = auth.user!;
      await services.ready;
      final cameraReady = await services.ensureCameraStarted();
      if (!cameraReady) {
        await _close(socket, 1011);
        await auth.events.cancel();
        return;
      }

      services.videoClientConnected();
      services.broadcaster.add(socket);
      AppLog.info(
        'Video stream authenticated for ${user.userName}',
        name: 'pi7600.websocket',
      );
      try {
        while (await auth.events.moveNext()) {
          if (auth.events.current is CloseReceived) break;
        }
      } finally {
        services.broadcaster.remove(socket);
        services.videoClientDisconnected();
        await auth.events.cancel();
        AppLog.info(
          'Video stream disconnected for ${user.userName}',
          name: 'pi7600.websocket',
        );
      }
    });
  }
}
