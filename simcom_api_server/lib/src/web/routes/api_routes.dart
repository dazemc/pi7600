import 'dart:async';
import 'dart:io';

import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/generated/message.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:simcom_api_server/src/services/audit_service.dart';
import 'package:simcom_api_server/src/services/sms_service.dart';
import 'package:simcom_api_server/src/services/user_service.dart';
import 'package:simcom_api_server/src/util/app_log.dart';
import 'package:simcom_api_server/src/web/at_audit.dart';
import 'package:simcom_api_server/src/web/http.dart';
import 'package:simcom_api_server/src/web/metrics.dart';
import 'package:simcom_modem/simcom_modem.dart';
import 'package:serverpod/serverpod.dart' hide Message;

/// Serialize a message with the snake_case keys used by the Python API.
Map<String, Object?> messageToJson(Message message) {
  return {
    'id': message.id,
    'message_index': message.messageIndex,
    'message_type': message.messageType,
    'message_originating_address': message.messageOriginatingAddress,
    'message_destination_address': message.messageDestinationAddress,
    'message_date': message.messageDate,
    'message_time': message.messageTime,
    'message_contents': message.messageContents,
    'partial_key': message.partialKey,
    'partial_count': message.partialCount,
    'partial_index': message.partialIndex,
    'is_partial': message.isPartial,
    'in_sim_memory': message.inSimMemory,
    'is_sent': message.isSent,
  };
}

Response _tooManyAttempts(Duration retryAfter) {
  final seconds = retryAfter.inSeconds.clamp(1, 86400);
  return errorResponse(
    429,
    'Too many failed login attempts',
    extraHeaders: {'Retry-After': '$seconds'},
  );
}

Response? _throttleCheck(AppServices services, String key) {
  final retryAfter = services.loginLimiter.retryAfter(key);
  return retryAfter == null ? null : _tooManyAttempts(retryAfter);
}

Response _recordThrottledFailure(
  AppServices services,
  String key,
  String detail, {
  int status = 403,
}) {
  final block = services.loginLimiter.recordFailure(key);
  if (block != null) return _tooManyAttempts(block);
  return errorResponse(status, detail);
}

/// `POST /token`
class TokenRoute extends Route {
  TokenRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final body = await request.readAsString();
    final Map<String, String> form;
    try {
      form = Uri.splitQueryString(body);
    } on Object {
      return errorResponse(422, 'Invalid form body');
    }
    final username = form['username'];
    final password = form['password'];
    if (username == null || password == null) {
      return errorResponse(422, 'Missing username or password');
    }

    final limiter = services.loginLimiter;
    final address = request.connectionInfo.remote.address.toString();
    final userKey = 'user:${username.trim().toLowerCase()}';
    final addressKey = 'ip:$address';
    final audit = services.auditService(session);
    final blockedFor =
        limiter.retryAfter(userKey) ?? limiter.retryAfter(addressKey);
    if (blockedFor != null) {
      await audit.record(
        eventType: 'login',
        userName: username,
        remoteAddress: address,
        success: false,
        detail: 'rate limited',
      );
      return _tooManyAttempts(blockedFor);
    }

    Future<Response> recordFailure(String detail) async {
      final userBlock = limiter.recordFailure(userKey);
      final addressBlock = limiter.recordFailure(addressKey);
      final block = userBlock ?? addressBlock;
      AppLog.warning(
        'Failed login for $username',
        name: 'simcom_api.auth',
      );
      await audit.record(
        eventType: 'login',
        userName: username,
        remoteAddress: address,
        success: false,
        detail: block == null ? detail : '$detail (rate limited)',
      );
      if (block != null) return _tooManyAttempts(block);
      return errorResponse(401, detail, authenticate: true);
    }

    final auth = services.authService(session);
    final user = await auth.authenticatePassword(username, password);
    if (user == null) {
      return recordFailure('Incorrect username or password');
    }

    if (user.totpEnabled) {
      final otp = form['otp']?.trim() ?? '';
      if (otp.isEmpty) {
        await audit.record(
          eventType: 'login',
          userName: username,
          remoteAddress: address,
          success: false,
          detail: 'TOTP code required',
        );
        return errorResponse(
          401,
          'TOTP code required',
          authenticate: true,
        );
      }
      if (!await auth.verifySecondFactor(user, otp)) {
        return recordFailure('Incorrect TOTP code');
      }
    }

