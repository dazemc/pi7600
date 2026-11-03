import 'dart:async';
import 'dart:typed_data';

import 'package:simcom_api_server/src/camera/video_broadcaster.dart';
import 'package:test/test.dart';

import 'support/fake_web_socket.dart';

void main() {
  late StreamController<Uint8List> frames;
  late VideoBroadcaster broadcaster;

  setUp(() {
    frames = StreamController<Uint8List>.broadcast();
    broadcaster = VideoBroadcaster()..attach(frames.stream);
  });

  tearDown(() async {
    await broadcaster.stop();
    await frames.close();
  });

  test('forwards frames to every connected client', () async {
    final first = FakeWebSocket();
    final second = FakeWebSocket();
    broadcaster.add(first);
    broadcaster.add(second);

    frames.add(Uint8List.fromList([1, 2, 3]));
    await Future<void>.delayed(Duration.zero);

    expect(first.sentBytes, hasLength(1));
    expect(second.sentBytes, hasLength(1));
    expect(broadcaster.clientCount, 2);
  });

  test('removes a client that cannot accept a frame', () async {
    final broken = FakeWebSocket(sendBytesResult: false);
    final healthy = FakeWebSocket();
    broadcaster.add(broken);
    broadcaster.add(healthy);

    frames.add(Uint8List.fromList([1]));
    await Future<void>.delayed(Duration.zero);

    expect(broadcaster.clientCount, 1);
    expect(healthy.sentBytes, hasLength(1));
  });

  test('stops and closes every client', () async {
    final first = FakeWebSocket();
    final second = FakeWebSocket();
    broadcaster.add(first);
    broadcaster.add(second);

    await broadcaster.stop();

    expect(first.isClosed, isTrue);
    expect(second.isClosed, isTrue);
    expect(broadcaster.hasClients, isFalse);
  });
}
