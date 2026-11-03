import 'dart:io';

import 'package:path/path.dart' as p;

/// Compiles the interactive `/docs` Jaspr app to `web/docs/app.js`.
///
/// Usage (from `pi7600_server`):
///
/// ```sh
/// dart run tool/build_docs_client.dart
/// ```
///
/// The output is a build artifact and is intentionally not committed. The
/// native server bundle looks for it at `<bundle>/web/docs/app.js`; local
/// `dart run bin/main.dart` looks for `pi7600_server/web/docs/app.js`.
Future<void> main(List<String> arguments) async {
  final packageRoot = _packageRoot();
  if (packageRoot == null) return;
  final output = p.normalize(
    p.absolute(
      arguments.isEmpty
          ? p.join(packageRoot, 'web', 'docs', 'app.js')
          : arguments.first,
    ),
  );
  final entrypoint = p.join(
    packageRoot,
    'lib',
    'src',
    'web',
    'docs',
    'docs_app.client.dart',
  );

  if (!File(entrypoint).existsSync()) {
    stderr.writeln('Docs client entrypoint not found: $entrypoint');
    exitCode = 1;
    return;
  }

  await Directory(p.dirname(output)).create(recursive: true);

  stdout.writeln('Compiling $entrypoint -> $output');
  final result = await Process.run(
    Platform.resolvedExecutable,
    [
      'compile',
      'js',
      '-O2',
      '--no-source-maps',
      '-o',
      output,
      entrypoint,
    ],
    workingDirectory: packageRoot,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exitCode = result.exitCode;
    return;
  }

  final size = File(output).lengthSync();
  stdout.writeln('Built $output (${_formatSize(size)}).');
}

String? _packageRoot() {
  final current = Directory.current;
  for (final candidate in [
    current.path,
    p.join(current.path, 'pi7600_server'),
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

  stderr.writeln(
    'Run this tool from pi7600_server (or the repository root).',
  );
  exitCode = 2;
  return null;
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}
