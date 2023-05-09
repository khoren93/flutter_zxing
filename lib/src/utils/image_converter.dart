import 'dart:math';
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
    return img.getBytes(format: imglib.Format.luminance); //.toUint8List();
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
    // format: imglib.Format.int8,
    // order: imglib.ChannelOrder.bgra,
  );
}

// ignore: unused_element
// imglib.Image convertYUV420(CameraImage image) {
//   final imglib.Image img = imglib.Image(
//     width: image.width,
//     height: image.height,
//   ); // Create Image buffer

//   final Plane plane = image.planes[0];
//   const int shift = 0xFF << 24;

//   // Fill image buffer with plane[0] from YUV420_888
//   for (int x = 0; x < image.width; x++) {
//     for (int planeOffset = 0;
//         planeOffset < image.height * image.width;
//         planeOffset += image.width) {
//       final int pixelColor = plane.bytes[planeOffset + x];
//       // color: 0x FF  FF  FF  FF
//       //           A   B   G   R
//       // Calculate pixel color
//       final int newVal =
//           shift | (pixelColor << 16) | (pixelColor << 8) | pixelColor;

//       // img.data?.buffer[planeOffset + x] = newVal;
//     }
//   }

//   return img;
// }

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
  return image.getBytes(format: imglib.Format.luminance);
  // final imglib.Image imgRgba8 = image.convert(
  //   format: imglib.Format.uint8,
  //   numChannels: 1,
  // ); // Make sure it's an RGBA 32-bit image like v3
  // imglib.grayscale(imgRgba8); // map the pixels to grayscale (luminance)
  // return imgRgba8.getBytes();
}
