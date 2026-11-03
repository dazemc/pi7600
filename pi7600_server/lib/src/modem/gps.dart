import 'dart:async';

import 'package:pi7600_server/src/modem/at.dart';
import 'package:pi7600_server/src/modem/settings.dart';

/// Query and manage the modem GPS session.
class Gps {
  Gps(this.settings);

  final ModemSettings settings;

  static const int timeout = 3;
  static const int gpsTimeout = 1;

  bool isRunning = false;
  String location = '';

  Future<bool> sessionCheck() async {
    final check = await settings.sendAt('AT+CGPS?', '+CGPS', timeout);
    isRunning = !At.isError(check) && check.contains('+CGPS: 1,1');
    return isRunning;
  }

  Future<bool> gpsSession(bool start) async {
    await sessionCheck();
    if (start) {
      if (isRunning) return true;
      await settings.sendAt('AT+CGPS=0,1', 'OK', gpsTimeout);
      final response = await settings.sendAt('AT+CGPS=1,1', 'OK', gpsTimeout);
      if (At.isError(response)) return false;
      await Future<void>.delayed(const Duration(seconds: 2));
      isRunning = true;
      return true;
    }

    final response = await settings.sendAt('AT+CGPS=0,1', 'OK', gpsTimeout);
    if (At.isError(response)) return false;
    isRunning = false;
    return true;
  }

  /// Return the raw `+CGPSINFO` response, or `null` on failure.
  Future<String?> getGpsPosition() async {
    if (!await sessionCheck()) {
      if (!await gpsSession(true)) return null;
    }

    final answer = await settings.sendAt(
      'AT+CGPSINFO',
      '+CGPSINFO: ',
      gpsTimeout,
    );
    if (At.isError(answer)) {
      await gpsSession(false);
      return null;
    }
    if (answer.contains(',,,,,,')) {
      return 'GPS is active but no signal was found';
    }
    return answer;
  }
}
