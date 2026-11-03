import 'package:jaspr/client.dart';
import 'package:pi7600_server/src/web/docs/docs_app.dart';

/// Browser entrypoint for the interactive `/docs` page.
///
/// This file is compiled to JavaScript by `tool/build_docs_client.dart` and
/// served from `/docs/app.js`. It is never imported by the server.
void main() {
  Jaspr.initializeApp();
  runApp(const DocsApp());
}
