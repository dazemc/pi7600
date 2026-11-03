import 'dart:io';

/// Application configuration for the Simcom API service.
///
/// All settings are read from `SIMCOM_API_*` environment variables. For local
/// development a `.env` file in the working directory is also read; real
/// environment variables always take precedence.
class AppConfig {
  AppConfig({
    required this.atCom,
    required this.atBaudrate,
    required this.atTimeout,
    required this.cameraIndex,
    required this.cameraDevice,
    required this.cameraFps,
    required this.cameraWidth,
    required this.cameraHeight,
    required this.faceDetectorModel,
    required this.faceRecognizerModel,
    required this.faceEmbeddingsDir,
    required this.faceMatchThreshold,
    required this.jwtPrivateKeyPath,
    required this.jwtPublicKeyPath,
    required this.jwtIssuer,
    required this.jwtExpireMinutes,
    required this.jwtRefreshDays,
    required this.websocketAuthTimeout,
    required this.loginMaxAttempts,
    required this.loginWindow,
    required this.loginBlockDuration,
    required this.auditRetentionDays,
    required this.logLevel,
    required this.pingInterface,
    required this.pingTargets,
    required this.docsEnabled,
  });

  final String atCom;
  final int atBaudrate;
  final int atTimeout;
  final int cameraIndex;

  /// Optional explicit V4L2 device path, for example `/dev/video0`.
  final String? cameraDevice;
  final int cameraFps;
  final int cameraWidth;
  final int cameraHeight;
  final String faceDetectorModel;
  final String faceRecognizerModel;
  final String faceEmbeddingsDir;
  final double faceMatchThreshold;
  final String jwtPrivateKeyPath;
  final String jwtPublicKeyPath;
  final String jwtIssuer;
  final int jwtExpireMinutes;
  final int jwtRefreshDays;
  final double websocketAuthTimeout;

  /// Failed logins allowed per username or client address inside
  /// [loginWindow] before that key is blocked for [loginBlockDuration].
  final int loginMaxAttempts;
  final Duration loginWindow;
  final Duration loginBlockDuration;

  /// How long persistent audit events are retained.
  final int auditRetentionDays;
  final String logLevel;
  final String pingInterface;
  final List<String> pingTargets;

  /// Whether `/docs` and `/openapi.json` are served.
  final bool docsEnabled;

  static AppConfig fromEnvironment([Map<String, String>? environment]) {
    final env = _loadEnvironment(environment ?? Platform.environment);

    String string(String key, String fallback) =>
        (env['SIMCOM_API_$key'] ?? '').trim().isNotEmpty
        ? env['SIMCOM_API_$key']!.trim()
        : fallback;

    int integer(String key, int fallback) =>
        int.tryParse(string(key, '$fallback')) ?? fallback;

    double decimal(String key, double fallback) =>
        double.tryParse(string(key, '$fallback')) ?? fallback;

    bool boolean(String key, bool fallback) {
      final value = string(key, '').toLowerCase();
      if (value.isEmpty) return fallback;
      return value == '1' || value == 'true' || value == 'yes' || value == 'on';
    }

    final targets = string('PING_TARGETS', '1.1.1.1,www.google.com')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    return AppConfig(
      atCom: string('AT_COM', '/dev/ttyUSB2'),
      atBaudrate: integer('AT_BAUDRATE', 115200),
      atTimeout: integer('AT_TIMEOUT', 10),
      cameraIndex: integer('CAMERA_INDEX', -1),
      cameraDevice: _nullIfEmpty(env['SIMCOM_API_CAMERA_DEVICE']),
      cameraFps: integer('CAMERA_FPS', 15),
      cameraWidth: integer('CAMERA_WIDTH', 640),
      cameraHeight: integer('CAMERA_HEIGHT', 480),
      faceDetectorModel: string(
        'FACE_DETECTOR_MODEL',
        './ml/face_detection_yunet_2023mar_int8bq.onnx',
      ),
      faceRecognizerModel: string(
        'FACE_RECOGNIZER_MODEL',
        './ml/face_recognition_sface_2021dec.onnx',
      ),
      faceEmbeddingsDir: string('FACE_EMBEDDINGS_DIR', './data/embeddings'),
      faceMatchThreshold: decimal('FACE_MATCH_THRESHOLD', 0.363),
      jwtPrivateKeyPath: string('JWT_PRIVATE_KEY_PATH', '.keys/private.pem'),
      jwtPublicKeyPath: string('JWT_PUBLIC_KEY_PATH', '.keys/public.pem'),
      jwtIssuer: string('JWT_ISSUER', 'pi.daazed.dev'),
      jwtExpireMinutes: integer('JWT_EXPIRE_MINUTES', 30),
      jwtRefreshDays: integer(
        'JWT_REFRESH_DAYS',
        7,
      ).clamp(1, 365).toInt(),
      websocketAuthTimeout: decimal('WEBSOCKET_AUTH_TIMEOUT', 5.0),
      loginMaxAttempts: integer(
        'LOGIN_MAX_ATTEMPTS',
        5,
      ).clamp(1, 100).toInt(),
      loginWindow: Duration(
        seconds: integer('LOGIN_WINDOW_SECONDS', 300).clamp(1, 86400).toInt(),
      ),
      loginBlockDuration: Duration(
        seconds: integer('LOGIN_BLOCK_SECONDS', 300).clamp(1, 86400).toInt(),
      ),
      auditRetentionDays: integer(
        'AUDIT_RETENTION_DAYS',
        90,
      ).clamp(1, 3650).toInt(),
      logLevel: string('LOG_LEVEL', 'INFO'),
      pingInterface: string('PING_INTERFACE', 'usb0'),
      pingTargets: targets.isEmpty ? const ['1.1.1.1'] : targets,
      docsEnabled: boolean('DOCS_ENABLED', true),
    );
  }

  static String? _nullIfEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static Map<String, String> _loadEnvironment(Map<String, String> environment) {
    final merged = <String, String>{};
    try {
      final file = File('.env');
      if (file.existsSync()) {
        for (final rawLine in file.readAsLinesSync()) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final separator = line.indexOf('=');
          if (separator <= 0) continue;
          final key = line.substring(0, separator).trim();
          var value = line.substring(separator + 1).trim();
          if (value.length >= 2 &&
              ((value.startsWith('"') && value.endsWith('"')) ||
                  (value.startsWith("'") && value.endsWith("'")))) {
            value = value.substring(1, value.length - 1);
          }
          merged[key] = value;
        }
      }
    } on FileSystemException {
      // A missing or unreadable .env is not an error.
    }
    merged.addAll(environment);
    return merged;
  }
}
