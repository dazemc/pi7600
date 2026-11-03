import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:simcom_api_server/src/camera/v4l2.dart';

/// A camera capture pipeline running in a dedicated isolate.
///
/// The isolate opens a V4L2 device, converts every frame to JPEG (MJPEG frames
/// are passed through untouched), and sends them back to the main isolate. The
/// main isolate keeps only the latest frame so slow WebSocket clients cannot
/// stall capture.
class CameraCapture {
  CameraCapture({
    required this.candidatePaths,
    required this.width,
    required this.height,
    required this.fps,
  });

  final List<String> candidatePaths;
  final int width;
  final int height;
  final int fps;

  final StreamController<Uint8List> _frames =
      StreamController<Uint8List>.broadcast();

  Isolate? _isolate;
  ReceivePort? _receiver;
  SendPort? _control;
  Completer<void>? _ready;
  Completer<void>? _stopped;

  Uint8List? _latestFrame;
  bool _running = false;
  Object? _error;
  String? _devicePath;
  int? _frameWidth;
  int? _frameHeight;
  String? _frameFormat;

  Stream<Uint8List> get frames => _frames.stream;

  Uint8List? get latestFrame => _latestFrame;

  /// Return the latest frame, waiting up to [timeout] for a new one.
  ///
  /// Returns `null` when capture produces no frame in time or the stream has
  /// already been closed.
  Future<Uint8List?> waitForFrame({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final current = _latestFrame;
    if (current != null) return current;

    try {
      return await _frames.stream.first.timeout(timeout);
    } on TimeoutException {
      return null;
    } on StateError {
      return null;
    }
  }

  bool get isRunning => _running;

  Object? get error => _error;

  String? get devicePath => _devicePath;

  int? get frameWidth => _frameWidth;

  int? get frameHeight => _frameHeight;

  String? get frameFormat => _frameFormat;

  /// Start capture. Completes once the device is streaming.
  Future<void> start() async {
    if (_running) return;
    _error = null;
    _ready = Completer<void>();
    _stopped = Completer<void>();
    _receiver = ReceivePort();
    _receiver!.listen(_handleMessage);

    try {
      _isolate = await Isolate.spawn(_cameraIsolate, [
        _receiver!.sendPort,
        candidatePaths,
        width,
        height,
        fps,
      ]);

      return await _ready!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _error = StateError('Timed out while starting camera');
          throw _error!;
        },
      );
    } on Object {
      _resetCapture();
      rethrow;
    }
  }

  void _resetCapture() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _control = null;
    _running = false;
    _latestFrame = null;
    _receiver?.close();
    _receiver = null;
  }

  void _handleMessage(Object? message) {
    if (message is SendPort) {
      _control = message;
      return;
    }
    if (message is! Map) return;

    switch (message['type']) {
      case 'ready':
        _running = true;
        _devicePath = message['path'] as String?;
        _frameWidth = message['width'] as int?;
        _frameHeight = message['height'] as int?;
        _frameFormat = message['format'] as String?;
        if (_ready case final ready? when !ready.isCompleted) {
          ready.complete();
        }
      case 'frame':
        final transferable = message['data'] as TransferableTypedData?;
        if (transferable == null) return;
        final bytes = transferable.materialize().asUint8List();
        _latestFrame = bytes;
        if (!_frames.isClosed) _frames.add(bytes);
      case 'error':
        _error = StateError('${message['message']}');
        _running = false;
        if (_ready case final ready? when !ready.isCompleted) {
          ready.completeError(_error!);
        }
      case 'stopped':
        _running = false;
        if (_stopped case final stopped? when !stopped.isCompleted) {
          stopped.complete();
        }
    }
  }

  /// Stop capture and release the device.
  ///
  /// The frame stream stays open so capture can be started again on demand.
  Future<void> stop() async {
    final control = _control;
    if (control != null) {
      control.send('stop');
      try {
        await _stopped?.future.timeout(const Duration(seconds: 3));
      } on TimeoutException {
        // The isolate is killed below.
      }
    }
    _resetCapture();
  }

  /// Stop capture and permanently close the frame stream.
  Future<void> dispose() async {
    await stop();
    if (!_frames.isClosed) await _frames.close();
  }
}

