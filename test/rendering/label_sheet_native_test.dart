// BarcodeLabelSheet on the real engine: items encoded page by page into SVG
// and PDF, every code of a page painted from the files and read back with
// BarcodeReader, an item that cannot be encoded, and the preview widget.
@Tags(<String>['native'])
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/rendering/label_sheet_output.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

import 'label_sheet_files.dart';

List<String> _items(int n) => <String>[
  for (int i = 1; i <= n; i++) 'SKU-${i.toString().padLeft(4, '0')}',
];

/// The texts of every code on [pixels].
Future<Set<String>> _read(PixelBuffer pixels) async => <String>{
  for (final Barcode b in await const BarcodeReader().readAllPixels(pixels))
    b.text,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(warmUpBarcodeEngine);

  const BarcodeLabelSheet qr = BarcodeLabelSheet(columns: 3, rows: 8);
  final BarcodeLabelSheet code128 = qr.copyWith(
    columns: 2,
    rows: 10,
    writer: const BarcodeWriter(BarcodeFormat.code128),
  );

  test('SVG: a document a page, the last one partly filled', () async {
    final List<String> pages = await qr.svgPages(_items(30)).toList();
    expect(pages, hasLength(2));
    expect(RegExp('<svg x=').allMatches(pages[0]), hasLength(24));
    expect(RegExp('<svg x=').allMatches(pages[1]), hasLength(6));
    expect(pages[1], contains('>SKU-0030</text>'));
    expect(await qr.svgPages(const <String>[]).toList(), isEmpty);
  });

  test('custom captions', () async {
    final String page = await qr.svgPages(<String>[
      'A',
    ], captionText: (String item) => 'Box $item').first;
    expect(page, contains('>Box A</text>'));
  });

  test('PDF: pages, progress', () async {
    final List<(int, int)> progress = <(int, int)>[];
    final Uint8List bytes = await qr.pdf(
      _items(30),
      onProgress: (int done, int total) => progress.add((done, total)),
    );
    final PdfPages pages = readPdf(bytes);
    expect(pages.contents, hasLength(2));
    expect(progress, <(int, int)>[(24, 30), (30, 30)]);
    expect(() => qr.pdf(const <String>[]), throwsArgumentError);
  });

  test('an item that cannot be encoded is named in the error', () async {
    const BarcodeLabelSheet ean = BarcodeLabelSheet(
      columns: 3,
      rows: 8,
      writer: BarcodeWriter(BarcodeFormat.ean13),
    );
    final List<String> items = <String>[
      '4006381333931',
      '9780201379624',
      'not digits',
    ];
    for (final Future<Object?> Function() make in <Future<Object?> Function()>[
      () => ean.pdf(items),
      () => ean.svgPages(items).toList(),
    ]) {
      await expectLater(
        make(),
        throwsA(
          isA<BarcodeWriteException>().having(
            (BarcodeWriteException e) => e.message,
            'message',
            allOf(contains('Item 2'), contains('"not digits"')),
          ),
        ),
      );
    }
  });

  for (final (String name, BarcodeLabelSheet sheet)
      in <(String, BarcodeLabelSheet)>[('QR', qr), ('Code 128', code128)]) {
    final List<String> items = _items(sheet.labelsPerPage + 3);
    final Set<String> firstPage = items.take(sheet.labelsPerPage).toSet();

    test('$name: every code of the PDF page reads back', () async {
      final String content = readPdf(await sheet.pdf(items)).contents.first;
      final PixelBuffer pixels = await paintPdfPage(content, sheet.paper, 8);
      expect(await _read(pixels), firstPage);
    });

    test('$name: every code of the SVG page reads back', () async {
      final String svg = await sheet.svgPages(items).first;
      final PixelBuffer pixels = await paintSvgPage(svg, sheet.paper, 8);
      expect(await _read(pixels), firstPage);
    });
  }

  testWidgets('the preview puts the codes where the files do', (
    WidgetTester tester,
  ) async {
    final List<String> items = _items(30);
    await tester.binding.setSurfaceSize(const Size(420, 700));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 420,
            child: BarcodeLabelSheetView(sheet: qr, items: items, page: 1),
          ),
        ),
      ),
    );
    for (int i = 0; i < 100; i++) {
      if (find.byType(BarcodeView).evaluate().length == 6) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(BarcodeView), findsNWidgets(6));
    expect(find.text('SKU-0025'), findsOneWidget);
    expect(tester.getSize(find.byType(BarcodeLabelSheetView)).height, 594);
    // 2 logical pixels a millimetre.
    final BarcodeSymbol symbol = (await tester.runAsync(
      () => qr.writer.encode('SKU-0025'),
    ))!;
    final LabelPlacement at = placeLabel(
      qr,
      qr.labelRect(0),
      SymbolLayout(symbol),
      'SKU-0025',
    );
    final Rect shown = tester.getRect(find.byType(BarcodeView).first);
    expect(shown.left, closeTo(at.code.left * 2, 0.01));
    expect(shown.top, closeTo(at.code.top * 2, 0.01));
    expect(shown.width, closeTo(at.code.width * 2, 0.01));
    // The caption is centred under its code, as in the files.
    final Rect text = tester.getRect(find.text('SKU-0025'));
    expect(text.center.dx, closeTo(at.code.center.dx * 2, 0.5));
    await tester.binding.setSurfaceSize(null);
  });
}
