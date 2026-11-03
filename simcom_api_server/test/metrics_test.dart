import 'package:simcom_api_server/src/web/metrics.dart';
import 'package:test/test.dart';

void main() {
  test('renders service metrics in Prometheus format', () {
    final text = buildMetrics(
      modemReady: true,
      cameraRunning: false,
      recognitionReady: false,
      videoClients: 2,
      phase: 'ready',
    );

    expect(text, contains('simcom_api_up 1'));
    expect(text, contains('simcom_api_modem_ready 1'));
    expect(text, contains('simcom_api_camera_running 0'));
    expect(text, contains('simcom_api_recognition_ready 0'));
    expect(text, contains('simcom_api_video_clients 2'));
    expect(text, contains('simcom_api_service_phase{phase="ready"} 1'));
    expect(text, contains('# TYPE simcom_api_rss_bytes gauge'));
  });

  test('renders request counters and durations', () {
    final requests = RequestMetrics()
      ..record('GET', '/healthz', 200, 1500)
      ..record('GET', '/healthz', 200, 2500);

    final text = buildMetrics(
      modemReady: true,
      cameraRunning: false,
      recognitionReady: false,
      videoClients: 0,
      phase: 'ready',
      requests: requests,
    );

    expect(
      text,
      contains(
        'simcom_api_requests_total'
        '{method="GET",path="/healthz",status="200"} 2',
      ),
    );
    expect(
      text,
      contains(
        'simcom_api_request_duration_seconds_sum'
        '{method="GET",path="/healthz",status="200"} 0.004000',
      ),
    );
    expect(
      text,
      contains(
        'simcom_api_request_duration_seconds_count'
        '{method="GET",path="/healthz",status="200"} 2',
      ),
    );
  });

  test('normalizes identifier paths for metrics labels', () {
    expect(metricPath(Uri.parse('http://localhost/users/42')), '/users/{id}');
    expect(
      metricPath(Uri.parse('http://localhost/sms/delete/7')),
      '/sms/delete/{id}',
    );
    expect(
      metricPath(Uri.parse('http://localhost/sms/retry/7')),
      '/sms/retry/{id}',
    );
    expect(metricPath(Uri.parse('http://localhost/sms')), '/sms');
  });
}
