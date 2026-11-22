// Renders the barcodes the documentation site shows on its pages about
// creating codes, with the package's own PNG export. Skipped unless
// SITE_IMAGES names an output folder (`make site-shots` sets it):
//
//   SITE_IMAGES=website/public/codes flutter test test/tool/site_images_test.dart
//
// Text uses Roboto from the Flutter SDK when FLUTTER_ROOT is set.
@Tags(<String>['native'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

final String? _out = Platform.environment['SITE_IMAGES'];

const TextStyle _text = TextStyle(
  fontFamily: 'Roboto',
  fontWeight: FontWeight.w600,
  color: Color(0xFF0E1218),
);

Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    return;
  }
  final String dir = '$root/bin/cache/artifacts/material_fonts';
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
    final File file = File('$dir/Roboto-$weight.ttf');
    if (file.existsSync()) {
      roboto.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
}

/// Writes [png] as [name], once it reads back as [text]: the site shows
/// only codes that scan.
Future<void> _write(String name, Uint8List png, String text) async {
  final Barcode? read = await const BarcodeReader().read(png);
  expect(read?.text, text, reason: '$name does not read back');
  final File file = File('$_out/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(png);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'site images',
    skip: _out == null ? 'SITE_IMAGES not set' : null,
    () async {
      await _loadFonts();
      const BarcodeWriter qr = BarcodeWriter(BarcodeFormat.qrCode);
      const String url = 'https://pub.dev/packages/flutter_zxing';

      // Every ready-made style.
      for (final MapEntry<String, BarcodeStyle> e
          in BarcodeStyle.presets.entries) {
        await _write(
          'style-${e.key}',
          await e.value.encodePng(qr, url, size: 480),
          url,
        );
      }

      // A logo, with the error correction it needs.
      final MemoryImage logo = MemoryImage(
        File('example/web/icons/Icon-192.png').readAsBytesSync(),
      );
      await _write(
        'logo',
        await BarcodeStyle(
          moduleShape: ModuleShape.rounded,
          finderShape: FinderShape.rounded,
          logo: BarcodeLogo(logo),
        ).encodePng(qr, 'https://flutter.dev', size: 480),
        'https://flutter.dev',
      );

      // A caption and a card, like a profile code in a messenger.
      await _write(
        'caption-card',
        await const BarcodeStyle(
          moduleShape: ModuleShape.rounded,
          finderShape: FinderShape.rounded,
          caption: BarcodeCaption('@FLUTTERDEV', style: _text),
          card: BarcodeCard(elevation: 0.04),
        ).encodePng(qr, 'https://t.me/flutterdev', size: 480),
        'https://t.me/flutterdev',
      );

      // A gradient.
      await _write(
        'gradient',
        await const BarcodeStyle(
          moduleShape: ModuleShape.circle,
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF00735D), Color(0xFF2563EB)],
          ),
        ).encodePng(qr, 'https://pub.dev', size: 480),
        'https://pub.dev',
      );

      // Other formats, black on white.
      // As SVG: its digits are text, drawn by the browser's font.
      final String ean = await const BarcodeWriter(
        BarcodeFormat.ean13,
      ).toSvg('4006381333931', size: 480);
      await File('$_out/ean13.svg').writeAsString(ean);
      await _write(
        'datamatrix-gs1',
        await const BarcodeWriter(
          BarcodeFormat.dataMatrix,
          gs1: true,
        ).toPng('(01)09501101530003(17)270101(10)AB12', size: 480),
        '(01)09501101530003(17)270101(10)AB12',
      );
      await _write(
        'pdf417',
        await const BarcodeWriter(BarcodeFormat.pdf417).toPng(
          'M1DOE/JOHN            EXYZ123 ZRHAMSLX 0423 304Y012A0034 100',
          size: 480,
        ),
        'M1DOE/JOHN            EXYZ123 ZRHAMSLX 0423 304Y012A0034 100',
      );
    },
  );
}
