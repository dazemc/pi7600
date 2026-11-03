import 'dart:io';

import 'package:serverpod/serverpod.dart';

/// In-memory request counters for Prometheus metrics.
class RequestMetrics {
  final Map<_MetricKey, _MetricValue> _values = {};

  void record(String method, String path, int status, int microseconds) {
    final key = _MetricKey(method, path, status);
    final value = _values.putIfAbsent(key, _MetricValue.new);
    value.count++;
    value.totalMicroseconds += microseconds;
  }

  List<RequestMetricSnapshot> snapshot() {
    final values = [
      for (final entry in _values.entries)
        RequestMetricSnapshot(
          method: entry.key.method,
          path: entry.key.path,
          status: entry.key.status,
          count: entry.value.count,
          totalMicroseconds: entry.value.totalMicroseconds,
        ),
    ]..sort((a, b) => a.metricKey.compareTo(b.metricKey));
    return values;
  }
}

class RequestMetricSnapshot {
  const RequestMetricSnapshot({
    required this.method,
    required this.path,
    required this.status,
    required this.count,
    required this.totalMicroseconds,
  });

  final String method;
  final String path;
  final int status;
  final int count;
  final int totalMicroseconds;

  String get labels => 'method="$method",path="$path",status="$status"';

  String get metricKey => '$method|$path|$status';
}

class _MetricKey {
  const _MetricKey(this.method, this.path, this.status);

  final String method;
  final String path;
  final int status;

  @override
  bool operator ==(Object other) {
    return other is _MetricKey &&
        other.method == method &&
        other.path == path &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(method, path, status);
}

class _MetricValue {
  int count = 0;
  int totalMicroseconds = 0;
}

/// Collapse identifiers in known paths so metric labels stay bounded.
String metricPath(Uri uri) {
  final path = uri.path;
  if (RegExp(r'^/users/[^/]+$').hasMatch(path)) return '/users/{id}';
  final sms = RegExp(r'^/sms/(delete|retry)/[^/]+$').firstMatch(path);
  if (sms != null) return '/sms/${sms.group(1)}/{id}';
  return path;
}

/// Middleware that records request counts and durations.
Middleware requestMetricsMiddleware(RequestMetrics metrics) {
  return (next) {
    return (request) async {
      final stopwatch = Stopwatch()..start();
      try {
        final result = await next(request);
        metrics.record(
          request.method.name.toUpperCase(),
          metricPath(request.url),
          result is Response ? result.statusCode : 0,
          stopwatch.elapsedMicroseconds,
        );
        return result;
      } on Object {
        metrics.record(
          request.method.name.toUpperCase(),
          metricPath(request.url),
          500,
          stopwatch.elapsedMicroseconds,
        );
        rethrow;
      }
    };
  };
}

/// Render Prometheus text exposition for the service.
String buildMetrics({
  required bool modemReady,
  required bool cameraRunning,
  required bool recognitionReady,
  required int videoClients,
  required String phase,
  RequestMetrics? requests,
}) {
  final rss = ProcessInfo.currentRss;
  final maxRss = ProcessInfo.maxRss;
  final lines = [
    '# HELP simcom_api_up Process is running.',
    '# TYPE simcom_api_up gauge',
    'simcom_api_up 1',
    '# HELP simcom_api_modem_ready Whether the modem initialized.',
    '# TYPE simcom_api_modem_ready gauge',
    'simcom_api_modem_ready ${modemReady ? 1 : 0}',
    '# HELP simcom_api_camera_running Whether camera capture is active.',
    '# TYPE simcom_api_camera_running gauge',
    'simcom_api_camera_running ${cameraRunning ? 1 : 0}',
    '# HELP simcom_api_recognition_ready Whether a recognition backend initialized.',
    '# TYPE simcom_api_recognition_ready gauge',
    'simcom_api_recognition_ready ${recognitionReady ? 1 : 0}',
    '# HELP simcom_api_video_clients Number of connected video clients.',
    '# TYPE simcom_api_video_clients gauge',
    'simcom_api_video_clients $videoClients',
    '# HELP simcom_api_service_phase Current service lifecycle phase.',
    '# TYPE simcom_api_service_phase gauge',
    'simcom_api_service_phase{phase="$phase"} 1',
    '# HELP simcom_api_rss_bytes Resident set size.',
    '# TYPE simcom_api_rss_bytes gauge',
    'simcom_api_rss_bytes $rss',
    '# HELP simcom_api_max_rss_bytes Maximum resident set size.',
    '# TYPE simcom_api_max_rss_bytes gauge',
    'simcom_api_max_rss_bytes $maxRss',
  ];

  if (requests != null) {
    final snapshot = requests.snapshot();
    lines.addAll([
      '# HELP simcom_api_requests_total HTTP requests handled.',
      '# TYPE simcom_api_requests_total counter',
      for (final metric in snapshot)
        'simcom_api_requests_total{${metric.labels}} ${metric.count}',
      '# HELP simcom_api_request_duration_seconds Request duration.',
      '# TYPE simcom_api_request_duration_seconds summary',
      for (final metric in snapshot)
        'simcom_api_request_duration_seconds_sum{${metric.labels}} '
            '${(metric.totalMicroseconds / 1000000).toStringAsFixed(6)}',
      for (final metric in snapshot)
        'simcom_api_request_duration_seconds_count{${metric.labels}} '
            '${metric.count}',
    ]);
  }

  return lines.join('\n');
}
