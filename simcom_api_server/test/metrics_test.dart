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
}
