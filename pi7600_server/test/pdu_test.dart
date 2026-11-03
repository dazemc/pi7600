import 'package:pi7600_server/src/modem/pdu.dart';
import 'package:test/test.dart';

void main() {
  group('decodeDeliverPdu', () {
    test('decodes a GSM 7-bit delivery report', () {
      final decoded = decodeDeliverPdu(
        '07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07',
      );

      expect(decoded.sender, '+31641600986');
      expect(decoded.content, 'How are you?');
      expect(decoded.partialKey, isNull);
      expect(decoded.timestamp, DateTime.utc(2002, 8, 26, 19, 37, 41));
    });

    test('rejects a submit PDU', () {
      expect(
        () => decodeDeliverPdu(
          '0011000B911346610089F60000AA0CC8F71D14969741F977FD07',
        ),
        throwsFormatException,
      );
    });
  });

  group('SmsParser.parsePdu', () {
    test('parses an AT+CMGL response', () {
      final parser = SmsParser(timezone: 0);
      final messages = parser.parsePdu(
        '+CMGL: 4,1,,24\r\n'
        '07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07\r\n'
        'OK\r\n',
      );

      expect(messages, hasLength(1));
      final message = messages.single;
      expect(message.messageIndex, '4');
      expect(message.messageType, 'REC READ');
      expect(message.messageOriginatingAddress, '+31641600986');
      expect(message.messageContents, 'How are you?');
      expect(message.messageDate, '2002-08-26');
      expect(message.messageTime, '19:37:41');
      expect(message.isPartial, isFalse);
      expect(message.inSimMemory, isTrue);
    });

    test('applies the modem timezone offset', () {
      final parser = SmsParser(timezone: 2);
      final messages = parser.parsePdu(
        '+CMGL: 1,0,,24\r\n'
        '07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07\r\n',
      );

      expect(messages.single.messageTime, '21:37:41');
    });

    test('converts the service-centre offset to UTC first', () {
      // Same PDU as above, but with a -07:00 service-centre offset (0x8A).
      final parser = SmsParser(timezone: 0);
      final messages = parser.parsePdu(
        '+CMGL: 1,0,,24\r\n'
        '07911326040000F0040B911346610089F600002080629173148A0CC8F71D14969741F977FD07\r\n',
      );

      expect(messages.single.messageDate, '2002-08-27');
      expect(messages.single.messageTime, '02:37:41');
    });

    test('adds the modem timezone after the service-centre offset', () {
      final parser = SmsParser(timezone: -8);
      final messages = parser.parsePdu(
        '+CMGL: 1,0,,24\r\n'
        '07911326040000F0040B911346610089F600002080629173148A0CC8F71D14969741F977FD07\r\n',
      );

      expect(messages.single.messageDate, '2002-08-26');
      expect(messages.single.messageTime, '18:37:41');
    });

    test('skips malformed entries', () {
      final parser = SmsParser();
      final messages = parser.parsePdu(
        '+CMGL: 1,0,,24\r\nnot-a-pdu\r\n'
        '+CMGL: 2,1,,24\r\n'
        '07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07\r\n',
      );

      expect(messages, hasLength(1));
      expect(messages.single.messageIndex, '2');
    });

    test('returns nothing for an empty buffer', () {
      expect(SmsParser().parsePdu(''), isEmpty);
    });
  });

  group('SmsParser text mode', () {
    test('parses a +CMGL response', () {
      final messages = SmsParser().parseSms(
        '+CMGL: 1,"REC READ","+31641600986",,"24/01/02,03:04:05+04"\r\n'
        'Hello\r\n'
        '\r\nOK\r\n',
      );

      expect(messages, hasLength(1));
      expect(messages.single.messageContents, 'Hello');
      expect(messages.single.messageOriginatingAddress, '+31641600986');
    });
  });
}
