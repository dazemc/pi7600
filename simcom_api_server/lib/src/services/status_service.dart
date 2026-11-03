import 'dart:async';
import 'dart:io';

import 'package:simcom_modem/simcom_modem.dart';

final _lineBreak = RegExp(r'\r\n|[\n\v\f\r\x1c-\x1e\x85\u2028\u2029]');

/// Split a modem response into lines like Python's `str.splitlines()`.
///
/// Modem responses separate lines with `\r\r\n`, so splitting on `\n` alone
/// leaves empty entries and shifts the response indices.
List<String> splitResponseLines(String response) {
  if (response.isEmpty) return const [];
  final lines = response.split(_lineBreak);
  if (_lineBreak.hasMatch(response[response.length - 1])) {
    lines.removeLast();
  }
  return lines;
}

class StatusResult {
  const StatusResult({
    required this.at,
    required this.cnum,
    required this.csq,
    required this.cpin,
    required this.creg,
    required this.cops,
    required this.gpsinfo,
    required this.data,
    required this.dns,
    required this.apn,
    required this.timezone,
  });

  final String at;
  final String cnum;
  final String csq;
  final String cpin;
  final String creg;
  final String cops;
  final String gpsinfo;
  final String data;
  final String dns;
  final String apn;
  final int? timezone;

  Map<String, Object?> toJson() => {
    'at': at,
    'cnum': cnum,
    'csq': csq,
    'cpin': cpin,
    'creg': creg,
    'cops': cops,
    'gpsinfo': gpsinfo,
    'data': data,
    'dns': dns,
    'apn': apn,
    'timezone': timezone,
  };
}

class InfoResult {
  const InfoResult({
    required this.hostname,
    required this.uname,
    required this.date,
    required this.arch,
  });

  final String hostname;
  final String uname;
  final String date;
  final String arch;

  Map<String, Object?> toJson() => {
    'hostname': hostname,
    'uname': uname,
    'date': date,
    'arch': arch,
  };
}

/// Modem and host status queries exposed by the REST API.
class StatusService {
  StatusService({
    required this.modem,
    required this.gps,
    this.pingInterface = 'usb0',
    this.pingTargets = const ['1.1.1.1', 'www.google.com'],
    this.modemTimeout = 3,
  });

  final ModemSettings modem;
  final Gps gps;
  final String pingInterface;
  final List<String> pingTargets;
  final int modemTimeout;

  // Hostname, kernel release, and architecture do not change during a normal
  // process lifetime. Cache them instead of spawning three processes per
  // `/info` request. The date is still read live so the API keeps its format.
  String? _hostname;
  Future<String>? _uname;
  Future<String>? _arch;

  // `/` is often polled by dashboards. A short cache avoids spawning two ping
  // processes for every request while keeping the result reasonably fresh.
  static const Duration _pingCacheTtl = Duration(seconds: 5);
  Future<bool>? _dataPing;
  Future<bool>? _dnsPing;
  DateTime? _dataPingAt;
  DateTime? _dnsPingAt;
  bool? _dataPingValue;
  bool? _dnsPingValue;

