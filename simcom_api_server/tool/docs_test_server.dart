import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:simcom_api_server/src/web/docs/docs_client.dart';
import 'package:simcom_api_server/src/web/docs/docs_page.dart';

/// Minimal fake API used by the browser docs smoke test.
///
/// It serves the real `/docs` page and compiled client, plus fake `/token` and
/// `/info` endpoints. No PostgreSQL, modem, or camera is required.
Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['DOCS_TEST_PORT'] ?? '') ?? 8099;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('Docs test server: http://127.0.0.1:$port/docs');

  await for (final request in server) {
    unawaited(_handle(request));
  }
}

Future<void> _handle(HttpRequest request) async {
  try {
    final path = request.uri.path;
    if (path == '/docs' && request.method == 'GET') {
      final body = await renderDocsPage();
      await _bytes(request.response, body, ContentType.html);
      return;
    }
    if (path == '/docs/style.css' && request.method == 'GET') {
      await _bytes(
        request.response,
        utf8.encode(docsCss),
        ContentType('text', 'css', charset: 'utf-8'),
      );
      return;
    }
    if (path == '/docs/app.js' && request.method == 'GET') {
      final body = await loadDocsClientBundle();
      if (body == null) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await _json(request.response, {'detail': 'docs client not built'});
        return;
      }
      await _bytes(
        request.response,
        body,
        ContentType('text', 'javascript', charset: 'utf-8'),
      );
      return;
    }
    if (path == '/token' && request.method == 'POST') {
      final body = await utf8.decoder.bind(request).join();
      final form = Uri.splitQueryString(body);
      if (form['username'] == 'alice' && form['password'] == 'secret') {
        await _json(request.response, {
          'access_token': _tokenFor('alice'),
          'token_type': 'bearer',
        });
        return;
      }
      request.response.statusCode = HttpStatus.unauthorized;
      await _json(request.response, {
        'detail': 'Incorrect username or password',
      });
      return;
    }
    if (path == '/info' && request.method == 'GET') {
      if (!_authorized(
        request.headers.value(HttpHeaders.authorizationHeader),
      )) {
        request.response.statusCode = HttpStatus.unauthorized;
        await _json(request.response, {'detail': 'Not authenticated'});
        return;
      }
      await _json(request.response, {
        'hostname': 'docs-test',
        'uname': 'test-kernel',
        'date': 'Tue Nov 3 00:00:00 UTC 2026',
        'arch': 'x86_64',
      });
      return;
    }
    if (path == '/gps' && request.method == 'GET') {
      if (!_authorized(
        request.headers.value(HttpHeaders.authorizationHeader),
      )) {
        request.response.statusCode = HttpStatus.unauthorized;
        await _json(request.response, {'detail': 'Not authenticated'});
        return;
      }
      await _json(request.response, {
        'raw':
            '+CGPSINFO: 1234.5678,N,12345.6789,W,031126,120000.00,12.3,0.5,90.0',
        'latitude': 12.57613,
        'longitude': -123.761315,
        'date': '031126',
        'time': '120000.00',
        'altitude': 12.3,
        'speed_knots': 0.5,
        'course_degrees': 90.0,
        'maps_url':
            'https://www.google.com/maps/search/?api=1&query=12.57613,-123.761315',
      });
      return;
    }
    if (path == '/healthz') {
      await _json(request.response, {'status': 'ok'});
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await _json(request.response, {'detail': 'Not found'});
  } on Object catch (error) {
    try {
      request.response.statusCode = HttpStatus.internalServerError;
      await _json(request.response, {'detail': '$error'});
    } on Object {
      // The response may already be committed.
    }
  }
}

bool _authorized(String? header) {
  if (header == null || !header.startsWith('Bearer ')) return false;
  final token = header.substring('Bearer '.length).trim();
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    return payload is Map && payload['sub'] == 'alice';
  } on Object {
    return false;
  }
}

String _tokenFor(String subject) {
  final header = _encode({'alg': 'RS256', 'typ': 'JWT'});
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final payload = _encode({
    'sub': subject,
    'iat': now,
    'exp': now + 1800,
    'iss': 'docs.test',
  });
  return '$header.$payload.signature';
}

String _encode(Map<String, Object?> value) {
  return base64Url.encode(utf8.encode(jsonEncode(value)));
}

Future<void> _json(HttpResponse response, Object value) async {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  await response.close();
}

Future<void> _bytes(
  HttpResponse response,
  List<int> body,
  ContentType contentType,
) async {
  response.headers.contentType = contentType;
  response.add(body);
  await response.close();
}
