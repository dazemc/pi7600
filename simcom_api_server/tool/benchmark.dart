import 'dart:io';
import 'dart:typed_data';

import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/auth/password.dart';
import 'package:simcom_api_server/src/camera/camera_capture.dart';
import 'package:simcom_modem/simcom_modem.dart';
import 'package:simcom_modem/testing.dart';

/// Lightweight, hardware-free benchmark harness.
///
/// Run from `simcom_api_server`:
///   dart run tool/benchmark.dart
Future<void> main() async {
  stdout.writeln('Pi7600 / simcom_api benchmark');
  stdout.writeln('');

  await _benchmarkAt();
  await _benchmarkPduParsing();
  await _benchmarkBcrypt();
  await _benchmarkJwt();
  await _benchmarkYuyv();
}

Future<void> _benchmarkAt() async {
  final transport = FakeTransport()
    ..onCommand = (command, fake) {
      fake.emit('\r\nOK\r\n');
    };
  final at = At(
    com: '/dev/fake',
    baudRate: 115200,
    transport: transport,
  )..open();

  // Warm up the stream subscription and lock.
  await at.sendAt('AT', 'OK', 1);

  const iterations = 1000;
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    await at.sendAt('AT', 'OK', 1);
  }
  stopwatch.stop();

  final perCommand = stopwatch.elapsedMicroseconds / iterations;
  stdout.writeln(
    'AT round trip: $iterations commands in '
    '${stopwatch.elapsedMilliseconds} ms '
    '(${perCommand.toStringAsFixed(1)} us/command)',
  );

  at.closeSerial();
  await transport.dispose();
}

Future<void> _benchmarkPduParsing() async {
  const pdu =
      '07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07';
  final buffer = List.generate(
    100,
    (index) => '+CMGL: $index,0,,,,\r\n$pdu\r\n',
  ).join();
  final parser = SmsParser(timezone: 0);

  // Warm up.
  parser.parsePdu(buffer);

  const iterations = 20;
  final stopwatch = Stopwatch()..start();
  var count = 0;
  for (var i = 0; i < iterations; i++) {
    count += parser.parsePdu(buffer).length;
  }
  stopwatch.stop();

  stdout.writeln(
    'SMS PDU parse: ${count ~/ iterations} messages in '
    '${(stopwatch.elapsedMicroseconds / iterations / 1000).toStringAsFixed(2)} '
    'ms/parse',
  );
}

Future<void> _benchmarkBcrypt() async {
  // A cost-12 hash for the non-secret benchmark password.
  const hash = r'$2b$12$5t3UItJNZZ9bCnkHE84XJeSKczTNPvndnjAXTynmiwxeS2QK07Apu';
  const password = 'jaspr-check-pass';

  const iterations = 3;
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    if (!verifyPassword(password, hash)) {
      throw StateError('bcrypt verification failed');
    }
  }
  stopwatch.stop();

  final asyncWatch = Stopwatch()..start();
  await verifyPasswordAsync(password, hash);
  asyncWatch.stop();

  stdout.writeln(
    'bcrypt verify: '
    '${(stopwatch.elapsedMilliseconds / iterations).toStringAsFixed(1)} ms/verify '
    '(native/fallback), '
    '${asyncWatch.elapsedMilliseconds} ms/verify in a worker isolate',
  );
}

Future<void> _benchmarkJwt() async {
  final jwt = JwtService(
    privateKeyPath: 'test/fixtures/private.pem',
    publicKeyPath: 'test/fixtures/public.pem',
    issuer: 'benchmark.test',
    expireMinutes: 30,
  );
  final token = jwt.createToken('alice');
  jwt.verifyToken(token);

  const iterations = 1000;
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    jwt.verifyToken(token);
  }
  stopwatch.stop();

  stdout.writeln(
    'JWT RS256 verify: '
    '${(stopwatch.elapsedMicroseconds / iterations / 1000).toStringAsFixed(2)} '
    'ms/token',
  );
}

Future<void> _benchmarkYuyv() async {
  const width = 640;
  const height = 480;
  final frame = Uint8List(width * height * 2)
    ..fillRange(0, width * height * 2, 128);

  // Warm up and measure a small number of frames; this is CPU-bound.
  yuyvToJpeg(frame, width, height, width * 2);

  const iterations = 3;
  final stopwatch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    yuyvToJpeg(frame, width, height, width * 2);
  }
  stopwatch.stop();

  stdout.writeln(
    'YUYV -> JPEG (640x480): '
    '${(stopwatch.elapsedMilliseconds / iterations).toStringAsFixed(1)} '
    'ms/frame',
  );
}
