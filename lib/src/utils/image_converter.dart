import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

/// Copies [plane] into a tightly packed buffer of `width * height * pixelStride`
/// bytes, dropping the row padding the camera may add.
///
/// Camera planes are frequently padded so that every row starts at an aligned
/// address (`bytesPerRow > width * pixelStride`). Handing such a buffer to the
/// decoder as-is shifts every row and makes the image unreadable.
Uint8List _tightlyPackedPlane(
  Plane plane,
  int width,
  int height,
  int pixelStride,
) {
  final int rowLength = width * pixelStride;
  final int bytesPerRow = plane.bytesPerRow;
  if (bytesPerRow == rowLength) {
    return plane.bytes;
  }

  final Uint8List packed = Uint8List(rowLength * height);
  for (int row = 0; row < height; row++) {
    final int srcOffset = row * bytesPerRow;
    if (srcOffset + rowLength > plane.bytes.length) {
      break;
    }
    packed.setRange(
      row * rowLength,
      row * rowLength + rowLength,
      plane.bytes,
      srcOffset,
    );
  }
  return packed;
}

/// Returns the luminance (Y) plane of [image] without its row padding.
Uint8List tightlyPackedYPlaneFromCameraImage(CameraImage image) =>
    _tightlyPackedPlane(image.planes.first, image.width, image.height, 1);

/// Extracts the bytes the decoder should scan from a camera frame.
///
/// For YUV420 and NV21 that is the luminance plane, which is the first plane in
/// both layouts; for BGRA8888 it is the whole interleaved plane. In every case
/// the row padding is removed so the buffer matches `width x height`.
Future<Uint8List> convertImage(CameraImage image) async {
  try {
    final Plane plane = image.planes.first;
    final int pixelStride = switch (image.format.group) {
      ImageFormatGroup.bgra8888 => 4,
      _ => 1,
    };
    return _tightlyPackedPlane(plane, image.width, image.height, pixelStride);
  } catch (e) {
    debugPrint('flutter_zxing: failed to convert camera image: $e');
  }
  return Uint8List(0);
}

/// Scales [image] down so that neither side exceeds [maxSize], preserving the
/// aspect ratio. Returns [image] untouched when [maxSize] is null or not
/// positive, or when the image already fits.
imglib.Image resizeToMaxSize(imglib.Image image, int? maxSize) {
  if (maxSize == null || maxSize <= 0) {
    return image;
  }
  final int longestSide = max(image.width, image.height);
  if (longestSide <= maxSize) {
    return image;
  }
  final double scaleFactor = maxSize / longestSide;
  // Round up so a very thin image never collapses to a zero-sized side, which
  // `copyResize` rejects.
  return imglib.copyResize(
    image,
    width: max(1, (image.width * scaleFactor).round()),
    height: max(1, (image.height * scaleFactor).round()),
  );
}

/// Returns [image] as a tightly packed 8-bit RGB buffer of
/// `width * height * 3` bytes.
///
/// [imglib.Image.getBytes] hands back the image's own storage, which for a
/// palette image, a 1/2/4-bit image or a 16-bit image is not 8-bit RGB and can
/// be a small fraction of the expected size — a 1-bit PNG stores 8 pixels per
/// byte. Passing such a buffer to the decoder while telling it the image is RGB
/// makes it read far past the end of the allocation. Convert first so the
/// buffer always matches the dimensions the decoder is given.
Uint8List rgbBytes(imglib.Image image) {
  final imglib.Image rgb =
      image.hasPalette ||
          image.format != imglib.Format.uint8 ||
          image.numChannels < 3
      ? image.convert(format: imglib.Format.uint8, numChannels: 3)
      : image;
  return rgb.getBytes(order: imglib.ChannelOrder.rgb);
}

/// Encodes a single-channel (grayscale) buffer as a PNG.
///
/// [bytes] must hold at least `width * height` bytes. Both the barcode bitmap
/// returned by `zx.encodeBarcode` and the debug image on a [Code] use this
/// layout — pass the `width`/`height` reported by the result, not the ones you
/// requested, since the encoder enlarges symbols that do not fit.
Uint8List pngFromBytes(Uint8List bytes, int width, int height) {
  if (width <= 0 || height <= 0) {
    throw ArgumentError(
      'pngFromBytes: width and height must be positive, got ${width}x$height',
    );
  }
  final int expectedLength = width * height;
  if (bytes.length < expectedLength) {
    throw ArgumentError(
      'pngFromBytes: expected at least $expectedLength bytes for a '
      '${width}x$height image, got ${bytes.length}',
    );
  }
  final imglib.Image img = imglib.Image.fromBytes(
    width: width,
    height: height,
    bytes: bytes.buffer,
    // `bytes` may be a view into a larger buffer, in which case its data does
    // not start at offset 0 of that buffer.
    bytesOffset: bytes.offsetInBytes,
    numChannels: 1,
  );
  // Encode the resulting image to the PNG image format.
  return imglib.encodePng(img);
}
