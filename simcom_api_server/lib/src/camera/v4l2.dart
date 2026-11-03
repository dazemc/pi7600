import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// Thrown when a V4L2 device cannot be opened, configured, or read.
class V4l2Exception implements Exception {
  V4l2Exception(this.message, {this.errno});

  final String message;
  final int? errno;

  @override
  String toString() =>
      'V4l2Exception: $message${errno == null ? '' : ' (errno $errno)'}';
}

/// A raw frame read from a V4L2 device.
class V4l2Frame {
  const V4l2Frame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.pixelFormat,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int pixelFormat;

  /// Whether [bytes] already contains an encoded JPEG image.
  bool get isJpeg => pixelFormat == V4l2Device.pixelFormatMjpeg;
}

class _MappedBuffer {
  _MappedBuffer({
    required this.index,
    required this.pointer,
    required this.length,
  });

  final int index;
  final Pointer<Uint8> pointer;
  final int length;
}

/// Minimal Video4Linux2 capture device implemented with `dart:ffi`.
///
/// Only the streaming MMAP API is used. The device is opened in non-blocking
/// mode so [readFrame] can return `null` when no frame is ready instead of
/// blocking the isolate event loop.
class V4l2Device {
  V4l2Device._(this.path, this._fd);

  static const int pixelFormatMjpeg = 0x47504A4D; // 'MJPG'
  static const int pixelFormatYuyv = 0x56595559; // 'YUYV'

  static const int _v4l2BufTypeVideoCapture = 1;
  static const int _v4l2MemoryMmap = 1;
  static const int _v4l2FieldNone = 1;

  static const int _v4l2CapVideoCapture = 0x00000001;
  static const int _v4l2CapVideoOutput = 0x00000002;
  static const int _v4l2CapVideoM2m = 0x00008000;
  static const int _v4l2CapVideoM2mMplane = 0x00004000;
  static const int _v4l2CapStreaming = 0x04000000;
  static const int _v4l2CapDeviceCaps = 0x80000000;

  static const int _oRdwr = 2;
  static const int _oNonblock = 0x800;

  static const int _protRead = 1;
  static const int _protWrite = 2;
  static const int _mapShared = 1;

  static const int _eagain = 11;
  static const int _eintr = 4;

  static const int _vidiocQuerycap = 0x80685600;
  static const int _vidiocGfmt = 0xC0D05604;
  static const int _vidiocSfmt = 0xC0D05605;
  static const int _vidiocReqbufs = 0xC0145608;
  static const int _vidiocQuerybuf = 0xC0585609;
  static const int _vidiocQbuf = 0xC058560F;
  static const int _vidiocDqbuf = 0xC0585611;
  static const int _vidiocStreamon = 0x40045612;
  static const int _vidiocStreamoff = 0x40045613;

  static const int _capabilitySize = 104;
  static const int _formatSize = 208;
  static const int _requestBuffersSize = 20;
  static const int _bufferSize = 88;

  static final DynamicLibrary _libc = DynamicLibrary.process();

  static final _open = _libc
      .lookupFunction<
        Int32 Function(Pointer<Utf8>, Int32),
        int Function(Pointer<Utf8>, int)
      >('open');

  static final _close = _libc
      .lookupFunction<Int32 Function(Int32), int Function(int)>('close');

  static final _ioctl = _libc
      .lookupFunction<
        Int32 Function(Int32, Uint64, Uint64),
        int Function(int, int, int)
      >('ioctl');

  static final _mmap = _libc
      .lookupFunction<
        Pointer<Uint8> Function(
          Pointer<Void>,
          UintPtr,
          Int32,
          Int32,
          Int32,
          Int64,
        ),
        Pointer<Uint8> Function(Pointer<Void>, int, int, int, int, int)
      >('mmap');

  static final _munmap = _libc
      .lookupFunction<
        Int32 Function(Pointer<Void>, UintPtr),
        int Function(Pointer<Void>, int)
      >('munmap');

