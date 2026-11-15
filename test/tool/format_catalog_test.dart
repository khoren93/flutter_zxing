// A sheet with a code of every format the scanner reads, to show on a
// screen and scan with a phone. Formats BarcodeWriter creates are drawn by
// BarcodeView; the others are samples from zxing-cpp's test images
// (third_party/zxing-cpp). Skipped unless CATALOG names the output file:
//
//   CATALOG=/tmp/formats.png flutter test test/tool/format_catalog_test.dart
//
// Text uses Roboto from the Flutter SDK when FLUTTER_ROOT is set.
@Tags(<String>['native'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

final String? _out = Platform.environment['CATALOG'];
const String _samples = 'third_party/zxing-cpp/test/samples';
final GlobalKey _boundary = GlobalKey();

/// A code BarcodeView draws: format, data.
typedef _Drawn = (BarcodeFormat, String);

/// A tile: its label and either a drawn code or a sample image path. Wide
/// codes take two cells, see [_wide].
final List<(String, Object)> _tiles = <(String, Object)>[
  // Two-dimensional.
  ('QR Code', (BarcodeFormat.qrCode, 'https://pub.dev/packages/flutter_zxing')),
  ('Micro QR Code', '$_samples/microqrcode-1/M2-Alpha.png'),
  ('rMQR Code', '$_samples/rmqrcode-1/R7x43-H.png'),
  ('Data Matrix', (BarcodeFormat.dataMatrix, 'flutter_zxing 4.0')),
  ('Aztec', (BarcodeFormat.aztec, 'flutter_zxing 4.0')),
  ('PDF417', (BarcodeFormat.pdf417, 'flutter_zxing 4.0 PDF417')),
  ('MicroPDF417', '$_samples/micropdf417-1/MPDF-0.png'),
  // zxing-cpp reads MaxiCode only from clean, straight images (files,
  // screenshots), not from the camera.
  ('MaxiCode (files only)', '$_samples/maxicode-1/MODE2.png'),
  // Retail.
  ('EAN-13', (BarcodeFormat.ean13, '5901234123457')),
  ('EAN-8', (BarcodeFormat.ean8, '96385074')),
  ('UPC-A', (BarcodeFormat.upcA, '036000291452')),
  ('UPC-E', (BarcodeFormat.upcE, '01234565')),
  ('ISBN (EAN-13)', (BarcodeFormat.ean13, '9783161484100')),
  ('EAN-13 + EAN-5 add-on', '$_samples/ean13-extension-1/1.png'),
  ('DataBar', '$_samples/rss14-1/4.png'),
  ('DataBar Stacked', '$_samples/rss14-2/2.png'),
  ('DataBar Limited', '$_samples/databarltd-1/00.png'),
  ('DataBar Expanded', '$_samples/rssexpanded-1/14.png'),
  ('DataBar Expanded Stacked', '$_samples/rssexpandedstacked-1/1.png'),
  // Industrial and others.
  ('Code 128', (BarcodeFormat.code128, 'FLUTTER-ZXING-4')),
  ('Code 39', (BarcodeFormat.code39, 'ZXING-4')),
  ('Code 39 Extended', '$_samples/code39-2/2.png'),
  ('Code 32', '$_samples/code39-1/code32-1.png'),
  ('PZN', '$_samples/code39-1/pzn-1.png'),
  ('Code 93', (BarcodeFormat.code93, 'ZXING-93')),
  ('Codabar', (BarcodeFormat.codabar, 'A40156B')),
  ('ITF', (BarcodeFormat.itf, '30712345000010')),
  ('Telepen', '$_samples/telepen-1/telepen-alpha-2.png'),
  ('DX Film Edge', '$_samples/dxfilmedge-1/2.png'),
];

/// Tiles two cells wide: long codes stay large enough to read.
const Set<String> _wide = <String>{
  'rMQR Code',
  'PDF417',
  'MicroPDF417',
  'DataBar Expanded',
  'Telepen',
  'DX Film Edge',
};

/// Where each tile goes: left to right, two-cell tiles on one row.
List<Rect> _layout(int columns, Size cell) {
  final List<Rect> rects = <Rect>[];
  int column = 0;
  int row = 0;
  for (final (String label, Object _) in _tiles) {
    final int span = _wide.contains(label) ? 2 : 1;
    if (column + span > columns) {
      column = 0;
      row++;
    }
    rects.add(
      Rect.fromLTWH(
        column * cell.width,
        row * cell.height,
        span * cell.width,
        cell.height,
      ),
    );
    column += span;
  }
  return rects;
}

Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    return;
  }
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium']) {
    final File file = File(
      '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
    );
    if (file.existsSync()) {
      roboto.addFont(
        Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await roboto.load();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await warmUpBarcodeEngine();
  });

  testWidgets('format catalog', (WidgetTester tester) async {
    const int columns = 6;
    const Size tile = Size(300, 250);
    final List<Rect> cells = _layout(columns, tile);
    final Size size = Size(columns * tile.width + 40, cells.last.bottom + 40);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Map<String, ui.Image> images = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final (String _, Object code) in _tiles) {
        if (code is String) {
          images[code] = await decodeImageFromList(
            File(code).readAsBytesSync(),
          );
        }
      }
    });

    Widget code(Object code) => switch (code) {
      final String path => SizedBox.expand(
        child: RawImage(
          image: images[path],
          fit: BoxFit.contain,
          // Small samples grow with sharp module edges; large ones shrink
          // smoothly.
          filterQuality: images[path]!.width < 250
              ? FilterQuality.none
              : FilterQuality.medium,
        ),
      ),
      final _Drawn drawn => BarcodeView(
        drawn.$2,
        format: drawn.$1,
        showText: drawn.$1.isLinear,
      ),
      _ => const SizedBox(),
    };

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        // BarcodeView takes the font of its digits from here.
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: RepaintBoundary(
            key: _boundary,
            child: ColoredBox(
              color: const Color(0xFFFFFFFF),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Stack(
                  children: <Widget>[
                    for (int i = 0; i < _tiles.length; i++)
                      Positioned.fromRect(
                        rect: cells[i],
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _tiles[i].$1,
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0E1218),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Center(child: code(_tiles[i].$2)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 100; i++) {
      final bool waiting = find
          .byType(BarcodeView)
          .evaluate()
          .any(
            (Element e) => find
                .descendant(
                  of: find.byWidget(e.widget),
                  matching: find.byType(CustomPaint),
                )
                .evaluate()
                .isEmpty,
          );
      if (!waiting) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump();

    final RenderRepaintBoundary boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ByteData? rgba = await tester.runAsync<ByteData?>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2);
      final ByteData png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      File(_out!).writeAsBytesSync(png.buffer.asUint8List());
      final ByteData? pixels = await image.toByteData();
      image.dispose();
      return pixels;
    });

    // Every tile must read as what its label says.
    final List<String> report = <String>[];
    int missing = 0;
    for (int i = 0; i < _tiles.length; i++) {
      // The code under the label: the label's text would get in the way of
      // MaxiCode's bounding box search.
      final Rect cell = Rect.fromLTRB(
        (20 + cells[i].left) * 2,
        (20 + cells[i].top + 48) * 2,
        (20 + cells[i].right) * 2,
        (20 + cells[i].bottom) * 2,
      );
      final Barcode? found = await tester.runAsync<Barcode?>(
        () =>
            const BarcodeReader(
              options: ReaderOptions(eanAddOn: EanAddOn.read),
            ).readPixels(
              PixelBuffer(
                rgba!.buffer.asUint8List(),
                width: (size.width * 2).round(),
                height: (size.height * 2).round(),
                layout: PixelLayout.rgba,
                crop: cell,
              ),
            ),
      );
      if (found == null) {
        missing++;
      }
      report.add(
        '${_tiles[i].$1.padRight(26)} '
        '${found == null ? 'NOT READ' : '${found.format.displayName}: ${found.text}'}',
      );
    }
    // ignore: avoid_print
    print(report.join('\n'));
    expect(missing, 0);
    for (final ui.Image image in images.values) {
      image.dispose();
    }
  }, skip: _out == null);
}
