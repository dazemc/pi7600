import 'package:simcom_api_server/src/data/user_store.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:simcom_api_server/src/services/user_service.dart';
import 'package:test/test.dart';

class FakeUserStore implements UserStore {
  final List<User> rows = [];
  int _nextId = 1;

  @override
  Future<User?> findByUsername(String username) async {
    for (final row in rows) {
      if (row.userName == username) return row;
    }
    return null;
  }

  @override
  Future<User?> findById(int id) async {
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  @override
  Future<List<User>> findAll() async => List.of(rows);

  @override
  Future<User> insert(User user) async {
    user.id = _nextId++;
    rows.add(user);
    return user;
  }

  @override
  Future<User> update(User user) async => user;
}

void main() {
  late FakeUserStore store;
  late UserService service;

  setUp(() {
    store = FakeUserStore();
    service = UserService(
      users: store,
      hashPassword: (password) async => 'hashed:$password',
    );
  });

  User actor({bool admin = true}) {
    return User(
      id: 99,
      userName: 'admin',
      userPassword: 'hash',
      isAdmin: admin,
    );
  }

  test('creates a user with a hashed password and trimmed fields', () async {
    final user = await service.create(
      username: '  bob  ',
      password: 'long-enough',
      fullName: ' Bob Example ',
      email: ' bob@example.com ',
    );

    expect(user.id, 1);
    expect(user.userName, 'bob');
    expect(user.userPassword, 'hashed:long-enough');
    expect(user.userFullName, 'Bob Example');
    expect(user.userEmail, 'bob@example.com');
    expect(user.isDisabled, isFalse);
    expect(user.isAdmin, isFalse);
  });

  test('rejects invalid usernames, passwords, and emails', () async {
    await expectLater(
      service.create(username: 'bad name', password: 'long-enough'),
      throwsA(isA<UserValidationException>()),
    );
    await expectLater(
      service.create(username: 'bob', password: 'short'),
      throwsA(isA<UserValidationException>()),
    );
    await expectLater(
      service.create(
        username: 'bob',
        password: 'long-enough',
        email: 'not-an-email',
      ),
      throwsA(isA<UserValidationException>()),
    );
  });

  test('rejects duplicate usernames', () async {
    await service.create(username: 'bob', password: 'long-enough');

    await expectLater(
      service.create(username: 'bob', password: 'long-enough'),
      throwsA(isA<UserNameTakenException>()),
    );
  });

  test('updates a password and revokes outstanding tokens', () async {
    final user = await service.create(
      username: 'bob',
      password: 'long-enough',
    );

    final updated = await service.update(
      id: user.id!,
      actor: actor(),
      password: 'new-long-password',
    );

    expect(updated.userPassword, 'hashed:new-long-password');
    expect(updated.tokenVersion, 1);
  });

  test('disabling a user revokes outstanding tokens', () async {
    final user = await service.create(
      username: 'bob',
      password: 'long-enough',
    );

    final updated = await service.update(
      id: user.id!,
      actor: actor(),
      isDisabled: true,
    );

    expect(updated.isDisabled, isTrue);
    expect(updated.tokenVersion, 1);
  });

  test('administrators cannot disable or demote themselves', () async {
    final admin = actor();
    store.rows.add(admin);

    await expectLater(
      service.update(id: admin.id!, actor: admin, isDisabled: true),
      throwsA(isA<UserValidationException>()),
    );
    await expectLater(
      service.update(id: admin.id!, actor: admin, isAdmin: false),
      throwsA(isA<UserValidationException>()),
    );
  });

  test('clears optional fields with an empty string', () async {
    final user = await service.create(
      username: 'bob',
      password: 'long-enough',
      fullName: 'Bob',
      email: 'bob@example.com',
    );

    final updated = await service.update(
      id: user.id!,
      actor: actor(),
      fullName: '',
      email: '',
    );

    expect(updated.userFullName, isNull);
    expect(updated.userEmail, isNull);
  });

  test('reports missing users', () async {
    await expectLater(
      service.update(id: 42, actor: actor(), isAdmin: true),
      throwsA(isA<UserNotFoundException>()),
    );
  });

  test('never serializes credentials or TOTP state', () async {
    final user = await service.create(
      username: 'bob',
      password: 'long-enough',
    );
    user.totpSecret = 'SECRET';
    user.totpRecoveryCodes = '["hash"]';
    user.totpEnabled = true;

    final json = userToJson(user);

    expect(json.keys, isNot(contains('userPassword')));
    expect(json.keys, isNot(contains('totpSecret')));
    expect(json.keys, isNot(contains('totpRecoveryCodes')));
    expect(json['totp_enabled'], isTrue);
  });
}
