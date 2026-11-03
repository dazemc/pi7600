import 'package:simcom_modem/simcom_modem.dart';

/// One AT query in the modem diagnostics report.
class ModemQuery {
  const ModemQuery(
    this.section,
    this.command, {
    this.timeoutSeconds = 2,
  });

  final String section;
  final String command;
  final int timeoutSeconds;
}

const modemQueries = <ModemQuery>[
  ModemQuery('identity', 'ATI'),
  ModemQuery('identity', 'AT+CGMI'),
  ModemQuery('identity', 'AT+CGMM'),
  ModemQuery('identity', 'AT+CGMR'),
  ModemQuery('identity', 'AT+CGSN'),
  ModemQuery('identity', 'AT+CIMI'),
  ModemQuery('identity', 'AT+CCID'),
  ModemQuery('identity', 'AT+CNUM'),
  ModemQuery('sim', 'AT+CPIN?'),
  ModemQuery('sim', 'AT+CPINR?'),
  ModemQuery('sim', 'AT+CPAS'),
  ModemQuery('sim', 'AT+CFUN?'),
  ModemQuery('sim', 'AT+CPBS?'),
  ModemQuery('sim', 'AT+CPMS?'),
  ModemQuery('network', 'AT+CSQ'),
  ModemQuery('network', 'AT+CESQ'),
  ModemQuery('network', 'AT+CREG?'),
  ModemQuery('network', 'AT+CGREG?'),
  ModemQuery('network', 'AT+CEREG?'),
  ModemQuery('network', 'AT+COPS?'),
  ModemQuery('network', 'AT+CGATT?'),
  ModemQuery('network', 'AT+CPSI?'),
  ModemQuery('data', 'AT+CGACT?'),
  ModemQuery('data', 'AT+CGPADDR'),
  ModemQuery('data', 'AT+CGCONTRDP', timeoutSeconds: 3),
  ModemQuery('data', 'AT+CGDCONT?'),
  ModemQuery('sms', 'AT+CMGF?'),
  ModemQuery('sms', 'AT+CNMI?'),
  ModemQuery('sms', 'AT+CSMP?'),
  ModemQuery('sms', 'AT+CSCA?'),
  ModemQuery('sms', 'AT+CSDH?'),
  ModemQuery('sms', 'AT+CSMS?'),
  ModemQuery('sms', 'AT+CSCS?'),
  ModemQuery('audio', 'AT+CMUT?'),
  ModemQuery('audio', 'AT+CLVL?'),
  ModemQuery('audio', 'AT+CSDVC?'),
  ModemQuery('settings', 'AT&V', timeoutSeconds: 5),
  ModemQuery('settings', 'AT+CMEE?'),
  ModemQuery('settings', 'AT+CRC?'),
  ModemQuery('settings', 'AT+CLIP?'),
  ModemQuery('settings', 'AT+CLIR?'),
  ModemQuery('settings', 'AT+COLP?'),
  ModemQuery('settings', 'AT+CCWA?'),
  ModemQuery('settings', 'AT+CUSD?'),
  ModemQuery('settings', 'AT+CTZU?'),
  ModemQuery('settings', 'AT+CTZR?'),
  ModemQuery('settings', 'AT+CLTS?'),
  ModemQuery('settings', 'AT+CCLK?'),
  ModemQuery('power', 'AT+CBC'),
  ModemQuery('power', 'AT+CPMUTEMP?'),
  ModemQuery('gps', 'AT+CGPS?'),
  ModemQuery('gps', 'AT+CGPSINFO', timeoutSeconds: 3),
  ModemQuery('gps', 'AT+CGPSSTATUS?'),
  ModemQuery('gps', 'AT+CGPSAUTO?'),
  ModemQuery('phone', 'AT+CLCC'),
];

/// Read the modem's complete settings and status catalog.
class ModemInfoService {
  ModemInfoService({required this.modem});

  final ModemSettings modem;

  Future<Map<String, Object?>> read() async {
    final raw = <String, String>{};
    final sections = <String, Map<String, String>>{};

    for (final query in modemQueries) {
      final response = await modem.sendRaw(
        query.command,
        timeoutSeconds: query.timeoutSeconds,
      );
      raw[query.command] = response;
      sections.putIfAbsent(query.section, () => {})[query.command] = response;
    }

    return {
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'parsed': _parse(raw),
      'sections': sections,
      'raw': raw,
    };
  }

