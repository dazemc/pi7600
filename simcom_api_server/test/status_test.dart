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
}
