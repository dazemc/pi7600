const _sensitiveAtPrefixes = <String>[
  'AT+CPIN',
  'AT+CLCK',
  'AT+CPWD',
  'AT+CGAUTH',
  'AT+CSIM',
  'AT+CRSM',
];

/// Whether an AT command can contain a PIN, password, or SIM credential.
bool isSensitiveAtCommand(String command) {
  final upper = command.trim().toUpperCase();
  return _sensitiveAtPrefixes.any(upper.startsWith);
}

/// Redact the payload of sensitive AT commands for audit logs.
///
/// Query forms such as `AT+CPIN?` have no payload and are left intact.
String redactAtCommand(String command) {
  if (!isSensitiveAtCommand(command)) return command;
  final separator = command.indexOf('=');
  if (separator < 0) return command;
  return '${command.substring(0, separator)}=***';
}

/// Keep only success/failure for sensitive commands; bound other responses.
String auditAtResponse(
  String command,
  String response, {
  int maxLength = 500,
}) {
  if (isSensitiveAtCommand(command)) {
    return response.contains('ERROR') ? 'ERROR' : 'OK';
  }
  return response.length > maxLength
      ? response.substring(0, maxLength)
      : response;
}
