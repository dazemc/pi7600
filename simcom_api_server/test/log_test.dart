import 'package:simcom_api_server/src/util/app_log.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() => AppLog.configure('info'));

  test('parses common log level values', () {
    AppLog.configure('debug');
    expect(AppLog.level, AppLogLevel.debug);
    AppLog.configure('INFO');
    expect(AppLog.level, AppLogLevel.info);
    AppLog.configure('warn');
    expect(AppLog.level, AppLogLevel.warning);
    AppLog.configure('warning');
    expect(AppLog.level, AppLogLevel.warning);
    AppLog.configure('error');
    expect(AppLog.level, AppLogLevel.error);
    AppLog.configure('unknown');
    expect(AppLog.level, AppLogLevel.info);
  });

  test('filters messages below the configured level', () {
    AppLog.configure('warn');

    expect(AppLog.enabled(AppLogLevel.debug), isFalse);
    expect(AppLog.enabled(AppLogLevel.info), isFalse);
    expect(AppLog.enabled(AppLogLevel.warning), isTrue);
    expect(AppLog.enabled(AppLogLevel.error), isTrue);
  });
}
