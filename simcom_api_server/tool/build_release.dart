import 'dart:io';

import 'package:path/path.dart' as p;

/// Build the docs client and a native release bundle in one step.
///
/// Usage (from `simcom_api_server`):
///
/// ```sh
/// dart run tool/build_release.dart
/// dart run tool/build_release.dart --target-arch=x64 --output=build/linux
/// ```
///
/// The script compiles `web/docs/app.js`, runs `dart build cli`, and copies the
/// docs client into `<output>/bundle/web/docs/app.js`.
Future<void> main(List<String> arguments) async {
  final packageRoot = _packageRoot();
  if (packageRoot == null) return;

  var targetOs = 'linux';
  var targetArch = 'arm64';
  var output = 'build/pi';
  for (final argument in arguments) {
    if (argument.startsWith('--target-os=')) {
      targetOs = argument.substring('--target-os='.length);
    } else if (argument.startsWith('--target-arch=')) {
      targetArch = argument.substring('--target-arch='.length);
    } else if (argument.startsWith('--output=')) {
      output = argument.substring('--output='.length);
    }
  }

  final outputPath = p.normalize(p.absolute(packageRoot, output));
  final docsBundle = p.join(packageRoot, 'web', 'docs', 'app.js');

  stdout.writeln('Building docs client...');
  final docsResult = await Process.run(
    Platform.resolvedExecutable,
    ['run', 'tool/build_docs_client.dart'],
    workingDirectory: packageRoot,
  );
  stdout.write(docsResult.stdout);
  stderr.write(docsResult.stderr);
  if (docsResult.exitCode != 0) {
    exitCode = docsResult.exitCode;
    return;
  }

  stdout.writeln('Building native bundle ($targetOs/$targetArch)...');
  final buildResult = await Process.run(
    Platform.resolvedExecutable,
    [
      'build',
      'cli',
      '--target',
      'bin/main.dart',
      '--target-os',
      targetOs,
      '--target-arch',
      targetArch,
      '--output',
      outputPath,
    ],
    workingDirectory: packageRoot,
  );
  stdout.write(buildResult.stdout);
  stderr.write(buildResult.stderr);
  if (buildResult.exitCode != 0) {
    exitCode = buildResult.exitCode;
    return;
  }

  final bundleDocs = p.join(outputPath, 'bundle', 'web', 'docs');
  await Directory(bundleDocs).create(recursive: true);
  await File(docsBundle).copy(p.join(bundleDocs, 'app.js'));

  stdout.writeln('Release bundle: ${p.join(outputPath, 'bundle')}');
  stdout.writeln('Included: ${p.join(bundleDocs, 'app.js')}');
}

String? _packageRoot() {
  final current = Directory.current;
  for (final candidate in [
    current.path,
    p.join(current.path, 'simcom_api_server'),
  ]) {
    if (File(p.join(candidate, 'bin', 'main.dart')).existsSync()) {
      return candidate;
    }
  }

  stderr.writeln(
    'Run this tool from simcom_api_server (or the repository root).',
  );
  exitCode = 2;
  return null;
}
