import 'dart:convert';

import 'package:hashlib/hashlib.dart';

/// Verify a plaintext password against a bcrypt hash.
///
/// Both `$2a$` and `$2b$` hashes are supported, matching the hashes produced by
/// the previous Python service.
bool verifyPassword(String password, String encodedHash) {
  try {
    return bcryptVerify(encodedHash, utf8.encode(password));
  } catch (_) {
    return false;
  }
}
