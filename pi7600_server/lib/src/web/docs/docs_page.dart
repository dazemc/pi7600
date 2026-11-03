import 'dart:typed_data';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:pi7600_server/src/web/docs/api_catalog.dart';

/// Stylesheet served at `/docs/style.css`.
const docsCss = r'''
:root {
  --bg: #f6f7f9;
  --surface: #ffffff;
  --border: #e2e5ea;
  --text: #1f2430;
  --muted: #6b7280;
  --brand: #0b3d2e;
  --brand-soft: #e6f2ee;
  --get: #1d6fd8;
  --post: #128a4b;
  --delete: #c03434;
  --put: #b26a00;
  --patch: #7a3bb5;
  --code-bg: #0f172a;
  --code-text: #e2e8f0;
}

* { box-sizing: border-box; }

html, body {
  margin: 0;
  padding: 0;
  background: var(--bg);
  color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica,
    Arial, sans-serif;
  line-height: 1.55;
}

a { color: var(--get); text-decoration: none; }
a:hover { text-decoration: underline; }

.topbar {
  background: var(--brand);
  color: #f4fbf8;
  padding: 1.1rem 1.5rem;
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  align-items: center;
  justify-content: space-between;
}

.topbar h1 {
  margin: 0;
  font-size: 1.35rem;
  letter-spacing: 0.01em;
}

.topbar p { margin: 0.15rem 0 0; color: #bfe0d4; font-size: 0.88rem; }
.topbar nav { display: flex; gap: 1rem; font-size: 0.9rem; }
.topbar nav a { color: #d9f2e9; }

.auth-bar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  align-items: center;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  padding: 0.75rem 1.5rem;
  position: sticky;
  top: 0;
  z-index: 10;
}

.auth-bar label { font-weight: 600; font-size: 0.85rem; }
.auth-bar input {
  flex: 1 1 18rem;
  min-width: 12rem;
  padding: 0.45rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  font: inherit;
  font-size: 0.85rem;
}

.muted { color: var(--muted); font-size: 0.82rem; }

button {
  font: inherit;
  cursor: pointer;
  border: 1px solid var(--border);
  background: var(--surface);
  color: var(--text);
  border-radius: 6px;
  padding: 0.4rem 0.75rem;
  font-size: 0.85rem;
}
button:hover { background: #f0f2f5; }
button.primary { background: var(--brand); border-color: var(--brand); color: #fff; }
button.primary:hover { background: #0f513b; }
button:disabled { opacity: 0.6; cursor: progress; }

.layout {
  max-width: 1100px;
  margin: 0 auto;
  padding: 1.5rem;
}

.intro {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 1rem 1.25rem;
  margin-bottom: 1.25rem;
}
.intro h2 { margin: 0 0 0.35rem; font-size: 1.05rem; }
.intro p { margin: 0.3rem 0; color: var(--muted); font-size: 0.9rem; }
.intro code { background: #eef1f4; padding: 0.1rem 0.3rem; border-radius: 4px; }

.section-title {
  font-size: 0.78rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--muted);
  margin: 1.6rem 0 0.6rem;
}

.endpoint {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  margin-bottom: 0.55rem;
  overflow: hidden;
}
.endpoint[open] { box-shadow: 0 2px 10px rgba(15, 23, 42, 0.06); }

.endpoint > summary {
  list-style: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.65rem;
  padding: 0.6rem 0.85rem;
  flex-wrap: wrap;
}
.endpoint > summary::-webkit-details-marker { display: none; }
.endpoint > summary:hover { background: #fafbfc; }

.method {
  display: inline-block;
  min-width: 4.1rem;
  text-align: center;
  color: #fff;
  font-weight: 700;
  font-size: 0.72rem;
  letter-spacing: 0.04em;
  padding: 0.18rem 0.45rem;
  border-radius: 4px;
}
.method-get { background: var(--get); }
.method-post { background: var(--post); }
.method-delete { background: var(--delete); }
.method-put { background: var(--put); }
.method-patch { background: var(--patch); }

.endpoint .path {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.88rem;
  font-weight: 600;
}
.endpoint .summary { color: var(--muted); font-size: 0.85rem; flex: 1 1 14rem; }

.badge {
  font-size: 0.7rem;
  padding: 0.12rem 0.42rem;
  border-radius: 999px;
  border: 1px solid var(--border);
  color: var(--muted);
  white-space: nowrap;
}
.badge.admin { background: #fff4e5; border-color: #f0d3a8; color: #8a5a00; }
.badge.user { background: var(--brand-soft); border-color: #bfe0d4; color: var(--brand); }

.endpoint-body {
  border-top: 1px solid var(--border);
  padding: 0.9rem 1rem 1.1rem;
}
.endpoint-body .description { margin: 0 0 0.75rem; font-size: 0.9rem; }

.field-grid { display: grid; gap: 0.7rem; margin-bottom: 0.85rem; }
.field label { display: block; font-size: 0.78rem; font-weight: 600; margin-bottom: 0.2rem; }
.field .hint { color: var(--muted); font-weight: 400; }
.field input, .field textarea {
  width: 100%;
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0.45rem 0.55rem;
  font: inherit;
  font-size: 0.85rem;
}
.field textarea {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  resize: vertical;
}

.responses { margin: 0.75rem 0; }
.responses h4 { margin: 0 0 0.35rem; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }
.responses ul { margin: 0; padding: 0; list-style: none; }
.responses li { font-size: 0.84rem; padding: 0.12rem 0; }
.responses .code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-weight: 700; margin-right: 0.5rem; }

.actions { display: flex; gap: 0.6rem; align-items: center; margin-top: 0.5rem; }

.result-wrap { margin-top: 0.85rem; }
.result-status { font-size: 0.8rem; font-weight: 700; margin-bottom: 0.35rem; }
.result-status.ok { color: var(--post); }
.result-status.error { color: var(--delete); }
.result-status.network { color: var(--put); }
.result {
  margin: 0;
  background: var(--code-bg);
  color: var(--code-text);
  border-radius: 6px;
  padding: 0.75rem;
  overflow-x: auto;
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.8rem;
  max-height: 22rem;
}

.ws-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 0.9rem 1rem;
  margin-bottom: 0.55rem;
}
.ws-card h3 { margin: 0 0 0.3rem; font-size: 0.95rem; }
.ws-card p { margin: 0.25rem 0 0; color: var(--muted); font-size: 0.87rem; }
.ws-card .path { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-weight: 600; }

.footer {
  text-align: center;
  color: var(--muted);
  font-size: 0.8rem;
  padding: 2rem 1rem 2.5rem;
}
''';

