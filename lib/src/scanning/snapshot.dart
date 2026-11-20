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

/// The whole pixels of [bounds] around [positions], to cut out: `null` if
/// they are outside it.
///
/// A matrix code's cut reaches a third of its size beyond it, for the quiet
/// zone. A [linear] code is known only by the lines read across it, which
/// may run anywhere from the top to the bottom of its bars: its cut reaches
/// almost its width up and down, to find where the bars end.
Rect? cutArea(
  List<BarcodePosition> positions,
  Rect bounds, {
  List<bool>? linear,
}) {
  if (positions.isEmpty) {
    return null;
  }
  Rect? box;
  for (int i = 0; i < positions.length; i++) {
    final Rect code = positions[i].bounds;
    final double reach =
        code.longestSide * (linear != null && linear[i] ? 0.9 : 0.35);
    final Rect around = code.inflate(reach);
    box = box == null ? around : box.expandToInclude(around);
  }
  final Rect area = box!.intersect(bounds);
  if (area.width < 2 || area.height < 2) {
    return null;
  }
  return Rect.fromLTRB(
    area.left.floorToDouble(),
    area.top.floorToDouble(),
    area.right.ceilToDouble(),
    area.bottom.ceilToDouble(),
  );
}

/// Copies the grayscale pixels of [pixels] around [positions] (see
/// [cutArea]). `null` if they are outside the frame.
FrameCut? cutFrame(
  PixelBuffer pixels,
  List<BarcodePosition> positions, {
  List<bool>? linear,
}) {
  final Rect? area = cutArea(
    positions,
    Rect.fromLTWH(0, 0, pixels.width.toDouble(), pixels.height.toDouble()),
    linear: linear,
  );
  if (area == null) {
    return null;
  }
  final int channels = switch (pixels.layout) {
    PixelLayout.luminance => 1,
    PixelLayout.rgb => 3,
    PixelLayout.rgba || PixelLayout.bgra => 4,
  };
  return grayCut(
    pixels.bytes,
    pixels.rowStride ?? pixels.width * channels,
    channels,
    area,
    bgr: pixels.layout == PixelLayout.bgra,
  );
}