    limiter.reset(userKey);
    limiter.reset(addressKey);
    await audit.record(
      eventType: 'login',
      userName: user.userName,
      remoteAddress: address,
      detail: user.totpEnabled ? 'password+totp' : 'password',
    );
    return _tokenResponse(services, user);
  }
}

/// `POST /token/refresh`
class TokenRefreshRoute extends Route {
  TokenRefreshRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final body = await request.readAsString();
    final Map<String, String> form;
    try {
      form = Uri.splitQueryString(body);
    } on Object {
      return errorResponse(422, 'Invalid form body');
    }

    final refreshToken = form['refresh_token'];
    if (refreshToken == null || refreshToken.isEmpty) {
      return errorResponse(422, 'refresh_token is required');
    }

    try {
      final user = await services
          .authService(session)
          .authenticateRefreshToken(refreshToken);
      if (user == null) {
        return errorResponse(401, 'Invalid or revoked refresh token');
      }
      AppLog.info(
        '/token/refresh POST: Refreshed token for ${user.userName}',
        name: 'simcom_api.auth',
      );
      return _tokenResponse(services, user);
    } on TokenException {
      return errorResponse(401, 'Invalid or expired refresh token');
    }
  }
}

/// `POST /logout`
class LogoutRoute extends Route {
  LogoutRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.authService(session).revokeTokens(auth.user!);
    await services
        .auditService(session)
        .record(
          eventType: 'logout',
          userName: auth.user!.userName,
          remoteAddress: request.connectionInfo.remote.address.toString(),
        );
    return jsonResponse({'detail': 'Logged out'});
  }
}

Response _tokenResponse(AppServices services, User user) {
  return jsonResponse({
    'access_token': services.jwt.createToken(
      user.userName,
      version: user.tokenVersion,
    ),
    'refresh_token': services.jwt.createRefreshToken(
      user.userName,
      version: user.tokenVersion,
    ),
    'token_type': 'bearer',
    'expires_in': services.config.jwtExpireMinutes * 60,
  });
}

/// `GET /totp`
class TotpStatusRoute extends Route {
  TotpStatusRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    return jsonResponse({'enabled': auth.user!.totpEnabled});
  }
}

/// `POST /totp/setup`
class TotpSetupRoute extends Route {
  TotpSetupRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    if (auth.user!.totpEnabled) {
      return errorResponse(409, 'TOTP is already enabled');
    }

    final body = await readJsonObject(request);
    final password = body?['password'];
    if (password is! String || password.isEmpty) {
      return errorResponse(422, 'password is required');
    }

    final throttleKey = 'totp-setup:${auth.user!.userName}';
    final throttled = _throttleCheck(services, throttleKey);
    if (throttled != null) return throttled;

    final setup = await services
        .authService(session)
        .setupTotp(auth.user!, password);
    if (setup == null) {
      return _recordThrottledFailure(
        services,
        throttleKey,
        'Incorrect password',
      );
    }
    services.loginLimiter.reset(throttleKey);
    await services
        .auditService(session)
        .record(
          eventType: 'totp_setup',
          userName: auth.user!.userName,
          remoteAddress: request.connectionInfo.remote.address.toString(),
          detail: 'started',
        );

    return jsonResponse({
      'secret': setup.secret,
      'provisioning_uri': setup.provisioningUri,
      'recovery_codes': setup.recoveryCodes,
    });
  }
}

/// `POST /totp/enable`
class TotpEnableRoute extends Route {
  TotpEnableRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    if (auth.user!.totpEnabled) {
      return errorResponse(409, 'TOTP is already enabled');
    }

    final body = await readJsonObject(request);
    final code = body?['code'];
    if (code is! String || code.trim().isEmpty) {
      return errorResponse(422, 'code is required');
    }

    final throttleKey = 'totp-enable:${auth.user!.userName}';
    final throttled = _throttleCheck(services, throttleKey);
    if (throttled != null) return throttled;