/// Interactive behaviour served at `/docs/app.js`.
const docsJs = r'''
(function () {
  'use strict';

  var TOKEN_KEY = 'pi7600.docs.token';
  var tokenInput = document.getElementById('token');
  var tokenStatus = document.getElementById('token-status');

  function savedToken() {
    try {
      return window.localStorage.getItem(TOKEN_KEY) || '';
    } catch (error) {
      return '';
    }
  }

  function setTokenStatus(text) {
    if (tokenStatus) tokenStatus.textContent = text;
  }

  function refreshTokenUi() {
    var token = savedToken();
    if (tokenInput) tokenInput.value = token;
    setTokenStatus(token ? 'Token saved in this browser' : 'No token saved');
  }

  refreshTokenUi();

  var saveButton = document.getElementById('save-token');
  if (saveButton) {
    saveButton.addEventListener('click', function () {
      var value = tokenInput ? tokenInput.value.trim() : '';
      try {
        if (value) window.localStorage.setItem(TOKEN_KEY, value);
        else window.localStorage.removeItem(TOKEN_KEY);
      } catch (error) {
        setTokenStatus('Could not save token');
        return;
      }
      refreshTokenUi();
    });
  }

  var clearButton = document.getElementById('clear-token');
  if (clearButton) {
    clearButton.addEventListener('click', function () {
      try {
        window.localStorage.removeItem(TOKEN_KEY);
      } catch (error) {}
      if (tokenInput) tokenInput.value = '';
      refreshTokenUi();
    });
  }

  function showResult(card, status, text, elapsed) {
    var wrap = card.querySelector('.result-wrap');
    var statusEl = card.querySelector('.result-status');
    var pre = card.querySelector('.result');
    if (!wrap || !statusEl || !pre) return;

    wrap.hidden = false;
    statusEl.className = 'result-status ' +
      (status >= 200 && status < 300 ? 'ok' : status ? 'error' : 'network');
    statusEl.textContent = status
      ? 'HTTP ' + status + (elapsed != null ? ' - ' + elapsed + ' ms' : '')
      : 'Request failed';
    pre.textContent = text;
  }

  function buildPath(card) {
    var path = card.dataset.path || '/';
    card.querySelectorAll('[data-param]').forEach(function (input) {
      var value = (input.value || input.placeholder || '').trim();
      path = path.replace('{' + input.dataset.param + '}', encodeURIComponent(value));
    });
    return path;
  }

  async function execute(card, button) {
    var method = (card.dataset.method || 'GET').toUpperCase();
    var headers = {};
    var body;

    var textarea = card.querySelector('textarea[data-json]');
    if (textarea) {
      var raw = textarea.value.trim();
      if (raw) {
        try {
          JSON.parse(raw);
        } catch (error) {
          showResult(card, 0, 'Invalid JSON: ' + error.message);
          return;
        }
        headers['Content-Type'] = 'application/json';
        body = raw;
      }
    }

    var formInputs = card.querySelectorAll('[data-form]');
    if (formInputs.length > 0) {
      var params = new URLSearchParams();
      formInputs.forEach(function (input) {
        if (input.value) params.append(input.dataset.form, input.value);
      });
      headers['Content-Type'] = 'application/x-www-form-urlencoded';
      body = params.toString();
    }

    var token = savedToken();
    if (token && card.dataset.auth !== 'none') {
      headers['Authorization'] = 'Bearer ' + token;
    }

    var url = new URL(buildPath(card), window.location.origin);
    var previous = button.textContent;
    button.disabled = true;
    button.textContent = 'Executing...';
    var started = window.performance ? window.performance.now() : Date.now();

    try {
      var response = await fetch(url.toString(), {
        method: method,
        headers: headers,
        body: body
      });
      var text = await response.text();
      var pretty = text;
      try {
        pretty = JSON.stringify(JSON.parse(text), null, 2);
      } catch (error) {}
      var finished = window.performance ? window.performance.now() : Date.now();
      showResult(card, response.status, pretty, Math.round(finished - started));
    } catch (error) {
      showResult(card, 0, 'Network error: ' + error.message);
    } finally {
      button.disabled = false;
      button.textContent = previous;
    }
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest('.execute');
    if (!button) return;
    var card = button.closest('.endpoint');
    if (!card) return;
    event.preventDefault();
    execute(card, button);
  });
})();
''';