/// The grayscale cut of [area] (whole pixels) out of [src], rows [stride]
/// bytes apart with [channels] bytes per pixel (RGB(A), or BGRA with [bgr]).
FrameCut grayCut(
  Uint8List src,
  int stride,
  int channels,
  Rect area, {
  bool bgr = false,
  Offset shift = Offset.zero,
}) {
  final int left = area.left.toInt() - shift.dx.toInt();
  final int top = area.top.toInt() - shift.dy.toInt();
  final int width = area.width.toInt();
  final int height = area.height.toInt();
  final Uint8List gray = Uint8List(width * height);
  for (int y = 0; y < height; y++) {
    final int row = (top + y) * stride + left * channels;
    if (channels == 1) {
      gray.setRange(y * width, y * width + width, src, row);
      continue;
    }
    // Luma of RGB(A); BGRA swaps red and blue.
    for (int x = 0; x < width; x++) {
      final int i = row + x * channels;
      final int r = src[bgr ? i + 2 : i];
      final int g = src[i + 1];
      final int b = src[bgr ? i : i + 2];
      gray[y * width + x] = (r * 77 + g * 150 + b * 29) >> 8;
    }
  }
  return FrameCut(gray, width, height, area.topLeft);
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

/// Turns the box [corners] of a linear code (from [snapshotCorners]) to the
/// bars' real direction, measured in [cut].
///
/// The reader reports a linear code by the lines it scanned across it,
/// which run along the image rows: a code held at a slant would come out
/// slanted. The bars' direction is where the image's gradients point: the
/// dominant orientation of the structure tensor over the box. Kept as is
/// when the box shows no clear bars or they lean more than 40°.
List<Offset> alignToBars(
  FrameCut cut,
  List<Offset> corners, {
  bool mirrored = false,
}) {
  final Offset origin = cut.origin;
  final Offset center = (corners[0] + corners[1] + corners[2] + corners[3]) / 4;
  final Offset across = corners[1] - corners[0];
  final Offset down = corners[3] - corners[0];
  final double width = across.distance;
  final double height = down.distance;
  if (width < 8 || height < 4) {
    return corners;
  }
  double jxx = 0, jyy = 0, jxy = 0;
  const int columns = 64;
  const int rows = 12;
  for (int j = 0; j < rows; j++) {
    for (int i = 0; i < columns; i++) {
      // The middle of the box, where the bars are.
      final Offset p =
          center +
          across * (0.4 * (2 * i / (columns - 1) - 1)) +
          down * (0.15 * (2 * j / (rows - 1) - 1)) -
          origin;
      final int gx =
          _sample(cut, p.dx + 1, p.dy) - _sample(cut, p.dx - 1, p.dy);
      final int gy =
          _sample(cut, p.dx, p.dy + 1) - _sample(cut, p.dx, p.dy - 1);
      jxx += (gx * gx).toDouble();
      jyy += (gy * gy).toDouble();
      jxy += (gx * gy).toDouble();
    }
  }
  final double trace = jxx + jyy;
  if (trace == 0) {
    return corners;
  }
  // Coherence: how much more the gradients agree than not.
  final double spread = math.sqrt((jxx - jyy) * (jxx - jyy) + 4 * jxy * jxy);
  if (spread / trace < 0.5) {
    return corners;
  }
  final double theta = 0.5 * math.atan2(2 * jxy, jxx - jyy);
  Offset axis = Offset(math.cos(theta), math.sin(theta));
  final Offset unit = across / width;
  double cos = axis.dx * unit.dx + axis.dy * unit.dy;
  if (cos < 0) {
    axis = -axis;
    cos = -cos;
  }
  if (cos < math.cos(40 * math.pi / 180)) {
    return corners;
  }
  // A scan line crosses a slanted code on a longer path than its width.
  final Offset along = axis * (width * cos);
  final Offset normal = mirrored
      ? Offset(axis.dy, -axis.dx)
      : Offset(-axis.dy, axis.dx);
  final Offset side = normal * math.max(height, width * cos * 0.5);
  return <Offset>[
    center - along / 2 - side / 2,
    center + along / 2 - side / 2,
    center + along / 2 + side / 2,
    center - along / 2 + side / 2,
  ];
}

/// Fits the box [corners] of a linear code (from [alignToBars]) to its
/// bars, measured in [cut]: the reader only reports the lines it read
/// across the code, not where its bars start and end.
///
/// From the middle line, rows along the bars are followed up and down,
/// each compared with the one before (allowing it to shift a little
/// sideways), until the bar pattern ends. How far the pattern shifted
/// over that height corrects the bars' direction. Room is left above, and
/// below for the digits.
List<Offset> fitBarHeight(FrameCut cut, List<Offset> corners) {
  final Offset origin = cut.origin;
  final Offset center = (corners[0] + corners[1] + corners[2] + corners[3]) / 4;
  final Offset across = corners[1] - corners[0];
  final Offset side = corners[3] - corners[0];
  final double width = across.distance;
  final double height = side.distance;
  if (width < 16 || height == 0) {
    return corners;
  }
  final Offset unit = across / width;
  final Offset down = side / height;
  const int samples = 192;
  const double span = 0.84;
  // Pixels between two samples of a row.
  final double spacing = width * span / (samples - 1);
  List<double> profile(double offset) => <double>[
    for (int i = 0; i < samples; i++)
      () {
        final Offset p =
            center +
            across * (span / 2 * (2 * i / (samples - 1) - 1)) +
            down * offset -
            origin;
        return _sample(cut, p.dx, p.dy).toDouble();
      }(),
  ];
  final List<double> middle = profile(0);
  final double middleSpread = _spread(middle);
  if (middleSpread < 8) {
    return corners;
  }
  final double step = math.max(1, width / 120);
  // How far the bars reach in [direction] (-1 up, 1 down), in pixels, and
  // how many samples the pattern has shifted along the code there.
  (double, double) reach(int direction) {
    List<double> previous = middle;
    double last = 0;
    double shift = 0;
    double lastShift = 0;
    for (double d = step; d < width; d += step) {
      final List<double> row = profile(direction * d);
      if (_spread(row) < middleSpread * 0.35) {
        break;
      }
      double best = -1;
      int bestShift = 0;
      for (int k = -2; k <= 2; k++) {
        final double c = _correlation(previous, row, k);
        if (c > best) {
          best = c;
          bestShift = k;
        }
      }
      if (best < 0.7) {
        break;
      }
      shift += bestShift;
      last = d;
      lastShift = shift;
      previous = row;
    }
    return (last, lastShift);
  }

  final (double up, double upShift) = reach(-1);
  final (double below, double belowShift) = reach(1);
  // The pattern moves along the code by this much per pixel down the bars:
  // the bars lean that way.
  final double reached = up + below;
  final double lean = reached < width * 0.1
      ? 0
      : (belowShift - upShift) * spacing / reached;
  Offset bars = down + unit * lean;
  bars = bars / bars.distance;
  final Offset axis =
      Offset(bars.dy, -bars.dx) *
      ((bars.dy * unit.dx - bars.dx * unit.dy) >= 0 ? 1 : -1);
  final double codeWidth =
      width * (axis.dx * unit.dx + axis.dy * unit.dy).abs();
  // Above: a margin; below: also the digits printed under the bars.
  final double top = -up - codeWidth * 0.06;
  final double bottom = below + codeWidth * 0.16;
  final Offset mid = center + bars * ((top + bottom) / 2);
  final Offset half = bars * ((bottom - top) / 2);
  final Offset halfAcross = axis * (codeWidth / 2);
  return <Offset>[
    mid - halfAcross - half,
    mid + halfAcross - half,
    mid + halfAcross + half,
    mid - halfAcross + half,
  ];
}

double _spread(List<double> values) {
  double sum = 0, squares = 0;
  for (final double v in values) {
    sum += v;
    squares += v * v;
  }
  final double mean = sum / values.length;
  return math.sqrt(math.max(0, squares / values.length - mean * mean));
}

/// Pearson correlation of [a] with [b] moved [shift] samples, over where
/// they overlap.
double _correlation(List<double> a, List<double> b, int shift) {
  final int from = math.max(0, -shift);
  final int to = math.min(a.length, b.length - shift);
  final int n = to - from;
  if (n < 8) {
    return 0;
  }
  double ma = 0, mb = 0;
  for (int i = from; i < to; i++) {
    ma += a[i];
    mb += b[i + shift];
  }
  ma /= n;
  mb /= n;
  double ab = 0, aa = 0, bb = 0;
  for (int i = from; i < to; i++) {
    final double x = a[i] - ma;
    final double y = b[i + shift] - mb;
    ab += x * y;
    aa += x * x;
    bb += y * y;
  }
  return aa == 0 || bb == 0 ? 0 : ab / math.sqrt(aa * bb);
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
  List<BarcodePosition> positions, {
  List<bool>? linear,
}) async {
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
      linear: linear,
    );
    return cut == null ? null : (cut, scale);
  } on Object {
    return null;
  }
}

