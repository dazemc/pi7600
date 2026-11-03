import 'dart:async';
import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

/// Tracks every connected `/wss/video` client and pushes the latest JPEG frame
/// to all of them.
class VideoBroadcaster {
  final Set<RelicWebSocket> _clients = {};
  StreamSubscription<Uint8List>? _subscription;

  bool get hasClients => _clients.isNotEmpty;

  int get clientCount => _clients.length;

  /// Start forwarding frames from [frames] to connected clients.
  void attach(Stream<Uint8List> frames) {
    unawaited(_subscription?.cancel());
    _subscription = frames.listen(_broadcast);
  }

  void add(RelicWebSocket client) {
    _clients.add(client);
  }

  void remove(RelicWebSocket client) {
    _clients.remove(client);
  }

  void _broadcast(Uint8List frame) {
    if (_clients.isEmpty) return;
    for (final client in _clients.toList(growable: false)) {
      if (!client.trySendBytes(frame)) {
        _clients.remove(client);
      }
    }
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    final clients = _clients.toList(growable: false);
    _clients.clear();
    for (final client in clients) {
      try {
        await client.close();
      } on Object {
        // The peer may already be gone.
      }
    }
  }
}
