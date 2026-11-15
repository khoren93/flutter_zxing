// Cut-outs of scanned codes: a code drawn turned and in perspective into a
// synthetic camera frame is cut out, straightened, and reads back.
@Tags(<String>['native'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/snapshot.dart';

/// A [size] grey frame with [symbol] drawn into the quadrilateral
/// [corners] (its modules, without quiet zone), black on white paper.
PixelBuffer _frame(Size size, BarcodeSymbol symbol, List<Offset> corners) {
  final int width = size.width.round();
  final int height = size.height.round();
  final Uint8List gray = Uint8List(width * height)
    ..fillRange(0, width * height, 90);
  // Paper a little larger than the code, in perspective like a camera.
  final Offset Function(double, double) at = squareToQuad(corners);

  const int steps = 900;
  for (int j = -60; j < steps + 60; j++) {
    for (int i = -60; i < steps + 60; i++) {
      final double u = i / steps;
      final double v = j / steps;
      final Offset p = at(u, v);
      final int x = p.dx.round();
      final int y = p.dy.round();
      if (x < 0 || y < 0 || x >= width || y >= height) {
        continue;
      }
      bool dark = false;
      if (u >= 0 && v >= 0 && u < 1 && v < 1) {
        dark = symbol.isDark(
          (u * symbol.width).floor(),
          (v * symbol.height).floor(),
        );
      }
      gray[y * width + x] = dark ? 30 : 220;
    }
  }
  return PixelBuffer(gray, width: width, height: height);
}

void main() {
  setUpAll(warmUpBarcodeEngine);

  Future<void> roundTrip(List<Offset> corners) async {
    final BarcodeSymbol symbol = await const BarcodeWriter(
      BarcodeFormat.qrCode,
      quietZone: false,
    ).encode('cut out and straightened');
    final PixelBuffer frame = _frame(const Size(640, 480), symbol, corners);
    final BarcodePosition position = BarcodePosition(
      topLeft: corners[0],
      topRight: corners[1],
      bottomRight: corners[2],
      bottomLeft: corners[3],
    );
    final FrameCut cut = cutFrame(frame, <BarcodePosition>[position])!;
    expect(cut.width, lessThan(640));
    final GrayImage image = straighten(
      cut,
      snapshotCorners(position, linear: false),
    )!;
    // Straight: about as wide as high, and the code reads.
    expect(image.width / image.height, closeTo(1, 0.2));
    final Barcode? read = await const BarcodeReader().readPixels(
      PixelBuffer(image.pixels, width: image.width, height: image.height),
    );
    expect(read?.text, 'cut out and straightened');
    // Straightened: its corners are near the image's, not turned.
    final Rect bounds = read!.position.bounds;
    expect(bounds.width / image.width, greaterThan(0.75));
  }

  test('a turned code comes out straight', () async {
    const double a = 25 * math.pi / 180;
    const Offset c = Offset(330, 240);
    const double r = 120;
    Offset corner(double angle) =>
        c + Offset(math.cos(a + angle), math.sin(a + angle)) * r;
    await roundTrip(<Offset>[
      corner(-3 * math.pi / 4),
      corner(-math.pi / 4),
      corner(math.pi / 4),
      corner(3 * math.pi / 4),
    ]);
  });

  test('a code seen at an angle comes out flat', () async {
    await roundTrip(const <Offset>[
      Offset(220, 120),
      Offset(430, 150),
      Offset(410, 360),
      Offset(240, 330),
    ]);
  });

  test('upside down: the code is turned back', () async {
    await roundTrip(const <Offset>[
      Offset(420, 360),
      Offset(220, 360),
      Offset(220, 160),
      Offset(420, 160),
    ]);
  });

  test('a linear code gets a box tall enough for its bars', () {
    final List<Offset> box = snapshotCorners(
      const BarcodePosition(
        topLeft: Offset(100, 200),
        topRight: Offset(300, 200),
        bottomRight: Offset(300, 204),
        bottomLeft: Offset(100, 204),
      ),
      linear: true,
    );
    final double height = (box[3] - box[0]).distance;
    final double width = (box[1] - box[0]).distance;
    expect(height / width, greaterThan(0.45));
    // Centred on the lines that were read.
    expect((box[0] + box[3]).dy / 2, closeTo(202, 1));
  });

  test('a linear code reads top down, whatever order its lines are in '
      '(found on a Pixel 4a: EAN cut-outs were upside down)', () {
    // The lines read across an EAN, listed bottom line first.
    const BarcodePosition band = BarcodePosition(
      topLeft: Offset(100, 230),
      topRight: Offset(300, 230),
      bottomRight: Offset(300, 200),
      bottomLeft: Offset(100, 200),
    );
    final List<Offset> box = snapshotCorners(band, linear: true);
    // Top left above bottom left: the image's top is the code's top.
    expect(box[3].dy, greaterThan(box[0].dy));
    expect(box[1].dx, greaterThan(box[0].dx));
    // Upside down in the frame (read right to left): its top is down.
    final List<Offset> turned = snapshotCorners(
      const BarcodePosition(
        topLeft: Offset(300, 200),
        topRight: Offset(100, 200),
        bottomRight: Offset(100, 230),
        bottomLeft: Offset(300, 230),
      ),
      linear: true,
    );
    expect(turned[3].dy, lessThan(turned[0].dy));
    // A mirrored frame (the iPhone's front camera) flips it back.
    final List<Offset> mirrored = snapshotCorners(
      const BarcodePosition(
        topLeft: Offset(300, 200),
        topRight: Offset(100, 200),
        bottomRight: Offset(100, 230),
        bottomLeft: Offset(300, 230),
      ),
      linear: true,
      mirrored: true,
    );
    expect(mirrored[3].dy, greaterThan(mirrored[0].dy));
  });

  test('cuts stay inside the frame and copy colour frames as gray', () {
    final Uint8List rgba = Uint8List(10 * 10 * 4)..fillRange(0, 400, 255);
    final FrameCut cut = cutFrame(
      PixelBuffer(rgba, width: 10, height: 10, layout: PixelLayout.rgba),
      const <BarcodePosition>[
        BarcodePosition(
          topLeft: Offset(-5, -5),
          topRight: Offset(8, -5),
          bottomRight: Offset(8, 8),
          bottomLeft: Offset(-5, 8),
        ),
      ],
    )!;
    expect(cut.origin, Offset.zero);
    expect(cut.width, 10);
    expect(cut.gray.every((int v) => v >= 254), isTrue);
  });
}
