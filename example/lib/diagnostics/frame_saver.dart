// Saves the part of the last frame the engine decoded: to read a frame that
// was not decoded again on a computer.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter_zxing/flutter_zxing.dart';
// The last frame is not public API.
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import 'recording.dart' show lumaOf;

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
  final Directory dir = Directory('${Directory.systemTemp.path}/frames')
    ..createSync(recursive: true);
  final String name = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')
      .first;
  File('${dir.path}/$name.pgm').writeAsBytesSync(<int>[
    ...ascii.encode('P5\n$w $h\n255\n'),
    ...lumaOf(image, crop),
  ]);
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
