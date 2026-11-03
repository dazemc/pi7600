import 'dart:async';

/// A simple FIFO async lock used to serialize modem serial I/O.
class AsyncLock {
  Future<void> _tail = Future<void>.value();

  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _tail;
    _tail = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }
}
