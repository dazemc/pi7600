import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:simcom_api_server/src/util/app_log.dart';
import 'package:simcom_api_server/src/web/routes/websockets.dart';
import 'package:test/test.dart';

import 'support/fake_web_socket.dart';

void main() {
  final user = User(id: 1, userName: 'alice', userPassword: 'hash');

  setUp(() => AppLog.configure('error'));
  tearDown(() => AppLog.configure('info'));

  Future<WebSocketAuthResult> authenticate(
    FakeWebSocket socket, {
    Duration timeout = const Duration(seconds: 1),
  }) {
    return authenticateWebSocket(
      socket,
      timeout: timeout,
      authenticateToken: (token) async => token == 'good' ? user : null,
    );
  }

  test('accepts a valid authentication message', () async {
    final socket = FakeWebSocket();
    final resultFuture = authenticate(socket);
    socket.addEvent(
      TextDataReceived(
        jsonEncode({'type': 'auth', 'token': 'good'}),
      ),
    );

    final result = await resultFuture;

    expect(result.failed, isFalse);
    expect(result.user, same(user));
    await result.events.cancel();
    await socket.close();
  });

  test('closes with 1008 for an invalid token', () async {
    final socket = FakeWebSocket();
    final resultFuture = authenticate(socket);
    socket.addEvent(
      TextDataReceived(
        jsonEncode({'type': 'auth', 'token': 'bad'}),
      ),
    );

    final result = await resultFuture;

    expect(result.failed, isTrue);
    expect(socket.closeCodes, [1008]);
  });

  test('closes with 1008 for a missing token', () async {
    final socket = FakeWebSocket();
    final resultFuture = authenticate(socket);
    socket.addEvent(
      TextDataReceived(jsonEncode({'type': 'auth'})),
    );

    final result = await resultFuture;

    expect(result.failed, isTrue);
    expect(socket.closeCodes, [1008]);
  });

  test('closes with 1008 for malformed JSON', () async {
    final socket = FakeWebSocket();
    final resultFuture = authenticate(socket);
    socket.addEvent(TextDataReceived('not json'));

    final result = await resultFuture;

    expect(result.failed, isTrue);
    expect(socket.closeCodes, [1008]);
  });

  test('closes with 1008 when authentication times out', () async {
    final socket = FakeWebSocket();

    final result = await authenticate(
      socket,
      timeout: const Duration(milliseconds: 10),
    );

    expect(result.failed, isTrue);
    expect(socket.closeCodes, [1008]);
  });
}
