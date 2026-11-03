import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pi7600_server/src/modem/serial_transport.dart';
import 'package:pi7600_server/src/util/async_lock.dart';

/// AT command client for SIM7600-series modems.
///
/// All access to the underlying serial port is serialized through [AsyncLock],
/// matching the behavior of the original Python library. Incoming bytes are
/// consumed from a subscription to [SerialTransport.received] rather than
/// polling the port, so responses wake the pending command immediately.
class At {
  At({
    required this.com,
    required this.baudRate,
    required this.transport,
  });

  final String com;
  final int baudRate;
  final SerialTransport transport;
  final AsyncLock _lock = AsyncLock();

  String _buffer = '';
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _dataSignal;

  bool get isOpen => transport.isOpen;

  void open() {
    transport.open();
    _subscription ??= transport.received.listen(
      _onData,
      onError: (Object _) {
        // A reader error surfaces as a timeout on the pending command. Keep the
        // subscription alive so a later reopen can recover.
      },
    );
  }

  void reopen() {
    closeSerial();
    open();
  }

  void closeSerial() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    _buffer = '';
    _wakeWaiter();
    transport.close();
  }

  Future<void> close() async {
    closeSerial();
  }

  /// Return `true` when a modem response represents a failure.
  ///
  /// Modem timeouts are returned as strings that contain `ERROR`, so callers
  /// must use this helper instead of treating any non-empty string as success.
  static bool isError(String? response) {
    return response == null || response.isEmpty || response.contains('ERROR');
  }

  /// Send an AT [command] and wait for [back] to appear in the response.
  Future<String> sendAt(String command, String back, int timeoutSeconds) {
    return _exchange(
      command: command,
      timeoutSeconds: timeoutSeconds,
      isComplete: (buffer) =>
          buffer.contains(back) ||
          (back != 'ERROR' && buffer.contains('ERROR')),
    );
  }

  /// Read from the modem without writing a command.
  Future<String> readUntil(String back, int timeoutSeconds) {
    return _exchange(
      timeoutSeconds: timeoutSeconds,
      isComplete: (buffer) => buffer.contains(back) || buffer.contains('ERROR'),
      timeoutMessage: "ERROR: Timeout while waiting for '$back'",
    );
  }

  /// Write raw bytes while holding the serial lock.
  Future<void> writeData(List<int> data) {
    return _lock.synchronized(() async {
      try {
        transport.write(Uint8List.fromList(data));
      } on Object {
        // The caller observes the failure through the following read.
      }
    });
  }

  /// Send an arbitrary AT command and return the raw response.
  Future<String> sendRaw(String command, {int timeoutSeconds = 10}) {
    return _exchange(
      command: command,
      timeoutSeconds: timeoutSeconds,
      isComplete: (buffer) => buffer.contains('OK') || buffer.contains('ERROR'),
    );
  }

  Future<String> _exchange({
    String? command,
    required int timeoutSeconds,
    required bool Function(String buffer) isComplete,
    String? timeoutMessage,
  }) {
    return _lock.synchronized(() async {
      try {
        _clearBuffer();
        if (command != null) _writeCommand(command);

        final deadline = Duration(seconds: timeoutSeconds);
        final stopwatch = Stopwatch()..start();
        while (true) {
          if (isComplete(_buffer)) {
            final response = _buffer;
            _clearBuffer();
            return response;
          }

          final remaining = deadline - stopwatch.elapsed;
          if (remaining <= Duration.zero) {
            _clearBuffer();
            return timeoutMessage ??
                "ERROR: Timeout while waiting for response to "
                    "'${command ?? ''}'";
          }
          await _waitForData(remaining);
        }
      } on Object catch (error) {
        _buffer = '';
        return "ERROR: $error";
      }
    });
  }

  void _onData(Uint8List data) {
    _buffer += utf8.decode(data, allowMalformed: true);
    _wakeWaiter();
  }

  /// Wait until [_onData] receives another chunk or [timeout] elapses.
  Future<void> _waitForData(Duration timeout) async {
    final signal = Completer<void>();
    _dataSignal = signal;
    try {
      await signal.future.timeout(timeout);
    } on TimeoutException {
      // The caller re-checks its overall deadline.
    } finally {
      if (identical(_dataSignal, signal)) _dataSignal = null;
    }
  }

  void _wakeWaiter() {
    final signal = _dataSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
  }

  void _writeCommand(String command) {
    transport.write(Uint8List.fromList(utf8.encode('$command\r\n')));
  }

  void _clearBuffer() {
    try {
      transport.resetInputBuffer();
    } on Object {
      // The port may already be closed; clearing the local buffer is enough.
    }
    _buffer = '';
  }
}
