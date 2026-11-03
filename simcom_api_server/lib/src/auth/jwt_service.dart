import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

class TokenException implements Exception {
  TokenException(this.message);

  final String message;

  @override
  String toString() => 'TokenException: $message';
}

/// Issues and verifies RS256 JSON Web Tokens.
class JwtService {
  JwtService({
    required this.privateKeyPath,
    required this.publicKeyPath,
    required this.issuer,
    required this.expireMinutes,
  });

  final String privateKeyPath;
  final String publicKeyPath;
  final String issuer;
  final int expireMinutes;

  RSAPrivateKey? _privateKey;
  RSAPublicKey? _publicKey;

  RSAPrivateKey get _signingKey =>
      _privateKey ??= RSAPrivateKey(File(privateKeyPath).readAsStringSync());

  RSAPublicKey get _verificationKey =>
      _publicKey ??= RSAPublicKey(File(publicKeyPath).readAsStringSync());

  /// Create an access token for [subject].
  String createToken(String subject) {
    final jwt = JWT(
      {'sub': subject},
      issuer: issuer,
    );
    return jwt.sign(
      _signingKey,
      algorithm: JWTAlgorithm.RS256,
      expiresIn: Duration(minutes: expireMinutes),
    );
  }

  /// Verify [token] and return its subject.
  String verifyToken(String token) {
    try {
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
      return subject;
    } on TokenException {
      rethrow;
    } on JWTException catch (error) {
      throw TokenException(error.message);
    } catch (error) {
      throw TokenException('$error');
    }
  }
}
