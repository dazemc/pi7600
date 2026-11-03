import 'dart:async';
import 'dart:developer' as developer;

import 'package:pi7600_server/src/app_services.dart';
import 'package:pi7600_server/src/generated/message.dart';
import 'package:pi7600_server/src/services/sms_service.dart';
import 'package:pi7600_server/src/web/http.dart';
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
    final form = Uri.splitQueryString(body);
    final username = form['username'];
    final password = form['password'];
    if (username == null || password == null) {
      return errorResponse(422, 'Missing username or password');
    }

    final auth = services.authService(session);
    final user = await auth.authenticatePassword(username, password);
    if (user == null) {
      developer.log(
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
    developer.log(
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
    developer.log(
      '/info GET: Accessed by ${auth.user!.userName}',
      name: 'pi7600',
    );
    final result = await services.status.info();
    return jsonResponse(result.toJson());
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
    developer.log(
      '/sms GET: Accessed by ${auth.user!.userName}',
      name: 'pi7600',
    );
    final messages = await services.smsService(session).listMessages();
    return jsonResponse(messages.map(messageToJson).toList(growable: false));
  }

  Future<Result> _create(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    developer.log(
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

/// `DELETE /sms/delete/:id`
class SmsDeleteRoute extends Route {
  SmsDeleteRoute(this.services) : super(methods: {Method.delete});

  final AppServices services;

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    final auth = await authenticateRequest(session, request, services);
    if (!auth.isAuthenticated) return auth.error!;
    developer.log(
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
      return errorResponse(
        502,
        'Modem could not delete message ${error.messageIndex}',
      );
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
    developer.log(
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

    final body = await readJsonObject(request);
    final command = body?['cmd'] is String ? body!['cmd'] as String : 'AT';

    developer.log(
      'AT audit: user=${auth.user!.userName} cmd=$command',
      name: 'pi7600.at',
    );
    final response = await services.modem.sendRaw(
      command,
      timeoutSeconds: services.config.atTimeout,
    );
    final preview = response.length > 500
        ? response.substring(0, 500)
        : response;
    developer.log(
      'AT audit: user=${auth.user!.userName} cmd=$command response=$preview',
      name: 'pi7600.at',
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
