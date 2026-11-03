/// Static description of the Simcom API HTTP contract.
///
/// The same catalog drives the interactive `/docs` page and the generated
/// `/openapi.json` document, so the two cannot drift apart.
library;

import 'dart:convert';

/// Authentication required by an endpoint.
enum ApiAuth {
  /// No bearer token required.
  none,

  /// A valid bearer token for any user.
  user,

  /// A valid bearer token for an administrator.
  admin,
}

/// A path parameter such as `{id}` in `/sms/delete/{id}`.
class ApiPathParameter {
  const ApiPathParameter({
    required this.name,
    this.type = 'integer',
    this.description = '',
    this.example = '1',
  });

  final String name;
  final String type;
  final String description;
  final String example;
}

/// An optional query parameter such as `?limit=50`.
class ApiQueryParameter {
  const ApiQueryParameter({
    required this.name,
    this.type = 'string',
    this.description = '',
    this.example = '',
  });

  final String name;
  final String type;
  final String description;
  final String example;
}

/// A form field used by `application/x-www-form-urlencoded` endpoints.
class ApiFormField {
  const ApiFormField({
    required this.name,
    this.type = 'string',
    this.required = true,
    this.description = '',
    this.example = '',
  });

  final String name;
  final String type;
  final bool required;
  final String description;
  final String example;
}

/// One HTTP operation exposed by the service.
class ApiEndpoint {
  const ApiEndpoint({
    required this.method,
    required this.path,
    required this.summary,
    this.description = '',
    this.auth = ApiAuth.none,
    this.jsonBody,
    this.formFields = const [],
    this.pathParameters = const [],
    this.queryParameters = const [],
    this.responses = const {},
    this.binaryResponse = false,
    this.binaryContentType = 'application/octet-stream',
    this.operationId,
  });

  final String method;

  /// OpenAPI-style path, for example `/sms/delete/{id}`.
  final String path;
  final String summary;
  final String description;
  final ApiAuth auth;

  /// Example JSON request body, pretty printed. `null` when there is none.
  final String? jsonBody;
  final List<ApiFormField> formFields;
  final List<ApiPathParameter> pathParameters;
  final List<ApiQueryParameter> queryParameters;

  /// Response status code to description.
  final Map<String, String> responses;

  /// Whether the successful response is raw bytes rather than JSON text.
  final bool binaryResponse;
  final String binaryContentType;
  final String? operationId;

  String get id => operationId ?? _deriveOperationId();

