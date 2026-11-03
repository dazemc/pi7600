import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:hashlib/hashlib.dart';

const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

/// Alphabet for recovery codes. It omits visually ambiguous characters.
const _recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Generate a random 160-bit TOTP secret encoded as base32.
String generateTotpSecret({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(20, (_) => source.nextInt(256));
  return base32Encode(bytes);
}

/// Encode [bytes] as RFC 4648 base32 without padding.
String base32Encode(List<int> bytes) {
  final output = StringBuffer();
  var buffer = 0;
  var bits = 0;

  for (final byte in bytes) {
    buffer = (buffer << 8) | (byte & 0xff);
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      output.write(_base32Alphabet[(buffer >> bits) & 0x1f]);
    }
  }
  if (bits > 0) {
    output.write(_base32Alphabet[(buffer << (5 - bits)) & 0x1f]);
  }
  return output.toString();
}

/// Decode an RFC 4648 base32 string.
///
/// Spaces, hyphens, and `=` padding are ignored. Throws [FormatException] for
/// other characters.
Uint8List base32Decode(String value) {
  final normalized = value.toUpperCase().replaceAll(RegExp(r'[\s=-]'), '');
  final output = <int>[];
  var buffer = 0;
  var bits = 0;

  for (final codeUnit in normalized.codeUnits) {
    final index = _base32Alphabet.indexOf(String.fromCharCode(codeUnit));
    if (index < 0) {
      throw const FormatException('Invalid base32 secret');
    }
    buffer = (buffer << 5) | index;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      output.add((buffer >> bits) & 0xff);
    }
  }
  return Uint8List.fromList(output);
}

/// Build an `otpauth://totp/...` provisioning URI for authenticator apps.
String totpProvisioningUri({
  required String secret,
  required String accountName,
  String issuer = 'Simcom API',
  int digits = 6,
  int period = 30,
}) {
  final label = Uri.encodeComponent('$issuer:$accountName');
  final query = Uri(
    queryParameters: {
      'secret': secret,
      'issuer': issuer,
      'algorithm': 'SHA1',
      'digits': '$digits',
      'period': '$period',
    },
  ).query;
  return 'otpauth://totp/$label?$query';
}

/// Generate a six-digit TOTP value for [secret].
String totpCode(
  String secret, {
  DateTime? at,
  int digits = 6,
  int period = 30,
}) {
  final seconds = (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
  final counter = seconds ~/ period;
  final message = Uint8List(8);
  var remaining = counter;
  for (var index = 7; index >= 0; index--) {
    message[index] = remaining & 0xff;
    remaining >>= 8;
  }

  final digest = sha1.hmac.by(base32Decode(secret)).convert(message).bytes;
  final offset = digest[19] & 0x0f;
  final binary =
      ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);

  var modulus = 1;
  for (var index = 0; index < digits; index++) {
    modulus *= 10;
  }
  return (binary % modulus).toString().padLeft(digits, '0');
}

/// Verify a TOTP code, accepting one time step before and after [at].
bool verifyTotpCode(
  String secret,
  String code, {
  DateTime? at,
  int window = 1,
  int digits = 6,
  int period = 30,
}) {
  final normalized = code.replaceAll(RegExp(r'\s'), '');
  if (!RegExp('^\\d{$digits}\$').hasMatch(normalized)) return false;

  final now = at ?? DateTime.now();
  for (var offset = -window; offset <= window; offset++) {
    final candidate = totpCode(
      secret,
      at: now.add(Duration(seconds: offset * period)),
      digits: digits,
      period: period,
    );
    if (constantTimeEquals(candidate, normalized)) return true;
  }
  return false;
}

/// Generate human-friendly recovery codes, for example `ABCDE-FGHJK`.
List<String> generateRecoveryCodes({int count = 10, Random? random}) {
  final source = random ?? Random.secure();
  return List.generate(count, (_) {
    final characters = List.generate(
      10,
      (_) => _recoveryAlphabet[source.nextInt(_recoveryAlphabet.length)],
    );
    return '${characters.sublist(0, 5).join()}-'
        '${characters.sublist(5).join()}';
  }, growable: false);
}

/// Hash a recovery code for storage. Recovery codes are high-entropy random
/// values, so a fast SHA-256 hash is sufficient.
String hashRecoveryCode(String code) {
  final normalized = code.trim().toUpperCase().replaceAll(
    RegExp(r'[\s-]'),
    '',
  );
  return sha256.hex(utf8.encode(normalized));
}

/// Compare two strings without short-circuiting on the first difference.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var index = 0; index < a.length; index++) {
    difference |= a.codeUnitAt(index) ^ b.codeUnitAt(index);
  }
  return difference == 0;
}
