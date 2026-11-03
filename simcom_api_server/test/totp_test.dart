import 'dart:math';

import 'package:simcom_api_server/src/auth/totp.dart';
import 'package:test/test.dart';

void main() {
  // RFC 6238 Appendix B, SHA-1 test secret.
  const rfcSecret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

  test('matches the RFC 6238 SHA-1 vectors', () {
    expect(totpCode(rfcSecret, at: _at(59)), '287082');
    expect(totpCode(rfcSecret, at: _at(1111111109)), '081804');
    expect(totpCode(rfcSecret, at: _at(1111111111)), '050471');
    expect(totpCode(rfcSecret, at: _at(1234567890)), '005924');
    expect(totpCode(rfcSecret, at: _at(2000000000)), '279037');
    expect(totpCode(rfcSecret, at: _at(20000000000)), '353130');
  });

  test('accepts adjacent time steps and rejects others', () {
    final now = _at(1111111109);

    expect(verifyTotpCode(rfcSecret, '081804', at: now), isTrue);
    expect(
      verifyTotpCode(
        rfcSecret,
        '050471',
        at: now.add(const Duration(seconds: 30)),
      ),
      isTrue,
    );
    expect(
      verifyTotpCode(
        rfcSecret,
        '287082',
        at: now.add(const Duration(minutes: 10)),
      ),
      isFalse,
    );
    expect(verifyTotpCode(rfcSecret, 'abcdef', at: now), isFalse);
    expect(verifyTotpCode(rfcSecret, '12345', at: now), isFalse);
  });

  test('base32 round-trips bytes', () {
    final bytes = List<int>.generate(20, (index) => index * 11 % 256);
    final encoded = base32Encode(bytes);

    expect(base32Decode(encoded), bytes);
    expect(base32Decode('gezd gnbv-gy3t'), base32Decode('GEZDGNBVGY3T'));
    expect(() => base32Decode('not base32!'), throwsFormatException);
  });

  test('generates unique, decodable secrets', () {
    final first = generateTotpSecret(random: Random(1));
    final second = generateTotpSecret(random: Random(2));

    expect(first, isNot(second));
    expect(base32Decode(first), hasLength(20));
  });

  test('builds an otpauth provisioning URI', () {
    final uri = totpProvisioningUri(
      secret: 'JBSWY3DPEHPK3PXP',
      accountName: 'alice',
    );

    expect(uri, startsWith('otpauth://totp/Simcom%20API%3Aalice?'));
    expect(uri, contains('secret=JBSWY3DPEHPK3PXP'));
    expect(uri, contains('issuer=Simcom+API'));
  });

  test('recovery codes are unique and hash consistently', () {
    final codes = generateRecoveryCodes(random: Random(3));

    expect(codes, hasLength(10));
    expect(codes.toSet(), hasLength(10));
    expect(
      codes.every(
        (code) => RegExp(r'^[A-Z2-9]{5}-[A-Z2-9]{5}$').hasMatch(code),
      ),
      isTrue,
    );
    expect(
      hashRecoveryCode(codes.first),
      hashRecoveryCode(codes.first.toLowerCase().replaceAll('-', '')),
    );
    expect(hashRecoveryCode(codes.first), isNot(hashRecoveryCode(codes.last)));
  });
}

DateTime _at(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
