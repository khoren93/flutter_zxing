// ScannerController.readImage on the real engine: a photo goes through the
// controller's formats and reaches its listeners like a camera frame.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

Future<Uint8List> _png(BarcodeFormat format, String text) async {
  final BarcodeImage image = await BarcodeWriter(
    format,
  ).toImage(text, size: 300);
  return image.toPng();
}

void main() {
  setUpAll(warmUpBarcodeEngine);

  test('reports a photo on the stream and returns it', () async {
    final ScannerController controller = ScannerController(
      formats: <BarcodeFormat>{BarcodeFormat.qrCode},
    );
    addTearDown(controller.dispose);
    final List<BarcodeCapture> reported = <BarcodeCapture>[];
    controller.barcodes.listen(reported.add);

    final BarcodeCapture? capture = await controller.readImage(
      await _png(BarcodeFormat.qrCode, 'from a photo'),
    );
    expect(capture!.barcode.text, 'from a photo');
    expect(capture.source, CaptureSource.image);
    // The writer rounds 300 px down to whole modules.
    expect(capture.imageSize.width, closeTo(300, 15));
    expect(capture.imageSize.height, capture.imageSize.width);
    await pumpEventQueue();
    expect(reported.single.barcode.text, 'from a photo');
  });

  test("uses the controller's formats and finds nothing else", () async {
    final ScannerController controller = ScannerController(
      formats: <BarcodeFormat>{BarcodeFormat.dataMatrix},
    );
    addTearDown(controller.dispose);
    expect(
      await controller.readImage(await _png(BarcodeFormat.qrCode, 'no')),
      isNull,
    );
    controller.formats = null;
    expect(
      await controller.readImage(await _png(BarcodeFormat.qrCode, 'yes')),
      isNotNull,
    );
  });

  test('a file that is not an image throws', () async {
    final ScannerController controller = ScannerController();
    addTearDown(controller.dispose);
    await expectLater(
      controller.readImage(Uint8List.fromList(<int>[1, 2, 3])),
      throwsA(isA<ImageDecodeException>()),
    );
  });
}
