import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pi7600_server/src/web/docs/api_catalog.dart';
import 'package:pi7600_server/src/web/docs/docs_page.dart';
import 'package:serverpod/serverpod.dart';

/// Shared 404 for every docs route when `PI7600_DOCS_ENABLED=false`.
Response _docsDisabled() {
  return Response(
    404,
    body: Body.fromString('Not found', mimeType: MimeType.plainText),
  );
}

/// `GET /docs`
///
/// Server-renders the Jaspr API explorer. The rendered page is static, so it is
/// cached after the first request.
class DocsRoute extends Route {
  DocsRoute(this.enabled) : super(methods: {Method.get});

  final bool enabled;

  static Future<Uint8List>? _cachedPage;

  Future<Uint8List> _page() async {
    final cached = _cachedPage;
    if (cached != null) return cached;

    final future = renderDocsPage();
    _cachedPage = future;
    try {
      return await future;
    } on Object {
      // Do not cache a failed render; a later request can retry.
      _cachedPage = null;
      rethrow;
    }
  }

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    if (!enabled) return _docsDisabled();
    final body = await _page();
    return Response(
      200,
      body: Body.fromData(body, mimeType: MimeType.html),
    );
  }
}

/// `GET /docs/style.css`
class DocsStyleRoute extends Route {
  DocsStyleRoute(this.enabled) : super(methods: {Method.get});

  final bool enabled;

  static final Uint8List _body = Uint8List.fromList(utf8.encode(docsCss));

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    if (!enabled) return _docsDisabled();
    return Response(
      200,
      body: Body.fromData(_body, mimeType: MimeType.css),
    );
  }
}

/// `GET /docs/app.js`
class DocsScriptRoute extends Route {
  DocsScriptRoute(this.enabled) : super(methods: {Method.get});

  final bool enabled;

  static final Uint8List _body = Uint8List.fromList(utf8.encode(docsJs));

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    if (!enabled) return _docsDisabled();
    return Response(
      200,
      body: Body.fromData(_body, mimeType: MimeType.javascript),
    );
  }
}

/// `GET /openapi.json`
class OpenApiRoute extends Route {
  OpenApiRoute(this.enabled) : super(methods: {Method.get});

  final bool enabled;

  static final Uint8List _body = Uint8List.fromList(
    utf8.encode(buildOpenApiJson()),
  );

  @override
  FutureOr<Result> handleCall(Session session, Request request) {
    if (!enabled) return _docsDisabled();
    return Response(
      200,
      body: Body.fromData(_body, mimeType: MimeType.json),
    );
  }
}
