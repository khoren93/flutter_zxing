import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

// https://gist.github.com/Alby-o/fe87e35bc21d534c8220aed7df028e03

Future<Uint8List> convertImage(CameraImage image) async {
  try {
    late imglib.Image img;
    if (image.format.group == ImageFormatGroup.yuv420) {
      // img = convertYUV420(image);
      return image.planes.first.bytes;
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      img = convertBGRA8888(image);
    }
    return img.getBytes(format: imglib.Format.luminance);
  } catch (e) {
    debugPrint('>>>>>>>>>>>> ERROR: $e');
  }
  return Uint8List(0);
}

imglib.Image convertBGRA8888(CameraImage image) {
  return imglib.Image.fromBytes(
    image.width,
    image.height,
    image.planes[0].bytes,
    format: imglib.Format.bgra,
  );
}

// ignore: unused_element
imglib.Image convertYUV420(CameraImage image) {
  final imglib.Image img =
      imglib.Image(image.width, image.height); // Create Image buffer

  final Plane plane = image.planes[0];
  const int shift = 0xFF << 24;

  // Fill image buffer with plane[0] from YUV420_888
  for (int x = 0; x < image.width; x++) {
    for (int planeOffset = 0;
        planeOffset < image.height * image.width;
        planeOffset += image.width) {
      final int pixelColor = plane.bytes[planeOffset + x];
      // color: 0x FF  FF  FF  FF
      //           A   B   G   R
      // Calculate pixel color
      final int newVal =
          shift | (pixelColor << 16) | (pixelColor << 8) | pixelColor;

      img.data[planeOffset + x] = newVal;
    }
  }

  return img;
}
