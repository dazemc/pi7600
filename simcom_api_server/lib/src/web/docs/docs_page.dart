import 'dart:typed_data';

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:simcom_api_server/src/web/docs/docs_app.dart';

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
  flex: 0 1 12rem;
  min-width: 9rem;
  padding: 0.45rem 0.6rem;
  border: 1px solid var(--border);
  border-radius: 6px;
  font: inherit;
  font-size: 0.85rem;
}

.login-form {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem;
  align-items: center;
  flex: 1 1 auto;
}
.session {
  display: flex;
  gap: 0.75rem;
  align-items: center;
  flex: 1 1 auto;
}
.error-text { color: var(--delete); }
.login-form[hidden], .session[hidden] { display: none; }

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
.result-link { margin-top: 0.5rem; font-size: 0.85rem; }
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

/// Render the `/docs` page to HTML bytes.
///
/// Jaspr is initialized lazily because the docs page is optional and the
/// server may run with `SIMCOM_API_DOCS_ENABLED=false`. The client entrypoint is
/// compiled from Dart by `tool/build_docs_client.dart` and served from
/// `/docs/app.js`.
Future<Uint8List> renderDocsPage() async {
  if (!Jaspr.isInitialized) {
    Jaspr.initializeApp(
      options: const ServerOptions(clientId: '/docs/app.js'),
    );
  }

  final response = await renderComponent(
    const Document(
      title: 'Simcom API docs',
      lang: 'en',
      head: [link(href: '/docs/style.css', rel: 'stylesheet')],
      body: DocsApp(),
    ),
  );
  return response.body;
}
