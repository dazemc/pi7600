import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:simcom_api_server/src/camera/camera_capture.dart';
import 'package:test/test.dart';

void main() {
  test('converts a YUYV frame to a decodable JPEG', () {
    const width = 2;
    const height = 2;
    final yuyv = Uint8List(width * height * 2);
    for (var i = 0; i < yuyv.length; i++) {
      // Every 4-byte group is Y0 U Y1 V. Mid-range values produce gray.
      yuyv[i] = 128;
    }

    final jpeg = yuyvToJpeg(yuyv, width, height, width * 2);
    final decoded = img.decodeJpg(jpeg);

    expect(decoded, isNotNull);
    expect(decoded!.width, width);
    expect(decoded.height, height);
  });
}
