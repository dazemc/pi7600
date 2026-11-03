import 'dart:convert';

import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_api_server/src/auth/auth_service.dart';
import 'package:simcom_api_server/src/auth/jwt_service.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:serverpod/serverpod.dart';

/// Encode [data] as a JSON response with the given [status].
Response jsonResponse(Object? data, {int status = 200}) {
  return Response(
    status,
    body: Body.fromString(jsonEncode(data), mimeType: MimeType.json),
  );
}

/// Build the FastAPI-compatible error payload `{"detail": ...}`.
Response errorResponse(
  int status,
  Object? detail, {
  bool authenticate = false,
  Map<String, String>? extraHeaders,
}) {
  final headers = Headers.build((builder) {
    if (authenticate) {
      builder[Headers.wwwAuthenticateHeader] = ['Bearer'];
    }
    extraHeaders?.forEach((key, value) {
      builder[key] = [value];
    });
  });
  return Response(
    status,
    body: Body.fromString(
      jsonEncode({'detail': detail}),
      mimeType: MimeType.json,
    ),
    headers: headers,
  );
}

/// Result of authenticating an HTTP request.
class AuthOutcome {
  const AuthOutcome._(this.user, this.error);

  const AuthOutcome.user(User user) : this._(user, null);

  const AuthOutcome.error(Response response) : this._(null, response);

  final User? user;
  final Response? error;

  bool get isAuthenticated => user != null;
}

/// Validate the bearer token on [request] and load the matching user.
Future<AuthOutcome> authenticateRequest(
  Session session,
  Request request,
  AppServices services,
) async {
  final values = request.headers[Headers.authorizationHeader];
  final header = values == null || values.isEmpty ? null : values.first;
  final token = AuthService.bearerToken(header);
  if (token == null) {
    return AuthOutcome.error(
      errorResponse(401, 'Not authenticated', authenticate: true),
    );
  }

  final auth = services.authService(session);
  try {
    final user = await auth.authenticateToken(token);
    if (user == null) {
      return AuthOutcome.error(
        errorResponse(401, 'User is unavailable', authenticate: true),
      );
    }
    return AuthOutcome.user(user);
  } on TokenException {
    return AuthOutcome.error(
      errorResponse(
        401,
        'Invalid or expired token',
        authenticate: true,
      ),
    );
  }
}

/// Validate a bearer token and require [User.isAdmin].
Future<AuthOutcome> authenticateAdmin(
  Session session,
  Request request,
  AppServices services,
) async {
  final outcome = await authenticateRequest(session, request, services);
  if (!outcome.isAuthenticated) return outcome;
  if (outcome.user!.isAdmin != true) {
    return AuthOutcome.error(
      errorResponse(403, 'Administrator access required'),
    );
  }
  return outcome;
}

/// Read a JSON object body. Returns `null` when the body is not a JSON object.
Future<Map<String, dynamic>?> readJsonObject(Request request) async {
  try {
    final body = await request.readAsString();
    if (body.trim().isEmpty) return null;
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on Object {
    return null;
  }
}
