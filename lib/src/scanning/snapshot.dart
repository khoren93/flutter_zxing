// Cut-outs of scanned barcodes: the part of a camera frame (or photo)
// around the codes is kept when they are reported; a code is then
// straightened from its four corners into a flat grayscale image.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../barcode/barcode.dart';
import '../reading/pixel_buffer.dart';

/// The grayscale pixels of a frame around some barcodes, and where the
/// barcodes are in it. Kept by a capture until its snapshot is asked for.
@immutable
final class FrameCut {
  /// Creates a cut of [width] × [height] pixels whose top left is [origin]
  /// in the frame.
  const FrameCut(this.gray, this.width, this.height, this.origin);

  /// One byte per pixel, rows without padding.
  final Uint8List gray;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// The cut's top left in the frame.
  final Offset origin;

  int _at(int x, int y) => gray[y * width + x];
}

/// The longest side of a snapshot, in pixels.
const int _maxSide = 360;

/// How far a cut reaches beyond the codes, relative to their size: room for
/// the quiet zone and for the taller box of linear codes.
const double _cutMargin = 0.35;

/// Copies the grayscale pixels of [pixels] around [positions]. `null` if
/// they are outside the frame.
FrameCut? cutFrame(PixelBuffer pixels, List<BarcodePosition> positions) {
  if (positions.isEmpty) {
    return null;
  }
  Rect box = positions.first.bounds;
  for (final BarcodePosition p in positions.skip(1)) {
    box = box.expandToInclude(p.bounds);
  }
  final double reach = box.longestSide * _cutMargin;
  final Rect frame = Rect.fromLTWH(
    0,
    0,
    pixels.width.toDouble(),
    pixels.height.toDouble(),
  );
  final Rect area = box.inflate(reach).intersect(frame);
  if (area.width < 2 || area.height < 2) {
    return null;
  }
  final int left = area.left.floor();
  final int top = area.top.floor();
  final int width = area.right.ceil() - left;
  final int height = area.bottom.ceil() - top;
  final int channels = switch (pixels.layout) {
    PixelLayout.luminance => 1,
    PixelLayout.rgb => 3,
    PixelLayout.rgba || PixelLayout.bgra => 4,
  };
  final int stride = pixels.rowStride ?? pixels.width * channels;
  final Uint8List src = pixels.bytes;
  final Uint8List gray = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    final int row = (top + y) * stride + left * channels;
    if (channels == 1) {
      gray.setRange(y * width, y * width + width, src, row);
      continue;
    }
    // Luma of RGB(A); BGRA swaps red and blue.
    final bool bgr = pixels.layout == PixelLayout.bgra;
    for (int x = 0; x < width; x++) {
      final int i = row + x * channels;
      final int r = src[bgr ? i + 2 : i];
      final int g = src[i + 1];
      final int b = src[bgr ? i : i + 2];
      gray[y * width + x] = (r * 77 + g * 150 + b * 29) >> 8;
    }
  }
  return FrameCut(gray, width, height, Offset(left.toDouble(), top.toDouble()));
}

/// A straightened code: grayscale pixels, rows without padding.
@immutable
final class GrayImage {
  /// Creates an image.
  const GrayImage(this.pixels, this.width, this.height);

  /// One byte per pixel.
  final Uint8List pixels;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// As a `dart:ui` image.
  Future<ui.Image> toImage() {
    final Uint8List rgba = Uint8List(width * height * 4);
    for (int i = 0; i < pixels.length; i++) {
      final int v = pixels[i];
      rgba[i * 4] = v;
      rgba[i * 4 + 1] = v;
      rgba[i * 4 + 2] = v;
      rgba[i * 4 + 3] = 255;
    }
    return ui.ImmutableBuffer.fromUint8List(rgba).then((
      ui.ImmutableBuffer buffer,
    ) async {
      final ui.ImageDescriptor descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final ui.Codec codec = await descriptor.instantiateCodec();
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      return frame.image;
    });
  }
}