/// Render the `/docs` page to HTML bytes.
///
/// Jaspr is initialized lazily because the docs page is optional and the
/// server may run with `PI7600_DOCS_ENABLED=false`.
Future<Uint8List> renderDocsPage() async {
  if (!Jaspr.isInitialized) {
    // The client script is served by the docs routes, not by a Jaspr client
    // build, so reuse `clientId` to let Jaspr inject the <script> tag.
    Jaspr.initializeApp(
      options: const ServerOptions(clientId: '/docs/app.js'),
    );
  }

  final response = await renderComponent(const _DocsPage());
  return response.body;
}

class _DocsPage extends StatelessComponent {
  const _DocsPage();

  @override
  Component build(BuildContext context) {
    return Document(
      title: 'Pi7600 API docs',
      lang: 'en',
      head: [link(href: '/docs/style.css', rel: 'stylesheet')],
      body: Component.fragment([
        _topbar(),
        _authBar(),
        main_([
          div(classes: 'layout', [
            _intro(),
            h2(classes: 'section-title', [
              Component.text('HTTP endpoints'),
            ]),
            for (final endpoint in apiEndpoints) _EndpointCard(endpoint),
            h2(classes: 'section-title', [
              Component.text('WebSocket endpoints'),
            ]),
            for (final endpoint in webSocketEndpoints) _WebSocketCard(endpoint),
          ]),
          footer(classes: 'footer', [
            Component.text(
              'Pi7600 - interactive reference generated from the live API '
              'catalog.',
            ),
          ]),
        ]),
      ]),
    );
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
    return section(classes: 'auth-bar', [
      label([Component.text('Bearer token')], htmlFor: 'token'),
      input(
        type: InputType.password,
        id: 'token',
        attributes: const {
          'placeholder': 'Paste a JWT from POST /token',
          'autocomplete': 'off',
          'spellcheck': 'false',
        },
      ),
      button(
        [Component.text('Save')],
        id: 'save-token',
        type: ButtonType.button,
        classes: 'primary',
      ),
      button(
        [Component.text('Clear')],
        id: 'clear-token',
        type: ButtonType.button,
      ),
      span(
        [Component.text('No token saved')],
        id: 'token-status',
        classes: 'muted',
      ),
    ]);
  }