  static final _errnoLocation = _libc
      .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
        '__errno_location',
      );

  static int get _errno => _errnoLocation().value;

  final String path;
  final int _fd;

  int _width = 0;
  int _height = 0;
  int _pixelFormat = 0;
  int _bytesPerLine = 0;
  int _sizeImage = 0;
  bool _streaming = false;

  final List<_MappedBuffer> _buffers = [];

  late final Pointer<Uint8> _formatPtr = calloc<Uint8>(_formatSize);
  late final Pointer<Uint8> _requestPtr = calloc<Uint8>(_requestBuffersSize);
  late final Pointer<Uint8> _bufferPtr = calloc<Uint8>(_bufferSize);
  late final Pointer<Uint8> _capabilityPtr = calloc<Uint8>(_capabilitySize);
  late final Pointer<Uint8> _intPtr = calloc<Uint8>(4);

  int get width => _width;
  int get height => _height;
  int get pixelFormat => _pixelFormat;
  int get bytesPerLine => _bytesPerLine;
  int get sizeImage => _sizeImage;

  /// Open [path] and negotiate a capture format.
  ///
  /// MJPEG is preferred because frames can be forwarded to WebSocket clients
  /// without re-encoding. YUYV is used as a fallback.
  static V4l2Device open({
    required String path,
    required int width,
    required int height,
  }) {
    final nativePath = path.toNativeUtf8();
    final fd = _open(nativePath, _oRdwr | _oNonblock);
    calloc.free(nativePath);
    if (fd < 0) {
      throw V4l2Exception('Unable to open $path', errno: _errno);
    }

    final device = V4l2Device._(path, fd);
    try {
      device._verifyCaptureCapability();
      device._configureFormat(width, height);
      device._requestBuffers(4);
      device._queueAllBuffers();
      device._streamOn();
      return device;
    } on Object {
      device.close();
      rethrow;
    }
  }

  /// Return `true` when [path] is a streaming video-capture device.
  static bool isCaptureDevice(String path) {
    final nativePath = path.toNativeUtf8();
    final fd = _open(nativePath, _oRdwr | _oNonblock);
    calloc.free(nativePath);
    if (fd < 0) return false;

    final capability = calloc<Uint8>(_capabilitySize);
    try {
      _zero(capability, _capabilitySize);
      if (_ioctl(fd, _vidiocQuerycap, capability.address) != 0) return false;
      var caps = _readU32(capability, 84);
      if ((caps & _v4l2CapDeviceCaps) != 0) {
        caps = _readU32(capability, 88);
      }
      final capture = (caps & _v4l2CapVideoCapture) != 0;
      final output = (caps & _v4l2CapVideoOutput) != 0;
      final memoryToMemory =
          (caps & (_v4l2CapVideoM2m | _v4l2CapVideoM2mMplane)) != 0;
      final streaming = (caps & _v4l2CapStreaming) != 0;
      return capture && !output && !memoryToMemory && streaming;
    } finally {
      _close(fd);
      calloc.free(capability);
    }
  }

  void _verifyCaptureCapability() {
    _zero(_capabilityPtr, _capabilitySize);
    if (_ioctl(_fd, _vidiocQuerycap, _capabilityPtr.address) != 0) {
      throw V4l2Exception('VIDIOC_QUERYCAP failed', errno: _errno);
    }
    var caps = _readU32(_capabilityPtr, 84);
    if ((caps & _v4l2CapDeviceCaps) != 0) {
      caps = _readU32(_capabilityPtr, 88);
    }
    if ((caps & _v4l2CapVideoCapture) == 0) {
      throw V4l2Exception('$path is not a video capture device');
    }
    if ((caps & _v4l2CapVideoOutput) != 0 ||
        (caps & (_v4l2CapVideoM2m | _v4l2CapVideoM2mMplane)) != 0) {
      throw V4l2Exception('$path is a codec or memory-to-memory device');
    }
    if ((caps & _v4l2CapStreaming) == 0) {
      throw V4l2Exception('$path does not support streaming');
    }
  }

  void _configureFormat(int width, int height) {
    for (final candidate in const [pixelFormatMjpeg, pixelFormatYuyv]) {
      _zero(_formatPtr, _formatSize);
      _writeU32(_formatPtr, 0, _v4l2BufTypeVideoCapture);
      _writeU32(_formatPtr, 8, width);
      _writeU32(_formatPtr, 12, height);
      _writeU32(_formatPtr, 16, candidate);
      _writeU32(_formatPtr, 20, _v4l2FieldNone);

      if (_ioctl(_fd, _vidiocSfmt, _formatPtr.address) != 0) continue;

      _zero(_formatPtr, _formatSize);
      _writeU32(_formatPtr, 0, _v4l2BufTypeVideoCapture);
      if (_ioctl(_fd, _vidiocGfmt, _formatPtr.address) != 0) continue;

      final actual = _readU32(_formatPtr, 16);
      if (actual != candidate) continue;

      _width = _readU32(_formatPtr, 8);
      _height = _readU32(_formatPtr, 12);
      _pixelFormat = actual;
      _bytesPerLine = _readU32(_formatPtr, 24);
      _sizeImage = _readU32(_formatPtr, 28);
      return;
    }
    throw V4l2Exception(
      'Unable to negotiate MJPEG or YUYV on $path',
      errno: _errno,
    );
  }

  void _requestBuffers(int count) {
    _zero(_requestPtr, _requestBuffersSize);
    _writeU32(_requestPtr, 0, count);
    _writeU32(_requestPtr, 4, _v4l2BufTypeVideoCapture);
    _writeU32(_requestPtr, 8, _v4l2MemoryMmap);
    if (_ioctl(_fd, _vidiocReqbufs, _requestPtr.address) != 0) {
      throw V4l2Exception('VIDIOC_REQBUFS failed', errno: _errno);
    }
    final allocated = _readU32(_requestPtr, 0);
    if (allocated < 1) {
      throw V4l2Exception('Driver allocated no capture buffers');
    }

    for (var index = 0; index < allocated; index++) {
      _zero(_bufferPtr, _bufferSize);
      _writeU32(_bufferPtr, 0, index);
      _writeU32(_bufferPtr, 4, _v4l2BufTypeVideoCapture);
      _writeU32(_bufferPtr, 8, _v4l2MemoryMmap);
      if (_ioctl(_fd, _vidiocQuerybuf, _bufferPtr.address) != 0) {
        throw V4l2Exception(
          'VIDIOC_QUERYBUF failed for buffer $index',
          errno: _errno,
        );
      }
      final length = _readU32(_bufferPtr, 72);
      final offset = _readU32(_bufferPtr, 64);
      final pointer = _mmap(
        nullptr,
        length,
        _protRead | _protWrite,
        _mapShared,
        _fd,
        offset,
      );
      if (pointer.address == -1) {
        throw V4l2Exception(
          'mmap failed for buffer $index',
          errno: _errno,
        );
      }
      _buffers.add(
        _MappedBuffer(index: index, pointer: pointer, length: length),
      );
    }
  }

  void _queueBuffer(int index) {
    _zero(_bufferPtr, _bufferSize);
    _writeU32(_bufferPtr, 0, index);
    _writeU32(_bufferPtr, 4, _v4l2BufTypeVideoCapture);
    _writeU32(_bufferPtr, 8, _v4l2MemoryMmap);
    if (_ioctl(_fd, _vidiocQbuf, _bufferPtr.address) != 0) {
      throw V4l2Exception(
        'VIDIOC_QBUF failed for buffer $index',
        errno: _errno,
      );
    }
  }

  void _queueAllBuffers() {
    for (final buffer in _buffers) {
      _queueBuffer(buffer.index);
    }
  }

  void _streamOn() {
    _writeU32(_intPtr, 0, _v4l2BufTypeVideoCapture);
    if (_ioctl(_fd, _vidiocStreamon, _intPtr.address) != 0) {
      throw V4l2Exception('VIDIOC_STREAMON failed', errno: _errno);
    }
    _streaming = true;
  }

  void _streamOff() {
    if (!_streaming) return;
    _streaming = false;
    _writeU32(_intPtr, 0, _v4l2BufTypeVideoCapture);
    _ioctl(_fd, _vidiocStreamoff, _intPtr.address);
  }

  /// Dequeue the next frame, or return `null` when no frame is ready yet.
  V4l2Frame? readFrame() {
    while (true) {
      _zero(_bufferPtr, _bufferSize);
      _writeU32(_bufferPtr, 0, 0);
      _writeU32(_bufferPtr, 4, _v4l2BufTypeVideoCapture);
      _writeU32(_bufferPtr, 8, _v4l2MemoryMmap);

      if (_ioctl(_fd, _vidiocDqbuf, _bufferPtr.address) != 0) {
        final error = _errno;
        if (error == _eagain) return null;
        if (error == _eintr) continue;
        throw V4l2Exception('VIDIOC_DQBUF failed', errno: error);
      }

      final index = _readU32(_bufferPtr, 0);
      final used = _readU32(_bufferPtr, 8);
      final buffer = _buffers[index];
      final length = used > buffer.length ? buffer.length : used;
      final bytes = Uint8List.fromList(
        buffer.pointer.asTypedList(length),
      );
      _queueBuffer(index);
      return V4l2Frame(
        bytes: bytes,
        width: _width,
        height: _height,
        pixelFormat: _pixelFormat,
      );
    }
  }

  void close() {
    _streamOff();
    for (final buffer in _buffers) {
      _munmap(buffer.pointer.cast<Void>(), buffer.length);
    }
    _buffers.clear();
    _close(_fd);
    calloc
      ..free(_formatPtr)
      ..free(_requestPtr)
      ..free(_bufferPtr)
      ..free(_capabilityPtr)
      ..free(_intPtr);
  }

  static void _zero(Pointer<Uint8> pointer, int size) {
    pointer.asTypedList(size).fillRange(0, size, 0);
  }

  static int _readU32(Pointer<Uint8> pointer, int offset) {
    return ByteData.sublistView(
      pointer.asTypedList(offset + 4),
    ).getUint32(offset, Endian.host);
  }

  static void _writeU32(Pointer<Uint8> pointer, int offset, int value) {
    ByteData.sublistView(
      pointer.asTypedList(offset + 4),
    ).setUint32(offset, value, Endian.host);
  }
}
