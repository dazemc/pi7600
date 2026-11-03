/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'audit_event.dart' as _irb38j2y;
import 'message.dart' as _ify7mmka;
import 'user.dart' as _iv73i78m;
export 'audit_event.dart';
export 'message.dart';
export 'user.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager
    implements _isc.ProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  @override
  _isc.ProtocolDeserialization get deserializationMetadata =>
      _isc.ProtocolDeserialization.cached(
        this,
        types: const [
          _isc.getType<_irb38j2y.AuditEvent>,
          _isc.getType<_ify7mmka.Message>,
          _isc.getType<_iv73i78m.User>,
          _isc.getType<_irb38j2y.AuditEvent?>,
          _isc.getType<_ify7mmka.Message?>,
          _isc.getType<_iv73i78m.User?>,
        ],
        modules: const [],
        classNames: const [
          'AuditEvent',
          'Message',
          'User',
        ],
      );

  static String? getClassNameFromObjectJson(dynamic data) =>
      _isc.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    final rawDataClassName = _isc.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _irb38j2y.AuditEvent) {
      return _irb38j2y.AuditEvent.fromJson(data) as T;
    }
    if (t == _ify7mmka.Message) {
      return _ify7mmka.Message.fromJson(data) as T;
    }
    if (t == _iv73i78m.User) {
      return _iv73i78m.User.fromJson(data) as T;
    }
    if (t == _isc.getType<_irb38j2y.AuditEvent?>()) {
      return (data != null ? _irb38j2y.AuditEvent.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ify7mmka.Message?>()) {
      return (data != null ? _ify7mmka.Message.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iv73i78m.User?>()) {
      return (data != null ? _iv73i78m.User.fromJson(data) : null) as T;
    }
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _irb38j2y.AuditEvent => 'AuditEvent',
      _ify7mmka.Message => 'Message',
      _iv73i78m.User => 'User',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('simcom_api.', '');
    }

    switch (data) {
      case _irb38j2y.AuditEvent():
        return 'AuditEvent';
      case _ify7mmka.Message():
        return 'Message';
      case _iv73i78m.User():
        return 'User';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AuditEvent') {
      return deserialize<_irb38j2y.AuditEvent>(data['data']);
    }
    if (dataClassName == 'Message') {
      return deserialize<_ify7mmka.Message>(data['data']);
    }
    if (dataClassName == 'User') {
      return deserialize<_iv73i78m.User>(data['data']);
    }
    return super.deserializeByClassName(data);
  }

  @override
  String getModuleName() => 'simcom_api';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
