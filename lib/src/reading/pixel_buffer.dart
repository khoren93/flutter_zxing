import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Raw pixels to read barcodes from: a video frame, a frame from another
/// camera plugin, a rendered widget, a decoded image.
///
/// ```dart
/// // Y plane of a YUV camera frame:
/// PixelBuffer(plane.bytes, width: w, height: h, rowStride: plane.bytesPerRow)
///
/// // A dart:ui image:
/// final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
/// PixelBuffer(rgba!.buffer.asUint8List(), width: image.width, height: image.height, layout: PixelLayout.rgba)
/// ```
@immutable
final class PixelBuffer {
  /// Wraps [bytes] (not copied until sent to the engine).
  const PixelBuffer(
    this.bytes, {
    required this.width,
    required this.height,
    this.layout = PixelLayout.luminance,
    this.rowStride,
    this.crop,
  });

  /// The pixel data.
  final Uint8List bytes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Byte layout of one pixel.
  final PixelLayout layout;

  /// Bytes per row, if rows are padded. Defaults to `width * bytesPerPixel`.
  final int? rowStride;

  /// Only search this region, in pixels. Positions in the result are still
  /// relative to the whole buffer.
  final Rect? crop;
}

/// Byte layout of the pixels in a [PixelBuffer].
enum PixelLayout {
  /// One byte per pixel: brightness (e.g. the Y plane of YUV).
  luminance(1),

  /// Red, green, blue.
  rgb(3),

  /// Red, green, blue, alpha (`ui.ImageByteFormat.rawRgba`).
  rgba(4),

  /// Blue, green, red, alpha (iOS camera frames).
  bgra(4);

  const PixelLayout(this.bytesPerPixel);

  /// Bytes per pixel.
  final int bytesPerPixel;
}
