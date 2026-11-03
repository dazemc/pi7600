import 'package:pi7600_server/src/generated/user.dart';
import 'package:serverpod/serverpod.dart';

/// Read access to API users.
abstract interface class UserStore {
  Future<User?> findByUsername(String username);
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
}
