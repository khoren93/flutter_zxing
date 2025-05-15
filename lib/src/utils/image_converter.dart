import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

Uint8List tightlyPackedYPlaneFromCameraImage(CameraImage image) {
  final Plane yPlane = image.planes.first;
  final int bytesPerRow = yPlane.bytesPerRow;

  // If row stride matches the image width, copy directly.
  if (bytesPerRow == image.width) {
    return yPlane.bytes;
  }

  final Uint8List packed = Uint8List(image.width * image.height);

  for (int row = 0; row < image.height; row++) {
    final int srcOffset = row * bytesPerRow;
    final int dstOffset = row * image.width;
    packed.setRange(
        dstOffset, dstOffset + image.width, yPlane.bytes, srcOffset);
  }
  return packed;
}

Future<Uint8List> convertImage(CameraImage image) async {
  try {
    final Plane yPlane = image.planes.first;
    if (image.format.group == ImageFormatGroup.yuv420 &&
        yPlane.bytesPerRow != image.width) {
      return tightlyPackedYPlaneFromCameraImage(image);
    }
    return yPlane.bytes;
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

Uint8List pngFromBytes(Uint8List bytes, int width, int height) {
  final imglib.Image img = imglib.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    numChannels: 1,
  );
  // Encode the resulting image to the PNG image format.
  return imglib.encodePng(img);
}
