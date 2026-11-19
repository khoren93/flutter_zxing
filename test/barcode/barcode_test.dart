import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  test('BarcodeSequence.toString', () {
    expect(
      const BarcodeSequence(index: 0, size: 3).toString(),
      'BarcodeSequence(index: 0, size: 3)',
    );
    expect(
      const BarcodeSequence(index: 2, size: 0, id: '42').toString(),
      'BarcodeSequence(index: 2, size: 0, id: "42")',
    );
  });
}
