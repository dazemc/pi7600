import 'dart:convert';

import 'package:serverpod/serverpod.dart' hide Message;
import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_api_server/src/config/app_config.dart';
import 'package:simcom_api_server/src/generated/audit_event.dart';
import 'package:simcom_api_server/src/generated/message.dart';
import 'package:simcom_api_server/src/generated/user.dart';

/// In-memory database used by route tests.
class FakeDatabase implements Database {
  final List<User> users = [];
  final List<Message> messages = [];
  final List<AuditEvent> auditEvents = [];

  /// Optional queue of results for successive `findFirstRow<User>` calls.
  ///
  /// A `null` entry represents a missing user. When the queue is empty, the
  /// first user in [users] is returned.
  final List<User?> userLookups = [];
  int _nextId = 100;

  List<User> _findUsers(Invocation invocation) {
    var rows = List<User>.of(users);
    final limit = invocation.namedArguments[#limit] as int?;
    final offset = invocation.namedArguments[#offset] as int? ?? 0;
    if (offset > 0) rows = rows.skip(offset).toList();
    if (limit != null && rows.length > limit) rows = rows.take(limit).toList();
    return rows;
  }

  List<AuditEvent> _findAuditEvents(Invocation invocation) {
    final rows = List<AuditEvent>.of(auditEvents)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limit = invocation.namedArguments[#limit] as int?;
    return limit == null || rows.length <= limit
        ? rows
        : rows.take(limit).toList();
  }

  User? _nextUser() {
    if (userLookups.isNotEmpty) return userLookups.removeAt(0);
    return users.isEmpty ? null : users.first;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final typeArguments = invocation.typeArguments;
    final type = typeArguments.isEmpty ? null : typeArguments.first;

    switch (invocation.memberName) {
      case #find:
        if (type == User) return Future.value(_findUsers(invocation));
        if (type == Message) return Future.value(List<Message>.of(messages));
        if (type == AuditEvent) {
          return Future.value(_findAuditEvents(invocation));
        }
      case #findFirstRow:
        if (type == User) return Future.value(_nextUser());
        if (type == Message) {
          return Future.value(messages.isEmpty ? null : messages.first);
        }
        if (type == AuditEvent) {
          final rows = _findAuditEvents(invocation);
          return Future.value(rows.isEmpty ? null : rows.first);
        }
      case #insertRow:
        final row = invocation.positionalArguments.first;
        if (row is User) {
          row.id ??= _nextId++;
          users.add(row);
          return Future.value(row);
        }
        if (row is Message) {
          row.id ??= _nextId++;
          messages.add(row);
          return Future.value(row);
        }
        if (row is AuditEvent) {
          row.id ??= _nextId++;
          auditEvents.add(row);
          return Future.value(row);
        }
      case #updateRow:
        final row = invocation.positionalArguments.first;
        if (row is User) {
          final index = users.indexWhere((item) => item.id == row.id);
          if (index >= 0) users[index] = row;
          return Future.value(row);
        }
        if (row is Message) {
          final index = messages.indexWhere((item) => item.id == row.id);
          if (index >= 0) messages[index] = row;
          return Future.value(row);
        }
      case #deleteRow:
        final row = invocation.positionalArguments.first;
        if (row is User) users.removeWhere((item) => item.id == row.id);
        if (row is Message) {
          messages.removeWhere((item) => item.id == row.id);
        }
        return Future.value(row);
      case #deleteWhere:
        if (type == AuditEvent) {
          final deleted = List<AuditEvent>.of(auditEvents);
          auditEvents.clear();
          return Future.value(deleted);
        }
        if (type == Message) {
          final deleted = List<Message>.of(messages);
          messages.clear();
          return Future.value(deleted);
        }
    }

    throw UnsupportedError(
      'FakeDatabase does not implement ${invocation.memberName}',
    );
  }
}

/// Minimal [Session] backed by [FakeDatabase].
class FakeSession implements Session {
  FakeSession(this.db);

  @override
  final Database db;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError(
      'FakeSession does not implement ${invocation.memberName}',
    );
  }
}

/// Build app services with test JWT keys and without starting hardware.
AppServices createTestServices() {
  final config = AppConfig.fromEnvironment({
    'SIMCOM_API_JWT_PRIVATE_KEY_PATH': 'test/fixtures/private.pem',
    'SIMCOM_API_JWT_PUBLIC_KEY_PATH': 'test/fixtures/public.pem',
    'SIMCOM_API_JWT_ISSUER': 'test.simcom',
    'SIMCOM_API_JWT_EXPIRE_MINUTES': '30',
  });
  return AppServices.create(config);
}

Request buildRequest(
  Method method,
  String path, {
  Map<String, String> query = const {},
  Map<String, String> headers = const {},
  String? body,
}) {
  final uri = Uri.parse('http://localhost$path').replace(
    queryParameters: query.isEmpty ? null : query,
  );
  return RequestInternal.create(
    method,
    uri,
    Object(),
    headers: Headers.build((values) {
      headers.forEach((key, value) => values[key] = [value]);
    }),
    body: body == null ? Body.empty() : Body.fromString(body),
  );
}

Future<(int, String)> readResponse(Result result) async {
  if (result is! Response) {
    throw StateError('Expected a Response, got ${result.runtimeType}');
  }
  return (result.statusCode, await result.readAsString());
}

Future<(int, dynamic)> readJsonResponse(Result result) async {
  final (status, body) = await readResponse(result);
  return (status, jsonDecode(body));
}