  Future<StatusResult> status() async {
    final gpsFuture = gps.getGpsPosition();
    final dataTarget = pingTargets.first;
    final dnsTarget = pingTargets.length > 1
        ? pingTargets[1]
        : pingTargets.first;
    final dataFuture = _cachedPing(dataTarget, data: true);
    final dnsFuture = _cachedPing(dnsTarget, data: false);

    final atCheck = await modem.sendAt('AT', 'OK', modemTimeout);
    final at = _atOk(atCheck) ? _responseLine(atCheck, 2) : 'ERROR';

    final cnumCheck = await modem.sendAt('AT+CNUM', '+CNUM:', modemTimeout);
    var cnum = 'ERROR';
    if (_atOk(cnumCheck)) {
      final parts = _responseLine(cnumCheck, 2).split(',');
      if (parts.length > 1) {
        cnum = parts[1].replaceAll('"', '');
      }
    }

    final csqCheck = await modem.sendAt('AT+CSQ', 'OK', modemTimeout);
    final csq = _atOk(csqCheck) ? _responseLine(csqCheck, 2) : 'ERROR';

    final cpinCheck = await modem.sendAt('AT+CPIN?', 'READY', modemTimeout);
    final cpin = _atOk(cpinCheck) ? _responseLine(cpinCheck, 2) : 'ERROR';

    final cregCheck = await modem.sendAt('AT+CREG?', 'OK', modemTimeout);
    final creg = _atOk(cregCheck) ? _responseLine(cregCheck, 2) : 'ERROR';

    final copsCheck = await modem.sendAt('AT+COPS?', 'OK', modemTimeout);
    final cops = _atOk(copsCheck) ? _responseLine(copsCheck, 2) : 'ERROR';

    final apnCheck = await modem.sendAt('AT+CGDCONT?', 'OK', modemTimeout);
    var apn = 'ERROR';
    if (_atOk(apnCheck)) {
      for (final line in splitResponseLines(apnCheck)) {
        if (!line.contains('+CGDCONT:')) continue;
        final parts = line
            .split(',')
            .map((part) => part.trim().replaceAll('"', ''))
            .toList();
        if (parts.length > 2) apn = parts[2];
        break;
      }
    }

    final gpsinfo = await gpsFuture ?? 'ERROR';
    final data = await dataFuture ? 'OK' : 'ERROR';
    final dns = await dnsFuture ? 'OK' : 'ERROR';

    return StatusResult(
      at: at,
      cnum: cnum,
      csq: csq,
      cpin: cpin,
      creg: creg,
      cops: cops,
      gpsinfo: gpsinfo,
      data: data,
      dns: dns,
      apn: apn,
      timezone: modem.timezone,
    );
  }

  Future<InfoResult> info() async {
    final hostname = _hostname ??= Platform.localHostname;
    final uname = _uname ??= _run(['uname', '-r']);
    final arch = _arch ??= _run(['arch']);
    final date = _run(['date']);

    final results = await Future.wait([uname, date, arch]);
    final unameValue = results[0].trim();
    final archValue = results[2].trim();
    // Retry on a transient command failure instead of caching the error.
    if (unameValue.startsWith('ERROR')) _uname = null;
    if (archValue.startsWith('ERROR')) _arch = null;

    return InfoResult(
      hostname: hostname.trim(),
      uname: unameValue,
      date: results[1].trim(),
      arch: archValue,
    );
  }

  static bool _atOk(String response) {
    return response.isNotEmpty && !response.contains('ERROR');
  }

  static String _responseLine(String response, int index) {
    final lines = splitResponseLines(response);
    if (lines.length <= index) return 'ERROR';
    return lines[index];
  }

  Future<bool> _cachedPing(String target, {required bool data}) {
    final now = DateTime.now();
    final cachedAt = data ? _dataPingAt : _dnsPingAt;
    final cachedValue = data ? _dataPingValue : _dnsPingValue;
    if (cachedValue != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _pingCacheTtl) {
      return Future.value(cachedValue);
    }

    final inFlight = data ? _dataPing : _dnsPing;
    if (inFlight != null) return inFlight;

    final future = _ping(pingInterface, target).then((value) {
      if (data) {
        _dataPingValue = value;
        _dataPingAt = DateTime.now();
        _dataPing = null;
      } else {
        _dnsPingValue = value;
        _dnsPingAt = DateTime.now();
        _dnsPing = null;
      }
      return value;
    });
    if (data) {
      _dataPing = future;
    } else {
      _dnsPing = future;
    }
    return future;
  }

  static Future<bool> _ping(String interface, String target) async {
    try {
      final result = await Process.run(
        'ping',
        ['-I', interface, '-c', '1', '-W', '2', target],
      ).timeout(const Duration(seconds: 5));
      return result.exitCode == 0;
    } on Object {
      return false;
    }
  }

  static Future<String> _run(List<String> command) async {
    try {
      final result = await Process.run(
        command.first,
        command.sublist(1),
      ).timeout(const Duration(seconds: 5));
      final stdout = result.stdout.toString();
      if (stdout.isNotEmpty) return stdout;
      return result.stderr.toString();
    } on TimeoutException {
      return 'ERROR: subprocess timed out';
    } on Object catch (error) {
      return 'ERROR: $error';
    }
  }
}