/// The corners of the box to cut out around a code at [position]: a margin
/// for the quiet zone, and a linear code's box made tall enough to show its
/// bars.
///
/// A linear code's position only spans the lines the reader read across
/// it, in no particular order, so its "down" is taken from its reading
/// direction instead: clockwise from it, or counter-clockwise in a
/// [mirrored] image.
List<Offset> snapshotCorners(
  BarcodePosition position, {
  required bool linear,
  bool mirrored = false,
}) {
  final Offset tl = position.topLeft;
  final Offset tr = position.topRight;
  final Offset br = position.bottomRight;
  final Offset bl = position.bottomLeft;
  final Offset center = (tl + tr + br + bl) / 4;
  // The code's own axes: along its top edge and down its side.
  final Offset across = ((tr - tl) + (br - bl)) / 2;
  Offset down = ((bl - tl) + (br - tr)) / 2;
  final double width = across.distance;
  if (width == 0) {
    return <Offset>[tl, tr, br, bl];
  }
  final Offset unit = across / width;
  if (linear) {
    // Clockwise from the reading direction in y-down image coordinates.
    final Offset normal = mirrored
        ? Offset(unit.dy, -unit.dx)
        : Offset(-unit.dy, unit.dx);
    down = normal * math.max(down.distance, width * 0.5);
  } else if (down.distance == 0) {
    down = Offset(-unit.dy, unit.dx) * width;
  }
  final double grow = linear ? 1.12 : 1.18;
  final Offset halfAcross = across / 2 * grow;
  final Offset halfDown = down / 2 * grow;
  return <Offset>[
    center - halfAcross - halfDown,
    center + halfAcross - halfDown,
    center + halfAcross + halfDown,
    center - halfAcross + halfDown,
  ];
}

/// Straightens the quadrilateral [corners] (top left, top right, bottom
/// right, bottom left, in frame pixels) of [cut] into a flat image, with
/// its contrast stretched. `null` for a degenerate quadrilateral.
GrayImage? straighten(FrameCut cut, List<Offset> corners) {
  final List<Offset> q = <Offset>[
    for (final Offset c in corners) c - cut.origin,
  ];
  final double top = (q[1] - q[0]).distance;
  final double bottom = (q[2] - q[3]).distance;
  final double left = (q[3] - q[0]).distance;
  final double right = (q[2] - q[1]).distance;
  double w = math.max(top, bottom);
  double h = math.max(left, right);
  if (w < 2 || h < 2) {
    return null;
  }
  final double shrink = math.min(1, _maxSide / math.max(w, h));
  w *= shrink;
  h *= shrink;
  final int width = math.max(1, w.round());
  final int height = math.max(1, h.round());
  final _Homography map = _Homography.squareTo(q);
  final Uint8List out = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    final double v = (y + 0.5) / height;
    for (int x = 0; x < width; x++) {
      final Offset p = map.apply((x + 0.5) / width, v);
      out[y * width + x] = _sample(cut, p.dx - 0.5, p.dy - 0.5);
    }
  }
  _stretch(out);
  return GrayImage(out, width, height);
}

/// Bilinear sample of [cut] at ([x], [y]); white outside.
int _sample(FrameCut cut, double x, double y) {
  if (x < -1 || y < -1 || x > cut.width || y > cut.height) {
    return 255;
  }
  final int x0 = x.floor().clamp(0, cut.width - 1);
  final int y0 = y.floor().clamp(0, cut.height - 1);
  final int x1 = math.min(x0 + 1, cut.width - 1);
  final int y1 = math.min(y0 + 1, cut.height - 1);
  final double fx = (x - x0).clamp(0.0, 1.0);
  final double fy = (y - y0).clamp(0.0, 1.0);
  final double a = cut._at(x0, y0) + (cut._at(x1, y0) - cut._at(x0, y0)) * fx;
  final double b = cut._at(x0, y1) + (cut._at(x1, y1) - cut._at(x0, y1)) * fx;
  return (a + (b - a) * fy).round().clamp(0, 255);
}

