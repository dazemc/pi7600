import 'package:simcom_api_server/src/auth/login_rate_limiter.dart';
import 'package:test/test.dart';

void main() {
  late DateTime now;
  late LoginRateLimiter limiter;

  setUp(() {
    now = DateTime.utc(2026, 1, 1, 12);
    limiter = LoginRateLimiter(
      maxAttempts: 3,
      window: const Duration(minutes: 5),
      blockDuration: const Duration(minutes: 10),
      clock: () => now,
    );
  });

  test('blocks after the configured number of failures', () {
    expect(limiter.recordFailure('user:alice'), isNull);
    expect(limiter.recordFailure('user:alice'), isNull);
    expect(limiter.recordFailure('user:alice'), const Duration(minutes: 10));

    expect(limiter.retryAfter('user:alice'), const Duration(minutes: 10));
  });

  test('reports the remaining block time and then unblocks', () {
    for (var i = 0; i < 3; i++) {
      limiter.recordFailure('user:alice');
    }

    now = now.add(const Duration(minutes: 4));
    expect(limiter.retryAfter('user:alice'), const Duration(minutes: 6));

    now = now.add(const Duration(minutes: 6));
    expect(limiter.retryAfter('user:alice'), isNull);
  });

  test('only counts failures inside the window', () {
    limiter.recordFailure('user:alice');
    limiter.recordFailure('user:alice');

    now = now.add(const Duration(minutes: 6));
    expect(limiter.recordFailure('user:alice'), isNull);

    now = now.add(const Duration(minutes: 1));
    expect(limiter.recordFailure('user:alice'), isNull);
    expect(limiter.recordFailure('user:alice'), const Duration(minutes: 10));
  });

  test('reset clears the failure history', () {
    limiter.recordFailure('user:alice');
    limiter.recordFailure('user:alice');
    limiter.reset('user:alice');

    expect(limiter.recordFailure('user:alice'), isNull);
    expect(limiter.retryAfter('user:alice'), isNull);
  });

  test('tracks keys independently', () {
    limiter.recordFailure('user:alice');
    limiter.recordFailure('user:alice');
    limiter.recordFailure('user:alice');

    expect(limiter.retryAfter('user:alice'), isNotNull);
    expect(limiter.retryAfter('user:bob'), isNull);
    expect(limiter.retryAfter('ip:127.0.0.1'), isNull);
  });
}