/// Entry point of the capture isolate.
Future<void> _cameraIsolate(List<Object?> args) async {
  final mainPort = args[0] as SendPort;
  final candidates = (args[1] as List).cast<String>();
  final width = args[2] as int;
  final height = args[3] as int;
  final fps = args[4] as int;

  final control = ReceivePort();
  mainPort.send(control.sendPort);

  var stop = false;
  control.listen((message) {
    if (message == 'stop') stop = true;
  });

  V4l2Device? device;
  Object? lastError;
  for (final path in candidates) {
    try {
      device = V4l2Device.open(path: path, width: width, height: height);
      break;
    } on Object catch (error) {
      lastError = error;
    }
  }

  if (device == null) {
    mainPort.send({
      'type': 'error',
      'message': candidates.isEmpty
          ? 'No camera device candidates configured'
          : 'No usable camera found: $lastError',
    });
    control.close();
    return;
  }

  mainPort.send({
    'type': 'ready',
    'path': device.path,
    'width': device.width,
    'height': device.height,
    'format': device.pixelFormat == V4l2Device.pixelFormatMjpeg
        ? 'MJPEG'
        : 'YUYV',
  });

  final frameInterval = Duration(
    microseconds: (1000000 / (fps < 1 ? 1 : fps)).round(),
  );
  final clock = Stopwatch()..start();

  try {
    while (!stop) {
      final started = clock.elapsed;
      final frame = device.readFrame();
      if (frame == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        continue;
      }

      final jpeg = frame.isJpeg
          ? frame.bytes
          : yuyvToJpeg(
              frame.bytes,
              frame.width,
              frame.height,
              device.bytesPerLine,
            );

      mainPort.send({
        'type': 'frame',
        'data': TransferableTypedData.fromList([jpeg]),
      });

      final elapsed = clock.elapsed - started;
      if (elapsed < frameInterval) {
        await Future<void>.delayed(frameInterval - elapsed);
      }
    }
  } on Object catch (error) {
    mainPort.send({'type': 'error', 'message': '$error'});
  } finally {
    device.close();
    control.close();
    mainPort.send({'type': 'stopped'});
  }
}

/// Convert a YUYV (YUV 4:2:2) frame to a JPEG image.
///
/// Public so the conversion can be tested without a V4L2 device.
Uint8List yuyvToJpeg(
  Uint8List data,
  int width,
  int height,
  int stride,
) {
  final rowStride = stride > 0 ? stride : width * 2;
  final rgb = Uint8List(width * height * 3);
  var destination = 0;

  for (var y = 0; y < height; y++) {
    var source = y * rowStride;
    final rowEnd = source + width * 2;
    while (source + 3 < rowEnd && source + 3 < data.length) {
      final y0 = data[source];
      final u = data[source + 1];
      final y1 = data[source + 2];
      final v = data[source + 3];
      source += 4;

      _writeYuvPixel(rgb, destination, y0, u, v);
      destination += 3;
      _writeYuvPixel(rgb, destination, y1, u, v);
      destination += 3;
    }
  }

  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgb.buffer,
    numChannels: 3,
    order: img.ChannelOrder.rgb,
  );
  return img.encodeJpg(image, quality: 80, chroma: img.JpegChroma.yuv420);
}

void _writeYuvPixel(Uint8List target, int offset, int y, int u, int v) {
  final c = y - 16;
  final d = u - 128;
  final e = v - 128;
  target[offset] = _clamp((298 * c + 409 * e + 128) >> 8);
  target[offset + 1] = _clamp((298 * c - 100 * d - 208 * e + 128) >> 8);
  target[offset + 2] = _clamp((298 * c + 516 * d + 128) >> 8);
}

int _clamp(int value) {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return value;
}
