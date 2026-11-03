import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:simcom_api_server/src/web/docs/api_catalog.dart';
import 'package:universal_web/web.dart' as web;

/// Key used to keep the JWT in browser storage.
const docsTokenKey = 'pi7600.docs.token';

/// The interactive `/docs` application.
///
/// The same component tree is rendered on the server and mounted in the
/// browser. State that only exists in the browser (the stored token) is read
/// in [State.initState], which is a no-op during server-side rendering.
class DocsApp extends StatefulComponent {
  const DocsApp({super.key});

  @override
  State<DocsApp> createState() => _DocsAppState();
}

class _DocsAppState extends State<DocsApp> {
  final GlobalNodeKey<web.HTMLInputElement> _usernameKey = GlobalNodeKey();
  final GlobalNodeKey<web.HTMLInputElement> _passwordKey = GlobalNodeKey();

  String? _token;
  String _username = '';
  String _password = '';
  String _loginStatus = '';
  bool _loginError = false;
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _token = _readToken();
  }

  String? _readToken() {
    if (!kIsWeb) return null;
    try {
      final value = web.window.localStorage.getItem(docsTokenKey);
      return value == null || value.isEmpty ? null : value;
    } on Object {
      return null;
    }
  }

  void _storeToken(String? token) {
    if (!kIsWeb) return;
    try {
      if (token == null || token.isEmpty) {
        web.window.localStorage.removeItem(docsTokenKey);
      } else {
        web.window.localStorage.setItem(docsTokenKey, token);
      }
    } on Object {
      // Browser storage can be unavailable (private mode, disabled cookies).
      // The page still works for the current in-memory session.
    }
  }

  String _decodeSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return '';
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final decoded = utf8.decode(base64.decode(payload));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic> && json['sub'] is String) {
        return json['sub'] as String;
      }
    } on Object {
      // A malformed token is treated as an anonymous session.
    }
    return '';
  }

  String get _sessionLabel {
    final token = _token;
    if (token == null) return '';
    final subject = _decodeSubject(token);
    return subject.isEmpty ? 'Signed in' : 'Signed in as $subject';
  }

  Future<void> _login() async {
    if (_signingIn) return;

    // Read the live DOM values as well as the component state so browser
    // password managers and autofill work even when they do not emit input
    // events.
    final username = (_usernameKey.currentNode?.value ?? _username).trim();
    final password = _passwordKey.currentNode?.value ?? _password;
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _loginStatus = 'Enter a username and password.';
        _loginError = true;
      });
      return;
    }

    setState(() {
      _signingIn = true;
      _loginStatus = '';
      _loginError = false;
    });

    try {
      final response = await http.post(
        Uri.base.resolve('/token'),
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      );

      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } on Object {
        // The error response may not be JSON.
      }

      final token = data?['access_token'];
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          token is! String ||
          token.isEmpty) {
        final detail = data?['detail'];
        setState(() {
          _loginStatus = detail is String
              ? detail
              : 'Login failed (HTTP ${response.statusCode})';
          _loginError = true;
          _signingIn = false;
        });
        return;
      }

      _storeToken(token);
      setState(() {
        _token = token;
        _password = '';
        _signingIn = false;
        _loginStatus = '';
        _loginError = false;
      });
    } on Object catch (error) {
      setState(() {
        _loginStatus = 'Network error: $error';
        _loginError = true;
        _signingIn = false;
      });
    }
  }

  void _logout() {
    _storeToken(null);
    setState(() {
      _token = null;
      _password = '';
      _loginStatus = 'Signed out.';
      _loginError = false;
    });
    scheduleMicrotask(() {
      if (mounted) _usernameKey.currentNode?.focus();
    });
  }

  void _sessionExpired() {
    if (_token == null) return;
    _storeToken(null);
    setState(() {
      _token = null;
      _password = '';
      _loginStatus = 'Session expired. Sign in again.';
      _loginError = true;
    });
  }

  @override
  Component build(BuildContext context) {
    return Component.fragment([
      _topbar(),
      _authBar(),
      main_([
        div(classes: 'layout', [
          _intro(),
          h2(classes: 'section-title', [Component.text('HTTP endpoints')]),
          for (final endpoint in apiEndpoints)
            _EndpointCard(
              endpoint,
              token: _token,
              onUnauthorized: _sessionExpired,
            ),
          h2(classes: 'section-title', [Component.text('WebSocket endpoints')]),
          for (final endpoint in webSocketEndpoints) _WebSocketCard(endpoint),
        ]),
        footer(classes: 'footer', [
          Component.text(
            'Pi7600 - interactive reference generated from the live API '
            'catalog.',
          ),
        ]),
      ]),
    ]);
  }

  Component _topbar() {
    return header(classes: 'topbar', [
      div([
        h1([Component.text('Pi7600 API')]),
        p([
          Component.text(
            'SIM7600 modem, SMS, GPS, host information, and camera service.',
          ),
        ]),
      ]),
      nav([
        a([Component.text('OpenAPI schema')], href: '/openapi.json'),
        a([Component.text('Liveness')], href: '/healthz'),
        a([Component.text('Readiness')], href: '/readyz'),
      ]),
    ]);
  }

  Component _authBar() {
    final signedIn = _token != null;
    return section(classes: 'auth-bar', [
      form(
        [
          label([Component.text('Username')], htmlFor: 'username'),
          input<String>(
            key: _usernameKey,
            type: InputType.text,
            id: 'username',
            name: 'username',
            value: _username,
            onInput: (value) => setState(() => _username = value),
            attributes: const {
              'autocomplete': 'username',
              'required': '',
              'spellcheck': 'false',
            },
          ),
          label([Component.text('Password')], htmlFor: 'password'),
          input<String>(
            key: _passwordKey,
            type: InputType.password,
            id: 'password',
            name: 'password',
            value: _password,
            onInput: (value) => setState(() => _password = value),
            attributes: const {
              'autocomplete': 'current-password',
              'required': '',
            },
          ),
          button(
            [Component.text(_signingIn ? 'Signing in...' : 'Login')],
            type: ButtonType.submit,
            disabled: _signingIn,
            classes: 'primary',
          ),
        ],
        id: 'login-form',
        classes: 'login-form',
        attributes: signedIn ? const {'hidden': ''} : const {},
        events: {
          'submit': (event) {
            event.preventDefault();
            unawaited(_login());
          },
        },
      ),
      div(
        [
          span(
            [Component.text(_sessionLabel)],
            id: 'session-status',
            classes: 'muted',
          ),
          button(
            [Component.text('Logout')],
            id: 'logout',
            type: ButtonType.button,
            onClick: _logout,
          ),
        ],
        id: 'session',
        classes: 'session',
        attributes: signedIn ? const {} : const {'hidden': ''},
      ),
      span(
        [Component.text(_loginStatus)],
        id: 'login-status',
        classes: _loginError ? 'muted error-text' : 'muted',
      ),
    ]);
  }

  Component _intro() {
    return section(classes: 'intro', [
      h2([Component.text('Try the API')]),
      p([
        Component.text(
          'Sign in above with your Pi7600 username and password. The page '
          'exchanges them for a JWT with ',
        ),
        code([Component.text('POST /token')]),
        Component.text(
          ' and keeps only the token in this browser. Then expand an endpoint '
          'and press Execute. Requests are sent from this browser to the same '
          'origin, so the existing CORS and authentication rules apply.',
        ),
      ]),
      p([
        Component.text(
          'This page is a convenience client. It does not bypass any checks: '
          'admin-only endpoints still return 403 without an administrator '
          'account.',
        ),
      ]),
    ]);
  }
}

