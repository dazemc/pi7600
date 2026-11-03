import 'dart:async';

import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_api_server/src/config/app_config.dart';
import 'package:simcom_api_server/src/util/app_log.dart';
import 'package:simcom_api_server/src/web/routes/api_routes.dart';
import 'package:simcom_api_server/src/web/routes/docs_routes.dart';
import 'package:simcom_api_server/src/web/routes/readyz.dart';
import 'package:simcom_api_server/src/web/routes/websockets.dart';
import 'package:serverpod/serverpod.dart';

/// Wire the Simcom API services and routes into a [Serverpod] instance.
void configureServer(Serverpod pod) {
  final services = AppServices.create(AppConfig.fromEnvironment());
  AppLog.configure(services.config.logLevel);

  // Startup is asynchronous because the modem, camera, and recognition
  // backends touch hardware. Routes that need them await [AppServices.ready].
  unawaited(services.start());
  pod.experimental.shutdownTasks.addTask('simcom_api', services.stop);

  final web = pod.webServer;

  web
    ..addRoute(TokenRoute(services), '/token')
    ..addRoute(TokenRefreshRoute(services), '/token/refresh')
    ..addRoute(LogoutRoute(services), '/logout')
    ..addRoute(TotpStatusRoute(services), '/totp')
    ..addRoute(TotpSetupRoute(services), '/totp/setup')
    ..addRoute(TotpEnableRoute(services), '/totp/enable')
    ..addRoute(TotpDisableRoute(services), '/totp/disable')
    ..addRoute(UsersRoute(services), '/users')
    ..addRoute(UserUpdateRoute(services), '/users/:id')
    ..addRoute(StatusRoute(services), '/')
    ..addRoute(InfoRoute(services), '/info')
    ..addRoute(GpsRoute(services), '/gps')
    ..addRoute(CameraSnapshotRoute(services), '/camera/snapshot')
    ..addRoute(AuditLogRoute(services), '/audit')
    ..addRoute(AuditCleanupRoute(services), '/audit/cleanup')
    ..addRoute(MetricsRoute(services), '/metrics')
    ..addRoute(PhoneCallRoute(services), '/phone/call')
    ..addRoute(PhoneHangupRoute(services), '/phone/hangup')
    ..addRoute(PhoneCallsRoute(services), '/phone/calls')
    ..addRoute(SmsRoute(services), '/sms')
    ..addRoute(SmsRetryRoute(services), '/sms/retry/:id')
    ..addRoute(SmsDeleteRoute(services), '/sms/delete/:id')
    ..addRoute(SmsCleanupRoute(services), '/sms/cleanup/')
    ..addRoute(AtRoute(services), '/at')
    ..addRoute(HealthRoute(), '/healthz')
    ..addRoute(DocsRoute(services.config.docsEnabled), '/docs')
    ..addRoute(DocsStyleRoute(services.config.docsEnabled), '/docs/style.css')
    ..addRoute(DocsScriptRoute(services.config.docsEnabled), '/docs/app.js')
    ..addRoute(OpenApiRoute(services.config.docsEnabled), '/openapi.json')
    ..addRoute(EchoWebSocketRoute(services), '/wss')
    ..addRoute(VideoWebSocketRoute(services), '/wss/video');

  // Serverpod registers GET /readyz itself, so the Simcom API response is produced
  // by middleware instead of a conflicting route.
  web.addMiddleware(readyzMiddleware(), '/readyz');
}
