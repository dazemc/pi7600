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

abstract class User
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  User._({
    this.id,
    required this.userName,
    required this.userPassword,
    this.userFullName,
    this.userEmail,
    bool? isDisabled,
    bool? isAdmin,
  }) : isDisabled = isDisabled ?? false,
       isAdmin = isAdmin ?? false;

  factory User({
    int? id,
    required String userName,
    required String userPassword,
    String? userFullName,
    String? userEmail,
    bool? isDisabled,
    bool? isAdmin,
  }) = _UserImpl;

  factory User.fromJson(Map<String, dynamic> jsonSerialization) {
    return User(
      id: jsonSerialization['id'] as int?,
      userName: jsonSerialization['userName'] as String,
      userPassword: jsonSerialization['userPassword'] as String,
      userFullName: jsonSerialization['userFullName'] as String?,
      userEmail: jsonSerialization['userEmail'] as String?,
      isDisabled: jsonSerialization['isDisabled'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isDisabled']),
      isAdmin: jsonSerialization['isAdmin'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isAdmin']),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String userName;

  String userPassword;

  String? userFullName;

  String? userEmail;

  bool isDisabled;

  bool isAdmin;

  /// Returns a shallow copy of this [User]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  User copyWith({
    int? id,
    String? userName,
    String? userPassword,
    String? userFullName,
    String? userEmail,
    bool? isDisabled,
    bool? isAdmin,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'User',
      if (id != null) 'id': id,
      'userName': userName,
      'userPassword': userPassword,
      if (userFullName != null) 'userFullName': userFullName,
      if (userEmail != null) 'userEmail': userEmail,
      'isDisabled': isDisabled,
      'isAdmin': isAdmin,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'User',
      if (id != null) 'id': id,
      'userName': userName,
      'userPassword': userPassword,
      if (userFullName != null) 'userFullName': userFullName,
      if (userEmail != null) 'userEmail': userEmail,
      'isDisabled': isDisabled,
      'isAdmin': isAdmin,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _UserImpl extends User {
  _UserImpl({
    int? id,
    required String userName,
    required String userPassword,
    String? userFullName,
    String? userEmail,
    bool? isDisabled,
    bool? isAdmin,
  }) : super._(
         id: id,
         userName: userName,
         userPassword: userPassword,
         userFullName: userFullName,
         userEmail: userEmail,
         isDisabled: isDisabled,
         isAdmin: isAdmin,
       );

  /// Returns a shallow copy of this [User]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  User copyWith({
    Object? id = _Undefined,
    String? userName,
    String? userPassword,
    Object? userFullName = _Undefined,
    Object? userEmail = _Undefined,
    bool? isDisabled,
    bool? isAdmin,
  }) {
    return User(
      id: id is int? ? id : this.id,
      userName: userName ?? this.userName,
      userPassword: userPassword ?? this.userPassword,
      userFullName: userFullName is String? ? userFullName : this.userFullName,
      userEmail: userEmail is String? ? userEmail : this.userEmail,
      isDisabled: isDisabled ?? this.isDisabled,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
