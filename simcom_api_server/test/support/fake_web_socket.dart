import 'dart:async';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

/// Hardware-free [RelicWebSocket] for route and broadcaster tests.
class FakeWebSocket implements RelicWebSocket {
  FakeWebSocket({this.sendBytesResult = true});

  final StreamController<WebSocketEvent> _events =
      StreamController<WebSocketEvent>.broadcast();
  final List<Uint8List> sentBytes = [];
  final List<String> sentText = [];
  final List<int> closeCodes = [];

  bool sendBytesResult;
  bool _closed = false;

  void addEvent(WebSocketEvent event) => _events.add(event);

  @override
  Stream<WebSocketEvent> get events => _events.stream;

  @override
  bool get isClosed => _closed;

  @override
  Duration? pingInterval;

  @override
  bool trySendText(String text) {
    if (_closed) return false;
    sentText.add(text);
    return true;
  }

  @override
  bool trySendBytes(Uint8List bytes) {
    if (_closed) return false;
    sentBytes.add(bytes);
    return sendBytesResult;
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    if (_closed) return;
    _closed = true;
    closeCodes.add(code ?? 1005);
    await _events.close();
  }

  @override
  Future<bool> tryClose([int? code, String? reason]) async {
    final wasOpen = !_closed;
    await close(code, reason);
    return wasOpen;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