    final enabled = await services
        .authService(session)
        .enableTotp(auth.user!, code.trim());
    if (!enabled) {
      return _recordThrottledFailure(
        services,
        throttleKey,
        'Invalid TOTP code',
        status: 422,
      );
    }
    services.loginLimiter.reset(throttleKey);
    await services
        .auditService(session)
        .record(
          eventType: 'totp_enable',
          userName: auth.user!.userName,
          remoteAddress: request.connectionInfo.remote.address.toString(),
          detail: 'enabled',
        );
    return jsonResponse({'enabled': true});
  }
}

/// `POST /totp/disable`
class TotpDisableRoute extends Route {
  TotpDisableRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;

    final body = await readJsonObject(request);
    final password = body?['password'];
    final code = body?['code'];
    if (password is! String || password.isEmpty) {
      return errorResponse(422, 'password is required');
    }
    if (code is! String || code.trim().isEmpty) {
      return errorResponse(422, 'code is required');
    }

    final throttleKey = 'totp-disable:${auth.user!.userName}';
    final throttled = _throttleCheck(services, throttleKey);
    if (throttled != null) return throttled;

    final disabled = await services
        .authService(session)
        .disableTotp(auth.user!, password, code.trim());
    if (!disabled) {
      return _recordThrottledFailure(
        services,
        throttleKey,
        'Incorrect password or code',
      );
    }
    services.loginLimiter.reset(throttleKey);
    await services
        .auditService(session)
        .record(
          eventType: 'totp_disable',
          userName: auth.user!.userName,
          remoteAddress: request.connectionInfo.remote.address.toString(),
          detail: 'disabled',
        );
    return jsonResponse({'enabled': false});
  }
}

/// `GET /users` and `POST /users`
class UsersRoute extends Route {
  UsersRoute(this.services) : super(methods: {Method.get, Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;

    if (request.method == Method.post) {
      return _create(session, request, auth.user!);
    }

    final users = await services.userService(session).list();
    return jsonResponse(users.map(userToJson).toList(growable: false));
  }

  Future<Result> _create(
    Session session,
    Request request,
    User actor,
  ) async {
    final body = await readJsonObject(request);
    if (body == null) return errorResponse(422, 'Invalid JSON body');

    final username = body['username'];
    final password = body['password'];
    if (username is! String || username.trim().isEmpty) {
      return errorResponse(422, 'username is required');
    }
    if (password is! String || password.isEmpty) {
      return errorResponse(422, 'password is required');
    }

    final fullName = body['full_name'];
    if (fullName != null && fullName is! String) {
      return errorResponse(422, 'full_name must be a string');
    }
    final email = body['email'];
    if (email != null && email is! String) {
      return errorResponse(422, 'email must be a string');
    }
    final isAdmin = body['is_admin'];
    if (isAdmin != null && isAdmin is! bool) {
      return errorResponse(422, 'is_admin must be a boolean');
    }

    try {
      final user = await services
          .userService(session)
          .create(
            username: username,
            password: password,
            fullName: fullName as String?,
            email: email as String?,
            isAdmin: isAdmin as bool? ?? false,
          );
      AppLog.audit(
        'User ${actor.userName} created user ${user.userName} '
        'admin=${user.isAdmin}',
      );
      await services
          .auditService(session)
          .record(
            eventType: 'user_create',
            userName: actor.userName,
            remoteAddress: request.connectionInfo.remote.address.toString(),
            detail: 'target=${user.userName} admin=${user.isAdmin}',
          );
      return jsonResponse(userToJson(user), status: 201);
    } on UserNameTakenException {
      return errorResponse(409, 'Username already exists');
    } on UserValidationException catch (error) {
      return errorResponse(422, error.message);
    }
  }
}

/// `PATCH /users/:id`
class UserUpdateRoute extends Route {
  UserUpdateRoute(this.services) : super(methods: {Method.patch});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;

