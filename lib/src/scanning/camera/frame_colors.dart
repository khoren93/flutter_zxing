// A camera frame in color, turned the way the preview shows it: the picture
// that stays on screen when ScannerTemplate.pick freezes the camera.
import 'dart:math' as math;
import 'dart:typed_data';

import '../../reading/pixel_buffer.dart';
import '../frame_geometry.dart';

/// The longest side of a frozen frame.
const int _longestSide = 1280;

/// The pixels of a camera frame, with its colors where they are separate
/// (YUV 4:2:0).
final class FrameColors {
  /// Creates the colors of a frame of [width] × [height]. [bytes] holds the
  /// brightness of a YUV frame ([u] and [v] set), otherwise the pixels in
  /// [layout].
  const FrameColors(
    this.bytes, {
    required this.width,
    required this.height,
    required this.stride,
    this.layout = PixelLayout.luminance,
    this.u,
    this.v,
    this.vOffset = 0,
    this.chromaStride = 0,
    this.chromaPixelStride = 1,
    this.limitedRange = false,
  });

  /// The colors of [pixels], which have no separate color planes.
  FrameColors.of(PixelBuffer pixels)
    : this(
        pixels.bytes,
        width: pixels.width,
        height: pixels.height,
        stride: pixels.rowStride ?? pixels.width * pixels.layout.bytesPerPixel,
        layout: pixels.layout,
      );

  /// The brightness plane, or all the pixels.
  final Uint8List bytes;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Bytes per row of [bytes].
  final int stride;

  /// Byte layout of [bytes].
  final PixelLayout layout;

  /// The blue-difference plane, for every 2 × 2 pixels.
  final Uint8List? u;

  /// The red-difference plane; the same buffer as [u] when they alternate.
  final Uint8List? v;

  /// Where [v] starts in each of its samples.
  final int vOffset;

  /// Bytes per row of [u] and [v].
  final int chromaStride;

  /// Bytes from one color sample to the next.
  final int chromaPixelStride;

  /// Whether brightness runs from 16 to 235 (video range), not 0 to 255.
  final bool limitedRange;
}

/// [job]'s frame as RGBA pixels, turned and mirrored by its transform into
/// the display frame, at most [_longestSide] long. Returns the pixels and
/// their size. A plain function, to run in another isolate.
(Uint8List, int, int) frameToRgba((FrameColors, FrameTransform) job) {
  final (FrameColors frame, FrameTransform transform) = job;
  final int w = frame.width;
  final int h = frame.height;
  final bool turned = transform.rotation % 180 != 0;
  final int shownWidth = turned ? h : w;
  final int shownHeight = turned ? w : h;
  final int step = math.max(1, (math.max(w, h) / _longestSide).ceil());
  final int outWidth = shownWidth ~/ step;
  final int outHeight = shownHeight ~/ step;
  final Uint8List out = Uint8List(outWidth * outHeight * 4);
  int at = 0;
  for (int oy = 0; oy < outHeight; oy++) {
    final int my = oy * step;
    for (int ox = 0; ox < outWidth; ox++) {
      final int dx = ox * step;
      final int mx = transform.mirrored ? shownWidth - 1 - dx : dx;
      final (int x, int y) = switch (transform.rotation) {
        90 => (my, h - 1 - mx),
        180 => (w - 1 - mx, h - 1 - my),
        270 => (w - 1 - my, mx),
        _ => (mx, my),
      };
      _putPixel(frame, x, y, out, at);
      at += 4;
    }
  }
  return (out, outWidth, outHeight);
}

void _putPixel(FrameColors f, int x, int y, Uint8List out, int at) {
  final int i = y * f.stride + x * f.layout.bytesPerPixel;
  final Uint8List b = f.bytes;
  if (i + f.layout.bytesPerPixel > b.length) {
    out[at + 3] = 255;
    return;
  }
  final Uint8List? uPlane = f.u;
  final Uint8List? vPlane = f.v;
  int r;
  int g;
  int c;
  if (uPlane != null && vPlane != null) {
    final int s = (y ~/ 2) * f.chromaStride + (x ~/ 2) * f.chromaPixelStride;
    final int v2 = s + f.vOffset;
    final int u = (s < uPlane.length ? uPlane[s] : 128) - 128;
    final int v = (v2 < vPlane.length ? vPlane[v2] : 128) - 128;
    if (f.limitedRange) {
      final int l = (b[i] - 16) * 298;
      r = (l + 409 * v + 128) >> 8;
      g = (l - 100 * u - 208 * v + 128) >> 8;
      c = (l + 516 * u + 128) >> 8;
    } else {
      final int l = b[i] << 8;
      r = (l + 359 * v) >> 8;
      g = (l - 88 * u - 183 * v) >> 8;
      c = (l + 454 * u) >> 8;
    }
  } else {
    switch (f.layout) {
      case PixelLayout.luminance:
        r = g = c = b[i];
      case PixelLayout.rgb || PixelLayout.rgba:
        r = b[i];
        g = b[i + 1];
        c = b[i + 2];
      case PixelLayout.bgra:
        c = b[i];
        g = b[i + 1];
        r = b[i + 2];
    }
  }
  out[at] = r.clamp(0, 255);
  out[at + 1] = g.clamp(0, 255);
  out[at + 2] = c.clamp(0, 255);
  out[at + 3] = 255;
}
