import 'dart:io';

/// Render Prometheus text exposition for the service.
String buildMetrics({
  required bool modemReady,
  required bool cameraRunning,
  required bool recognitionReady,
  required int videoClients,
  required String phase,
}) {
  final rss = ProcessInfo.currentRss;
  final maxRss = ProcessInfo.maxRss;
  return [
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
  ].join('\n');
}
