import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/function_patterns.dart';

void main() {
  Uint8List grid(int size, int Function(int x, int y) dark) =>
      Uint8List.fromList(<int>[
        for (int y = 0; y < size; y++)
          for (int x = 0; x < size; x++) dark(x, y),
      ]);

  test('leaves other formats alone', () {
    final Uint8List modules = grid(21, (int x, int y) => 0);
    expect(
      withQrFunctionPatterns(BarcodeFormat.dataMatrix, 21, 21, modules),
      same(modules),
    );
  });

  test('leaves sizes that are no QR version alone', () {
    final Uint8List modules = grid(22, (int x, int y) => 1);
    expect(
      withQrFunctionPatterns(BarcodeFormat.qrCode, 22, 22, modules),
      same(modules),
    );
  });

  test('puts the dark module of a mirrored code where it is read', () {
    // Finders where a QR code has them, all else light.
    final Uint8List modules = grid(21, (int x, int y) {
      for (final (int fx, int fy) in <(int, int)>[(0, 0), (14, 0), (0, 14)]) {
        final int dx = (x - fx - 3).abs(), dy = (y - fy - 3).abs();
        if (dx <= 3 && dy <= 3) {
          final int ring = dx > dy ? dx : dy;
          return ring == 2 ? 0 : 1;
        }
      }
      return 0;
    });
    final Uint8List plain = withQrFunctionPatterns(
      BarcodeFormat.qrCode,
      21,
      21,
      modules,
    );
    expect(plain[13 * 21 + 8], 1);
    expect(plain[8 * 21 + 13], 0);
    // Transposed: (13, 8) is the dark module, (8, 13) a format bit.
    final Uint8List mirrored = withQrFunctionPatterns(
      BarcodeFormat.qrCode,
      21,
      21,
      modules,
      mirrored: true,
    );
    expect(mirrored[8 * 21 + 13], 1);
    expect(mirrored[13 * 21 + 8], 0);
  });

  test('leaves a grid without finders alone', () {
    final Uint8List modules = grid(21, (int x, int y) => (x * 7 + y * 3) % 2);
    expect(
      withQrFunctionPatterns(BarcodeFormat.qrCode, 21, 21, modules),
      same(modules),
    );
  });
}
