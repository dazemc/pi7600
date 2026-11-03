import 'package:simcom_api_server/src/data/audit_store.dart';
import 'package:simcom_api_server/src/generated/audit_event.dart';
import 'package:simcom_api_server/src/util/app_log.dart';

/// Serialize an audit event for the admin API.
Map<String, Object?> auditEventToJson(AuditEvent event) {
  return {
    'id': event.id,
    'created_at': event.createdAt.toUtc().toIso8601String(),
    'event_type': event.eventType,
    'user_name': event.userName,
    'remote_address': event.remoteAddress,
    'success': event.success,
    'detail': event.detail,
  };
}

/// Best-effort persistent audit log.
///
/// Audit failures are logged but never fail the request they describe.
class AuditService {
  AuditService(this.store);

  final AuditStore store;

  static const _maxDetailLength = 2000;

  Future<void> record({
    required String eventType,
    String? userName,
    String? remoteAddress,
    bool success = true,
    String? detail,
  }) async {
    try {
      await store.insert(
        AuditEvent(
          createdAt: DateTime.now().toUtc(),
          eventType: eventType,
          userName: userName,
          remoteAddress: remoteAddress,
          success: success,
          detail: _truncate(detail),
        ),
      );
    } on Object catch (error) {
      AppLog.warning(
        'Unable to write audit event $eventType: $error',
        name: 'pi7600.audit',
      );
    }
  }

  Future<List<AuditEvent>> recent({int limit = 100}) {
    return store.recent(limit: limit.clamp(1, 500));
  }

  Future<int> cleanup({required Duration retention}) {
    return store.deleteBefore(DateTime.now().toUtc().subtract(retention));
  }

  static String? _truncate(String? detail) {
    if (detail == null || detail.length <= _maxDetailLength) return detail;
    return detail.substring(0, _maxDetailLength);
  }
}