  Map<String, Object?> _parse(Map<String, String> raw) {
    final csq = _line(raw['AT+CSQ'], '+CSQ:');
    final csqParts = csq?.split(':').skip(1).join(':').trim().split(',');
    final cops = _line(raw['AT+COPS?'], '+COPS:');
    final creg = _line(raw['AT+CREG?'], '+CREG:');
    final cgreg = _line(raw['AT+CGREG?'], '+CGREG:');
    final cereg = _line(raw['AT+CEREG?'], '+CEREG:');
    final cpin = _line(raw['AT+CPIN?'], '+CPIN:');
    final cfun = _line(raw['AT+CFUN?'], '+CFUN:');
    final cnum = _line(raw['AT+CNUM'], '+CNUM:');
    final cclk = _line(raw['AT+CCLK?'], '+CCLK:');
    final cgatt = _line(raw['AT+CGATT?'], '+CGATT:');
    final cpas = _line(raw['AT+CPAS'], '+CPAS:');
    final cpsms = _line(raw['AT+CPMS?'], '+CPMS:');
    final cgps = _line(raw['AT+CGPS?'], '+CGPS:');

    return {
      'manufacturer': _payload(raw['AT+CGMI']),
      'model': _payload(raw['AT+CGMM']),
      'firmware': _stripPrefix(_payload(raw['AT+CGMR']), '+CGMR:'),
      'imei': _digits(_payload(raw['AT+CGSN']), length: 15),
      'imsi': _digits(_payload(raw['AT+CIMI']), length: null),
      'iccid': _digits(_payload(raw['AT+CCID']), length: null),
      'number': _cnumNumber(cnum),
      'pin': _afterColon(cpin),
      'activity': _afterColon(cpas),
      'functionality': _afterColon(cfun),
      'sms_storage': _afterColon(cpsms),
      'signal_rssi': csqParts != null && csqParts.length > 1
          ? int.tryParse(csqParts[0].trim())
          : null,
      'signal_ber': csqParts != null && csqParts.length > 1
          ? int.tryParse(csqParts[1].trim())
          : null,
      'registration': creg,
      'gprs_registration': cgreg,
      'eps_registration': cereg,
      'operator': cops,
      'packet_attached': _afterColon(cgatt),
      'clock': _quoted(cclk),
      'gps_enabled': cgps?.contains('+CGPS: 1'),
      'gps_info': _line(raw['AT+CGPSINFO'], '+CGPSINFO:'),
      'active_calls': raw['AT+CLCC']?.contains('+CLCC:') == true,
      'config': raw['AT&V'],
    };
  }

  static String? _line(String? response, String prefix) {
    if (response == null) return null;
    for (final line in response.split(RegExp(r'\r\n|\n'))) {
      final trimmed = line.trim();
      if (trimmed.startsWith(prefix)) return trimmed;
    }
    return null;
  }

  static String? _payload(String? response) {
    if (response == null) return null;
    for (final line in response.split(RegExp(r'\r\n|\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed == 'OK' ||
          trimmed == 'ERROR' ||
          trimmed.startsWith('AT')) {
        continue;
      }
      return trimmed;
    }
    return null;
  }

  static String? _digits(String? value, {required int? length}) {
    if (value == null) return null;
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    if (length != null && digits.length < length) return null;
    return digits;
  }

  static String? _stripPrefix(String? value, String prefix) {
    if (value == null) return null;
    return value.startsWith(prefix)
        ? value.substring(prefix.length).trim()
        : value;
  }

  static String? _cnumNumber(String? line) {
    if (line == null) return null;
    final parts = line.split(',');
    if (parts.length < 2) return null;
    final number = parts[1].replaceAll('"', '').trim();
    return number.isEmpty ? null : number;
  }

  static String? _afterColon(String? line) {
    return line?.split(':').skip(1).join(':').trim();
  }

  static String? _quoted(String? value) {
    if (value == null) return null;
    final start = value.indexOf('"');
    if (start < 0) return null;
    final end = value.indexOf('"', start + 1);
    if (end <= start) return null;
    return value.substring(start + 1, end);
  }
}
