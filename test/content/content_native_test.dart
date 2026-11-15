// BarcodeContent on barcodes the real engine read: zxing-cpp's sample images
// and barcodes written by BarcodeWriter.
@Tags(<String>['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// zxing-cpp's samples, from the submodule the engine is built from.
Uint8List _sample(String name) => Uint8List.fromList(
  File('third_party/zxing-cpp/test/samples/$name').readAsBytesSync(),
);

Future<Barcode?> _roundTrip(BarcodeWriter writer, String data) async {
  final BarcodeSymbol symbol = await writer.encode(data);
  final BarcodeImage image = await symbol.toImage(moduleSize: 4);
  return const BarcodeReader().readPixels(
    PixelBuffer(image.pixels, width: image.width, height: image.height),
  );
}

void main() {
  const BarcodeReader reader = BarcodeReader();

  group('samples', () {
    test('vCard QR code', () async {
      final Barcode? barcode = await reader.read(_sample('qrcode-2/11.png'));
      final ContactContent contact = barcode!.content as ContactContent;
      expect(contact.name, 'Steve Kennedy');
      expect(contact.organization, 'NetTek Ltd');
      expect(contact.phones, <String>['+44 (0)7775 755503']);
      expect(contact.urls, <Uri>[Uri.parse('https://www.nettek.co.uk')]);
    });

    test('GS1 Data Matrix', () async {
      final Barcode? barcode = await reader.read(
        _sample('datamatrix-1/gs1-figure-4.15.1-2-32x32.png'),
      );
      expect(barcode!.contentType, BarcodeContentType.gs1);
      final Gs1Content gs1 = barcode.content as Gs1Content;
      expect(gs1.elements, <String, String>{
        '01': '09504000059101',
        '21': '12345678p901',
        '10': '1234567p',
        '17': '141120',
        '8200': 'http://www.gs1.org/demo/',
      });
      // Same split as the engine's human readable text.
      expect(
        gs1.elements.entries
            .map((MapEntry<String, String> e) => '(${e.key})${e.value}')
            .join(),
        barcode.text,
      );
    });

    test('GS1 DataBar Expanded and Expanded Stacked', () async {
      for (final String name in <String>[
        'rssexpanded-1/10.png',
        'rssexpandedstacked-2/1.png',
      ]) {
        final Barcode? barcode = await reader.read(_sample(name));
        final Gs1Content gs1 = barcode!.content as Gs1Content;
        expect(
          gs1.elements.entries
              .map((MapEntry<String, String> e) => '(${e.key})${e.value}')
              .join(),
          barcode.text,
          reason: name,
        );
      }
    });

    test('GS1 Code 128 that is not valid GS1 is text', () async {
      final Barcode? barcode = await reader.read(_sample('code128-1/1.png'));
      expect(barcode!.contentType, BarcodeContentType.gs1);
      expect(barcode.content, TextContent(barcode.text));
    });

    test('QR structured append: four symbols, one message', () async {
      final List<Barcode> parts = <Barcode>[
        for (final int i in <int>[3, 1, 4, 2])
          (await reader.read(_sample('qrcode-7/01-0$i.png')))!,
      ];
      expect(parts.map((Barcode b) => b.sequence?.size), everyElement(4));
      expect(Barcode.merge(parts.take(3)), isNull);
      final Barcode? message = Barcode.merge(parts);
      expect(
        message?.text,
        File(
          'third_party/zxing-cpp/test/samples/qrcode-7/01.txt',
        ).readAsStringSync(),
      );
    });
  });

  group('written and read back', () {
    test('Wi-Fi QR code', () async {
      final Barcode? barcode = await _roundTrip(
        const BarcodeWriter(BarcodeFormat.qrCode),
        r'WIFI:T:WPA;S:Lumen Guest;P:espresso\;2026;;',
      );
      expect(
        barcode!.content,
        const WifiContent(ssid: 'Lumen Guest', password: 'espresso;2026'),
      );
    });

    test(
      'GS1 Data Matrix with a variable length field in the middle',
      () async {
        final Barcode? barcode = await _roundTrip(
          const BarcodeWriter(BarcodeFormat.dataMatrix, gs1: true),
          '(01)09501101530003(10)ABC123(17)250101',
        );
        expect(barcode!.contentType, BarcodeContentType.gs1);
        expect(
          barcode.content,
          const Gs1Content(<String, String>{
            '01': '09501101530003',
            '10': 'ABC123',
            '17': '250101',
          }),
        );
      },
    );

    test('binary QR code', () async {
      final Uint8List data = Uint8List.fromList(<int>[0, 1, 2, 0xFE, 0xFF]);
      final BarcodeSymbol symbol = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).encodeBytes(data);
      final BarcodeImage image = await symbol.toImage(moduleSize: 4);
      final Barcode? barcode = await reader.readPixels(
        PixelBuffer(image.pixels, width: image.width, height: image.height),
      );
      expect(barcode!.content, BinaryContent(data));
    });
  });
}
