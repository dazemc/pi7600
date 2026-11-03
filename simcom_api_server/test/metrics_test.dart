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

    expect(text, contains('pi7600_up 1'));
    expect(text, contains('pi7600_modem_ready 1'));
    expect(text, contains('pi7600_camera_running 0'));
    expect(text, contains('pi7600_recognition_ready 0'));
    expect(text, contains('pi7600_video_clients 2'));
    expect(text, contains('pi7600_service_phase{phase="ready"} 1'));
    expect(text, contains('# TYPE pi7600_rss_bytes gauge'));
  });
}
