@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:simcom_api_server/src/config/app_config.dart';
import 'package:simcom_api_server/src/web/docs/api_catalog.dart';
import 'package:simcom_api_server/src/web/docs/docs_client.dart';
import 'package:simcom_api_server/src/web/docs/docs_page.dart';
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
          '/gps',
          '/camera/snapshot',
          '/metrics',
          '/phone/call',
          '/phone/hangup',
          '/phone/calls',
          '/sms',
          '/sms/retry/{id}',
          '/sms/delete/{id}',
          '/sms/cleanup/',
          '/at',
          '/healthz',
          '/readyz',
        ]),
      );

      final sms = paths['/sms'] as Map<String, Object?>;
      expect(sms.keys, containsAll(['get', 'post']));
      final smsGet = sms['get'] as Map<String, Object?>;
      final smsParameters = (smsGet['parameters'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        smsParameters.map((parameter) => parameter['name']),
        containsAll(['limit', 'offset', 'q']),
      );

      final delete = paths['/sms/delete/{id}'] as Map<String, Object?>;
      final deleteOperation = delete['delete'] as Map<String, Object?>;
      final parameters = deleteOperation['parameters'] as List<Object?>;
      expect(parameters, hasLength(1));
      expect((parameters.single as Map<String, Object?>)['name'], 'id');

      final snapshot = paths['/camera/snapshot'] as Map<String, Object?>;
      final snapshotGet = snapshot['get'] as Map<String, Object?>;
      final responses = snapshotGet['responses'] as Map<String, Object?>;
      final ok = responses['200'] as Map<String, Object?>;
      expect(
        (ok['content'] as Map<String, Object?>).keys,
        contains('image/jpeg'),
      );
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
      expect(html, contains('data-path="/gps"'));
      expect(html, contains('data-path="/camera/snapshot"'));
      expect(html, contains('data-path="/sms/delete/{id}"'));
      expect(html, contains('data-auth="admin"'));
      expect(html, contains('class="method method-get"'));
      expect(html, contains('data-param="id"'));
      expect(html, contains('data-query="limit"'));
      expect(html, contains('data-json'));
      expect(html, contains('data-form="username"'));
      expect(html, contains('Execute'));

      expect(html, contains('id="login-form"'));
      expect(html, contains('id="username"'));
      expect(html, contains('id="password"'));
      expect(html, contains('id="logout"'));
      expect(html, contains('id="session"'));

      expect(html, contains('WebSocket endpoints'));
      expect(html, contains('/wss/video'));
    });

    test('loads a compiled client bundle from an explicit path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pi7600-docs-bundle-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(p.join(directory.path, 'app.js'));
      await file.writeAsString('console.log("pi7600 docs");');

      final bytes = await loadDocsClientBundle(path: file.path);
      expect(utf8.decode(bytes!), contains('pi7600 docs'));

      final missing = await loadDocsClientBundle(
        path: p.join(directory.path, 'missing.js'),
      );
      expect(missing, isNull);
    });

    test('serves method colour and hidden-state styles', () {
      expect(docsCss, contains('.method-get'));
      expect(docsCss, contains('.method-post'));
      expect(docsCss, contains('.method-delete'));
      expect(docsCss, contains('.login-form[hidden]'));
      expect(docsCss, contains('.session[hidden]'));
    });
  });

  group('docs client', () {
    late Directory tempDir;
    late File bundle;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('pi7600-docs-client-');
      bundle = File(p.join(tempDir.path, 'app.js'));
      final root = _packageRoot();

      final result = await Process.run(
        Platform.resolvedExecutable,
        [
          'compile',
          'js',
          '-O2',
          '--no-source-maps',
          '-o',
          bundle.path,
          p.join('lib', 'src', 'web', 'docs', 'docs_app.client.dart'),
        ],
        workingDirectory: root,
      );

      if (result.exitCode != 0) {
        fail(
          'Failed to compile the Jaspr docs client '
          '(${result.exitCode}):\n${result.stdout}\n${result.stderr}',
        );
      }
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('compiles the Jaspr app to a browser bundle', () {
      final js = bundle.readAsStringSync();

      expect(js, isNotEmpty);
      expect(js, contains('pi7600.docs.token'));
      expect(js, contains('access_token'));
      expect(js, contains('Authorization'));
      expect(js, contains('Session expired'));
      expect(js, contains('Executing...'));
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

String _packageRoot() {
  final current = Directory.current;
  for (final candidate in [
    current.path,
    p.join(current.path, 'simcom_api_server'),
  ]) {
    final entrypoint = p.join(
      candidate,
      'lib',
      'src',
      'web',
      'docs',
      'docs_app.client.dart',
    );
    if (File(entrypoint).existsSync()) return candidate;
  }

  throw StateError(
    'Could not locate the simcom_api_server package root from ${current.path}.',
  );
}
