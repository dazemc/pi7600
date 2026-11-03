import 'package:bloc/bloc.dart';

/// Lifecycle phases of the hardware-backed services.
enum ServicePhase { starting, ready, degraded, stopped }

class ServiceStatus {
  const ServiceStatus({
    required this.phase,
    this.modemReady = false,
    this.cameraReady = false,
    this.recognitionReady = false,
    this.message,
  });

  final ServicePhase phase;
  final bool modemReady;
  final bool cameraReady;
  final bool recognitionReady;
  final String? message;

  ServiceStatus copyWith({
    ServicePhase? phase,
    bool? modemReady,
    bool? cameraReady,
    bool? recognitionReady,
    String? message,
  }) {
    return ServiceStatus(
      phase: phase ?? this.phase,
      modemReady: modemReady ?? this.modemReady,
      cameraReady: cameraReady ?? this.cameraReady,
      recognitionReady: recognitionReady ?? this.recognitionReady,
      message: message ?? this.message,
    );
  }
}

/// Server-side Bloc that exposes service lifecycle state.
///
/// The state is intentionally small: the REST and WebSocket routes only need to
/// know whether the modem and camera are usable. Keeping it in a Cubit makes
/// the startup/shutdown transitions observable and testable.
class ServiceStatusCubit extends Cubit<ServiceStatus> {
  ServiceStatusCubit()
    : super(const ServiceStatus(phase: ServicePhase.starting));

  void modemStarted() {
    emit(state.copyWith(modemReady: true, message: 'modem ready'));
  }

  void modemFailed(Object error) {
    emit(
      state.copyWith(
        modemReady: false,
        message: 'modem unavailable: $error',
      ),
    );
  }

  void cameraStarted() {
    emit(state.copyWith(cameraReady: true, message: 'camera ready'));
  }

  void cameraFailed(Object error) {
    emit(
      state.copyWith(
        cameraReady: false,
        message: 'camera unavailable: $error',
      ),
    );
  }

  void recognitionStarted() {
    emit(state.copyWith(recognitionReady: true, message: 'recognition ready'));
  }

  void recognitionFailed(Object error) {
    emit(
      state.copyWith(
        recognitionReady: false,
        message: 'recognition unavailable: $error',
      ),
    );
  }

  void ready() {
    emit(state.copyWith(phase: ServicePhase.ready, message: 'services ready'));
  }

  void degraded(String message) {
    emit(state.copyWith(phase: ServicePhase.degraded, message: message));
  }

  void stopped() {
    emit(const ServiceStatus(phase: ServicePhase.stopped, message: 'stopped'));
  }
}
