import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class TokenException implements Exception {
  TokenException(this.message);

  final String message;

  @override
  String toString() => 'TokenException: $message';
}

/// Claims extracted from a verified token.
class TokenClaims {
  const TokenClaims({
    required this.subject,
    required this.version,
    required this.isRefresh,
  });

  final String subject;
  final int version;
  final bool isRefresh;
}

/// Issues and verifies RS256 JSON Web Tokens.
class JwtService {
  JwtService({
    required this.privateKeyPath,
    required this.publicKeyPath,
    required this.issuer,
    required this.expireMinutes,
    this.refreshExpireDays = 7,
  });

  final String privateKeyPath;
  final String publicKeyPath;
  final String issuer;
  final int expireMinutes;
  final int refreshExpireDays;

  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;

  RSAPrivateKey get _signingKey =>
      _privateKey ??= RSAPrivateKey(File(privateKeyPath).readAsStringSync());

  RSAPublicKey get _verificationKey =>
      _publicKey ??= RSAPublicKey(File(publicKeyPath).readAsStringSync());

  /// Create an access token for [subject].
  ///
  /// [version] must match the user's current token version for the token to be
  /// accepted by [AuthService.authenticateToken].
  String createToken(String subject, {int version = 0}) {
    return _sign(subject, version: version, refresh: false);
  }

  /// Create a long-lived refresh token for [subject].
  String createRefreshToken(String subject, {int version = 0}) {
    return _sign(subject, version: version, refresh: true);
  }

  String _sign(String subject, {required int version, required bool refresh}) {
    final jwt = JWT(
      {
        'sub': subject,
        'ver': version,
        'typ': refresh ? 'refresh' : 'access',
      },
      issuer: issuer,
    );
    return jwt.sign(
      _signingKey,
      algorithm: JWTAlgorithm.RS256,
      expiresIn: refresh
          ? Duration(days: refreshExpireDays)
          : Duration(minutes: expireMinutes),
    );
  }

  /// Verify an access token and return its subject.
  String verifyToken(String token) => verifyTokenClaims(token).subject;

  /// Verify an access token and return its claims.
  TokenClaims verifyTokenClaims(String token) {
    return _verify(token, expectRefresh: false);
  }

  /// Verify a refresh token and return its claims.
  TokenClaims verifyRefreshToken(String token) {
    return _verify(token, expectRefresh: true);
  }

  TokenClaims _verify(String token, {required bool expectRefresh}) {
    try {
      _requireRs256(token);
      final jwt = JWT.verify(
        token,
        _verificationKey,
        issuer: issuer,
      );
      final payload = jwt.payload;
      if (payload is! Map) {
        throw TokenException('invalid token payload');
      }
      final subject = payload['sub'];
      if (subject is! String || subject.isEmpty) {
        throw TokenException('missing subject');
      }

      final type = payload['typ'];
      final isRefresh = type == 'refresh';
      if (expectRefresh && !isRefresh) {
        throw TokenException('refresh token required');
      }
      if (!expectRefresh && isRefresh) {
        throw TokenException('access token required');
      }

      final version = payload['ver'] ?? 0;
      if (version is! int || version < 0) {
        throw TokenException('invalid token version');
      }

      return TokenClaims(
        subject: subject,
        version: version,
        isRefresh: isRefresh,
      );
    } on TokenException {
      rethrow;
    } on JWTException catch (error) {
      throw TokenException(error.message);
    } catch (error) {
      throw TokenException('$error');
    }
  }

  static void _requireRs256(String token) {
    final parts = token.split('.');
    if (parts.length != 3) throw TokenException('invalid token');
    try {
      final header = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[0]))),
      );
      if (header is! Map || header['alg'] != 'RS256') {
        throw TokenException('unsupported token algorithm');
      }
    } on TokenException {
      rethrow;
    } on Object {
      throw TokenException('invalid token header');
    }
  }
}
