import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pi7600_server/src/modem/serial_transport.dart';

typedef CommandHandler = void Function(String command, FakeTransport transport);

/// A hardware-free [SerialTransport] whose responses are scripted by tests.
class FakeTransport implements SerialTransport {
  FakeTransport({this.onCommand});

  CommandHandler? onCommand;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  final List<String> written = [];

  bool _open = false;

  @override
  Stream<Uint8List> get received => _controller.stream;

  @override
  bool get isOpen => _open;

  @override
  void open() {
    _open = true;
  }

  @override
  void close() {
    _open = false;
  }

  @override
  int write(Uint8List bytes, {int timeout = -1}) {
    final text = utf8.decode(bytes, allowMalformed: true);
    written.add(text);
    onCommand?.call(text, this);
    return bytes.length;
  }

  @override
  void resetInputBuffer() {}

  void emit(String text) {
    _controller.add(Uint8List.fromList(utf8.encode(text)));
  }

  Future<void> dispose() => _controller.close();
}
