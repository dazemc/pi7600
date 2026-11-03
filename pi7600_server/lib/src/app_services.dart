import 'dart:async';
import 'dart:developer' as developer;

import 'package:simcom_modem/simcom_modem.dart';
import 'package:pi7600_server/src/auth/auth_service.dart';
import 'package:pi7600_server/src/auth/jwt_service.dart';
import 'package:pi7600_server/src/camera/camera_capture.dart';
import 'package:pi7600_server/src/camera/recognition.dart';
import 'package:pi7600_server/src/camera/video_broadcaster.dart';
import 'package:pi7600_server/src/config/app_config.dart';
import 'package:pi7600_server/src/data/message_store.dart';
import 'package:pi7600_server/src/data/user_store.dart';
import 'package:pi7600_server/src/services/service_status.dart';
import 'package:pi7600_server/src/services/sms_service.dart';
import 'package:pi7600_server/src/services/status_service.dart';
import 'package:serverpod/serverpod.dart';

/// Process-wide dependencies shared by the REST and WebSocket routes.
class AppServices {
  AppServices({
    required this.config,
    required this.jwt,
    required this.at,
    required this.modem,
    required this.sms,
    required this.gps,
    required this.phone,
    required this.status,
    required this.camera,
    required this.broadcaster,
    required this.recognition,
    required this.serviceStatus,
  });

  factory AppServices.create(AppConfig config) {
    final transport = LibSerialPortTransport(
      name: config.atCom,
      baudRate: config.atBaudrate,
    );
    final at = At(
      com: config.atCom,
      baudRate: config.atBaudrate,
      transport: transport,
    );
    final modem = ModemSettings(at: at);
    final sms = Sms(modem);
    final gps = Gps(modem);
    final phone = Phone(modem);

    return AppServices(
      config: config,
      jwt: JwtService(
        privateKeyPath: config.jwtPrivateKeyPath,
        publicKeyPath: config.jwtPublicKeyPath,
        issuer: config.jwtIssuer,
        expireMinutes: config.jwtExpireMinutes,
      ),
      at: at,
      modem: modem,
      sms: sms,
      gps: gps,
      phone: phone,
      status: StatusService(
        modem: modem,
        gps: gps,
        pingInterface: config.pingInterface,
        pingTargets: config.pingTargets,
      ),
      camera: CameraCapture(
        candidatePaths: _cameraCandidates(config),
        width: config.cameraWidth,
        height: config.cameraHeight,
        fps: config.cameraFps,
      ),
      broadcaster: VideoBroadcaster(),
      recognition: FacialRecognition(
        detectorPath: config.faceDetectorModel,
        recognizerPath: config.faceRecognizerModel,
        embeddingsDirectory: config.faceEmbeddingsDir,
        threshold: config.faceMatchThreshold,
      ),
      serviceStatus: ServiceStatusCubit(),
    );
  }

  final AppConfig config;
  final JwtService jwt;
  final At at;
  final ModemSettings modem;
  final Sms sms;
  final Gps gps;
  final Phone phone;
  final StatusService status;
  final CameraCapture camera;
  final VideoBroadcaster broadcaster;
  final FacialRecognition recognition;
  final ServiceStatusCubit serviceStatus;

  final Completer<void> _ready = Completer<void>();
  bool _started = false;
  bool _stopped = false;

  /// Completes once startup has finished, successfully or not.
  Future<void> get ready => _ready.future;

  bool get isReady => _ready.isCompleted;

  bool get cameraReady => camera.isRunning;

  /// Create request-scoped stores and services.
  AuthService authService(Session session) {
    return AuthService(jwt: jwt, users: SessionUserStore(session));
  }

  SmsService smsService(Session session) {
    return SmsService(sms: sms, store: SessionMessageStore(session));
  }

  /// Initialize the modem, camera, and recognition backends.
  ///
  /// Failures are logged and reflected in [serviceStatus] instead of aborting
  /// the process. This keeps `/healthz` and `/readyz` usable on a host without
  /// hardware, which is also what the hardware-free test suite needs.
  Future<void> start() async {
    if (_started) return ready;
    _started = true;

    try {
      await modem.initialize();
      serviceStatus.modemStarted();
      developer.log(
        'Modem initialized on ${config.atCom}',
        name: 'pi7600.modem',
      );
    } on Object catch (error, stackTrace) {
      serviceStatus.modemFailed(error);
      developer.log(
        'Modem unavailable: $error',
        name: 'pi7600.modem',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await camera.start();
      broadcaster.attach(camera.frames);
      serviceStatus.cameraStarted();
      developer.log(
        'Camera streaming from ${camera.devicePath} '
        '(${camera.frameWidth}x${camera.frameHeight} ${camera.frameFormat})',
        name: 'pi7600.camera',
      );
    } on Object catch (error, stackTrace) {
      serviceStatus.cameraFailed(error);
      developer.log(
        'Camera unavailable: $error',
        name: 'pi7600.camera',
        error: error,
        stackTrace: stackTrace,
      );
    }

    try {
      await recognition.initialize();
      if (recognition.enabled) {
        serviceStatus.recognitionStarted();
      } else {
        serviceStatus.recognitionFailed('models or backend unavailable');
      }
    } on Object catch (error) {
      serviceStatus.recognitionFailed(error);
      developer.log(
        'Facial recognition unavailable: $error',
        name: 'pi7600.recognition',
      );
    }

    serviceStatus.ready();
    developer.log('Pi7600 services ready', name: 'pi7600');
    if (!_ready.isCompleted) _ready.complete();
  }

  /// Release the camera, modem, and WebSocket clients.
  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    try {
      await broadcaster.stop();
      await camera.stop();
    } on Object catch (error) {
      developer.log('Error stopping camera: $error', name: 'pi7600.camera');
    }
    try {
      await modem.close();
    } on Object catch (error) {
      developer.log('Error closing modem: $error', name: 'pi7600.modem');
    }
    serviceStatus.stopped();
    await serviceStatus.close();
    if (!_ready.isCompleted) _ready.complete();
  }

  static List<String> _cameraCandidates(AppConfig config) {
    final explicit = config.cameraDevice;
    if (explicit != null && explicit.isNotEmpty) return [explicit];

    final candidates = <String>[];
    if (config.cameraIndex >= 0) {
      candidates.add('/dev/video${config.cameraIndex}');
    }
    for (var index = 0; index < 32; index++) {
      final path = '/dev/video$index';
      if (candidates.contains(path)) continue;
      candidates.add(path);
    }
    return candidates;
  }
}
