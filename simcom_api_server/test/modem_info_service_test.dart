import 'package:simcom_modem/simcom_modem.dart';
import 'package:simcom_modem/testing.dart';
import 'package:simcom_api_server/src/services/modem_info_service.dart';
import 'package:test/test.dart';

void main() {
  late FakeTransport transport;
  late At at;
  late ModemInfoService service;

  setUp(() {
    transport = FakeTransport();
    transport.onCommand = (command, fake) {
      final response = switch (command.trim()) {
        'AT+CGMI' => 'SIMCOM_Ltd',
        'AT+CGMM' => 'SIMCOM_SIM7600G-H',
        'AT+CGMR' => 'LE20B03SIM7600G22',
        'AT+CGSN' => '123456789012345',
        'AT+CIMI' => '310260123456789',
        'AT+CCID' => '8901260123456789012',
        'AT+CNUM' => '+CNUM: "","15642358964",129',
        'AT+CPIN?' => '+CPIN: READY',
        'AT+CSQ' => '+CSQ: 18,99',
        'AT+CREG?' => '+CREG: 0,1',
        'AT+CGREG?' => '+CGREG: 0,1',
        'AT+COPS?' => '+COPS: 0,0,"Tello",7',
        'AT+CGATT?' => '+CGATT: 1',
        'AT+CFUN?' => '+CFUN: 1',
        'AT+CPAS' => '+CPAS: 0',
        'AT+CPMS?' => '+CPMS: "SM",0,30,"SM",0,30,"SM",0,30',
        'AT+CCLK?' => '+CCLK: "26/11/03,12:34:56-32"',
        'AT+CGPS?' => '+CGPS: 1,1',
        'AT+CGPSINFO' => '+CGPSINFO: 1234.5678,N,12345.6789,W',
        _ => 'OK',
      };
      fake.emit('\r\n$response\r\n\r\nOK\r\n');
    };
    at = At(
      com: '/dev/fake',
      baudRate: 115200,
      transport: transport,
    )..open();
    service = ModemInfoService(modem: ModemSettings(at: at));
  });

  tearDown(() async {
    at.closeSerial();
    await transport.dispose();
  });

  test('reads the full modem catalog and parses core values', () async {
    final report = await service.read();
    final raw = report['raw'] as Map<String, String>;
    final parsed = report['parsed'] as Map<String, Object?>;
    final sections = report['sections'] as Map<String, Map<String, String>>;

    expect(raw, hasLength(modemQueries.length));
    expect(raw.keys, containsAll(['ATI', 'AT&V', 'AT+COPS?', 'AT+CGPSINFO']));
    expect(sections.keys, containsAll(['identity', 'network', 'sms', 'gps']));
    expect(parsed['manufacturer'], 'SIMCOM_Ltd');
    expect(parsed['model'], 'SIMCOM_SIM7600G-H');
    expect(parsed['firmware'], 'LE20B03SIM7600G22');
    expect(parsed['imei'], '123456789012345');
    expect(parsed['imsi'], '310260123456789');
    expect(parsed['iccid'], '8901260123456789012');
    expect(parsed['number'], '15642358964');
    expect(parsed['pin'], 'READY');
    expect(parsed['activity'], '0');
    expect(parsed['functionality'], '1');
    expect(parsed['signal_rssi'], 18);
    expect(parsed['signal_ber'], 99);
    expect(parsed['registration'], '+CREG: 0,1');
    expect(parsed['operator'], '+COPS: 0,0,"Tello",7');
    expect(parsed['packet_attached'], '1');
    expect(parsed['gps_enabled'], isTrue);
    expect(parsed['gps_info'], contains('+CGPSINFO:'));
  });

  test('keeps unsupported command errors in the raw report', () async {
    transport.onCommand = (command, fake) {
      if (command.trim() == 'AT+CPINR?') {
        fake.emit('\r\nERROR\r\n');
        return;
      }
      fake.emit('\r\nOK\r\n');
    };

    final report = await service.read();
    final raw = report['raw'] as Map<String, String>;

    expect(raw['AT+CPINR?'], contains('ERROR'));
  });
}
