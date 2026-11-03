import 'package:simcom_api_server/src/web/http.dart';
import 'package:serverpod/serverpod.dart';
// ignore: implementation_imports
import 'package:serverpod/src/server/serverpod.dart'
    show ServerpodInternalMethods;

/// Middleware that replaces Serverpod's `/readyz` probe with the Pi7600
/// payload and database check.
///
/// The built-in `HealthRoutes` already registers `GET /readyz`, so adding a
/// second route at that path throws. Middleware can intercept the request
/// before the built-in handler runs.
Middleware readyzMiddleware() {
  return (next) {
    return (request) async {
      if (request.method != Method.get || request.url.path != '/readyz') {
        return next(request);
      }

      try {
        await Serverpod.instance.internalSession.db.unsafeQuery('SELECT 1');
        return jsonResponse({'status': 'ok', 'detail': null});
      } on Object {
        return errorResponse(503, 'Database unavailable');
      }
    };
  };
}