    final rawId = request.rawPathParameters[#id];
    final id = rawId == null ? null : int.tryParse(rawId);
    if (id == null) return errorResponse(422, 'Invalid user id');

    final body = await readJsonObject(request);
    if (body == null) return errorResponse(422, 'Invalid JSON body');

    final password = body['password'];
    if (password != null && password is! String) {
      return errorResponse(422, 'password must be a string');
    }
    final isDisabled = body['is_disabled'];
    if (isDisabled != null && isDisabled is! bool) {
      return errorResponse(422, 'is_disabled must be a boolean');
    }
    final isAdmin = body['is_admin'];
    if (isAdmin != null && isAdmin is! bool) {
      return errorResponse(422, 'is_admin must be a boolean');
    }

    String? fullName;
    if (body.containsKey('full_name')) {
      final value = body['full_name'];
      if (value == null) {
        fullName = '';
      } else if (value is String) {
        fullName = value;
      } else {
        return errorResponse(422, 'full_name must be a string or null');
      }
    }

    String? email;
    if (body.containsKey('email')) {
      final value = body['email'];
      if (value == null) {
        email = '';
      } else if (value is String) {
        email = value;
      } else {
        return errorResponse(422, 'email must be a string or null');
      }
    }

    final changed = [
      if (password != null) 'password',
      if (fullName != null) 'full_name',
      if (email != null) 'email',
      if (isDisabled != null) 'is_disabled',
      if (isAdmin != null) 'is_admin',
    ];
    if (changed.isEmpty) {
      return errorResponse(422, 'No fields to update');
    }

    try {
      final user = await services
          .userService(session)
          .update(
            id: id,
            actor: auth.user!,
            password: password as String?,
            fullName: fullName,
            email: email,
            isDisabled: isDisabled as bool?,
            isAdmin: isAdmin as bool?,
          );
      AppLog.audit(
        'User ${auth.user!.userName} updated user ${user.userName}: '
        '${changed.join(',')}',
      );
      await services
          .auditService(session)
          .record(
            eventType: 'user_update',
            userName: auth.user!.userName,
            remoteAddress: request.connectionInfo.remote.address.toString(),
            detail: 'target=${user.userName} fields=${changed.join(',')}',
          );
      return jsonResponse(userToJson(user));
    } on UserNotFoundException {
      return errorResponse(404, 'User $id not found');
    } on UserValidationException catch (error) {
      return errorResponse(422, error.message);
    }
  }
}

/// `GET /`
class StatusRoute extends Route {
  StatusRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/ GET: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );
    final result = await services.status.status();
    return jsonResponse(result.toJson());
  }
}

/// `GET /info`
class InfoRoute extends Route {
  InfoRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    AppLog.info(
      '/info GET: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );
    final result = await services.status.info();
    return jsonResponse(result.toJson());
  }
}

/// `GET /gps`
class GpsRoute extends Route {
  GpsRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/gps GET: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );

    final raw = await services.gps.getGpsPosition();
    final fix = parseGpsInfo(raw);
    return jsonResponse({
      'raw': raw,
      ...?fix?.toJson(),
      if (fix == null) ...{
        'latitude': null,
        'longitude': null,
        'date': null,
        'time': null,
        'altitude': null,
        'speed_knots': null,
        'course_degrees': null,
        'maps_url': null,
      },
    });
  }
}

/// `GET /camera/snapshot`
class CameraSnapshotRoute extends Route {
  CameraSnapshotRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;

    if (!await services.ensureCameraStarted()) {
      return errorResponse(503, 'Camera unavailable');
    }
    services.cameraUsedTransiently();

    final frame = await services.camera.waitForFrame();
    if (frame == null) {
      return errorResponse(503, 'No camera frame available');
    }

    AppLog.info(
      '/camera/snapshot GET: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );
    return Response(
      200,
      body: Body.fromData(frame, mimeType: MimeType('image', 'jpeg')),
      headers: Headers.build((headers) {
        headers[HttpHeaders.cacheControlHeader] = ['no-store'];
      }),
    );
  }
}

/// `GET /audit`
class AuditLogRoute extends Route {
  AuditLogRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;

    var limit = 100;
    final rawLimit = request.url.queryParameters['limit'];
    if (rawLimit != null && rawLimit.isNotEmpty) {
      final parsed = int.tryParse(rawLimit);
      if (parsed == null || parsed < 1 || parsed > 500) {
        return errorResponse(422, 'limit must be between 1 and 500');
      }
      limit = parsed;
    }

