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

  test('leaves a grid without finders alone', () {
    final Uint8List modules = grid(21, (int x, int y) => (x * 7 + y * 3) % 2);
    expect(
      withQrFunctionPatterns(BarcodeFormat.qrCode, 21, 21, modules),
      same(modules),
    );
  });
}
