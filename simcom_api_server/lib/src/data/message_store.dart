import 'package:simcom_api_server/src/generated/message.dart';
import 'package:serverpod/serverpod.dart' hide Message;

/// Persistence operations for SMS messages.
abstract interface class MessageStore {
  Future<List<Message>> findAll({
    int? limit,
    int? offset,
    String? search,
  });

  Future<Message?> findById(int id);

  Future<Message?> findByFingerprint({
    required String messageType,
    required String messageContents,
    required String messageDate,
    required String messageTime,
  });

  Future<Message> insert(Message message);

  Future<Message> update(Message message);

  Future<void> delete(Message message);

  Future<List<Message>> findInSimMemory();
}

/// PostgreSQL backed [MessageStore] bound to a request session.
class SessionMessageStore implements MessageStore {
  const SessionMessageStore(this.session);

  final DatabaseSession session;

  @override
  Future<List<Message>> findAll({int? limit, int? offset, String? search}) {
    final term = search?.trim();
    return Message.db.find(
      session,
      where: term == null || term.isEmpty
          ? null
          : (table) =>
                table.messageContents.ilike('%$term%') |
                table.messageOriginatingAddress.ilike('%$term%') |
                table.messageDestinationAddress.ilike('%$term%'),
      orderBy: (table) => table.id,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Message?> findById(int id) {
    return Message.db.findById(session, id);
  }

  @override
  Future<Message?> findByFingerprint({
    required String messageType,
    required String messageContents,
    required String messageDate,
    required String messageTime,
  }) {
    return Message.db.findFirstRow(
      session,
      where: (table) =>
          table.messageType.equals(messageType) &
          table.messageContents.equals(messageContents) &
          table.messageDate.equals(messageDate) &
          table.messageTime.equals(messageTime),
    );
  }

  @override
  Future<Message> insert(Message message) {
    return Message.db.insertRow(session, message);
  }

  @override
  Future<Message> update(Message message) {
    return Message.db.updateRow(session, message);
  }

  @override
  Future<void> delete(Message message) async {
    await Message.db.deleteRow(session, message);
  }

  @override
  Future<List<Message>> findInSimMemory() {
    return Message.db.find(
      session,
      where: (table) => table.inSimMemory.equals(true),
      orderBy: (table) => table.id,
    );
  }
}