  String _deriveOperationId() {
    final cleaned = path
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('/', '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${method.toLowerCase()}_${cleaned.isEmpty ? 'root' : cleaned}';
  }
}

const _jsonHeaders = 'application/json';

/// Every HTTP operation in the Simcom API contract.
const apiEndpoints = <ApiEndpoint>[
  ApiEndpoint(
    method: 'POST',
    path: '/token',
    summary: 'Exchange credentials for a JWT',
    description:
        'Send `username` and `password` as an '
        '`application/x-www-form-urlencoded` body. Returns a short-lived '
        'access token (30 minutes by default), a refresh token (7 days by '
        'default), and the access-token lifetime in seconds. Repeated failed '
        'logins are throttled per username and client address.',
    formFields: [
      ApiFormField(name: 'username', example: 'alice'),
      ApiFormField(
        name: 'password',
        example: 'correct horse battery staple',
        description: 'Plaintext password; it is verified with bcrypt.',
      ),
      ApiFormField(
        name: 'otp',
        required: false,
        description:
            'TOTP code or single-use recovery code when TOTP is enabled.',
      ),
    ],
    responses: {
      '200': 'Access token, refresh token, token type, and `expires_in`',
      '401': 'Incorrect credentials or missing TOTP code',
      '422': 'Missing username or password',
      '429': 'Too many failed attempts; see `Retry-After`',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/token/refresh',
    summary: 'Exchange a refresh token for new tokens',
    description:
        'Send `refresh_token` as an `application/x-www-form-urlencoded` body. '
        'The user must still be enabled and the token version must match; '
        'logout invalidates all outstanding tokens.',
    formFields: [
      ApiFormField(
        name: 'refresh_token',
        description: 'Refresh token returned by `/token`',
      ),
    ],
    responses: {
      '200': 'New access and refresh tokens',
      '401': 'Invalid, expired, or revoked refresh token',
      '422': 'Missing refresh token',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/logout',
    summary: 'Revoke all tokens for the current user',
    description:
        'Increments the user token version, invalidating every access and '
        'refresh token issued before this call. The bearer token is required.',
    auth: ApiAuth.user,
    responses: {
      '200': 'Tokens revoked',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/users',
    summary: 'List API users (admin only)',
    description:
        'Returns id, username, full name, email, disabled/admin flags, and '
        'whether TOTP is enabled. Passwords, TOTP secrets, and recovery codes '
        'are never returned.',
    auth: ApiAuth.admin,
    responses: {
      '200': 'Array of users',
      '401': 'Authentication required',
      '403': 'Administrator access required',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/users',
    summary: 'Create an API user (admin only)',
    description:
        'Usernames are 1-64 characters (letters, digits, dot, underscore, or '
        'hyphen). Passwords must be at least 8 characters and are stored as '
        'bcrypt hashes.',
    auth: ApiAuth.admin,
    jsonBody:
        '{\n  "username": "bob",\n  "password": "a-long-password",\n'
        '  "full_name": "Bob Example",\n  "email": "bob@example.com",\n'
        '  "is_admin": false\n}',
    responses: {
      '201': 'Created user',
      '401': 'Authentication required',
      '403': 'Administrator access required',
      '409': 'Username already exists',
      '422': 'Invalid user fields',
    },
  ),
  ApiEndpoint(
    method: 'PATCH',
    path: '/users/{id}',
    summary: 'Update an API user (admin only)',
    description:
        'Updates any supplied fields. Changing the password or disabled state '
        'revokes the user\'s outstanding tokens. Administrators cannot disable '
        'their own account or remove their own administrator access. Send '
        '`null` or an empty string for `full_name`/`email` to clear it.',
    auth: ApiAuth.admin,
    pathParameters: [
      ApiPathParameter(
        name: 'id',
        description: 'PostgreSQL user id',
      ),
    ],
    jsonBody:
        '{\n  "is_disabled": false,\n  "is_admin": true,\n'
        '  "full_name": "Bob Example",\n  "email": "bob@example.com"\n}',
    responses: {
      '200': 'Updated user',
      '401': 'Authentication required',
      '403': 'Administrator access required',
      '404': 'User not found',
      '422': 'Invalid fields or self-protection rule',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/totp',
    summary: 'TOTP status for the current user',
    auth: ApiAuth.user,
    responses: {
      '200': '`{"enabled": true|false}`',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/totp/setup',
    summary: 'Start TOTP enrollment',
    description:
        'Requires the current password. Returns a base32 secret, an '
        '`otpauth://` provisioning URI, and one-time recovery codes. TOTP stays '
        'disabled until `/totp/enable` accepts the first code. Calling setup '
        'again before enabling replaces the pending secret and codes.',
    auth: ApiAuth.user,
    jsonBody: '{\n  "password": "correct horse battery staple"\n}',
    responses: {
      '200': 'Secret, provisioning URI, and recovery codes',
      '401': 'Authentication required',
      '403': 'Incorrect password',
      '409': 'TOTP is already enabled',
      '422': '`password` is required',
      '429': 'Too many failed attempts',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/totp/enable',
    summary: 'Enable TOTP with the first authenticator code',
    auth: ApiAuth.user,
    jsonBody: '{\n  "code": "123456"\n}',
    responses: {
      '200': '`{"enabled": true}`',
      '401': 'Authentication required',
      '409': 'TOTP is already enabled',
      '422': 'Invalid TOTP code',
      '429': 'Too many failed attempts',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/totp/disable',
    summary: 'Disable TOTP',
    description:
        'Requires the password and a current TOTP code or one of the recovery '
        'codes. Disabling clears the secret and remaining recovery codes.',
    auth: ApiAuth.user,
    jsonBody:
        '{\n  "password": "correct horse battery staple",\n'
        '  "code": "123456"\n}',
    responses: {
      '200': '`{"enabled": false}`',
      '401': 'Authentication required',
      '403': 'Incorrect password or code',
      '422': '`password` and `code` are required',
      '429': 'Too many failed attempts',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/',
    summary: 'Modem and host status',
    description:
        'Returns the AT, CNUM, CSQ, CPIN, CREG, COPS, GPS, data, DNS, APN, and '
        'timezone fields used by the original Python API.',
    auth: ApiAuth.user,
    responses: {
      '200': 'Status fields',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/modem',
    summary: 'Complete modem settings and status report',
    description:
        'Queries a broad SIM7600 catalog covering identity, SIM, network, '
        'packet data, SMS settings, audio, power, GPS, phone state, and the '
        'full `AT&V` settings dump. Returns parsed core values, sectioned raw '
        'responses, and a flat `raw` map. Unsupported commands are included '
        'with their raw error response.',
    auth: ApiAuth.user,
    responses: {
      '200': 'Parsed values plus raw responses for every queried command',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/info',
    summary: 'Host information',
    auth: ApiAuth.user,
    responses: {
      '200': 'Hostname, kernel, date, and architecture',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/gps',
    summary: 'Current GPS fix and Google Maps link',
    description:
        'Returns the raw `+CGPSINFO` response plus parsed latitude, longitude, '
        'altitude, speed, course, and a Google Maps URL when a fix is '
        'available. Coordinates and `maps_url` are null when there is no fix.',
    auth: ApiAuth.user,
    responses: {
      '200': 'GPS fix or null coordinate fields',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/camera/snapshot',
    summary: 'Latest camera JPEG frame',
    description:
        'Returns the most recent captured frame as `image/jpeg`. Capture starts '
        'on demand when needed and stops again after an idle period when no '
        'video clients are connected.',
    auth: ApiAuth.user,
    binaryResponse: true,
    binaryContentType: 'image/jpeg',
    responses: {
      '200': 'JPEG image',
      '401': 'Authentication required',
      '503': 'Camera unavailable or no frame arrived',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/audit',
    summary: 'Recent audit events (admin only)',
    description:
        'Returns the newest persistent audit events first. Events cover '
        'logins, WebSocket authentication, logout, `/at` commands, TOTP '
        'changes, user administration, and audit cleanup. Passwords, TOTP '
        'codes, and secrets are never stored. Defaults to 100 events.',
    auth: ApiAuth.admin,
    queryParameters: [
      ApiQueryParameter(
        name: 'limit',
        type: 'integer',
        description: 'Maximum events to return (1-500).',
        example: '100',
      ),
    ],
    responses: {
      '200': 'Array of audit events',
      '401': 'Authentication required',
      '403': 'Administrator access required',
      '422': 'Invalid limit',
    },
  ),
  ApiEndpoint(
    method: 'DELETE',
    path: '/audit/cleanup',
    summary: 'Delete expired audit events (admin only)',
    description:
        'Deletes events older than `SIMCOM_API_AUDIT_RETENTION_DAYS` and records '
        'the cleanup itself as an audit event.',
    auth: ApiAuth.admin,
    responses: {
      '200': '`{"deleted": <count>}`',
      '401': 'Authentication required',
      '403': 'Administrator access required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/metrics',
    summary: 'Prometheus service metrics',
    description:
        'Returns modem, camera, recognition, video-client, process memory, and '
        'lifecycle-phase metrics in Prometheus text format. Requires a bearer '
        'token.',
    auth: ApiAuth.user,
    responses: {
      '200': 'Prometheus text exposition',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/phone/call',
    summary: 'Place a voice call (admin only)',
    description:
        'Dials `number` through the modem. The number may contain an optional '
        'leading `+` followed by digits.',
    auth: ApiAuth.admin,
    jsonBody: '{\n  "number": "+15551234567"\n}',
    responses: {
      '202': 'Call request accepted',
      '401': 'Authentication required',
      '403': 'Administrator access required',
      '422': 'Invalid phone number',
      '502': 'The modem could not place the call',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/phone/hangup',
    summary: 'Hang up the active call (admin only)',
    auth: ApiAuth.admin,
    responses: {
      '202': 'Call ended',
      '401': 'Authentication required',
      '403': 'Administrator access required',
      '502': 'The modem could not hang up',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/phone/calls',
    summary: 'List active calls (admin only)',
    description: 'Returns the raw `+CLCC` response from the modem.',
    auth: ApiAuth.admin,
    responses: {
      '200': 'Raw active-call response',
      '401': 'Authentication required',
      '403': 'Administrator access required',
      '502': 'The modem could not read active calls',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/sms',
    summary: 'List stored SMS messages',
    description:
        'Returns messages ordered by database id. Optional `limit`, `offset`, '
        'and `q` query parameters page and search the stored rows.',
    auth: ApiAuth.user,
    queryParameters: [
      ApiQueryParameter(
        name: 'limit',
        type: 'integer',
        description: 'Maximum rows to return (1-500).',
        example: '50',
      ),
      ApiQueryParameter(
        name: 'offset',
        type: 'integer',
        description: 'Rows to skip before returning results.',
        example: '0',
      ),
      ApiQueryParameter(
        name: 'q',
        description: 'Search message contents and addresses.',
        example: 'invoice',
      ),
    ],
    responses: {
      '200': 'Messages ordered by database id',
      '401': 'Authentication required',
      '422': 'Invalid pagination or search parameters',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/sms',
    summary: 'Send an SMS message',
    description:
        'The message is stored before it is handed to the modem. If the modem '
        'cannot send it, the stored row is kept and the endpoint returns 502.',
    auth: ApiAuth.user,
    jsonBody:
        '{\n  "number": "+15551234567",\n  "msg": "Hello from Simcom API"\n}',
    responses: {
      '201': 'Message stored and sent',
      '401': 'Authentication required',
      '422': '`number` and `msg` are required',
      '502': 'Message stored but the modem could not send it',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/sms/retry/{id}',
    summary: 'Retry an unsent outgoing message',
    description:
        'Resends a stored `SENT` message whose `is_sent` flag is false. '
        'Already-sent rows are returned unchanged.',
    auth: ApiAuth.user,
    pathParameters: [
      ApiPathParameter(
        name: 'id',
        description: 'PostgreSQL message id',
        example: '1',
      ),
    ],
    responses: {
      '202': 'Message sent',
      '401': 'Authentication required',
      '404': 'Message not found',
      '422': 'Invalid message id',
      '502': 'The modem rejected the message',
    },
  ),
  ApiEndpoint(
    method: 'DELETE',
    path: '/sms/delete/{id}',
    summary: 'Delete a stored message',
    description:
        'Takes the PostgreSQL id, not the SIM message index. Messages that are '
        'still in SIM memory are also deleted from the modem.',
    auth: ApiAuth.user,
    pathParameters: [
      ApiPathParameter(
        name: 'id',
        description: 'PostgreSQL message id',
      ),
    ],
    responses: {
      '202': 'Message deleted',
      '401': 'Authentication required',
      '404': 'Message not found',
      '422': 'Invalid message id',
      '502': 'The modem could not delete the SIM message',
    },
  ),
  ApiEndpoint(
    method: 'DELETE',
    path: '/sms/cleanup/',
    summary: 'Delete read messages from SIM memory',
    auth: ApiAuth.user,
    responses: {
      '202': 'Cleanup finished',
      '401': 'Authentication required',
    },
  ),
  ApiEndpoint(
    method: 'POST',
    path: '/at',
    summary: 'Send a raw AT command (admin only)',
    description:
        'The command is written to the modem and the raw response is returned '
        'as a JSON string. Every call is written to the audit log.',
    auth: ApiAuth.admin,
    jsonBody: '{\n  "cmd": "AT+CSQ"\n}',
    responses: {
      '202': 'Raw modem response',
      '401': 'Authentication required',
      '403': 'Administrator access required',
    },
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/healthz',
    summary: 'Liveness probe',
    responses: {'200': 'Process is running'},
  ),
  ApiEndpoint(
    method: 'GET',
    path: '/readyz',
    summary: 'Readiness probe',
    description: 'Checks that the PostgreSQL connection accepts `SELECT 1`.',
    responses: {
      '200': 'Database is reachable',
      '503': 'Database is unavailable',
    },
  ),
];

/// WebSocket endpoints, documented on the page but not in the OpenAPI paths.
class WebSocketEndpoint {
  const WebSocketEndpoint({
    required this.path,
    required this.summary,
    required this.description,
  });

  final String path;
  final String summary;
  final String description;
}

const webSocketEndpoints = <WebSocketEndpoint>[
  WebSocketEndpoint(
    path: '/wss',
    summary: 'Authenticated echo',
    description:
        'Send `{"type":"auth","token":"<jwt>"}` as the first message. Every '
        'later text message is echoed back. Authentication failures close the '
        'socket with code 1008.',
  ),
  WebSocketEndpoint(
    path: '/wss/video',
    summary: 'Authenticated MJPEG stream',
    description:
        'Authenticate like `/wss`, then receive binary JPEG frames. When no '
        'camera is available the socket closes with code 1011.',
  ),
];

/// Build an OpenAPI 3.1 document from [apiEndpoints].
Map<String, Object?> buildOpenApiDocument() {
  final paths = <String, Map<String, Object?>>{};

  for (final endpoint in apiEndpoints) {
    final operation = <String, Object?>{
      'operationId': endpoint.id,
      'summary': endpoint.summary,
      if (endpoint.description.isNotEmpty) 'description': endpoint.description,
      'responses': {
        for (final response in endpoint.responses.entries)
          response.key: {
            'description': response.value,
            if (endpoint.binaryResponse && response.key == '200')
              'content': {
                endpoint.binaryContentType: {
                  'schema': {'type': 'string', 'format': 'binary'},
                },
              },
          },
      },
      if (endpoint.auth == ApiAuth.none)
        'security': <Object?>[]
      else
        'security': [
          {
            'bearerAuth': <String>[],
          },
        ],
      if (endpoint.pathParameters.isNotEmpty ||
          endpoint.queryParameters.isNotEmpty)
        'parameters': [
          for (final parameter in endpoint.pathParameters)
            {
              'name': parameter.name,
              'in': 'path',
              'required': true,
              'description': parameter.description,
              'schema': {'type': parameter.type},
            },
          for (final parameter in endpoint.queryParameters)
            {
              'name': parameter.name,
              'in': 'query',
              'required': false,
              'description': parameter.description,
              'schema': {'type': parameter.type},
            },
        ],
    };

    if (endpoint.jsonBody != null) {
      operation['requestBody'] = {
        'required': true,
        'content': {
          _jsonHeaders: {
            'schema': {'type': 'object'},
            'example': jsonDecode(endpoint.jsonBody!),
          },
        },
      };
    } else if (endpoint.formFields.isNotEmpty) {
      operation['requestBody'] = {
        'required': true,
        'content': {
          'application/x-www-form-urlencoded': {
            'schema': {
              'type': 'object',
              'required': [
                for (final field in endpoint.formFields)
                  if (field.required) field.name,
              ],
              'properties': {
                for (final field in endpoint.formFields)
                  field.name: {
                    'type': field.type,
                    if (field.description.isNotEmpty)
                      'description': field.description,
                  },
              },
            },
          },
        },
      };
    }

    final methods = paths.putIfAbsent(
      endpoint.path,
      () => <String, Object?>{},
    );
    methods[endpoint.method.toLowerCase()] = operation;
  }

  return {
    'openapi': '3.1.0',
    'info': {
      'title': 'Simcom API',
      'version': '1.0.0',
      'description':
          'SIM7600 modem, SMS, GPS, host information, and camera service. '
          'Authenticate with `POST /token` and send the token as '
          '`Authorization: Bearer <token>`.',
    },
    'servers': [
      {'url': '/'},
    ],
    'paths': paths,
    'components': {
      'securitySchemes': {
        'bearerAuth': {
          'type': 'http',
          'scheme': 'bearer',
          'bearerFormat': 'JWT',
        },
      },
    },
  };
}

/// Pretty-printed OpenAPI JSON, as served by `GET /openapi.json`.
String buildOpenApiJson() =>
    const JsonEncoder.withIndent('  ').convert(buildOpenApiDocument());
