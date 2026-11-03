import 'dart:async';

import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_modem/simcom_modem.dart';
import 'package:simcom_api_server/src/generated/message.dart';
import 'package:simcom_api_server/src/services/sms_service.dart';
import 'package:simcom_api_server/src/util/app_log.dart';
import 'package:simcom_api_server/src/web/at_audit.dart';
import 'package:simcom_api_server/src/web/http.dart';
import 'package:simcom_api_server/src/web/metrics.dart';
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

    final auth = services.authService(session);
    final user = await auth.authenticatePassword(username, password);
    if (user == null) {
      AppLog.warning(
        'Failed login for $username',
        name: 'pi7600.auth',
      );
      return errorResponse(
        401,
        'Incorrect username or password',
        authenticate: true,
      );
    }

    return jsonResponse({
      'access_token': services.jwt.createToken(user.userName),
      'token_type': 'bearer',
    });
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
      name: 'pi7600',
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
      name: 'pi7600',
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
      name: 'pi7600',
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
      name: 'pi7600.phone',
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
      name: 'pi7600.phone',
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
      name: 'pi7600',
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
      name: 'pi7600',
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
      name: 'pi7600',
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
      name: 'pi7600',
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
      name: 'pi7600',
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
