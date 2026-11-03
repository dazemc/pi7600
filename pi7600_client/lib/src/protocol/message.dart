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

abstract class Message
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Message._({
    this.id,
    this.messageIndex,
    required this.messageType,
    this.messageOriginatingAddress,
    this.messageDestinationAddress,
    required this.messageDate,
    required this.messageTime,
    required this.messageContents,
    this.partialKey,
    this.partialCount,
    this.partialIndex,
    required this.isPartial,
    this.inSimMemory,
    this.isSent,
  });

  factory Message({
    int? id,
    String? messageIndex,
    required String messageType,
    String? messageOriginatingAddress,
    String? messageDestinationAddress,
    required String messageDate,
    required String messageTime,
    required String messageContents,
    String? partialKey,
    int? partialCount,
    int? partialIndex,
    required bool isPartial,
    bool? inSimMemory,
    bool? isSent,
  }) = _MessageImpl;

  factory Message.fromJson(Map<String, dynamic> jsonSerialization) {
    return Message(
      id: jsonSerialization['id'] as int?,
      messageIndex: jsonSerialization['messageIndex'] as String?,
      messageType: jsonSerialization['messageType'] as String,
      messageOriginatingAddress:
          jsonSerialization['messageOriginatingAddress'] as String?,
      messageDestinationAddress:
          jsonSerialization['messageDestinationAddress'] as String?,
      messageDate: jsonSerialization['messageDate'] as String,
      messageTime: jsonSerialization['messageTime'] as String,
      messageContents: jsonSerialization['messageContents'] as String,
      partialKey: jsonSerialization['partialKey'] as String?,
      partialCount: jsonSerialization['partialCount'] as int?,
      partialIndex: jsonSerialization['partialIndex'] as int?,
      isPartial: _isc.BoolJsonExtension.fromJson(
        jsonSerialization['isPartial'],
      ),
      inSimMemory: jsonSerialization['inSimMemory'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['inSimMemory']),
      isSent: jsonSerialization['isSent'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isSent']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String? messageIndex;

  String messageType;

  String? messageOriginatingAddress;

  String? messageDestinationAddress;

  String messageDate;

  String messageTime;

  String messageContents;

  String? partialKey;

  int? partialCount;

  int? partialIndex;

  bool isPartial;

  bool? inSimMemory;

  bool? isSent;

  /// Returns a shallow copy of this [Message]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Message copyWith({
    int? id,
    String? messageIndex,
    String? messageType,
    String? messageOriginatingAddress,
    String? messageDestinationAddress,
    String? messageDate,
    String? messageTime,
    String? messageContents,
    String? partialKey,
    int? partialCount,
    int? partialIndex,
    bool? isPartial,
    bool? inSimMemory,
    bool? isSent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Message',
      if (id != null) 'id': id,
      if (messageIndex != null) 'messageIndex': messageIndex,
      'messageType': messageType,
      if (messageOriginatingAddress != null)
        'messageOriginatingAddress': messageOriginatingAddress,
      if (messageDestinationAddress != null)
        'messageDestinationAddress': messageDestinationAddress,
      'messageDate': messageDate,
      'messageTime': messageTime,
      'messageContents': messageContents,
      if (partialKey != null) 'partialKey': partialKey,
      if (partialCount != null) 'partialCount': partialCount,
      if (partialIndex != null) 'partialIndex': partialIndex,
      'isPartial': isPartial,
      if (inSimMemory != null) 'inSimMemory': inSimMemory,
      if (isSent != null) 'isSent': isSent,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Message',
      if (id != null) 'id': id,
      if (messageIndex != null) 'messageIndex': messageIndex,
      'messageType': messageType,
      if (messageOriginatingAddress != null)
        'messageOriginatingAddress': messageOriginatingAddress,
      if (messageDestinationAddress != null)
        'messageDestinationAddress': messageDestinationAddress,
      'messageDate': messageDate,
      'messageTime': messageTime,
      'messageContents': messageContents,
      if (partialKey != null) 'partialKey': partialKey,
      if (partialCount != null) 'partialCount': partialCount,
      if (partialIndex != null) 'partialIndex': partialIndex,
      'isPartial': isPartial,
      if (inSimMemory != null) 'inSimMemory': inSimMemory,
      if (isSent != null) 'isSent': isSent,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _MessageImpl extends Message {
  _MessageImpl({
    int? id,
    String? messageIndex,
    required String messageType,
    String? messageOriginatingAddress,
    String? messageDestinationAddress,
    required String messageDate,
    required String messageTime,
    required String messageContents,
    String? partialKey,
    int? partialCount,
    int? partialIndex,
    required bool isPartial,
    bool? inSimMemory,
    bool? isSent,
  }) : super._(
         id: id,
         messageIndex: messageIndex,
         messageType: messageType,
         messageOriginatingAddress: messageOriginatingAddress,
         messageDestinationAddress: messageDestinationAddress,
         messageDate: messageDate,
         messageTime: messageTime,
         messageContents: messageContents,
         partialKey: partialKey,
         partialCount: partialCount,
         partialIndex: partialIndex,
         isPartial: isPartial,
         inSimMemory: inSimMemory,
         isSent: isSent,
       );

  /// Returns a shallow copy of this [Message]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Message copyWith({
    Object? id = _Undefined,
    Object? messageIndex = _Undefined,
    String? messageType,
    Object? messageOriginatingAddress = _Undefined,
    Object? messageDestinationAddress = _Undefined,
    String? messageDate,
    String? messageTime,
    String? messageContents,
    Object? partialKey = _Undefined,
    Object? partialCount = _Undefined,
    Object? partialIndex = _Undefined,
    bool? isPartial,
    Object? inSimMemory = _Undefined,
    Object? isSent = _Undefined,
  }) {
    return Message(
      id: id is int? ? id : this.id,
      messageIndex: messageIndex is String? ? messageIndex : this.messageIndex,
      messageType: messageType ?? this.messageType,
      messageOriginatingAddress: messageOriginatingAddress is String?
          ? messageOriginatingAddress
          : this.messageOriginatingAddress,
      messageDestinationAddress: messageDestinationAddress is String?
          ? messageDestinationAddress
          : this.messageDestinationAddress,
      messageDate: messageDate ?? this.messageDate,
      messageTime: messageTime ?? this.messageTime,
      messageContents: messageContents ?? this.messageContents,
      partialKey: partialKey is String? ? partialKey : this.partialKey,
      partialCount: partialCount is int? ? partialCount : this.partialCount,
      partialIndex: partialIndex is int? ? partialIndex : this.partialIndex,
      isPartial: isPartial ?? this.isPartial,
      inSimMemory: inSimMemory is bool? ? inSimMemory : this.inSimMemory,
      isSent: isSent is bool? ? isSent : this.isSent,
    );
  }
}
