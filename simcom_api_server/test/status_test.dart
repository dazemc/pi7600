import 'package:simcom_api_server/src/services/status_service.dart';
import 'package:test/test.dart';

void main() {
  group('splitResponseLines', () {
    test('handles the modem CR CR LF line endings', () {
      expect(splitResponseLines('AT\r\r\nOK\r\n'), ['AT', '', 'OK']);
    });

    test('keeps response payloads at the same index as Python splitlines', () {
      final lines = splitResponseLines(
        'AT+CSQ\r\r\n+CSQ: 99,99\r\n\r\nOK\r\n',
      );

      expect(lines[2], '+CSQ: 99,99');
    });

    test('drops the trailing empty line and handles empty input', () {
      expect(splitResponseLines(''), isEmpty);
      expect(splitResponseLines('a\r\nb\n'), ['a', 'b']);
    });
  });

  group('responseValue', () {
    test('finds values even when the modem adds blank lines', () {
      expect(
        responseValue('AT\r\r\n\r\nOK\r\n', '+CSQ:'),
        'ERROR',
      );
      expect(
        responseValue('AT+CSQ\r\r\n\r\n+CSQ: 18,99\r\nOK\r\n', '+CSQ:'),
        '+CSQ: 18,99',
      );
      expect(
        responseValue('AT+CREG?\r\r\n\r\n+CREG: 0,2\r\nOK\r\n', '+CREG:'),
        '+CREG: 0,2',
      );
      expect(
        responseValue('AT+COPS?\r\r\n\r\n+COPS: 0\r\nOK\r\n', '+COPS:'),
        '+COPS: 0',
      );
    });

    test('returns ERROR when the value line is absent', () {
      expect(responseValue('OK\r\n', '+CSQ:'), 'ERROR');
    });
  });
}
