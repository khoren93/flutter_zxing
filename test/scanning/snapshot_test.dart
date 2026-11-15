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

  group('linear codes are cut along their bars (found on a Pixel 4a)', () {
    // An EAN-13 on white paper, its bars 140 px high, turned by 8°, in a
    // grey 640 × 480 frame. The reader reports it by the line it read,
    // here near the top of the bars.
    const double angle = 8 * math.pi / 180;
    const Offset center = Offset(320, 240);
    const double barWidth = 300;
    const double barHeight = 140;
    final Offset across = Offset(math.cos(angle), math.sin(angle));
    final Offset down = Offset(-math.sin(angle), math.cos(angle));
    Offset at(double x, double y) =>
        center + across * (x - barWidth / 2) + down * (y - barHeight / 2);

    Future<(PixelBuffer, BarcodePosition)> frame(double lineAt) async {
      final BarcodeSymbol ean = await const BarcodeWriter(
        BarcodeFormat.ean13,
        quietZone: false,
      ).encode('5901234123457');
      final Uint8List gray = Uint8List(640 * 480)..fillRange(0, 640 * 480, 80);
      for (int y = 0; y < 480; y++) {
        for (int x = 0; x < 640; x++) {
          final Offset d = Offset(x.toDouble(), y.toDouble()) - at(0, 0);
          final double u = d.dx * across.dx + d.dy * across.dy;
          final double v = d.dx * down.dx + d.dy * down.dy;
          if (u < -30 || u > barWidth + 30 || v < -30 || v > barHeight + 40) {
            continue;
          }
          final bool bar =
              u >= 0 &&
              u < barWidth &&
              v >= 0 &&
              v < barHeight &&
              ean.isDark((u / barWidth * ean.width).floor(), 0);
          gray[y * 640 + x] = bar ? 25 : 225;
        }
      }
      // The scan line runs along the image row through that height.
      final Offset p = at(barWidth / 2, lineAt);
      final double half = barWidth / 2 / math.cos(angle);
      final BarcodePosition line = BarcodePosition(
        topLeft: Offset(p.dx - half, p.dy),
        topRight: Offset(p.dx + half, p.dy),
        bottomRight: Offset(p.dx + half, p.dy + 1),
        bottomLeft: Offset(p.dx - half, p.dy + 1),
      );
      return (PixelBuffer(gray, width: 640, height: 480), line);
    }

    bool inside(List<Offset> quad, Offset p) {
      for (int i = 0; i < 4; i++) {
        final Offset a = quad[i];
        final Offset b = quad[(i + 1) % 4];
        if ((b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx) < 0) {
          return false;
        }
      }
      return true;
    }

    for (final double lineAt in <double>[15, 70, 125]) {
      test('read at ${lineAt.round()} px of 140', () async {
        final (PixelBuffer pixels, BarcodePosition line) = await frame(lineAt);
        final FrameCut cut = cutFrame(
          pixels,
          <BarcodePosition>[line],
          linear: <bool>[true],
        )!;
        final List<Offset> box = fitBarHeight(
          cut,
          alignToBars(cut, snapshotCorners(line, linear: true)),
        );
        // Turned like the code.
        final Offset top = box[1] - box[0];
        expect(math.atan2(top.dy, top.dx), closeTo(angle, 2 * math.pi / 180));
        // Every bar end is inside, top and bottom.
        for (final Offset corner in <Offset>[
          at(0, 0),
          at(barWidth, 0),
          at(barWidth, barHeight),
          at(0, barHeight),
        ]) {
          expect(inside(box, corner), isTrue, reason: '$corner in $box');
        }
        // And not much more than the bars and the digits' room.
        expect((box[3] - box[0]).distance, lessThan(barHeight + 100));
        final GrayImage image = straighten(cut, box)!;
        final Barcode? read = await const BarcodeReader().readPixels(
          PixelBuffer(image.pixels, width: image.width, height: image.height),
        );
        expect(read?.text, '5901234123457');
      });
    }
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
