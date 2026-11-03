import 'dart:convert';
import 'dart:io';

import 'package:hashlib/hashlib.dart';
import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/auth/password.dart';
import 'package:test/test.dart';

void main() {
  group('verifyPassword', () {
    test('accepts the matching bcrypt password', () {
      final hash = bcrypt(utf8.encode('correct horse battery staple'));

      expect(hash, startsWith(r'$2b$'));
      expect(verifyPassword('correct horse battery staple', hash), isTrue);
    });

    test('rejects a wrong password', () {
      final hash = bcrypt(utf8.encode('secret'));

      expect(verifyPassword('not-secret', hash), isFalse);
    });

    test('accepts a \$2a\$ hash', () {
      final hash = bcrypt(
        utf8.encode('secret'),
        bcryptSalt().replaceFirst(
          r'$2b$',
          r'$2a$',
        ),
      );

      expect(verifyPassword('secret', hash), isTrue);
    });

    test('rejects malformed hashes instead of throwing', () {
      expect(verifyPassword('secret', 'not-a-hash'), isFalse);
    });
  });

  group('JwtService', () {
    late JwtService jwt;

    setUp(() {
      jwt = JwtService(
        privateKeyPath: 'test/fixtures/private.pem',
        publicKeyPath: 'test/fixtures/public.pem',
        issuer: 'pi.test',
        expireMinutes: 30,
      );
    });

    test('round-trips the subject', () {
      final token = jwt.createToken('alice');

      expect(jwt.verifyToken(token), 'alice');
    });

    test('rejects a token from another issuer', () {
      final other = JwtService(
        privateKeyPath: 'test/fixtures/private.pem',
        publicKeyPath: 'test/fixtures/public.pem',
        issuer: 'other.test',
        expireMinutes: 30,
      );
      final token = other.createToken('alice');

      expect(() => jwt.verifyToken(token), throwsA(isA<TokenException>()));
    });

    test('rejects a tampered token', () {
      final token = jwt.createToken('alice');
      final parts = token.split('.');
      final tampered = '${parts[0]}.${parts[1]}.${parts[2].substring(0, 8)}';

      expect(() => jwt.verifyToken(tampered), throwsA(isA<TokenException>()));
    });

    test('reports missing key files as a TokenException', () {
      final missing = JwtService(
        privateKeyPath: 'test/fixtures/missing.pem',
        publicKeyPath: 'test/fixtures/public.pem',
        issuer: 'pi.test',
        expireMinutes: 30,
      );

      expect(
        () => missing.createToken('alice'),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}
