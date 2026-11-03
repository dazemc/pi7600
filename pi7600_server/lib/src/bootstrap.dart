import 'dart:async';

import 'package:pi7600_server/src/app_services.dart';
import 'package:pi7600_server/src/config/app_config.dart';
import 'package:pi7600_server/src/web/routes/api_routes.dart';
import 'package:pi7600_server/src/web/routes/readyz.dart';
import 'package:pi7600_server/src/web/routes/websockets.dart';
import 'package:serverpod/serverpod.dart';

/// Wire the Pi7600 services and routes into a [Serverpod] instance.
void configureServer(Serverpod pod) {
  final services = AppServices.create(AppConfig.fromEnvironment());

  // Startup is asynchronous because the modem, camera, and recognition
  // backends touch hardware. Routes that need them await [AppServices.ready].
  unawaited(services.start());
  pod.experimental.shutdownTasks.addTask('pi7600', services.stop);

  final web = pod.webServer;

  web
    ..addRoute(TokenRoute(services), '/token')
    ..addRoute(StatusRoute(services), '/')
    ..addRoute(InfoRoute(services), '/info')
    ..addRoute(SmsRoute(services), '/sms')
    ..addRoute(SmsDeleteRoute(services), '/sms/delete/:id')
    ..addRoute(SmsCleanupRoute(services), '/sms/cleanup/')
    ..addRoute(AtRoute(services), '/at')
    ..addRoute(HealthRoute(), '/healthz')
    ..addRoute(EchoWebSocketRoute(services), '/wss')
    ..addRoute(VideoWebSocketRoute(services), '/wss/video');

  // Serverpod registers GET /readyz itself, so the Pi7600 response is produced
  // by middleware instead of a conflicting route.
  web.addMiddleware(readyzMiddleware(), '/readyz');
}
