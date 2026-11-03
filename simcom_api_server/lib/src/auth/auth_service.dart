import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/auth/password.dart';
import 'package:simcom_api_server/src/data/user_store.dart';
import 'package:simcom_api_server/src/generated/user.dart';

/// Authentication and authorization for HTTP and WebSocket requests.
class AuthService {
  AuthService({required this.jwt, required this.users});

  final JwtService jwt;
  final UserStore users;

  /// Validate a username/password pair.
  Future<User?> authenticatePassword(String username, String password) async {
    final user = await users.findByUsername(username);
    if (user == null || user.isDisabled) return null;
    if (!verifyPassword(password, user.userPassword)) return null;
    return user;
  }

  /// Validate a JWT and load the matching, enabled user.
  Future<User?> authenticateToken(String token) async {
    final username = jwt.verifyToken(token);
    final user = await users.findByUsername(username);
    if (user == null || user.isDisabled) return null;
    return user;
  }

  /// Extract and validate a bearer token from an `Authorization` header.
  Future<User?> fromAuthorization(String? header) async {
    final token = bearerToken(header);
    if (token == null) return null;
    return authenticateToken(token);
  }

  /// Return the token part of a `Bearer` authorization header.
  static String? bearerToken(String? header) {
    if (header == null) return null;
    final trimmed = header.trim();
    final separator = trimmed.indexOf(' ');
    if (separator <= 0) return null;
    final scheme = trimmed.substring(0, separator).toLowerCase();
    if (scheme != 'bearer') return null;
    final token = trimmed.substring(separator + 1).trim();
    return token.isEmpty ? null : token;
  }
}