  Component _intro() {
    return section(classes: 'intro', [
      h2([Component.text('Try the API')]),
      p([
        Component.text('Get a token with '),
        code([Component.text('POST /token')]),
        Component.text(
          ', save it above, then expand an endpoint and press Execute. '
          'Requests are sent from this browser to the same origin, so the '
          'existing CORS and authentication rules apply.',
        ),
      ]),
      p([
        Component.text(
          'This page is a convenience client. It does not bypass any checks: '
          'admin-only endpoints still return 403 without an administrator '
          'token.',
        ),
      ]),
    ]);
  }
}

class _EndpointCard extends StatelessComponent {
  const _EndpointCard(this.endpoint);

  final ApiEndpoint endpoint;

  @override
  Component build(BuildContext context) {
    final method = endpoint.method.toLowerCase();
    final hasBody = endpoint.jsonBody != null || endpoint.formFields.isNotEmpty;

    return details(
      classes: 'endpoint',
      attributes: {
        'id': 'op-${endpoint.id}',
        'data-method': endpoint.method,
        'data-path': endpoint.path,
        'data-auth': endpoint.auth.name,
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
                  input(
                    type: InputType.text,
                    attributes: {
                      'data-param': parameter.name,
                      'placeholder': parameter.example,
                      'value': parameter.example,
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
                [Component.text(endpoint.jsonBody!)],
                attributes: const {
                  'data-json': '',
                  'rows': '7',
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
                  input(
                    type: field.name.toLowerCase().contains('password')
                        ? InputType.password
                        : InputType.text,
                    attributes: {
                      'data-form': field.name,
                      'placeholder': field.example,
                      'value': field.example,
                      'autocomplete': 'off',
                    },
                  ),
                ]),
            ]),
          ],
          if (endpoint.responses.isNotEmpty) _responses(),
          div(classes: 'actions', [
            button(
              [Component.text('Execute')],
              type: ButtonType.button,
              classes: 'execute primary',
            ),
            if (!hasBody && endpoint.pathParameters.isEmpty)
              span([Component.text('No request body')], classes: 'muted'),
          ]),
          div(
            [
              div([], classes: 'result-status'),
              pre([], classes: 'result'),
            ],
            classes: 'result-wrap',
            attributes: const {'hidden': ''},
          ),
        ]),
      ],
    );
  }

  Component _responses() {
    return div(classes: 'responses', [
      h4([Component.text('Responses')]),
      ul([
        for (final response in endpoint.responses.entries)
          li([
            span([Component.text(response.key)], classes: 'code'),
            Component.text(response.value),
          ]),
      ]),
    ]);
  }

  Component _authBadge(ApiAuth auth) {
    return switch (auth) {
      ApiAuth.none => span([Component.text('public')], classes: 'badge'),
      ApiAuth.user => span([Component.text('bearer')], classes: 'badge user'),
      ApiAuth.admin => span(
        [Component.text('admin')],
        classes: 'badge admin',
      ),
    };
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
