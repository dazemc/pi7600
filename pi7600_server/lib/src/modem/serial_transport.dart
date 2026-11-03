import 'dart:async';
import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';

/// Low-level serial transport used by [At].
///
/// The interface exists so the modem stack can be tested without hardware.
/// Incoming bytes are published through [received] so callers subscribe to the
/// port instead of polling it.
abstract interface class SerialTransport {
  bool get isOpen;

  /// Byte chunks received from the port.
  ///
  /// This is a broadcast stream that survives [open]/[close] cycles, so a
  /// single subscription can outlive a reconnect.
  Stream<Uint8List> get received;

  void open();

  void close();

  int write(Uint8List bytes, {int timeout = -1});

  void resetInputBuffer();
}

/// A [SerialTransport] backed by libserialport.
///
/// Reading is delegated to [SerialPortReader], which waits for data in a
/// dedicated isolate and emits it as a stream. That keeps blocking reads off
/// the server event loop while [At] writes commands from the main isolate.
class LibSerialPortTransport implements SerialTransport {
  LibSerialPortTransport({
    required this.name,
    required this.baudRate,
  });

  final String name;
  final int baudRate;

  final StreamController<Uint8List> _received =
      StreamController<Uint8List>.broadcast();

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _readerSubscription;

  @override
  bool get isOpen => _port?.isOpen ?? false;

  @override
  Stream<Uint8List> get received => _received.stream;

  @override
  void open() {
    if (isOpen) return;
    _stopReading();
    _port?.dispose();

    final port = SerialPort(name);
    if (!port.openReadWrite()) {
      final error = SerialPort.lastError?.message ?? 'unknown error';
      port.dispose();
      throw SerialPortException('Unable to open $name: $error');
    }
    try {
      final config = port.config;
      config.baudRate = baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.rts = SerialPortRts.flowControl;
      config.cts = SerialPortCts.flowControl;
      config.dtr = SerialPortDtr.invalid;
      config.dsr = SerialPortDsr.invalid;
      config.xonXoff = SerialPortXonXoff.disabled;
      port.config = config;
    } on Object {
      port.close();
      port.dispose();
      rethrow;
    }

    _port = port;
    _startReading(port);
  }

  void _startReading(SerialPort port) {
    final reader = SerialPortReader(port, timeout: 100);
    _reader = reader;
    _readerSubscription = reader.stream.listen(
      _received.add,
      onError: _received.addError,
    );
  }

  void _stopReading() {
    final subscription = _readerSubscription;
    _readerSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _reader?.close();
    _reader = null;
  }

  @override
  void close() {
    _stopReading();
    final port = _port;
    _port = null;
    if (port == null) return;
    try {
      port.close();
    } finally {
      port.dispose();
    }
  }

  @override
  int write(Uint8List bytes, {int timeout = -1}) {
    final port = _port;
    if (port == null) {
      throw SerialPortException('Serial port $name is not open');
    }
    return port.write(bytes, timeout: timeout);
  }

  @override
  void resetInputBuffer() {
    _port?.flush(SerialPortBuffer.input);
  }
}

class SerialPortException implements Exception {
  SerialPortException(this.message);

  final String message;

  @override
  String toString() => 'SerialPortException: $message';
}
