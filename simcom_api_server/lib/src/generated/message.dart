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
import 'dart:async' as _ida;
import 'package:serverpod/serverpod.dart' as _is;

abstract class Message
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
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
      isPartial: _is.BoolJsonExtension.fromJson(jsonSerialization['isPartial']),
      inSimMemory: jsonSerialization['inSimMemory'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['inSimMemory']),
      isSent: jsonSerialization['isSent'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['isSent']),
    );
  }

  static final t = MessageTable();

  static const db = MessageRepository._();

  @override
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

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [Message]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
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

  static MessageInclude include() {
    return MessageInclude._();
  }

  static MessageIncludeList includeList({
    _is.WhereExpressionBuilder<MessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    MessageInclude? include,
  }) {
    return MessageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
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
  @_is.useResult
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

class MessageUpdateTable extends _is.UpdateTable<MessageTable> {
  MessageUpdateTable(super.table);

  _is.ColumnValue<String, String> messageIndex(String? value) =>
      _is.ColumnValue(
        table.messageIndex,
        value,
      );

  _is.ColumnValue<String, String> messageType(String value) => _is.ColumnValue(
    table.messageType,
    value,
  );

  _is.ColumnValue<String, String> messageOriginatingAddress(String? value) =>
      _is.ColumnValue(
        table.messageOriginatingAddress,
        value,
      );

  _is.ColumnValue<String, String> messageDestinationAddress(String? value) =>
      _is.ColumnValue(
        table.messageDestinationAddress,
        value,
      );

  _is.ColumnValue<String, String> messageDate(String value) => _is.ColumnValue(
    table.messageDate,
    value,
  );

  _is.ColumnValue<String, String> messageTime(String value) => _is.ColumnValue(
    table.messageTime,
    value,
  );

  _is.ColumnValue<String, String> messageContents(String value) =>
      _is.ColumnValue(
        table.messageContents,
        value,
      );

  _is.ColumnValue<String, String> partialKey(String? value) => _is.ColumnValue(
    table.partialKey,
    value,
  );

  _is.ColumnValue<int, int> partialCount(int? value) => _is.ColumnValue(
    table.partialCount,
    value,
  );

  _is.ColumnValue<int, int> partialIndex(int? value) => _is.ColumnValue(
    table.partialIndex,
    value,
  );

  _is.ColumnValue<bool, bool> isPartial(bool value) => _is.ColumnValue(
    table.isPartial,
    value,
  );

  _is.ColumnValue<bool, bool> inSimMemory(bool? value) => _is.ColumnValue(
    table.inSimMemory,
    value,
  );

  _is.ColumnValue<bool, bool> isSent(bool? value) => _is.ColumnValue(
    table.isSent,
    value,
  );
}

class MessageTable extends _is.Table<int?> {
  MessageTable({super.tableRelation}) : super(tableName: 'messages') {
    updateTable = MessageUpdateTable(this);
    messageIndex = _is.ColumnString(
      'message_index',
      this,
      fieldName: 'messageIndex',
    );
    messageType = _is.ColumnString(
      'message_type',
      this,
      fieldName: 'messageType',
    );
    messageOriginatingAddress = _is.ColumnString(
      'message_originating_address',
      this,
      fieldName: 'messageOriginatingAddress',
    );
    messageDestinationAddress = _is.ColumnString(
      'message_destination_address',
      this,
      fieldName: 'messageDestinationAddress',
    );
    messageDate = _is.ColumnString(
      'message_date',
      this,
      fieldName: 'messageDate',
    );
    messageTime = _is.ColumnString(
      'message_time',
      this,
      fieldName: 'messageTime',
    );
    messageContents = _is.ColumnString(
      'message_contents',
      this,
      fieldName: 'messageContents',
    );
    partialKey = _is.ColumnString(
      'partial_key',
      this,
      fieldName: 'partialKey',
    );
    partialCount = _is.ColumnInt(
      'partial_count',
      this,
      fieldName: 'partialCount',
    );
    partialIndex = _is.ColumnInt(
      'partial_index',
      this,
      fieldName: 'partialIndex',
    );
    isPartial = _is.ColumnBool(
      'is_partial',
      this,
      fieldName: 'isPartial',
    );
    inSimMemory = _is.ColumnBool(
      'in_sim_memory',
      this,
      fieldName: 'inSimMemory',
    );
    isSent = _is.ColumnBool(
      'is_sent',
      this,
      fieldName: 'isSent',
    );
  }

  late final MessageUpdateTable updateTable;

  late final _is.ColumnString messageIndex;

  late final _is.ColumnString messageType;

  late final _is.ColumnString messageOriginatingAddress;

  late final _is.ColumnString messageDestinationAddress;

  late final _is.ColumnString messageDate;

  late final _is.ColumnString messageTime;

  late final _is.ColumnString messageContents;

  late final _is.ColumnString partialKey;

  late final _is.ColumnInt partialCount;

  late final _is.ColumnInt partialIndex;

  late final _is.ColumnBool isPartial;

  late final _is.ColumnBool inSimMemory;

  late final _is.ColumnBool isSent;

  @override
  List<_is.Column> get columns => [
    id,
    messageIndex,
    messageType,
    messageOriginatingAddress,
    messageDestinationAddress,
    messageDate,
    messageTime,
    messageContents,
    partialKey,
    partialCount,
    partialIndex,
    isPartial,
    inSimMemory,
    isSent,
  ];
}

class MessageInclude extends _is.IncludeObject {
  MessageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => Message.t;
}

class MessageIncludeList extends _is.IncludeList {
  MessageIncludeList._({
    _is.WhereExpressionBuilder<MessageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Message.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => Message.t;
}

class MessageRepository {
  const MessageRepository._();

  /// Returns a list of [Message]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Message>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Message>(
      where: where?.call(Message.t),
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Emits [Message]s matching the given query parameters every time the
  /// source tables are modified.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// Use [throttle] to specify the minimum interval between queries. It can
  /// also be set to `null`, in which case the stream will only be throttled
  /// when its subscription is paused.
  ///
  /// Source tables are collected from the queried table, [where], [orderBy],
  /// [orderByList], and the [include] graph. [alsoTriggerOnTables] is added
  /// to that set. Pass [Table] instances such as `Message.t`.
  ///
  /// Raw [Expression] SQL is not inspected. Tables referenced only in raw
  /// SQL must be passed via [alsoTriggerOnTables].
  ///
  /// The stream always reads committed state and never joins an ambient
  /// [Transaction]. Emissions for a write fire after that write commits.
  ///
  /// Currently only supported on SQLite. Calling this method on PostgreSQL
  /// throws an [UnsupportedError].
  ///
  /// ```dart
  /// var subscription = Persons.db.watch(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// ).listen((persons) {
  ///   // Handle the latest matching rows.
  /// });
  /// ```
  _ida.Stream<List<Message>> watch(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    Duration? throttle = const Duration(milliseconds: 30),
    Iterable<_is.Table>? alsoTriggerOnTables,
  }) {
    return session.db.watch<Message>(
      where: where?.call(Message.t),
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      limit: limit,
      offset: offset,
      throttle: throttle,
      alsoTriggerOnTables: alsoTriggerOnTables,
    );
  }

  /// Returns the first matching [Message] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Message?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MessageTable>? where,
    int? offset,
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Message>(
      where: where?.call(Message.t),
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Message] by its [id] or null if no such row exists.
  Future<Message?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Message>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Message]s in the list and returns the inserted rows.
  ///
  /// The returned [Message]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Message>> insert(
    _is.DatabaseSession session,
    List<Message> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Message>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Message] and returns the inserted row.
  ///
  /// The returned [Message] will have its `id` field set.
  Future<Message> insertRow(
    _is.DatabaseSession session,
    Message row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Message>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Message]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [Message]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Message>> upsert(
    _is.DatabaseSession session,
    List<Message> rows, {
    required _is.ColumnSelections<MessageTable> conflictColumns,
    _is.ColumnSelections<MessageTable>? updateColumns,
    _is.WhereExpressionBuilder<MessageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Message>(
      rows,
      conflictColumns: conflictColumns(Message.t),
      updateColumns: updateColumns?.call(Message.t),
      updateWhere: updateWhere?.call(Message.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Message] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [Message] will have its `id` field set.
  Future<Message?> upsertRow(
    _is.DatabaseSession session,
    Message row, {
    required _is.ColumnSelections<MessageTable> conflictColumns,
    _is.ColumnSelections<MessageTable>? updateColumns,
    _is.WhereExpressionBuilder<MessageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Message>(
      row,
      conflictColumns: conflictColumns(Message.t),
      updateColumns: updateColumns?.call(Message.t),
      updateWhere: updateWhere?.call(Message.t),
      transaction: transaction,
    );
  }

  /// Updates all [Message]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Message>> update(
    _is.DatabaseSession session,
    List<Message> rows, {
    _is.ColumnSelections<MessageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Message>(
      rows,
      columns: columns?.call(Message.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Message]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Message> updateRow(
    _is.DatabaseSession session,
    Message row, {
    _is.ColumnSelections<MessageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Message>(
      row,
      columns: columns?.call(Message.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Message] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Message?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<MessageUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Message>(
      id,
      columnValues: columnValues(Message.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Message]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Message>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<MessageUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<MessageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Message>(
      columnValues: columnValues(Message.t.updateTable),
      where: where(Message.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Message]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Message>> delete(
    _is.DatabaseSession session,
    List<Message> rows, {
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Message>(
      rows,
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Message].
  Future<Message> deleteRow(
    _is.DatabaseSession session,
    Message row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Message>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Message>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MessageTable> where,
    _is.OrderByBuilder<MessageTable>? orderBy,
    _is.OrderByListBuilder<MessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Message>(
      where: where(Message.t),
      orderBy: orderBy?.call(Message.t),
      orderByList: orderByList?.call(Message.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<MessageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Message>(
      where: where?.call(Message.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Message] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<MessageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Message>(
      where: where(Message.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
