import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

// https://gist.github.com/Alby-o/fe87e35bc21d534c8220aed7df028e03

Future<Uint8List> convertImage(CameraImage image) async {
  try {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return image.planes.first.bytes;
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      final Uint32List bytes =
          _getBGRABytes(image.planes[0].bytes, image.width, image.height);
      return _getLuminanceBytes(bytes, image.width, image.height);
    }
  } catch (e) {
    debugPrint('>>>>>>>>>>>> ERROR: $e');
  }
  return Uint8List(0);
}

Uint8List invertImage(Uint8List bytes) {
  final Uint8List invertedBytes = Uint8List.fromList(bytes);
  for (int i = 0; i < invertedBytes.length; i++) {
    invertedBytes[i] = 255 - invertedBytes[i];
  }
  return invertedBytes;
}

imglib.Image resizeToMaxSize(imglib.Image image, int? maxSize) {
  if (maxSize == null) {
    return image;
  }
  if (image.width > maxSize || image.height > maxSize) {
    final double scaleFactor = maxSize / max(image.width, image.height);
    image =
        imglib.copyResize(image, width: (image.width * scaleFactor).toInt());
  }
  return image;
}

// get the bytes of the image in grayscale format (luminance) like v3
Uint8List grayscaleBytes(imglib.Image image) {
  final Uint32List bytes =
      _getBGRABytes(image.buffer.asUint8List(), image.width, image.height);
  return _getLuminanceBytes(bytes, image.width, image.height);
}

Uint32List _getBGRABytes(Uint8List bytes, int width, int height) {
  final Uint8List input =
      bytes is Uint32List ? Uint8List.view(bytes.buffer) : bytes;

  final Uint32List data = Uint32List(width * height);
  final Uint8List rgba = Uint8List.view(data.buffer);

  for (int i = 0, len = input.length; i < len; i += 4) {
    rgba[i + 0] = input[i + 2];
    rgba[i + 1] = input[i + 1];
    rgba[i + 2] = input[i + 0];
    rgba[i + 3] = input[i + 3];
  }
  return data;
}

Uint8List _getLuminanceBytes(Uint32List data, int width, int height) {
  final Uint8List bytes = Uint8List(width * height);
  for (int i = 0, len = data.length; i < len; ++i) {
    bytes[i] = _getLuminance(data[i]);
  }
  return bytes;
}

/// Returns the luminance (grayscale) value of the [color].
int _getLuminance(int color) {
  final int r = _getRed(color);
  final int g = _getGreen(color);
  final int b = _getBlue(color);
  return _getLuminanceRgb(r, g, b);
}

/// Returns the luminance (grayscale) value of the color.
int _getLuminanceRgb(int r, int g, int b) =>
    (0.299 * r + 0.587 * g + 0.114 * b).round();

/// Get the red channel from the [color].
int _getRed(int color) => color & 0xff;

/// Get the green channel from the [color].
int _getGreen(int color) => (color >> 8) & 0xff;

/// Get the blue channel from the [color].
int _getBlue(int color) => (color >> 16) & 0xff;
