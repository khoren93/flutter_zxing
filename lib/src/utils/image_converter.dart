import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

Future<Uint8List> convertImage(CameraImage image) async {
  try {
    return image.planes.first.bytes;
  } catch (e) {
    debugPrint('>>>>>>>>>>>> ERROR: $e');
  }
  return Uint8List(0);
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

Uint8List rgbBytes(imglib.Image image) {
  return image.getBytes(order: imglib.ChannelOrder.rgb);
}
