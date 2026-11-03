import 'package:simcom_api_server/src/generated/audit_event.dart';
import 'package:serverpod/serverpod.dart';

/// Persistence for audit events.
abstract interface class AuditStore {
  Future<void> insert(AuditEvent event);

  Future<List<AuditEvent>> recent({int limit});

  Future<int> deleteBefore(DateTime cutoff);
}

/// PostgreSQL backed [AuditStore] bound to a request session.
class SessionAuditStore implements AuditStore {
  const SessionAuditStore(this.session);

  final DatabaseSession session;

  @override
  Future<void> insert(AuditEvent event) async {
    await AuditEvent.db.insertRow(session, event);
  }

  @override
  Future<List<AuditEvent>> recent({int limit = 100}) {
    return AuditEvent.db.find(
      session,
      orderBy: (table) => table.createdAt.desc(),
      limit: limit,
    );
  }

  @override
  Future<int> deleteBefore(DateTime cutoff) async {
    final deleted = await AuditEvent.db.deleteWhere(
      session,
      where: (table) => table.createdAt < cutoff,
    );
    return deleted.length;
  }
}