    final events = await services.auditService(session).recent(limit: limit);
    return jsonResponse(events.map(auditEventToJson).toList(growable: false));
  }
}

/// `DELETE /audit/cleanup`
class AuditCleanupRoute extends Route {
  AuditCleanupRoute(this.services) : super(methods: {Method.delete});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;

    final deleted = await services
        .auditService(session)
        .cleanup(
          retention: Duration(days: services.config.auditRetentionDays),
        );
    AppLog.audit(
      'Audit cleanup by ${auth.user!.userName}: deleted=$deleted',
    );
    await services
        .auditService(session)
        .record(
          eventType: 'audit_cleanup',
          userName: auth.user!.userName,
          remoteAddress: request.connectionInfo.remote.address.toString(),
          detail: 'deleted=$deleted',
        );
    return jsonResponse({'deleted': deleted});
  }
}

/// `GET /metrics`
class MetricsRoute extends Route {
  MetricsRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;

    final status = services.serviceStatus.state;
    final body = buildMetrics(
      modemReady: status.modemReady,
      cameraRunning: services.camera.isRunning,
      recognitionReady: status.recognitionReady,
      videoClients: services.broadcaster.clientCount,
      phase: status.phase.name,
      requests: services.requestMetrics,
    );
    return Response(
      200,
      body: Body.fromString(body, mimeType: MimeType.plainText),
    );
  }
}

/// `POST /phone/call`
class PhoneCallRoute extends Route {
  PhoneCallRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;

    final body = await readJsonObject(request);
    final number = body?['number'];
    if (number is! String || number.trim().isEmpty) {
      return errorResponse(422, 'number is required');
    }
    final normalized = number.trim();
    if (!RegExp(r'^\+?[0-9]{1,32}$').hasMatch(normalized)) {
      return errorResponse(422, 'Invalid phone number');
    }

    AppLog.info(
      'Phone call requested by ${auth.user!.userName}',
      name: 'simcom_api.phone',
    );
    final connected = await services.phone.call(normalized);
    if (!connected) {
      return errorResponse(502, 'Call failed');
    }
    return jsonResponse({'response': 'Ok'}, status: 202);
  }
}

/// `POST /phone/hangup`
class PhoneHangupRoute extends Route {
  PhoneHangupRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;

    AppLog.info(
      'Phone hangup requested by ${auth.user!.userName}',
      name: 'simcom_api.phone',
    );
    final hungUp = await services.phone.hangupCall();
    if (!hungUp) {
      return errorResponse(502, 'Hangup failed');
    }
    return jsonResponse({'response': 'Ok'}, status: 202);
  }
}

/// `GET /phone/calls`
class PhoneCallsRoute extends Route {
  PhoneCallsRoute(this.services) : super(methods: {Method.get});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;

    final calls = await services.phone.activeCalls();
    if (calls == null) {
      return errorResponse(502, 'Unable to read active calls');
    }
    return jsonResponse({'response': calls});
  }
}

/// `GET /sms` and `POST /sms`
///
/// Relic only allows one route per path, so the two methods share a route and
/// dispatch on [Request.method].
class SmsRoute extends Route {
  SmsRoute(this.services) : super(methods: {Method.get, Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    return switch (request.method) {
      Method.get => _list(session, request),
      Method.post => _create(session, request),
      _ => errorResponse(405, 'Method not allowed'),
    };
  }

  Future<Result> _list(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/sms GET: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );

    final query = request.url.queryParameters;
    final limitRaw = query['limit'];
    final offsetRaw = query['offset'];
    final searchRaw = query['q'];

    int? limit;
    if (limitRaw != null && limitRaw.isNotEmpty) {
      limit = int.tryParse(limitRaw);
      if (limit == null || limit < 1 || limit > 500) {
        return errorResponse(422, 'limit must be between 1 and 500');
      }
    }

    var offset = 0;
    if (offsetRaw != null && offsetRaw.isNotEmpty) {
      final parsed = int.tryParse(offsetRaw);
      if (parsed == null || parsed < 0) {
        return errorResponse(422, 'offset must be 0 or greater');
      }
      offset = parsed;
    }

    String? search;
    if (searchRaw != null) {
      final trimmed = searchRaw.trim();
      if (trimmed.length > 200) {
        return errorResponse(422, 'q must be at most 200 characters');
      }
      if (trimmed.isNotEmpty) search = trimmed;
    }

    final messages = await services
        .smsService(session)
        .listMessages(limit: limit, offset: offset, search: search);
    return jsonResponse(messages.map(messageToJson).toList(growable: false));
  }