class _EndpointCard extends StatefulComponent {
  const _EndpointCard(
    this.endpoint, {
    required this.token,
    required this.onUnauthorized,
  });

  final ApiEndpoint endpoint;
  final String? token;
  final VoidCallback onUnauthorized;

  @override
  State<_EndpointCard> createState() => _EndpointCardState();
}

class _EndpointCardState extends State<_EndpointCard> {
  final GlobalNodeKey<web.HTMLDetailsElement> _detailsKey = GlobalNodeKey();

  late final Map<String, String> _pathValues;
  late String _jsonBody;
  late final Map<String, String> _formValues;

  bool _open = false;
  String? _resultStatus;
  String _resultText = '';
  int? _resultCode;
  bool _executing = false;

  @override
  void initState() {
    super.initState();
    _pathValues = {
      for (final parameter in component.endpoint.pathParameters)
        parameter.name: parameter.example,
    };
    _jsonBody = component.endpoint.jsonBody ?? '';
    _formValues = {
      for (final field in component.endpoint.formFields)
        field.name: field.example,
    };
  }

  String get _resultClass {
    final status = _resultCode;
    if (status == null) return 'network';
    return status >= 200 && status < 300 ? 'ok' : 'error';
  }

  Future<void> _execute() async {
    if (_executing) return;

    final endpoint = component.endpoint;
    final headers = <String, String>{};
    String? body;

    if (endpoint.jsonBody != null) {
      final raw = _jsonBody.trim();
      if (raw.isNotEmpty) {
        try {
          jsonDecode(raw);
        } on Object catch (error) {
          _showResult(null, 'Invalid JSON: $error');
          return;
        }
        headers['Content-Type'] = 'application/json';
        body = raw;
      }
    }

    if (endpoint.formFields.isNotEmpty) {
      final params = <String, String>{};
      for (final field in endpoint.formFields) {
        final value = _formValues[field.name] ?? '';
        if (value.isNotEmpty) params[field.name] = value;
      }
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      body = Uri(queryParameters: params).query;
    }

    final token = component.token;
    if (token != null && token.isNotEmpty && endpoint.auth != ApiAuth.none) {
      headers['Authorization'] = 'Bearer $token';
    }

    var path = endpoint.path;
    for (final parameter in endpoint.pathParameters) {
      final value = (_pathValues[parameter.name] ?? '').trim();
      path = path.replaceFirst(
        '{${parameter.name}}',
        Uri.encodeComponent(value.isEmpty ? parameter.example : value),
      );
    }

    final stopwatch = Stopwatch()..start();
    setState(() => _executing = true);

    final client = http.Client();
    try {
      final request = http.Request(endpoint.method, Uri.base.resolve(path));
      request.headers.addAll(headers);
      if (body != null) request.body = body;

      final response = await http.Response.fromStream(
        await client.send(request),
      );
      stopwatch.stop();

      if (response.statusCode == 401 && endpoint.auth != ApiAuth.none) {
        component.onUnauthorized();
      }

      var pretty = response.body;
      try {
        pretty = const JsonEncoder.withIndent('  ').convert(
          jsonDecode(response.body),
        );
      } on Object {
        // Non-JSON responses are shown verbatim.
      }
      _showResult(response.statusCode, pretty, stopwatch.elapsedMilliseconds);
    } on Object catch (error) {
      stopwatch.stop();
      _showResult(
        null,
        'Network error: $error',
        stopwatch.elapsedMilliseconds,
      );
    } finally {
      client.close();
      if (mounted) setState(() => _executing = false);
    }
  }

