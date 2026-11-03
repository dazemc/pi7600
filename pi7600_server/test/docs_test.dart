import 'dart:convert';

import 'package:pi7600_server/src/config/app_config.dart';
import 'package:pi7600_server/src/web/docs/api_catalog.dart';
import 'package:pi7600_server/src/web/docs/docs_page.dart';
import 'package:test/test.dart';

void main() {
  group('OpenAPI document', () {
    test('contains every HTTP operation in the contract', () {
      final document = buildOpenApiDocument();
      final paths = document['paths'] as Map<String, Object?>;

      expect(
        paths.keys,
        containsAll([
          '/token',
          '/',
          '/info',
          '/sms',
          '/sms/delete/{id}',
          '/sms/cleanup/',
          '/at',
          '/healthz',
          '/readyz',
        ]),
      );

      final sms = paths['/sms'] as Map<String, Object?>;
      expect(sms.keys, containsAll(['get', 'post']));

      final delete = paths['/sms/delete/{id}'] as Map<String, Object?>;
      final deleteOperation = delete['delete'] as Map<String, Object?>;
      final parameters = deleteOperation['parameters'] as List<Object?>;
      expect(parameters, hasLength(1));
      expect((parameters.single as Map<String, Object?>)['name'], 'id');
    });

    test('marks public and protected endpoints with the right security', () {
      final document = buildOpenApiDocument();
      final paths = document['paths'] as Map<String, Object?>;

      final token = paths['/token'] as Map<String, Object?>;
      final tokenOperation = token['post'] as Map<String, Object?>;
      expect(tokenOperation['security'], isEmpty);

      final at = paths['/at'] as Map<String, Object?>;
      final atOperation = at['post'] as Map<String, Object?>;
      expect(atOperation['security'], [
        {
          'bearerAuth': <String>[],
        },
      ]);
    });

    test('is valid JSON with an OpenAPI version', () {
      final decoded = jsonDecode(buildOpenApiJson()) as Map<String, dynamic>;
      expect(decoded['openapi'], '3.1.0');
      expect(decoded['info'], isA<Map<String, dynamic>>());
      expect(decoded['components'], isA<Map<String, dynamic>>());
    });
  });

  group('docs page', () {
    test('renders the explorer shell and endpoint controls', () async {
      final html = utf8.decode(await renderDocsPage());

      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<title>Pi7600 API docs</title>'));
      expect(html, contains('/docs/style.css'));
      expect(html, contains('/docs/app.js'));

      expect(html, contains('data-method="GET"'));
      expect(html, contains('data-method="DELETE"'));
      expect(html, contains('data-path="/sms/delete/{id}"'));
      expect(html, contains('data-auth="admin"'));
      expect(html, contains('class="method method-get"'));
      expect(html, contains('data-param="id"'));
      expect(html, contains('data-json'));
      expect(html, contains('data-form="username"'));
      expect(html, contains('Execute'));

      expect(html, contains('WebSocket endpoints'));
      expect(html, contains('/wss/video'));
    });

    test('serves JavaScript with try-it-out behaviour', () {
      expect(docsJs, contains("querySelectorAll('[data-param]')"));
      expect(docsJs, contains("querySelector('textarea[data-json]')"));
      expect(docsJs, contains("querySelectorAll('[data-form]')"));
      expect(docsJs, contains("headers['Authorization']"));
      expect(docsJs, contains("method: method"));
    });

    test('serves method colour styles', () {
      expect(docsCss, contains('.method-get'));
      expect(docsCss, contains('.method-post'));
      expect(docsCss, contains('.method-delete'));
    });
  });

  group('AppConfig docs flag', () {
    test('docs are enabled by default', () {
      final config = AppConfig.fromEnvironment({});
      expect(config.docsEnabled, isTrue);
    });

    test('docs can be disabled', () {
      final config = AppConfig.fromEnvironment({
        'PI7600_DOCS_ENABLED': 'false',
      });
      expect(config.docsEnabled, isFalse);
    });

    test('accepts common truthy values', () {
      for (final value in ['1', 'true', 'yes', 'on', 'TRUE']) {
        final config = AppConfig.fromEnvironment({
          'PI7600_DOCS_ENABLED': value,
        });
        expect(config.docsEnabled, isTrue, reason: value);
      }
    });
  });
}
