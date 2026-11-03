import 'dart:convert';
import 'dart:io';

import 'package:hashlib/hashlib.dart';
import 'package:path/path.dart' as p;
import 'package:postgres/postgres.dart';
import 'package:serverpod/serverpod.dart' hide Endpoint;
// ignore: implementation_imports
import 'package:serverpod_shared/src/password_manager.dart';

/// Create a Pi7600 API user in PostgreSQL.
///
/// Usage:
///   dart run bin/create_user.dart --username alice --admin
///
/// The password is read from the terminal, from `--password`, or from
/// `PI7600_USER_PASSWORD`.
///
/// Database connection details come from the Serverpod configuration for the
/// current run mode (`SERVERPOD_RUN_MODE`, default `development`). For the
/// development configuration the embedded PostgreSQL socket is used, so start
/// the server once before creating users. In production, the regular
/// `SERVERPOD_DATABASE_PASSWORD` environment variable (or
/// `config/passwords.yaml`) supplies the database password.
Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);

  final username = options.username ?? _prompt('Username: ');
  if (username.isEmpty) {
    stderr.writeln('Username cannot be empty.');
    exitCode = 1;
    return;
  }

  final password =
      options.password ??
      Platform.environment['PI7600_USER_PASSWORD'] ??
      _promptPassword('Password: ');
  if (password.isEmpty) {
    stderr.writeln('Password cannot be empty.');
    exitCode = 1;
    return;
  }
  if (options.password == null &&
      Platform.environment['PI7600_USER_PASSWORD'] == null) {
    final confirmation = _promptPassword('Confirm password: ');
    if (password != confirmation) {
      stderr.writeln('Passwords do not match.');
      exitCode = 1;
      return;
    }
  }

  final endpoint = _databaseEndpoint();
  final connection = await Connection.open(
    endpoint,
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );

  try {
    final existing = await connection.execute(
      Sql.named('SELECT 1 FROM users WHERE user_name = @userName'),
      parameters: {'userName': username},
    );
    if (existing.isNotEmpty) {
      stderr.writeln("User '$username' already exists.");
      exitCode = 1;
      return;
    }

    await connection.execute(
      Sql.named('''
        INSERT INTO users (
          user_name,
          user_password,
          user_full_name,
          user_email,
          is_disabled,
          is_admin
        ) VALUES (
          @userName,
          @userPassword,
          @fullName,
          @email,
          @isDisabled,
          @isAdmin
        )
      '''),
      parameters: {
        'userName': username,
        'userPassword': bcrypt(utf8.encode(password)),
        'fullName': options.fullName,
        'email': options.email,
        'isDisabled': false,
        'isAdmin': options.admin,
      },
    );

    stdout.writeln("User '$username' created successfully.");
  } on PgException catch (error) {
    stderr.writeln('Database error: ${error.message}');
    exitCode = 1;
  } finally {
    await connection.close();
  }
}

/// Build the PostgreSQL endpoint from the active Serverpod configuration.
///
/// Embedded development databases listen on a Unix socket under
/// `.serverpod/<runMode>/run`; their TCP settings in `development.yaml` are
/// only a template.
Endpoint _databaseEndpoint() {
  final environment = Platform.environment;
  final runMode = _runMode(environment);
  final passwords = PasswordManager(
    runMode: runMode,
  ).loadPasswords();
  final config = ServerpodConfig.load(runMode, null, passwords);
  final database = config.database;
  if (database is! PostgresDatabaseConfig) {
    throw StateError('The $runMode configuration does not use PostgreSQL.');
  }

  final dataPath = database.dataPath;
  if (dataPath != null) {
    final directory = p.absolute(p.dirname(dataPath));
    final port = _embeddedPort(directory);
    return Endpoint(
      host: p.join(directory, 'run', '.s.PGSQL.$port'),
      port: port,
      database: database.name,
      username: database.user,
      password: database.password,
      isUnixSocket: true,
    );
  }

  return Endpoint(
    host: database.host,
    port: database.port,
    database: database.name,
    username: database.user,
    password: database.password,
    isUnixSocket: database.isUnixSocket,
  );
}

String _runMode(Map<String, String> environment) {
  final configured = environment['SERVERPOD_RUN_MODE']?.trim();
  if (configured != null && configured.isNotEmpty) return configured;
  return ServerpodRunMode.development;
}

/// Read the port from `postmaster.pid`, falling back to the default.
int _embeddedPort(String dataDirectory) {
  final file = File(p.join(dataDirectory, 'postmaster.pid'));
  try {
    final lines = file.readAsLinesSync();
    if (lines.length > 3) {
      return int.tryParse(lines[3].trim()) ?? 5432;
    }
  } on FileSystemException {
    // The server has not started the embedded database yet.
  }
  return 5432;
}

class _Options {
  const _Options({
    required this.admin,
    required this.username,
    required this.password,
    required this.fullName,
    required this.email,
  });

  final bool admin;
  final String? username;
  final String? password;
  final String? fullName;
  final String? email;

  static _Options parse(List<String> arguments) {
    var admin = false;
    String? username;
    String? password;
    String? fullName;
    String? email;

    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      switch (argument) {
        case '--admin':
          admin = true;
        case '--username':
          username = _value(arguments, ++index, '--username');
        case '--password':
          password = _value(arguments, ++index, '--password');
        case '--full-name':
          fullName = _value(arguments, ++index, '--full-name');
        case '--email':
          email = _value(arguments, ++index, '--email');
        case '--help':
        case '-h':
          stdout.writeln(
            'Usage: dart run bin/create_user.dart '
            '[--username NAME] [--password PASS] [--admin] '
            '[--full-name NAME] [--email ADDRESS]',
          );
          exit(0);
        default:
          stderr.writeln('Unknown option: $argument');
          exit(64);
      }
    }

    return _Options(
      admin: admin,
      username: username,
      password: password,
      fullName: fullName,
      email: email,
    );
  }

  static String _value(List<String> arguments, int index, String option) {
    if (index >= arguments.length) {
      stderr.writeln('Missing value for $option.');
      exit(64);
    }
    return arguments[index];
  }
}

String _prompt(String label) {
  stdout.write(label);
  return stdin.readLineSync()?.trim() ?? '';
}

String _promptPassword(String label) {
  stdout.write(label);
  final previous = stdin.echoMode;
  stdin.echoMode = false;
  try {
    return stdin.readLineSync()?.trim() ?? '';
  } finally {
    stdin.echoMode = previous;
    stdout.writeln();
  }
}
