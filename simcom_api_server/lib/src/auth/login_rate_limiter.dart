/// In-memory login throttle keyed by username and client address.
///
/// Failed attempts are counted per key. After [maxAttempts] failures inside
/// [window], the key is blocked for [blockDuration]. State is process-local, so
/// a restart clears the counters. Keys are only created on failed logins and
/// are pruned when their window or block expires.
class LoginRateLimiter {
  LoginRateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 5),
    this.blockDuration = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       assert(maxAttempts > 0);

  final int maxAttempts;
  final Duration window;
  final Duration blockDuration;
  final DateTime Function() _clock;

  final Map<String, _LoginAttempts> _entries = {};

  /// Remaining block time for [key], or `null` when it is not blocked.
  Duration? retryAfter(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    final now = _clock();
    final blockedUntil = entry.blockedUntil;
    if (blockedUntil != null) {
      if (now.isBefore(blockedUntil)) {
        return blockedUntil.difference(now);
      }
      _entries.remove(key);
      return null;
    }

    entry.prune(now.subtract(window));
    if (entry.failures.isEmpty) {
      _entries.remove(key);
      return null;
    }
    return null;
  }

  /// Record a failed login.
  ///
  /// Returns the remaining block time when this failure triggers (or extends)
  /// a block.
  Duration? recordFailure(String key) {
    final now = _clock();
    final entry = _entries.putIfAbsent(key, _LoginAttempts.new);

    final blockedUntil = entry.blockedUntil;
    if (blockedUntil != null) {
      if (now.isBefore(blockedUntil)) {
        return blockedUntil.difference(now);
      }
      entry.blockedUntil = null;
      entry.failures.clear();
    }

    entry.failures.add(now);
    entry.prune(now.subtract(window));
    if (entry.failures.length < maxAttempts) return null;

    entry.failures.clear();
    entry.blockedUntil = now.add(blockDuration);
    _pruneEntries(now);
    return blockDuration;
  }

  /// Clear the failure history for [key], for example after a successful login.
  void reset(String key) {
    _entries.remove(key);
  }

  void _pruneEntries(DateTime now) {
    _entries.removeWhere((_, entry) {
      final blockedUntil = entry.blockedUntil;
      if (blockedUntil != null) return !now.isBefore(blockedUntil);
      entry.prune(now.subtract(window));
      return entry.failures.isEmpty;
    });
  }
}

class _LoginAttempts {
  final List<DateTime> failures = [];
  DateTime? blockedUntil;

  void prune(DateTime cutoff) {
    failures.removeWhere((value) => value.isBefore(cutoff));
  }
}
