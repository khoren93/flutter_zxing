import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  group('toString', () {
    test('ReaderOptions shows what differs from the defaults', () {
      expect(const ReaderOptions().toString(), 'ReaderOptions()');
      expect(
        const ReaderOptions.camera().toString(),
        'ReaderOptions(tryInvert: false)',
      );
      expect(
        const ReaderOptions(
          isPure: true,
          binarizer: Binarizer.boolCast,
          minLineCount: 3,
          eanAddOn: EanAddOn.read,
          characterSet: CharacterSet.cp1251,
        ).toString(),
        'ReaderOptions(isPure: true, binarizer: boolCast, minLineCount: 3, '
        'eanAddOn: read, characterSet: cp1251)',
      );
    });

    test('BarcodeReader shows its formats and options', () {
      expect(const BarcodeReader().toString(), 'BarcodeReader()');
      expect(
        const BarcodeReader(
          formats: <BarcodeFormat>{BarcodeFormat.qrCode, BarcodeFormat.ean13},
          options: ReaderOptions.camera(),
        ).toString(),
        'BarcodeReader(formats: {qrCode, ean13}, '
        'options: ReaderOptions(tryInvert: false))',
      );
    });
  });

  test('copyWith cannot clear formats: create a new reader', () {
    const BarcodeReader qr = BarcodeReader(
      formats: <BarcodeFormat>{BarcodeFormat.qrCode},
      options: ReaderOptions(isPure: true),
    );
    // null means "keep": the formats stay.
    expect(qr.copyWith().formats, <BarcodeFormat>{BarcodeFormat.qrCode});
    final BarcodeReader all = BarcodeReader(options: qr.options);
    expect(all.formats, isNull);
    expect(all.options, qr.options);
  });
}
