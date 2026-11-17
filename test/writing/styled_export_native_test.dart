// toPng and toSvg with a BarcodeStyle on the real engine: every style is
// exported, decoded and read back with BarcodeReader.
@Tags(<String>['native'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// A 64 × 64 PNG: a dark rounded square, like an app icon.
Future<Uint8List> _logoPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 64, 64),
      const Radius.circular(14),
    ),
    Paint()..color = const Color(0xFF0B3D91),
  );
  final ui.Image image = await recorder.endRecording().toImage(64, 64);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

/// The PNG's size in pixels.
Future<(int, int)> _size(Uint8List png) async {
  final ui.Codec codec = await ui.instantiateImageCodec(png);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final (int, int) size = (frame.image.width, frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return size;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmUpBarcodeEngine);

  const String url = 'https://pub.dev/packages/flutter_zxing';
  const BarcodeWriter qr = BarcodeWriter(BarcodeFormat.qrCode);

  group('toPng', () {
    for (final ModuleShape modules in ModuleShape.values) {
      for (final FinderShape finders in FinderShape.values) {
        test('QR, ${modules.name} modules, ${finders.name} finders', () async {
          final Uint8List png = await BarcodeStyle(
            moduleShape: modules,
            finderShape: finders,
          ).encodePng(qr, url, moduleSize: 6);
          expect((await const BarcodeReader().read(png))?.text, url);
        });
      }
    }

    for (final MapEntry<String, BarcodeStyle> preset
        in BarcodeStyle.presets.entries) {
      test('preset ${preset.key}', () async {
        final Uint8List png = await preset.value.encodePng(
          qr,
          url,
          moduleSize: 5,
        );
        expect((await const BarcodeReader().read(png))?.text, url);
      });
    }

    // Every format the writer creates, in every preset and with dots:
    // the styles leave the parts a reader needs alone. zxing-cpp reads
    // light-on-dark (night) only for QR, Data Matrix and Aztec; its linear
    // and PDF417 readers skip inverted images.
    for (final BarcodeFormat format in BarcodeFormat.writable) {
      test(
        '${format.displayName} reads in every preset and with dots',
        () async {
          final BarcodeReader reader = BarcodeReader(
            formats: <BarcodeFormat>{
              for (final BarcodeFormat f in BarcodeFormat.values)
                if (f.symbology == format.symbology) f,
            },
          );
          final BarcodeWriter writer = BarcodeWriter(format);
          final String data = format.input!.example;
          final bool readsInverted =
              !format.isLinear && format.symbology != BarcodeFormat.pdf417;
          for (final MapEntry<String, BarcodeStyle> style
              in <String, BarcodeStyle>{
                for (final MapEntry<String, BarcodeStyle> p
                    in BarcodeStyle.presets.entries)
                  if (p.key != 'night' || readsInverted) p.key: p.value,
                'dots': const BarcodeStyle(moduleShape: ModuleShape.circle),
              }.entries) {
            final Uint8List png = await style.value.encodePng(
              writer,
              data,
              moduleSize: 6,
            );
            expect(await reader.read(png), isNotNull, reason: style.key);
          }
        },
      );
    }

    test('a gradient on a colored background', () async {
      final Uint8List png = await const BarcodeStyle(
        backgroundColor: Color(0xFFF4F1EA),
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0B3D91), Color(0xFF00735D)],
        ),
        moduleShape: ModuleShape.rounded,
      ).encodePng(qr, url, size: 400);
      expect((await const BarcodeReader().read(png))?.text, url);
    });

    test('a logo raises error correction and still reads', () async {
      final Uint8List logo = await _logoPng();
      final Uint8List png = await BarcodeStyle(
        moduleShape: ModuleShape.rounded,
        finderShape: FinderShape.rounded,
        logo: BarcodeLogo(MemoryImage(logo), size: 0.25),
      ).encodePng(qr, url, moduleSize: 6);
      final Barcode? read = await const BarcodeReader().read(png);
      expect(read?.text, url);
      expect(read?.ecLevel, 'H');
    });

    test('Data Matrix and Aztec dots', () async {
      for (final BarcodeFormat format in <BarcodeFormat>[
        BarcodeFormat.dataMatrix,
        BarcodeFormat.aztec,
      ]) {
        final Uint8List png = await const BarcodeStyle(
          moduleShape: ModuleShape.circle,
        ).encodePng(BarcodeWriter(format), 'Styled $format', moduleSize: 8);
        expect(
          (await const BarcodeReader().read(png))?.text,
          'Styled $format',
          reason: format.displayName,
        );
      }
    });

    test('an EAN-13 with its digits in color', () async {
      final Uint8List png = await const BarcodeStyle(color: Color(0xFF14213D))
          .encodePng(
            const BarcodeWriter(BarcodeFormat.ean13, showText: true),
            '950110153000',
            moduleSize: 3,
          );
      expect((await const BarcodeReader().read(png))?.text, '9501101530003');
    });

    test(
      'size fits whole modules; no quiet zone when the style says so',
      () async {
        final BarcodeSymbol symbol = await qr.encode('size');
        final int side = symbol.width + 2 * symbol.quietZone;
        expect(await _size(await symbol.toPng(size: side * 5 + 3)), (
          side * 5,
          side * 5,
        ));
        expect(
          await _size(
            await const BarcodeStyle(
              quietZone: false,
            ).toPng(symbol, moduleSize: 2),
          ),
          (symbol.width * 2, symbol.width * 2),
        );
        await expectLater(
          symbol.toPng(size: 10, moduleSize: 2),
          throwsArgumentError,
        );
      },
    );
  });

  group('toSvg', () {
    test('a logo is embedded and the QR gets error correction H', () async {
      final String svg = await BarcodeStyle(
        logo: BarcodeLogo(MemoryImage(await _logoPng())),
      ).encodeSvg(qr, url);
      expect(svg, contains('xlink:href="data:image/png;base64,'));
      // The logo only goes on with the most error correction: the same text
      // gives a larger symbol than at the default level.
      final BarcodeSymbol plain = await qr.encode(url);
      final BarcodeSymbol high = await qr
          .copyWith(errorCorrection: ErrorCorrection.high)
          .encode(url);
      expect(high.width, greaterThan(plain.width));
      final int side = high.width + 2 * high.quietZone;
      expect(svg, contains('viewBox="0 0 $side $side"'));
    });
  });
}
