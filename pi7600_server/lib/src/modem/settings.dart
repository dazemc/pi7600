import 'dart:async';

import 'package:pi7600_server/src/modem/at.dart';

/// Modem-level settings and helpers.
class ModemSettings {
  ModemSettings({
    required this.at,
    this.timeoutSeconds = 3,
  });

  final At at;
  final int timeoutSeconds;

  bool? pduMode;
  DateTime? dateTime;
  int? timezone;
  bool firstRun = true;

  Future<void> initialize() async {
    at.open();
    pduMode = await getDataMode();
    await getDateTime();
    firstRun = false;
  }

  Future<void> close() => at.close();

  Future<String> sendAt(String command, String back, [int? timeout]) {
    return at.sendAt(command, back, timeout ?? timeoutSeconds);
  }

  Future<String> sendRaw(String command, {int timeoutSeconds = 10}) {
    return at.sendRaw(command, timeoutSeconds: timeoutSeconds);
  }

  bool isError(String? response) => At.isError(response);

  Future<bool> enableVerboseLogging() async {
    final response = await sendAt('AT+CMEE=2', 'OK');
    return !At.isError(response);
  }

  Future<bool> simReadyCheck() async {
    final response = await sendAt('AT+CPIN?', 'READY');
    return !At.isError(response);
  }

  Future<String?> getConfig() async {
    final response = await sendAt('AT&V', 'OK');
    if (At.isError(response)) return null;
    return response;
  }

  Future<bool> setSmsStorage(String mode) async {
    final response = await sendAt(
      'AT+CPMS="$mode","$mode","$mode"',
      'OK',
    );
    return !At.isError(response);
  }

  Future<void> setDataMode(int mode) async {
    if (mode == 1) {
      await sendAt('AT+CMGF=1', 'OK');
    } else if (mode == 0) {
      await sendAt('AT+CMGF=0', 'OK');
    }
  }

  Future<void> setEncodingMode(int mode) async {
    switch (mode) {
      case 2:
        await sendAt('AT+CSCS="UCS2"', 'OK');
      case 1:
        await sendAt('AT+CSCS="GSM"', 'OK');
      case 0:
        await sendAt('AT+CSCS="IRA"', 'OK');
    }
  }

  /// Return `true` when the modem is in PDU mode, `false` for text mode.
  Future<bool?> getDataMode() async {
    final response = await sendAt('AT+CMGF?', 'OK');
    if (At.isError(response)) return null;
    for (final line in response.split('\n')) {
      if (!line.contains('+CMGF:')) continue;
      final value = int.tryParse(line.split(':').skip(1).join(':').trim());
      if (value == null) return null;
      return value == 0;
    }
    return null;
  }

  /// Read the modem clock and timezone offset (in hours).
  Future<void> getDateTime() async {
    final response = await sendAt('AT+CCLK?', 'OK');
    if (At.isError(response)) return;
    for (final line in response.split('\n')) {
      if (!line.contains('+CCLK:')) continue;
      try {
        final quoteStart = line.indexOf('"');
        final quoteEnd = line.indexOf('"', quoteStart + 1);
        if (quoteStart < 0 || quoteEnd < 0) return;
        final raw = line.substring(quoteStart + 1, quoteEnd);
        final parts = raw.split(',');
        if (parts.length < 2) return;
        final datePart = parts[0];
        final timePart = parts[1];
        final sign = timePart[8];
        final offsetHours = int.parse(timePart.substring(9)) ~/ 4;
        timezone = sign == '+' ? offsetHours : -offsetHours;
        final formatted = '$datePart ${timePart.substring(0, 8)}';
        dateTime = _parseModemDateTime(formatted);
      } on Object {
        // Ignore malformed clock responses; the rest of the service still works.
      }
      return;
    }
  }

  static DateTime? _parseModemDateTime(String value) {
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2})$',
    ).firstMatch(value);
    if (match == null) return null;
    final year = 2000 + int.parse(match.group(1)!);
    return DateTime(
      year,
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
}
