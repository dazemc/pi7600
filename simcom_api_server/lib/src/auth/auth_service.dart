import 'dart:convert';

import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/auth/password.dart';
import 'package:simcom_api_server/src/auth/totp.dart';
import 'package:simcom_api_server/src/data/user_store.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:simcom_api_server/src/util/app_log.dart';

/// Secret and one-time recovery codes returned when TOTP setup starts.
class TotpSetup {
  const TotpSetup({
    required this.secret,
    required this.provisioningUri,
    required this.recoveryCodes,
  });

  final String secret;
  final String provisioningUri;
  final List<String> recoveryCodes;
}

/// Authentication and authorization for HTTP and WebSocket requests.
class AuthService {
  AuthService({required this.jwt, required this.users});

  final JwtService jwt;
  final UserStore users;

  /// Validate a username/password pair.
  Future<User?> authenticatePassword(String username, String password) async {
    final stopwatch = Stopwatch()..start();
    final user = await users.findByUsername(username);
    final lookupMs = stopwatch.elapsedMilliseconds;
    if (user == null || user.isDisabled) {
      AppLog.debug(
        'password auth: lookup=${lookupMs}ms result=rejected',
        name: 'pi7600.auth',
      );
      return null;
    }
    final verified = await verifyPasswordAsync(password, user.userPassword);
    AppLog.debug(
      'password auth: lookup=${lookupMs}ms '
      'bcrypt=${stopwatch.elapsedMilliseconds - lookupMs}ms',
      name: 'pi7600.auth',
    );
    if (!verified) return null;
    return user;
  }

  /// Validate a JWT and load the matching, enabled user.
  Future<User?> authenticateToken(String token) async {
    final stopwatch = Stopwatch()..start();
    final username = jwt.verifyToken(token);
    final jwtMs = stopwatch.elapsedMilliseconds;
    final user = await users.findByUsername(username);
    AppLog.debug(
      'token auth: jwt=${jwtMs}ms '
      'lookup=${stopwatch.elapsedMilliseconds - jwtMs}ms',
      name: 'pi7600.auth',
    );
    if (user == null || user.isDisabled) return null;
    return user;
  }

  /// Start TOTP enrollment for [user].
  ///
  /// Returns `null` when [password] is wrong. The secret is stored immediately
  /// but TOTP stays disabled until [enableTotp] verifies the first code.
  Future<TotpSetup?> setupTotp(User user, String password) async {
    if (!await verifyPasswordAsync(password, user.userPassword)) return null;

    final secret = generateTotpSecret();
    final recoveryCodes = generateRecoveryCodes();
    user.totpSecret = secret;
    user.totpEnabled = false;
    user.totpRecoveryCodes = jsonEncode(
      recoveryCodes.map(hashRecoveryCode).toList(growable: false),
    );
    await users.update(user);

    return TotpSetup(
      secret: secret,
      provisioningUri: totpProvisioningUri(
        secret: secret,
        accountName: user.userName,
      ),
      recoveryCodes: recoveryCodes,
    );
  }

  /// Enable TOTP after verifying the first code from the authenticator app.
  Future<bool> enableTotp(User user, String code) async {
    final secret = user.totpSecret;
    if (secret == null || !verifyTotpCode(secret, code)) return false;
    user.totpEnabled = true;
    await users.update(user);
    return true;
  }

  /// Disable TOTP after verifying the password and a current or recovery code.
  Future<bool> disableTotp(
    User user,
    String password,
    String code,
  ) async {
    if (!await verifyPasswordAsync(password, user.userPassword)) return false;
    if (!await verifySecondFactor(user, code)) return false;
    user.totpEnabled = false;
    user.totpSecret = null;
    user.totpRecoveryCodes = null;
    await users.update(user);
    return true;
  }

  /// Verify the second factor for a user with TOTP enabled.
  ///
  /// Accepts a TOTP code or a single-use recovery code. Recovery codes are
  /// removed from the user row when consumed.
  Future<bool> verifySecondFactor(User user, String code) async {
    if (user.totpEnabled != true) return true;

    final secret = user.totpSecret;
    if (secret != null && verifyTotpCode(secret, code)) return true;
    return _consumeRecoveryCode(user, code);
  }

  Future<bool> _consumeRecoveryCode(User user, String code) async {
    final stored = user.totpRecoveryCodes;
    if (stored == null) return false;

    final List<dynamic> hashes;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return false;
      hashes = decoded;
    } on FormatException {
      return false;
    }

    final hash = hashRecoveryCode(code);
    var match = -1;
    for (var index = 0; index < hashes.length; index++) {
      final value = hashes[index];
      if (value is String && constantTimeEquals(value, hash)) {
        match = index;
      }
    }
    if (match < 0) return false;

    hashes.removeAt(match);
    user.totpRecoveryCodes = jsonEncode(hashes);
    await users.update(user);
    return true;
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
