import 'package:simcom_api_server/src/data/audit_store.dart';
import 'package:simcom_api_server/src/generated/audit_event.dart';
import 'package:simcom_api_server/src/services/audit_service.dart';
import 'package:test/test.dart';

class FakeAuditStore implements AuditStore {
  final List<AuditEvent> events = [];
  Object? error;
  DateTime? cutoff;
  int? lastLimit;

  @override
  Future<void> insert(AuditEvent event) async {
    if (error != null) throw error!;
    events.add(event);
  }

  @override
  Future<List<AuditEvent>> recent({int limit = 100}) async {
    lastLimit = limit;
    return events.take(limit).toList(growable: false);
  }

  @override
  Future<int> deleteBefore(DateTime cutoff) async {
    this.cutoff = cutoff;
    final before = events.length;
    events.removeWhere((event) => event.createdAt.isBefore(cutoff));
    return before - events.length;
  }
}

void main() {
  late FakeAuditStore store;
  late AuditService service;

  setUp(() {
    store = FakeAuditStore();
    service = AuditService(store);
  });

  test('records events with UTC timestamps', () async {
    await service.record(
      eventType: 'login',
      userName: 'alice',
      remoteAddress: '127.0.0.1',
      success: false,
      detail: 'bad password',
    );

    final event = store.events.single;
    expect(event.eventType, 'login');
    expect(event.userName, 'alice');
    expect(event.remoteAddress, '127.0.0.1');
    expect(event.success, isFalse);
    expect(event.detail, 'bad password');
    expect(event.createdAt.isUtc, isTrue);
  });

  test('truncates very long details', () async {
    await service.record(eventType: 'at', detail: 'x' * 5000);

    expect(store.events.single.detail, hasLength(2000));
  });

  test('does not throw when the store fails', () async {
    store.error = StateError('database unavailable');

    await expectLater(
      service.record(eventType: 'login', detail: 'test'),
      completes,
    );
  });

  test('clamps the recent-event limit', () async {
    await service.recent(limit: 9999);

    expect(store.lastLimit, 500);
  });

  test('cleanup uses the supplied retention window', () async {
    final old = AuditEvent(
      createdAt: DateTime.now().toUtc().subtract(const Duration(days: 100)),
      eventType: 'login',
      success: true,
    );
    final recent = AuditEvent(
      createdAt: DateTime.now().toUtc(),
      eventType: 'login',
      success: true,
    );
    store.events.addAll([old, recent]);

    final deleted = await service.cleanup(retention: const Duration(days: 90));

    expect(deleted, 1);
    expect(store.events, [recent]);
    expect(store.cutoff, isNotNull);
  });

  test('serializes safe event fields', () {
    final event = AuditEvent(
      id: 4,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      eventType: 'at',
      userName: 'alice',
      remoteAddress: '127.0.0.1',
      success: true,
      detail: 'cmd=AT+CSQ response=OK',
    );

    expect(auditEventToJson(event), {
      'id': 4,
      'created_at': '2026-01-02T03:04:05.000Z',
      'event_type': 'at',
      'user_name': 'alice',
      'remote_address': '127.0.0.1',
      'success': true,
      'detail': 'cmd=AT+CSQ response=OK',
    });
  });
}
