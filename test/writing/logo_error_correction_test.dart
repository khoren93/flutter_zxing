// The error correction a logo gets (BarcodeLogo.neededErrorCorrection),
// measured on the engine: under the largest logo of each level a QR code
// reads, and keeps reading with a blot elsewhere on it.
@Tags(<String>['native'])
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/rendering/symbol_shapes.dart';
import 'package:flutter_zxing/src/writing/creator_options.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

/// Whether (x, y) is in a finder pattern with its separator: damage there
/// stops a reader finding the code at all, which error correction does not
/// cover.
bool _finder(int x, int y, int n) =>
    (x < 8 && y < 8) || (x >= n - 8 && y < 8) || (x < 8 && y >= n - 8);

Future<bool> _reads(BarcodeSymbol s, Uint8List modules, String data) async {
  final BarcodeImage image = await BarcodeSymbol(
    format: s.format,
    width: s.width,
    height: s.height,
    modules: modules,
    quietZone: 4,
  ).toImage(moduleSize: 4);
  final Barcode? read = await const BarcodeReader().readPixels(
    PixelBuffer(image.pixels, width: image.width, height: image.height),
  );
  return read?.text == data;
}

void main() {
  final ImageProvider image = MemoryImage(Uint8List(0));

  test('the level by size', () {
    ErrorCorrection at(double size) =>
        BarcodeLogo(image, size: size).neededErrorCorrection;
    expect(at(0.1), ErrorCorrection.medium);
    expect(at(0.12), ErrorCorrection.medium);
    expect(at(0.14), ErrorCorrection.quartile);
    expect(at(0.18), ErrorCorrection.quartile);
    expect(at(0.2), ErrorCorrection.quartile);
    expect(at(0.22), ErrorCorrection.high);
    expect(
      BarcodeLogo(
        image,
        size: 0.3,
        errorCorrection: ErrorCorrection.medium,
      ).neededErrorCorrection,
      ErrorCorrection.medium,
    );
  });

  test('without a logo, QR codes get M', () {
    expect(
      writerCreatorOptions(const BarcodeWriter(BarcodeFormat.qrCode)),
      contains('ecLevel=M'),
    );
    expect(
      writerCreatorOptions(
        const BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: ErrorCorrection.low,
        ),
      ),
      contains('ecLevel=L'),
    );
    expect(
      writerCreatorOptions(const BarcodeWriter(BarcodeFormat.dataMatrix)),
      isNot(contains('ecLevel')),
    );
  });

  // The largest logo of each level, and the default logo.
  for (final double size in <double>[0.12, 0.2, 0.22]) {
    final BarcodeLogo logo = BarcodeLogo(image, size: size);
    final ErrorCorrection level = logo.neededErrorCorrection;
    test('a logo ${(size * 100).round()}% wide on ${level.name}: reads, '
        'and nine times in ten with a blot', () async {
      final math.Random random = math.Random(7);
      int blots = 0;
      int blotsRead = 0;
      // Short links to long ones: versions 2 to about 12.
      for (final int length in <int>[16, 24, 32, 44, 60, 80, 100, 130, 160]) {
        final String data =
            'https://example.com/${'x' * math.max(0, length - 20)}';
        final BarcodeSymbol symbol = await BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: level,
          quietZone: false,
        ).encode(data);
        final int n = symbol.width;
        final LogoBox box = SymbolShapes(
          symbol,
          SymbolLayout(symbol),
          BarcodeStyle(logo: logo),
        ).logo!;
        final Uint8List modules = Uint8List.fromList(symbol.modules);
        for (int y = 0; y < n; y++) {
          for (int x = 0; x < n; x++) {
            if (box.clears(x, y)) {
              modules[y * n + x] = 0;
            }
          }
        }
        expect(
          await _reads(symbol, modules, data),
          isTrue,
          reason: '$length characters, ${n}x$n: the logo alone',
        );
        // A blot a quarter of the logo's area (half its side), its modules
        // flipped: dirt, glare, a crease.
        final (int, int, int, int) c = box.cleared!;
        final int side = math.max(1, ((c.$3 - c.$1) / 2).round());
        final List<(int, int)> spots = <(int, int)>[
          for (int y = 0; y + side <= n; y++)
            for (int x = 0; x + side <= n; x++)
              if (!<bool>[
                for (int dy = 0; dy < side; dy++)
                  for (int dx = 0; dx < side; dx++)
                    box.clears(x + dx, y + dy) || _finder(x + dx, y + dy, n),
              ].contains(true))
                (x, y),
        ];
        for (int t = 0; t < 6 && spots.isNotEmpty; t++) {
          final (int bx, int by) = spots[random.nextInt(spots.length)];
          final Uint8List blotted = Uint8List.fromList(modules);
          for (int y = by; y < by + side; y++) {
            for (int x = bx; x < bx + side; x++) {
              blotted[y * n + x] ^= 1;
            }
          }
          blots++;
          if (await _reads(symbol, blotted, data)) {
            blotsRead++;
          }
        }
      }
      expect(
        blotsRead / blots,
        greaterThanOrEqualTo(0.9),
        reason: '$blotsRead of $blots blotted codes read',
      );
    });
  }
}