/// Maps the darkest 2% to black and the lightest 2% to white, so that a
/// code photographed in dim light looks printed.
void _stretch(Uint8List pixels) {
  final List<int> histogram = List<int>.filled(256, 0);
  for (final int v in pixels) {
    histogram[v]++;
  }
  final int cut = (pixels.length * 0.02).floor();
  int low = 0;
  for (int sum = 0; low < 255 && sum + histogram[low] <= cut; low++) {
    sum += histogram[low];
  }
  int high = 255;
  for (int sum = 0; high > 0 && sum + histogram[high] <= cut; high--) {
    sum += histogram[high];
  }
  if (high - low < 24) {
    return;
  }
  final double scale = 255 / (high - low);
  for (int i = 0; i < pixels.length; i++) {
    pixels[i] = ((pixels[i] - low) * scale).round().clamp(0, 255);
  }
}

/// The projective map from the unit square to the quadrilateral [quad]
/// (top left, top right, bottom right, bottom left), as a camera sees a
/// flat code.
@visibleForTesting
Offset Function(double u, double v) squareToQuad(List<Offset> quad) =>
    _Homography.squareTo(quad).apply;

/// The projective map from the unit square to a quadrilateral.
final class _Homography {
  const _Homography(
    this.a,
    this.b,
    this.c,
    this.d,
    this.e,
    this.f,
    this.g,
    this.h,
  );

  /// Maps (0,0), (1,0), (1,1), (0,1) to [q] (Heckbert's square-to-quad).
  factory _Homography.squareTo(List<Offset> q) {
    final double x0 = q[0].dx, y0 = q[0].dy;
    final double x1 = q[1].dx, y1 = q[1].dy;
    final double x2 = q[2].dx, y2 = q[2].dy;
    final double x3 = q[3].dx, y3 = q[3].dy;
    final double sx = x0 - x1 + x2 - x3;
    final double sy = y0 - y1 + y2 - y3;
    if (sx.abs() < 1e-9 && sy.abs() < 1e-9) {
      // A parallelogram: affine.
      return _Homography(x1 - x0, x2 - x1, x0, y1 - y0, y2 - y1, y0, 0, 0);
    }
    final double dx1 = x1 - x2, dx2 = x3 - x2;
    final double dy1 = y1 - y2, dy2 = y3 - y2;
    final double den = dx1 * dy2 - dx2 * dy1;
    final double g = (sx * dy2 - dx2 * sy) / den;
    final double h = (dx1 * sy - sx * dy1) / den;
    return _Homography(
      x1 - x0 + g * x1,
      x3 - x0 + h * x3,
      x0,
      y1 - y0 + g * y1,
      y3 - y0 + h * y3,
      y0,
      g,
      h,
    );
  }

  final double a, b, c, d, e, f, g, h;

  Offset apply(double u, double v) {
    final double w = g * u + h * v + 1;
    return Offset((a * u + b * v + c) / w, (d * u + e * v + f) / w);
  }
}

/// [position] scaled by [scale].
BarcodePosition scalePosition(BarcodePosition position, double scale) =>
    BarcodePosition(
      topLeft: position.topLeft * scale,
      topRight: position.topRight * scale,
      bottomRight: position.bottomRight * scale,
      bottomLeft: position.bottomLeft * scale,
    );

/// Decodes the image file [encoded] (at most 1600 pixels wide) and cuts it
/// around [positions], given in pixels of an image of [size]. Returns the
/// cut and the scale from [size] to it; `null` if the image cannot be
/// decoded here or is not shown the way the reader saw it (a photo turned
/// by its EXIF orientation).
Future<(FrameCut, double)?> cutEncoded(
  Uint8List encoded,
  Size size,
  List<BarcodePosition> positions,
) async {
  try {
    final ui.Codec codec = await ui.instantiateImageCodec(
      encoded,
      targetWidth: size.width > 1600 ? 1600 : null,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    codec.dispose();
    final ui.Image image = frame.image;
    final int width = image.width;
    final int height = image.height;
    final ByteData? rgba = await image.toByteData();
    image.dispose();
    if (rgba == null ||
        (width / height - size.width / size.height).abs() > 0.02) {
      return null;
    }
    final double scale = width / size.width;
    final FrameCut? cut = cutFrame(
      PixelBuffer(
        rgba.buffer.asUint8List(),
        width: width,
        height: height,
        layout: PixelLayout.rgba,
      ),
      <BarcodePosition>[
        for (final BarcodePosition p in positions) scalePosition(p, scale),
      ],
    );
    return cut == null ? null : (cut, scale);
  } on Object {
    return null;
  }
}
