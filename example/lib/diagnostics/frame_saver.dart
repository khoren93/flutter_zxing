// Saves the part of the last frame the engine decoded: to read a frame that
// was not decoded again on a computer.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_zxing/flutter_zxing.dart';
// The last frame is not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

/// Writes the decoded part of the last frame as a grayscale PGM with a JSON
/// description into the app's temporary directory. Returns its path, `null`
/// before the first frame.
String? saveLastFrame(ScannerController controller, Map<String, Object?> info) {
  final (PixelBuffer, Rect?)? last = controller.lastFrame;
  if (last == null) {
    return null;
  }
  final (PixelBuffer image, Rect? crop) = last;
  final Rect area =
      crop ??
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
  final int left = area.left.toInt();
  final int top = area.top.toInt();
  final int w = area.width.toInt();
  final int h = area.height.toInt();
  final int bpp = image.layout.bytesPerPixel;
  final int stride = image.rowStride ?? image.width * bpp;
  final Uint8List lum = Uint8List(w * h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int i = (top + y) * stride + (left + x) * bpp;
      final Uint8List b = image.bytes;
      lum[y * w + x] = switch (image.layout) {
        PixelLayout.luminance => b[i],
        PixelLayout.bgra =>
          (306 * b[i + 2] + 601 * b[i + 1] + 117 * b[i] + 0x200) >> 10,
        _ => (306 * b[i] + 601 * b[i + 1] + 117 * b[i + 2] + 0x200) >> 10,
      };
    }
  }
  final Directory dir = Directory('${Directory.systemTemp.path}/frames')
    ..createSync(recursive: true);
  final String name = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')
      .first;
  File(
    '${dir.path}/$name.pgm',
  ).writeAsBytesSync(<int>[...ascii.encode('P5\n$w $h\n255\n'), ...lum]);
  File('${dir.path}/$name.json').writeAsStringSync(
    jsonEncode(<String, Object?>{
      'frame': <int>[image.width, image.height],
      'layout': image.layout.name,
      'crop': <int>[left, top, w, h],
      ...info,
    }),
  );
  return '${dir.path}/$name.pgm';
}
