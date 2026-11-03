import 'package:pi7600_server/src/modem/at.dart';
import 'package:pi7600_server/src/modem/settings.dart';

/// Place and manage voice calls.
class Phone {
  Phone(this.settings);

  final ModemSettings settings;

  static const int phoneTimeout = 1;

  Future<bool> hangupCall() async {
    final response = await settings.sendAt('AT+CHUP', 'OK', phoneTimeout);
    return !At.isError(response);
  }

  Future<String?> activeCalls() async {
    final response = await settings.sendAt('AT+CLCC', 'OK', phoneTimeout);
    if (At.isError(response)) return null;
    return response;
  }

  Future<bool> call(String contactNumber, {int retry = 0}) async {
    var attempt = 1;
    while (true) {
      final response = await settings.sendAt(
        'ATD$contactNumber;',
        'OK',
        phoneTimeout,
      );
      if (!At.isError(response)) return true;
      if (retry == 0 || attempt >= retry) return false;
      attempt++;
    }
  }
}
