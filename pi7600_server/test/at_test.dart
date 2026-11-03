import 'package:pi7600_server/src/modem/at.dart';
import 'support/fake_transport.dart';
import 'package:test/test.dart';

void main() {
  late FakeTransport transport;
  late At at;

  setUp(() {
    transport = FakeTransport();
    at = At(com: '/dev/fake', baudRate: 115200, transport: transport);
    at.open();
  });

  tearDown(() async {
    at.closeSerial();
    await transport.dispose();
  });

  test('subscribes to the transport stream when opened', () async {
    expect(at.isOpen, isTrue);

    final response = at.readUntil('OK', 1);
    await Future<void>.delayed(Duration.zero);
    transport.emit('\r\nOK\r\n');

    expect(await response, contains('OK'));
  });

  test('sendAt returns the response that contains the token', () async {
    transport.onCommand = (command, transport) {
      if (command.startsWith('AT+TEST')) {
        transport.emit('\r\n+TEST: 42\r\nOK\r\n');
      }
    };

    final response = await at.sendAt('AT+TEST', 'OK', 1);

    expect(response, contains('+TEST: 42'));
    expect(transport.written, contains('AT+TEST\r\n'));
  });

  test('sendAt returns modem errors immediately', () async {
    transport.onCommand = (command, transport) {
      transport.emit('\r\n+CME ERROR: 10\r\n');
    };

    final response = await at.sendAt('AT+BAD', 'OK', 1);

    expect(At.isError(response), isTrue);
    expect(response, contains('+CME ERROR: 10'));
  });

  test('sendAt times out without a response', () async {
    final response = await at.sendAt('AT+SILENT', 'OK', 0);

    expect(At.isError(response), isTrue);
    expect(response, contains('Timeout'));
  });

  test('sendRaw waits for OK or ERROR', () async {
    transport.onCommand = (command, transport) {
      transport.emit('\r\nATI\r\nSIM7600G-H\r\n\r\nOK\r\n');
    };

    final response = await at.sendRaw('ATI');

    expect(response, contains('SIM7600G-H'));
  });

  test('writeData sends bytes under the serial lock', () async {
    await at.writeData([0x41, 0x42, 0x1A]);

    expect(transport.written, contains('AB\u001a'));
  });

  test('reopen resubscribes to the stream', () async {
    at.reopen();

    final response = at.readUntil('OK', 1);
    await Future<void>.delayed(Duration.zero);
    transport.emit('OK');

    expect(await response, 'OK');
  });
}
