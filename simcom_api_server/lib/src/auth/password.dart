import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:hashlib/hashlib.dart';

typedef _CryptRnNative =
    Pointer<Utf8> Function(
      Pointer<Utf8> phrase,
      Pointer<Utf8> setting,
      Pointer<Void> data,
      Int32 size,
    );

typedef _CryptRnDart =
    Pointer<Utf8> Function(
      Pointer<Utf8> phrase,
      Pointer<Utf8> setting,
      Pointer<Void> data,
      int size,
    );

_CryptRnDart? _cryptRn;
bool _cryptLoaded = false;

/// Load `crypt_rn` from the system libcrypt, if available.
///
/// libxcrypt implements bcrypt for `$2a$`, `$2b$`, and `$2y$` hashes. The
/// pure-Dart implementation is used as a fallback on systems without it.
_CryptRnDart? _loadCrypt() {
  if (_cryptLoaded) return _cryptRn;
  _cryptLoaded = true;

  for (final name in const [
    'libcrypt.so.2',
    'libcrypt.so.1',
    'libcrypt.so',
  ]) {
    try {
      final library = DynamicLibrary.open(name);
      _cryptRn = library.lookupFunction<_CryptRnNative, _CryptRnDart>(
        'crypt_rn',
      );
      return _cryptRn;
    } on Object {
      // Try the next library name.
    }
  }
  return null;
}

/// Verify a plaintext password against a bcrypt hash.
///
/// Both `$2a$` and `$2b$` hashes are supported. The native libcrypt
/// implementation is used when available; otherwise this falls back to the
/// pure-Dart implementation in `hashlib`.
bool verifyPassword(String password, String encodedHash) {
  final native = _verifyWithLibcrypt(password, encodedHash);
  if (native != null) return native;

  try {
    return bcryptVerify(encodedHash, utf8.encode(password));
  } catch (_) {
    return false;
  }
}

/// Return `true` for a match, `false` for a mismatch, and `null` when the
/// native implementation is unavailable or fails unexpectedly.
bool? _verifyWithLibcrypt(String password, String encodedHash) {
  final crypt = _loadCrypt();
  if (crypt == null) return null;

  final phrase = password.toNativeUtf8();
  final setting = encodedHash.toNativeUtf8();
  final buffer = calloc<Uint8>(65536);
  try {
    final result = crypt(phrase, setting, buffer.cast<Void>(), 65536);
    if (result == nullptr) return null;
    return _constantTimeEquals(result.toDartString(), encodedHash);
  } on Object {
    return null;
  } finally {
    calloc.free(phrase);
    calloc.free(setting);
    calloc.free(buffer);
  }
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return difference == 0;
}

/// Verify a password on a worker isolate.
///
/// Bcrypt is CPU-bound and can take several seconds on a Raspberry Pi. Running
/// it on the server event loop would stall every other request, so HTTP login
/// uses this async variant.
Future<bool> verifyPasswordAsync(String password, String encodedHash) async {
  try {
    return await Isolate.run(
      () => verifyPassword(password, encodedHash),
      debugName: 'pi7600.bcrypt',
    );
  } on Object {
    return false;
  }
}
