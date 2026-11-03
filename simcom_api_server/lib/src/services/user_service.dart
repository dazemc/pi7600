import 'package:simcom_api_server/src/auth/password.dart';
import 'package:simcom_api_server/src/data/user_store.dart';
import 'package:simcom_api_server/src/generated/user.dart';

class UserValidationException implements Exception {
  UserValidationException(this.message);

  final String message;

  @override
  String toString() => 'UserValidationException: $message';
}

class UserNameTakenException implements Exception {
  UserNameTakenException(this.username);

  final String username;
}

class UserNotFoundException implements Exception {
  UserNotFoundException(this.id);

  final int id;
}

/// Serialize a user without passwords, TOTP secrets, or recovery codes.
Map<String, Object?> userToJson(User user) {
  return {
    'id': user.id,
    'username': user.userName,
    'full_name': user.userFullName,
    'email': user.userEmail,
    'is_disabled': user.isDisabled,
    'is_admin': user.isAdmin,
    'totp_enabled': user.totpEnabled,
  };
}

/// Administrative user management.
class UserService {
  UserService({
    required this.users,
    Future<String> Function(String password)? hashPassword,
  }) : _hashPassword = hashPassword ?? hashPasswordAsync;

  final UserStore users;
  final Future<String> Function(String password) _hashPassword;

  static final _usernamePattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _minimumPasswordLength = 8;

  Future<List<User>> list() => users.findAll();

  Future<User> create({
    required String username,
    required String password,
    String? fullName,
    String? email,
    bool isAdmin = false,
  }) async {
    final normalizedUsername = username.trim();
    if (!_usernamePattern.hasMatch(normalizedUsername)) {
      throw UserValidationException(
        'username must be 1-64 characters using letters, digits, dot, '
        'underscore, or hyphen',
      );
    }
    _validatePassword(password);
    final normalizedFullName = _optionalText(
      fullName,
      maxLength: 200,
      field: 'full_name',
    );
    final normalizedEmail = _optionalEmail(email);

    if (await users.findByUsername(normalizedUsername) != null) {
      throw UserNameTakenException(normalizedUsername);
    }

    final user = User(
      userName: normalizedUsername,
      userPassword: await _hashPassword(password),
      userFullName: normalizedFullName,
      userEmail: normalizedEmail,
      isDisabled: false,
      isAdmin: isAdmin,
    );
    return users.insert(user);
  }

  Future<User> update({
    required int id,
    required User actor,
    String? password,
    String? fullName,
    String? email,
    bool? isDisabled,
    bool? isAdmin,
  }) async {
    final user = await users.findById(id);
    if (user == null) throw UserNotFoundException(id);

    if (user.id == actor.id) {
      if (isDisabled == true) {
        throw UserValidationException('cannot disable your own account');
      }
      if (isAdmin == false) {
        throw UserValidationException(
          'cannot remove your own administrator access',
        );
      }
    }

    var revokeTokens = false;
    if (password != null) {
      _validatePassword(password);
      user.userPassword = await _hashPassword(password);
      revokeTokens = true;
    }
    if (fullName != null) {
      user.userFullName = _optionalText(
        fullName,
        maxLength: 200,
        field: 'full_name',
      );
    }
    if (email != null) {
      user.userEmail = _optionalEmail(email);
    }
    if (isDisabled != null && isDisabled != user.isDisabled) {
      user.isDisabled = isDisabled;
      revokeTokens = true;
    }
    if (isAdmin != null) {
      user.isAdmin = isAdmin;
    }
    if (revokeTokens) user.tokenVersion++;

    return users.update(user);
  }

  void _validatePassword(String password) {
    if (password.length < _minimumPasswordLength) {
      throw UserValidationException(
        'password must be at least $_minimumPasswordLength characters',
      );
    }
  }

  String? _optionalText(
    String? value, {
    required int maxLength,
    required String field,
  }) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > maxLength) {
      throw UserValidationException('$field is too long');
    }
    return trimmed;
  }

  String? _optionalEmail(String? value) {
    final normalized = _optionalText(
      value,
      maxLength: 320,
      field: 'email',
    );
    if (normalized == null) return null;
    if (!_emailPattern.hasMatch(normalized)) {
      throw UserValidationException('invalid email address');
    }
    return normalized;
  }
}
