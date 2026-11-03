import 'package:simcom_modem/simcom_modem.dart';
import 'package:simcom_modem/testing.dart';
import 'package:simcom_api_server/src/services/modem_settings_service.dart';
import 'package:test/test.dart';

void main() {
  late FakeTransport transport;
  late At at;
  late ModemSettingsService service;

  setUp(() {
    transport = FakeTransport();
    transport.onCommand = (command, fake) => fake.emit('\r\nOK\r\n');
    at = At(
      com: '/dev/fake',
      baudRate: 115200,
      transport: transport,
    )..open();
    service = ModemSettingsService(modem: ModemSettings(at: at));
  });

  tearDown(() async {
    at.closeSerial();
    await transport.dispose();
  });

  test('applies commands in order and saves', () async {
    final results = await service.apply(
      {
        'AT+CMGF': '1',
        'AT+CSCS': '"GSM"',
        'AT+CSCA': '"+15551234567",145',
      },
      save: true,
    );

    expect(results, hasLength(4));
    expect(results.every((result) => result.success), isTrue);
    expect(transport.written, [
      'AT+CMGF=1\r\n',
      'AT+CSCS="GSM"\r\n',
      'AT+CSCA="+15551234567",145\r\n',
      'AT&W\r\n',
    ]);
  });

  test('reports per-command failures without throwing', () async {
    transport.onCommand = (command, fake) {
      if (command.startsWith('AT+CMGF')) {
        fake.emit('\r\nERROR\r\n');
      } else {
        fake.emit('\r\nOK\r\n');
      }
    };

    final results = await service.apply({'AT+CMGF': '1', 'AT+CMEE': '2'});

    expect(results, hasLength(2));
    expect(results[0].success, isFalse);
    expect(results[1].success, isTrue);
  });

  test('rejects malformed command names and values', () async {
    await expectLater(
      service.apply({'ATD': '+15551234567'}),
      throwsA(isA<ModemSettingException>()),
    );
    await expectLater(
      service.apply({'AT+CMGF': '1\r\nAT+CFUN=0'}),
      throwsA(isA<ModemSettingException>()),
    );
    await expectLater(
      service.apply({'AT+CMGF': '1', 'at+cmgf': '0'}),
      throwsA(isA<ModemSettingException>()),
    );
  });
}
