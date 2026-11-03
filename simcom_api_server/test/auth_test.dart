import 'dart:convert';
import 'dart:io';

import 'package:hashlib/hashlib.dart';
import 'package:simcom_api_server/src/auth/auth_service.dart';
import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/auth/password.dart';
import 'package:simcom_api_server/src/auth/totp.dart';
import 'package:simcom_api_server/src/data/user_store.dart';
import 'package:simcom_api_server/src/generated/user.dart';
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

    test('rejects a token with a non-RS256 header', () {
      final token = jwt.createToken('alice');
      final parts = token.split('.');
      final header =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(parts[0])),
                ),
              )
              as Map<String, dynamic>;
      header['alg'] = 'HS256';
      final forged =
          '${base64Url.encode(utf8.encode(jsonEncode(header)))}.'
          '${parts[1]}.${parts[2]}';

      expect(() => jwt.verifyToken(forged), throwsA(isA<TokenException>()));
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

  group('AuthService', () {
    late JwtService jwt;

    setUp(() {
      jwt = JwtService(
        privateKeyPath: 'test/fixtures/private.pem',
        publicKeyPath: 'test/fixtures/public.pem',
        issuer: 'pi.test',
        expireMinutes: 30,
      );
    });

    test('verifies passwords off the main isolate', () async {
      final hash = bcrypt(utf8.encode('secret'));
      final user = User(
        id: 1,
        userName: 'alice',
        userPassword: hash,
      );
      final auth = AuthService(jwt: jwt, users: _FakeUserStore(user));

      expect(await auth.authenticatePassword('alice', 'secret'), same(user));
      expect(await auth.authenticatePassword('alice', 'wrong'), isNull);
      expect(await auth.authenticatePassword('bob', 'secret'), isNull);
    });

    test('sets up and enables TOTP', () async {
      final user = User(
        id: 1,
        userName: 'alice',
        userPassword: bcrypt(utf8.encode('secret')),
      );
      final store = _FakeUserStore(user);
      final auth = AuthService(jwt: jwt, users: store);

      final setup = await auth.setupTotp(user, 'secret');

      expect(setup, isNotNull);
      expect(setup!.secret, isNotEmpty);
      expect(setup.recoveryCodes, hasLength(10));
      expect(setup.provisioningUri, startsWith('otpauth://totp/'));
      expect(user.totpEnabled, isFalse);
      expect(user.totpSecret, setup.secret);
      expect(store.updates, 1);

      expect(await auth.enableTotp(user, totpCode(setup.secret)), isTrue);
      expect(user.totpEnabled, isTrue);
      expect(store.updates, 2);
    });

    test('does not start TOTP setup with a wrong password', () async {
      final user = User(
        id: 1,
        userName: 'alice',
        userPassword: bcrypt(utf8.encode('secret')),
      );
      final store = _FakeUserStore(user);
      final auth = AuthService(jwt: jwt, users: store);

      expect(await auth.setupTotp(user, 'wrong'), isNull);
      expect(user.totpSecret, isNull);
      expect(store.updates, 0);
    });

    test('rejects an invalid first TOTP code', () async {
      final user = User(
        id: 1,
        userName: 'alice',
        userPassword: bcrypt(utf8.encode('secret')),
      );
      final auth = AuthService(
        jwt: jwt,
        users: _FakeUserStore(user),
      );
      await auth.setupTotp(user, 'secret');

      expect(await auth.enableTotp(user, '000000'), isFalse);
      expect(user.totpEnabled, isFalse);
    });

    test('accepts a recovery code once', () async {
      final user = User(
        id: 1,
        userName: 'alice',
        userPassword: bcrypt(utf8.encode('secret')),
      );
      final auth = AuthService(
        jwt: jwt,
        users: _FakeUserStore(user),
      );
      final setup = await auth.setupTotp(user, 'secret');
      await auth.enableTotp(user, totpCode(setup!.secret));

      final recoveryCode = setup.recoveryCodes.first;
      expect(await auth.verifySecondFactor(user, recoveryCode), isTrue);
      expect(await auth.verifySecondFactor(user, recoveryCode), isFalse);
    });

    test('disables TOTP with the password and a valid code', () async {
      final user = User(
        id: 1,
        userName: 'alice',
        userPassword: bcrypt(utf8.encode('secret')),
      );
      final auth = AuthService(
        jwt: jwt,
        users: _FakeUserStore(user),
      );
      final setup = await auth.setupTotp(user, 'secret');
      await auth.enableTotp(user, totpCode(setup!.secret));

      expect(
        await auth.disableTotp(user, 'wrong', totpCode(setup.secret)),
        isFalse,
      );
      expect(
        await auth.disableTotp(user, 'secret', totpCode(setup.secret)),
        isTrue,
      );
      expect(user.totpEnabled, isFalse);
      expect(user.totpSecret, isNull);
      expect(user.totpRecoveryCodes, isNull);
    });
  });
}

class _FakeUserStore implements UserStore {
  _FakeUserStore(this.user);

  User? user;
  int updates = 0;

  @override
  Future<User?> findByUsername(String username) async {
    return user?.userName == username ? user : null;
  }

  @override
  Future<User> update(User user) async {
    updates++;
    this.user = user;
    return user;
  }
}
