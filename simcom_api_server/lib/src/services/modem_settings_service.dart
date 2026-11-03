import 'package:simcom_modem/simcom_modem.dart';

class ModemSettingException implements Exception {
  ModemSettingException(this.message);

  final String message;
}

class ModemSettingResult {
  const ModemSettingResult({
    required this.command,
    required this.response,
    required this.success,
  });

  final String command;
  final String response;
  final bool success;

  Map<String, Object?> toJson() => {
    'command': command,
    'success': success,
    'response': response,
  };
}

/// Apply settings commands to the modem.
///
/// The caller supplies a map of command base (for example `AT+CMGF`) to value
/// (for example `1`). The service validates the command shape and executes the
/// resulting `AT+...=...` commands in insertion order.
class ModemSettingsService {
  ModemSettingsService({required this.modem});

  final ModemSettings modem;

  static final _basePattern = RegExp(
    r'^AT(\+[A-Z0-9]+|&[A-Z]|S\d{1,3})$',
  );

  Future<List<ModemSettingResult>> apply(
    Map<String, String> settings, {
    bool save = false,
    int timeoutSeconds = 10,
  }) async {
    final results = <ModemSettingResult>[];
    final seen = <String>{};

    for (final entry in settings.entries) {
      final base = entry.key.trim().toUpperCase();
      if (!_basePattern.hasMatch(base)) {
        throw ModemSettingException('Invalid setting command: ${entry.key}');
      }
      if (!seen.add(base)) {
        throw ModemSettingException('Duplicate setting command: $base');
      }

      final value = entry.value;
      if (value.length > 200) {
        throw ModemSettingException('Value for $base is too long');
      }
      if (value.contains('\r') || value.contains('\n') || value.contains(';')) {
        throw ModemSettingException('Invalid value for $base');
      }

      final command = value.isEmpty ? base : '$base=$value';
      final response = await modem.sendRaw(
        command,
        timeoutSeconds: timeoutSeconds,
      );
      results.add(
        ModemSettingResult(
          command: command,
          response: response,
          success: !At.isError(response),
        ),
      );
    }

    if (save) {
      final response = await modem.sendRaw('AT&W', timeoutSeconds: 10);
      results.add(
        ModemSettingResult(
          command: 'AT&W',
          response: response,
          success: !At.isError(response),
        ),
      );
    }

    return results;
  }
}