/// The EXIF orientation of the JPEG file [encoded], 1 to 8; 1 (as stored)
/// for any other file or without one. The reader sees a file's pixels as
/// stored, while Flutter shows them turned by this.
int exifOrientation(Uint8List encoded) {
  final ByteData data = ByteData.sublistView(encoded);
  final int end = data.lengthInBytes;
  if (end < 4 || data.getUint16(0) != 0xFFD8) {
    return 1;
  }
  int at = 2;
  while (at + 4 <= end) {
    final int marker = data.getUint16(at);
    // Not a segment, or the start of the pixels.
    if (marker < 0xFF00 || marker == 0xFFDA) {
      return 1;
    }
    final int length = data.getUint16(at + 2);
    if (length < 2) {
      return 1; // a length counts its own two bytes: not a JPEG after all
    }
    if (marker == 0xFFE1 &&
        length >= 8 &&
        at + 10 <= end &&
        data.getUint32(at + 4) == 0x45786966 && // "Exif"
        data.getUint16(at + 8) == 0) {
      return _tiffOrientation(
        ByteData.sublistView(encoded, at + 10, math.min(at + 2 + length, end)),
      );
    }
    at += 2 + length;
  }
  return 1;
}

/// The orientation tag of the first directory of a TIFF header.
int _tiffOrientation(ByteData tiff) {
  final int end = tiff.lengthInBytes;
  if (end < 8) {
    return 1;
  }
  final Endian? endian = switch (tiff.getUint16(0)) {
    0x4949 => Endian.little,
    0x4D4D => Endian.big,
    _ => null,
  };
  if (endian == null) {
    return 1;
  }
  final int directory = tiff.getUint32(4, endian);
  if (directory + 2 > end) {
    return 1;
  }
  final int entries = tiff.getUint16(directory, endian);
  for (int i = 0; i < entries; i++) {
    final int entry = directory + 2 + i * 12;
    if (entry + 12 > end) {
      return 1;
    }
    if (tiff.getUint16(entry, endian) == 0x0112) {
      final int value = tiff.getUint16(entry + 8, endian);
      return value >= 1 && value <= 8 ? value : 1;
    }
  }
  return 1;
}

/// The size an image of [size] shows in with EXIF [orientation].
Size orientedSize(Size size, int orientation) =>
    orientation >= 5 ? size.flipped : size;

/// Where the point [p] of an image of [size], as stored, shows with EXIF
/// [orientation].
Offset orientedPoint(Offset p, Size size, int orientation) {
  final double w = size.width;
  final double h = size.height;
  return switch (orientation) {
    2 => Offset(w - p.dx, p.dy),
    3 => Offset(w - p.dx, h - p.dy),
    4 => Offset(p.dx, h - p.dy),
    5 => Offset(p.dy, p.dx),
    6 => Offset(h - p.dy, p.dx),
    7 => Offset(h - p.dy, w - p.dx),
    8 => Offset(p.dy, w - p.dx),
    _ => p,
  };
}

/// [position] of an image of [size] where it shows with EXIF [orientation].
BarcodePosition orientedPosition(
  BarcodePosition position,
  Size size,
  int orientation,
) => BarcodePosition(
  topLeft: orientedPoint(position.topLeft, size, orientation),
  topRight: orientedPoint(position.topRight, size, orientation),
  bottomRight: orientedPoint(position.bottomRight, size, orientation),
  bottomLeft: orientedPoint(position.bottomLeft, size, orientation),
);
