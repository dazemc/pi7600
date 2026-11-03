import 'dart:developer' as developer;

enum AppLogLevel { debug, info, warning, error }

/// Small log-level filter for the service.
///
/// `SIMCOM_API_LOG_LEVEL` is read into [AppConfig.logLevel] and applied at startup.
/// Access logs are emitted at [AppLogLevel.info] and WebSocket message logs at
/// [AppLogLevel.debug], so production can run at `warn` or `error` without
/// losing audit-relevant failures.
abstract final class AppLog {
  static AppLogLevel level = AppLogLevel.info;

  static void configure(String value) {
    level = switch (value.trim().toLowerCase()) {
      'debug' => AppLogLevel.debug,
      'warn' || 'warning' => AppLogLevel.warning,
      'error' || 'critical' => AppLogLevel.error,
      _ => AppLogLevel.info,
    };
  }

  static bool enabled(AppLogLevel messageLevel) {
    return messageLevel.index >= level.index;
  }

  static void debug(String message, {String name = 'simcom_api'}) {
    _log(message, AppLogLevel.debug, name);
  }

  static void info(String message, {String name = 'simcom_api'}) {
    _log(message, AppLogLevel.info, name);
  }

  /// Audit events are not filtered by the application log level.
  static void audit(String message, {String name = 'simcom_api.audit'}) {
    developer.log(message, name: name, level: 1000);
  }

  static void warning(
    String message, {
    String name = 'simcom_api',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      AppLogLevel.warning,
      name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String message, {
    String name = 'simcom_api',
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      message,
      AppLogLevel.error,
      name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _log(
    String message,
    AppLogLevel messageLevel,
    String name, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled(messageLevel)) return;
    developer.log(
      message,
      name: name,
      level: _developerLevel(messageLevel),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static int _developerLevel(AppLogLevel level) {
    return switch (level) {
      AppLogLevel.debug => 500,
      AppLogLevel.info => 800,
      AppLogLevel.warning => 900,
      AppLogLevel.error => 1000,
    };
  }
}
