import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// Camera frames are frequently row-padded so every row starts at an aligned
/// address. Passing such a buffer to the decoder unchanged shifts every row and
/// makes the image unreadable, so the padding has to be stripped first.
CameraImage frame({
  required int width,
  required int height,
  required int bytesPerRow,
  required ImageFormatGroup group,
  int pixelStride = 1,
}) {
  // Fill with a recognisable pattern: real pixels count up from 1, padding is 0.
  final Uint8List bytes = Uint8List(bytesPerRow * height);
  for (int row = 0; row < height; row++) {
    for (int i = 0; i < width * pixelStride; i++) {
      bytes[row * bytesPerRow + i] = row * width * pixelStride + i + 1;
    }
  }
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: CameraImageFormat(group, raw: 0),
      planes: <CameraImagePlane>[
        CameraImagePlane(bytes: bytes, bytesPerRow: bytesPerRow),
      ],
      width: width,
      height: height,
    ),
  );
}

void main() {
  group('convertImage', () {
    test('strips row padding from a YUV420 luminance plane', () async {
      final Uint8List bytes = await convertImage(
        frame(
          width: 4,
          height: 3,
          bytesPerRow: 8, // 4 padding bytes per row
          group: ImageFormatGroup.yuv420,
        ),
      );

      expect(bytes.length, 12);
      expect(bytes, <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    });

    test('strips row padding from an NV21 luminance plane', () async {
      final Uint8List bytes = await convertImage(
        frame(
          width: 4,
          height: 3,
          bytesPerRow: 6,
          group: ImageFormatGroup.nv21,
        ),
      );

      expect(bytes.length, 12);
      expect(bytes, <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
    });

    test('strips row padding from a BGRA8888 plane', () async {
      final Uint8List bytes = await convertImage(
        frame(
          width: 2,
          height: 2,
          bytesPerRow: 12, // 2 pixels * 4 bytes + 4 padding bytes
          group: ImageFormatGroup.bgra8888,
          pixelStride: 4,
        ),
      );

      expect(bytes.length, 2 * 2 * 4);
      expect(bytes, <int>[
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        11,
        12,
        13,
        14,
        15,
        16,
      ]);
    });

    test('passes an unpadded plane through without copying', () async {
      final CameraImage image = frame(
        width: 4,
        height: 3,
        bytesPerRow: 4,
        group: ImageFormatGroup.yuv420,
      );

      final Uint8List bytes = await convertImage(image);
      expect(identical(bytes, image.planes.first.bytes), isTrue);
    });

    test('tightlyPackedYPlaneFromCameraImage matches convertImage', () async {
      final CameraImage image = frame(
        width: 5,
        height: 4,
        bytesPerRow: 9,
        group: ImageFormatGroup.yuv420,
      );

      expect(
        tightlyPackedYPlaneFromCameraImage(image),
        await convertImage(image),
      );
    });

    test('a plane shorter than its declared size does not throw', () async {
      // Defensive: a truncated frame must not take the whole scan loop down.
      final CameraImage image = CameraImage.fromPlatformInterface(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 0),
          planes: <CameraImagePlane>[
            CameraImagePlane(bytes: Uint8List(4), bytesPerRow: 8),
          ],
          width: 4,
          height: 4,
        ),
      );

      final Uint8List bytes = await convertImage(image);
      expect(bytes.length, 16);
    });
  });
}
