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
    '# HELP pi7600_up Process is running.',
    '# TYPE pi7600_up gauge',
    'pi7600_up 1',
    '# HELP pi7600_modem_ready Whether the modem initialized.',
    '# TYPE pi7600_modem_ready gauge',
    'pi7600_modem_ready ${modemReady ? 1 : 0}',
    '# HELP pi7600_camera_running Whether camera capture is active.',
    '# TYPE pi7600_camera_running gauge',
    'pi7600_camera_running ${cameraRunning ? 1 : 0}',
    '# HELP pi7600_recognition_ready Whether a recognition backend initialized.',
    '# TYPE pi7600_recognition_ready gauge',
    'pi7600_recognition_ready ${recognitionReady ? 1 : 0}',
    '# HELP pi7600_video_clients Number of connected video clients.',
    '# TYPE pi7600_video_clients gauge',
    'pi7600_video_clients $videoClients',
    '# HELP pi7600_service_phase Current service lifecycle phase.',
    '# TYPE pi7600_service_phase gauge',
    'pi7600_service_phase{phase="$phase"} 1',
    '# HELP pi7600_rss_bytes Resident set size.',
    '# TYPE pi7600_rss_bytes gauge',
    'pi7600_rss_bytes $rss',
    '# HELP pi7600_max_rss_bytes Maximum resident set size.',
    '# TYPE pi7600_max_rss_bytes gauge',
    'pi7600_max_rss_bytes $maxRss',
  ].join('\n');
}
