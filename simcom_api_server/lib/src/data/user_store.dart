import 'package:simcom_api_server/src/generated/user.dart';
import 'package:serverpod/serverpod.dart';

/// Read access to API users.
abstract interface class UserStore {
  Future<User?> findByUsername(String username);

  Future<User?> findById(int id);

  Future<List<User>> findAll();

  Future<User> insert(User user);

  Future<User> update(User user);
}

/// PostgreSQL backed [UserStore] bound to a request session.
class SessionUserStore implements UserStore {
  const SessionUserStore(this.session);

  final DatabaseSession session;

  @override
  Future<User?> findByUsername(String username) {
    return User.db.findFirstRow(
      session,
      where: (table) => table.userName.equals(username),
    );
  }

  @override
  Future<User?> findById(int id) {
    return User.db.findFirstRow(
      session,
      where: (table) => table.id.equals(id),
    );
  }

  @override
  Future<List<User>> findAll() {
    return User.db.find(session, orderBy: (table) => table.id);
  }

  @override
  Future<User> insert(User user) {
    return User.db.insertRow(session, user);
  }

  @override
  Future<User> update(User user) {
    return User.db.updateRow(session, user);
  }
}
