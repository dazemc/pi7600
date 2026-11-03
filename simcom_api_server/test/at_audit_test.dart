import 'package:simcom_api_server/src/web/at_audit.dart';
import 'package:test/test.dart';

void main() {
  test('redacts sensitive AT payloads', () {
    expect(redactAtCommand('AT+CPIN="1234"'), 'AT+CPIN=***');
    expect(redactAtCommand('AT+CLCK="SC",1,"1234"'), 'AT+CLCK=***');
    expect(redactAtCommand('AT+CPWD="SC","old","new"'), 'AT+CPWD=***');
    expect(redactAtCommand('AT+CGAUTH=1,2,"user","pass"'), 'AT+CGAUTH=***');
    expect(redactAtCommand('AT+CSIM=00A40000'), 'AT+CSIM=***');
    expect(redactAtCommand('AT+CRSM=192,28421'), 'AT+CRSM=***');
  });

  test('leaves queries and ordinary commands intact', () {
    expect(redactAtCommand('AT+CPIN?'), 'AT+CPIN?');
    expect(redactAtCommand('AT+CLCK?'), 'AT+CLCK?');
    expect(redactAtCommand('AT+CSQ'), 'AT+CSQ');
    expect(redactAtCommand('ATI'), 'ATI');
  });

  test('keeps only status for sensitive responses', () {
    expect(auditAtResponse('AT+CPIN="1234"', 'OK'), 'OK');
    expect(
      auditAtResponse('AT+CPIN="1234"', '+CME ERROR: 16'),
      'ERROR',
    );
  });

  test('bounds ordinary response previews', () {
    final preview = auditAtResponse('AT+CSQ', 'x' * 1000);

    expect(preview.length, 500);
  });
}
