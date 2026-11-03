/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

abstract class AuditEvent
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AuditEvent._({
    this.id,
    required this.createdAt,
    required this.eventType,
    this.userName,
    this.remoteAddress,
    required this.success,
    this.detail,
  });

  factory AuditEvent({
    int? id,
    required DateTime createdAt,
    required String eventType,
    String? userName,
    String? remoteAddress,
    required bool success,
    String? detail,
  }) = _AuditEventImpl;

  factory AuditEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return AuditEvent(
      id: jsonSerialization['id'] as int?,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      eventType: jsonSerialization['eventType'] as String,
      userName: jsonSerialization['userName'] as String?,
      remoteAddress: jsonSerialization['remoteAddress'] as String?,
      success: _isc.BoolJsonExtension.fromJson(jsonSerialization['success']),
      detail: jsonSerialization['detail'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  DateTime createdAt;

  String eventType;

  String? userName;

  String? remoteAddress;

  bool success;

  String? detail;

  /// Returns a shallow copy of this [AuditEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AuditEvent copyWith({
    int? id,
    DateTime? createdAt,
    String? eventType,
    String? userName,
    String? remoteAddress,
    bool? success,
    String? detail,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AuditEvent',
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'eventType': eventType,
      if (userName != null) 'userName': userName,
      if (remoteAddress != null) 'remoteAddress': remoteAddress,
      'success': success,
      if (detail != null) 'detail': detail,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AuditEvent',
      if (id != null) 'id': id,
      'createdAt': createdAt.toJson(),
      'eventType': eventType,
      if (userName != null) 'userName': userName,
      if (remoteAddress != null) 'remoteAddress': remoteAddress,
      'success': success,
      if (detail != null) 'detail': detail,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AuditEventImpl extends AuditEvent {
  _AuditEventImpl({
    int? id,
    required DateTime createdAt,
    required String eventType,
    String? userName,
    String? remoteAddress,
    required bool success,
    String? detail,
  }) : super._(
         id: id,
         createdAt: createdAt,
         eventType: eventType,
         userName: userName,
         remoteAddress: remoteAddress,
         success: success,
         detail: detail,
       );

  /// Returns a shallow copy of this [AuditEvent]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AuditEvent copyWith({
    Object? id = _Undefined,
    DateTime? createdAt,
    String? eventType,
    Object? userName = _Undefined,
    Object? remoteAddress = _Undefined,
    bool? success,
    Object? detail = _Undefined,
  }) {
    return AuditEvent(
      id: id is int? ? id : this.id,
      createdAt: createdAt ?? this.createdAt,
      eventType: eventType ?? this.eventType,
      userName: userName is String? ? userName : this.userName,
      remoteAddress: remoteAddress is String?
          ? remoteAddress
          : this.remoteAddress,
      success: success ?? this.success,
      detail: detail is String? ? detail : this.detail,
    );
  }
}