  Future<Result> _create(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/sms POST: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );

    final body = await readJsonObject(request);
    final number = body?['number'];
    final text = body?['msg'];
    if (number is! String || text is! String) {
      return errorResponse(422, 'number and msg are required');
    }

    try {
      final message = await services
          .smsService(session)
          .sendMessage(number: number, text: text);
      return jsonResponse(messageToJson(message), status: 201);
    } on SmsDeliveryException {
      return errorResponse(
        502,
        'Message was stored but the modem could not send it',
      );
    }
  }
}

/// `POST /sms/retry/:id`
class SmsRetryRoute extends Route {
  SmsRetryRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/sms/retry POST: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );

    final rawId = request.rawPathParameters[#id];
    final id = rawId == null ? null : int.tryParse(rawId);
    if (id == null) {
      return errorResponse(422, 'Invalid message id');
    }

    try {
      final message = await services.smsService(session).retryMessage(id);
      if (message == null) {
        return errorResponse(404, 'Message $id not found');
      }
      return jsonResponse(messageToJson(message), status: 202);
    } on SmsDeliveryException {
      return errorResponse(502, 'Message could not be sent');
    }
  }
}

/// `DELETE /sms/delete/:id`
class SmsDeleteRoute extends Route {
  SmsDeleteRoute(this.services) : super(methods: {Method.delete});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/sms/delete DELETE: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );

    final rawId = request.rawPathParameters[#id];
    final id = rawId == null ? null : int.tryParse(rawId);
    if (id == null) {
      return errorResponse(422, 'Invalid message id');
    }

    try {
      final deleted = await services.smsService(session).deleteMessage(id);
      if (!deleted) {
        return errorResponse(404, 'Message $id not found');
      }
      return jsonResponse({'response': 'Ok'}, status: 202);
    } on ModemDeleteException catch (error) {
      final target = error.messageIndex == null
          ? error.reason
          : 'message ${error.messageIndex}';
      return errorResponse(502, 'Modem could not delete $target');
    }
  }
}

/// `DELETE /sms/cleanup/`
class SmsCleanupRoute extends Route {
  SmsCleanupRoute(this.services) : super(methods: {Method.delete});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;
    AppLog.info(
      '/sms/cleanup DELETE: Accessed by ${auth.user!.userName}',
      name: 'simcom_api',
    );
    await services.smsService(session).cleanupSimMessages();
    return jsonResponse({'response': 'Ok'}, status: 202);
  }
}

/// `POST /at`
class AtRoute extends Route {
  AtRoute(this.services) : super(methods: {Method.post});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateAdmin(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    await services.ready;

    final body = await readJsonObject(request);
    final command = body?['cmd'] is String ? body!['cmd'] as String : 'AT';
    final auditCommand = redactAtCommand(command);

    AppLog.audit(
      'AT audit: user=${auth.user!.userName} cmd=$auditCommand',
    );
    final response = await services.modem.sendRaw(
      command,
      timeoutSeconds: services.config.atTimeout,
    );
    final preview = auditAtResponse(command, response);
    AppLog.audit(
      'AT audit: user=${auth.user!.userName} cmd=$auditCommand '
      'response=$preview',
    );
    await services
        .auditService(session)
        .record(
          eventType: 'at',
          userName: auth.user!.userName,
          remoteAddress: request.connectionInfo.remote.address.toString(),
          success: !At.isError(response),
          detail: 'cmd=$auditCommand response=$preview',
        );
    return jsonResponse(response, status: 202);
  }
}

/// `GET /healthz`
class HealthRoute extends Route {
  HealthRoute() : super(methods: {Method.get});

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    return jsonResponse({'status': 'ok', 'detail': null});
  }
}
