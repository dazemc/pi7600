/// Static description of the Pi7600 HTTP API.
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
    this.responses = const {},
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

  /// Response status code to description.
  final Map<String, String> responses;
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

/// Every HTTP operation in the Pi7600 contract.
const apiEndpoints = <ApiEndpoint>[
  ApiEndpoint(
    method: 'POST',
    path: '/token',
    summary: 'Exchange credentials for a JWT',
    description:
        'Send `username` and `password` as an '
        '`application/x-www-form-urlencoded` body. The returned token is valid '
        'for the configured JWT lifetime (30 minutes by default).',
    formFields: [
      ApiFormField(name: 'username', example: 'alice'),
      ApiFormField(
        name: 'password',
        example: 'correct horse battery staple',
        description: 'Plaintext password; it is verified with bcrypt.',
      ),
    ],
    responses: {
      '200': 'A bearer token',
      '401': 'Incorrect username or password',
      '422': 'Missing username or password',
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
    path: '/sms',
    summary: 'List stored SMS messages',
    auth: ApiAuth.user,
    responses: {
      '200': 'Messages ordered by database id',
      '401': 'Authentication required',
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
    jsonBody: '{\n  "number": "+15551234567",\n  "msg": "Hello from Pi7600"\n}',
    responses: {
      '201': 'Message stored and sent',
      '401': 'Authentication required',
      '422': '`number` and `msg` are required',
      '502': 'Message stored but the modem could not send it',
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
          response.key: {'description': response.value},
      },
      if (endpoint.auth == ApiAuth.none)
        'security': <Object?>[]
      else
        'security': [
          {
            'bearerAuth': <String>[],
          },
        ],
      if (endpoint.pathParameters.isNotEmpty)
        'parameters': [
          for (final parameter in endpoint.pathParameters)
            {
              'name': parameter.name,
              'in': 'path',
              'required': true,
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
      'title': 'Pi7600 API',
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
