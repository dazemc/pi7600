import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Loads the compiled Jaspr client bundle served at `/docs/app.js`.
///
/// The bundle is produced by `dart run tool/build_docs_client.dart` and is not
/// committed to git. The resolver checks `PI7600_DOCS_CLIENT_PATH`, then the
/// `web/docs/app.js` path next to the running executable, then the same path
/// under the current directory. This makes the same layout work for
/// `dart run bin/main.dart`, the native `dart build cli` bundle, and tests.
/// When [path] is provided, only that file is read and the result is not
/// cached. This is used by tests.
Future<Uint8List?> loadDocsClientBundle({String? path}) async {
  if (path != null) {
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  final cached = _cached;
  if (cached != null) return cached;

  for (final candidate in _candidatePaths()) {
    final file = File(candidate);
    if (!await file.exists()) continue;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) continue;
    _cached = bytes;
    return bytes;
  }
  return null;
}

Uint8List? _cached;

Iterable<String> _candidatePaths() sync* {
  final configured = Platform.environment['PI7600_DOCS_CLIENT_PATH'];
  if (configured != null && configured.isNotEmpty) {
    yield p.normalize(p.absolute(configured));
    return;
  }

  final script = Platform.script;
  if (script.scheme == 'file') {
    final scriptPath = script.toFilePath();
    yield p.normalize(
      p.join(p.dirname(scriptPath), '..', 'web', 'docs', 'app.js'),
    );
  }

  yield p.normalize(p.join(Directory.current.path, 'web', 'docs', 'app.js'));
  yield p.normalize(
    p.join(
      Directory.current.path,
      'simcom_api_server',
      'web',
      'docs',
      'app.js',
    ),
  );
}