  void _showResult(int? status, String text, [int? elapsed]) {
    if (!mounted) return;
    setState(() {
      _resultCode = status;
      _resultStatus = status == null
          ? 'Request failed'
          : 'HTTP $status${elapsed == null ? '' : ' - $elapsed ms'}';
      _resultText = text;
    });
  }

  @override
  Component build(BuildContext context) {
    final endpoint = component.endpoint;
    final method = endpoint.method.toLowerCase();
    final hasBody = endpoint.jsonBody != null || endpoint.formFields.isNotEmpty;
    // Prefer the live DOM value so a state update triggered by typing cannot
    // close a section before the asynchronous `toggle` event has updated
    // [_open].
    final open = _detailsKey.currentNode?.open ?? _open;

    return details(
      key: _detailsKey,
      open: open,
      classes: 'endpoint',
      attributes: {
        'id': 'op-${endpoint.id}',
        'data-method': endpoint.method,
        'data-path': endpoint.path,
        'data-auth': endpoint.auth.name,
      },
      events: {
        'toggle': (_) {
          final node = _detailsKey.currentNode;
          if (node == null || node.open == _open) return;
          setState(() => _open = node.open);
        },
      },
      [
        summary([
          span([
            Component.text(endpoint.method),
          ], classes: 'method method-$method'),
          code([Component.text(endpoint.path)], classes: 'path'),
          span([Component.text(endpoint.summary)], classes: 'summary'),
          _authBadge(endpoint.auth),
        ]),
        div(classes: 'endpoint-body', [
          if (endpoint.description.isNotEmpty)
            p([Component.text(endpoint.description)], classes: 'description'),
          if (endpoint.pathParameters.isNotEmpty) ...[
            h4(classes: 'section-title', [Component.text('Path parameters')]),
            div(classes: 'field-grid', [
              for (final parameter in endpoint.pathParameters)
                div(classes: 'field', [
                  label([
                    Component.text(parameter.name),
                    span([
                      Component.text(' ${parameter.type}'),
                    ], classes: 'hint'),
                  ]),
                  input<String>(
                    type: InputType.text,
                    value: _pathValues[parameter.name] ?? parameter.example,
                    onInput: (value) =>
                        setState(() => _pathValues[parameter.name] = value),
                    attributes: {
                      'data-param': parameter.name,
                      'placeholder': parameter.example,
                      'autocomplete': 'off',
                    },
                  ),
                ]),
            ]),
          ],
          if (endpoint.jsonBody != null) ...[
            div(classes: 'field', [
              label([
                Component.text('JSON body'),
                span([Component.text(' application/json')], classes: 'hint'),
              ]),
              textarea(
                [Component.text(_jsonBody)],
                rows: 7,
                onInput: (value) => setState(() => _jsonBody = value),
                attributes: const {
                  'data-json': '',
                  'spellcheck': 'false',
                },
              ),
            ]),
          ],
          if (endpoint.formFields.isNotEmpty) ...[
            h4(classes: 'section-title', [
              Component.text('Form fields'),
            ]),
            div(classes: 'field-grid', [
              for (final field in endpoint.formFields)
                div(classes: 'field', [
                  label([
                    Component.text(field.name),
                    if (field.description.isNotEmpty)
                      span([
                        Component.text(' ${field.description}'),
                      ], classes: 'hint'),
                  ]),
                  input<String>(
                    type: field.name.toLowerCase().contains('password')
                        ? InputType.password
                        : InputType.text,
                    value: _formValues[field.name] ?? field.example,
                    onInput: (value) =>
                        setState(() => _formValues[field.name] = value),
                    attributes: {
                      'data-form': field.name,
                      'placeholder': field.example,
                      'autocomplete': 'off',
                    },
                  ),
                ]),
            ]),
          ],
          if (endpoint.responses.isNotEmpty) _responses(),
          div(classes: 'actions', [
            button(
              [Component.text(_executing ? 'Executing...' : 'Execute')],
              type: ButtonType.button,
              classes: 'execute primary',
              disabled: _executing,
              onClick: () => unawaited(_execute()),
            ),
            if (!hasBody && endpoint.pathParameters.isEmpty)
              span([Component.text('No request body')], classes: 'muted'),
          ]),
          div(
            [
              div([
                Component.text(_resultStatus ?? ''),
              ], classes: 'result-status $_resultClass'),
              pre([Component.text(_resultText)], classes: 'result'),
            ],
            classes: 'result-wrap',
            attributes: _resultStatus == null ? const {'hidden': ''} : const {},
          ),
        ]),
      ],
    );
  }

  Component _responses() {
    return div(classes: 'responses', [
      h4([Component.text('Responses')]),
      ul([
        for (final response in component.endpoint.responses.entries)
          li([
            span([Component.text(response.key)], classes: 'code'),
            Component.text(response.value),
          ]),
      ]),
    ]);
  }
}

class _WebSocketCard extends StatelessComponent {
  const _WebSocketCard(this.endpoint);

  final WebSocketEndpoint endpoint;

  @override
  Component build(BuildContext context) {
    return div(classes: 'ws-card', [
      h3([
        code([Component.text(endpoint.path)], classes: 'path'),
        Component.text(' - ${endpoint.summary}'),
      ]),
      p([Component.text(endpoint.description)]),
    ]);
  }
}

Component _authBadge(ApiAuth auth) {
  return switch (auth) {
    ApiAuth.none => span([Component.text('public')], classes: 'badge'),
    ApiAuth.user => span([Component.text('bearer')], classes: 'badge user'),
    ApiAuth.admin => span([Component.text('admin')], classes: 'badge admin'),
  };
}
