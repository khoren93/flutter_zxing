// BarcodeLabelSheet on the real engine: items encoded page by page into SVG
// and PDF, every code of a page painted from the files and read back with
// BarcodeReader, an item that cannot be encoded, and the preview widget.
@Tags(<String>['native'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

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

/// A [size] x [size] PNG: a dark rounded square on transparency, like an
/// app icon.
Future<Uint8List> _logoPng([int size = 64]) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  Canvas(recorder).drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Radius.circular(size / 5),
    ),
    Paint()..color = const Color(0xFF0B3D91),
  );
  final ui.Image image = await recorder.endRecording().toImage(size, size);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

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

  group('column strips', () {
    // 3 x 4: 22 items take two pages; a column runs through both.
    final BarcodeLabelSheet strips = qr.copyWith(
      rows: 4,
      order: LabelOrder.columnStrips,
    );
    final List<String> items = _items(22);

    /// The item each caption of a page names, by the slot it is on.
    Map<int, String> slots(String page, RegExp caption) => <int, String>{
      for (final Match m in caption.allMatches(page))
        <int>[
          for (int slot = 0; slot < strips.labelsPerPage; slot++)
            if (strips
                .labelRect(slot)
                .contains(Offset(double.parse(m[1]!), double.parse(m[2]!))))
              slot,
        ].single: m[3]!,
    };

    /// The items the sheet puts on each slot of [page].
    Map<int, String> expected(int page) => <int, String>{
      for (int slot = 0; slot < strips.labelsPerPage; slot++)
        if (strips.itemAt(page, slot, items.length) case final int i)
          slot: items[i],
    };

    test('the sheet: page 2 starts each column where page 1 stops', () {
      expect(expected(0)[0], 'SKU-0001');
      expect(expected(0)[4], 'SKU-0009');
      expect(expected(1)[0], 'SKU-0005');
      expect(expected(1)[8], 'SKU-0021');
      expect(expected(1), hasLength(10));
    });

    test('SVG', () async {
      final RegExp caption = RegExp(
        r'<text x="([\d.]+)" y="([\d.]+)"[^>]*>([^<]+)</text>',
      );
      // An Iterable that is not a List is read into one.
      final List<String> pages = await strips
          .svgPages(items.map((String s) => s))
          .toList();
      expect(pages, hasLength(2));
      expect(slots(pages[0], caption), expected(0));
      expect(slots(pages[1], caption), expected(1));
    });

    test('PDF', () async {
      final List<(int, int)> progress = <(int, int)>[];
      final PdfPages pdf = readPdf(
        await strips.pdf(
          items,
          onProgress: (int done, int total) => progress.add((done, total)),
        ),
      );
      final RegExp caption = RegExp(r'([\d.]+) ([\d.]+) Tm \(([^)]+)\) Tj');
      expect(pdf.contents, hasLength(2));
      expect(slots(pdf.contents[0], caption), expected(0));
      expect(slots(pdf.contents[1], caption), expected(1));
      expect(progress, <(int, int)>[(12, 22), (22, 22)]);
    });
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

  group('styled codes', () {
    late final BarcodeStyle withLogo;
    setUpAll(() async {
      final Uint8List png = await _logoPng();
      withLogo = BarcodeStyle.soft.copyWith(
        logo: () => BarcodeLogo(MemoryImage(png)),
      );
    });

    final List<(String, BarcodeStyle Function())> styles =
        <(String, BarcodeStyle Function())>[
          ('soft', () => BarcodeStyle.soft),
          ('dots', () => BarcodeStyle.dots),
          ('lagoon (linear gradient)', () => BarcodeStyle.lagoon),
          (
            'radial gradient of three colors',
            () => const BarcodeStyle(
              moduleShape: ModuleShape.circle,
              finderShape: FinderShape.rounded,
              gradient: RadialGradient(
                colors: <Color>[
                  Color(0xFF000000),
                  Color(0xFF1D4ED8),
                  Color(0xFF00735D),
                ],
                stops: <double>[0, 0.6, 1],
              ),
            ),
          ),
          ('a logo', () => withLogo),
        ];
    for (final (String name, BarcodeStyle Function() style) in styles) {
      final List<String> items = _items(qr.labelsPerPage + 3);
      final Set<String> firstPage = items.take(qr.labelsPerPage).toSet();

      test('$name: every code of the PDF page reads back', () async {
        final BarcodeLabelSheet sheet = qr.copyWith(style: style());
        final String content = readPdf(await sheet.pdf(items)).contents.first;
        final PixelBuffer pixels = await paintPdfPage(content, qr.paper, 8);
        expect(await _read(pixels), firstPage);
      });

      test('$name: every code of the SVG page reads back', () async {
        final BarcodeLabelSheet sheet = qr.copyWith(style: style());
        final String svg = await sheet.svgPages(items).first;
        final PixelBuffer pixels = await paintSvgPage(svg, qr.paper, 8);
        expect(await _read(pixels), firstPage);
      });
    }

    test('a logo: encoded with the error correction it needs, in the PDF '
        'once', () async {
      final BarcodeLabelSheet sheet = qr.copyWith(style: withLogo);
      final List<String> items = _items(30);
      final PdfPages pdf = readPdf(await sheet.pdf(items));
      final List<String> images = pdf.objects.values
          .where((String o) => o.contains('/Subtype/Image/'))
          .toList();
      // The image and its soft mask (the logo's corners are transparent).
      expect(images, hasLength(2));
      expect(images.where((String o) => o.contains('/SMask')), hasLength(1));
      expect(pdf.contents, hasLength(2));
      expect(RegExp('/Logo Do').allMatches(pdf.contents[0]), hasLength(24));
      expect(RegExp('/Logo Do').allMatches(pdf.contents[1]), hasLength(6));
      expect(pdf.resources[1], contains('/XObject<</Logo '));
      // The PDF's code is the one BarcodeView shows: the logo's level.
      final BarcodeSymbol expected = await withLogo.encode(items.first);
      expect(expected.errorCorrection, ErrorCorrection.high);
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(0),
        SymbolLayout(expected),
        items.first,
      );
      final double m = at.code.width / SymbolLayout(expected).width;
      expect(pdf.contents[0], contains('q ${m.toStringAsFixed(6)} 0 0 '));

      final List<String> svg = await sheet.svgPages(items).toList();
      for (final String page in svg) {
        expect(RegExp('<symbol id="zx-logo"').allMatches(page), hasLength(1));
      }
      expect(RegExp('<use ').allMatches(svg[0]), hasLength(24));
    });

    test('a logo that cannot load fails before any page', () async {
      final BarcodeLabelSheet broken = qr.copyWith(
        style: BarcodeStyle.soft.copyWith(
          logo: () => BarcodeLogo(MemoryImage(Uint8List.fromList(<int>[1, 2]))),
        ),
      );
      final Matcher error = throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.message,
          'message',
          contains('logo'),
        ),
      );
      await expectLater(broken.pdf(_items(3)), error);
      await expectLater(broken.svgPages(_items(3)).toList(), error);
    });

    testWidgets('the preview draws styled codes where the files do', (
      WidgetTester tester,
    ) async {
      final BarcodeStyle style = BarcodeStyle.dots.copyWith(
        quietZone: false,
        caption: () => const BarcodeCaption('NOT ON A LABEL'),
      );
      final BarcodeLabelSheet sheet = qr.copyWith(style: style);
      final List<String> items = _items(5);
      await tester.binding.setSurfaceSize(const Size(420, 700));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              child: BarcodeLabelSheetView(sheet: sheet, items: items),
            ),
          ),
        ),
      );
      for (int i = 0; i < 100; i++) {
        if (find.byType(BarcodeView).evaluate().length == 5) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final List<BarcodeView> views = tester
          .widgetList<BarcodeView>(find.byType(BarcodeView))
          .toList();
      expect(views, hasLength(5));
      for (final BarcodeView view in views) {
        expect(view.style, style.copyWith(caption: () => null));
      }
      final BarcodeSymbol symbol = (await tester.runAsync(
        () => sheet.writer.encode(items[1]),
      ))!;
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(1),
        SymbolLayout(withoutQuietZone(symbol)),
        items[1],
      );
      final Rect shown = tester.getRect(find.byType(BarcodeView).at(1));
      expect(shown.left, closeTo(at.code.left * 2, 0.01));
      expect(shown.top, closeTo(at.code.top * 2, 0.01));
      expect(shown.width, closeTo(at.code.width * 2, 0.01));
      expect(find.text('NOT ON A LABEL'), findsNothing);
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets("the preview fills a page in the sheet's order", (
      WidgetTester tester,
    ) async {
      final BarcodeLabelSheet sheet = qr.copyWith(order: LabelOrder.columns);
      await tester.binding.setSurfaceSize(const Size(420, 700));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              child: BarcodeLabelSheetView(sheet: sheet, items: _items(2)),
            ),
          ),
        ),
      );
      for (int i = 0; i < 100; i++) {
        if (find.byType(BarcodeView).evaluate().length == 2) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final Rect first = tester.getRect(find.text('SKU-0001'));
      final Rect second = tester.getRect(find.text('SKU-0002'));
      expect(second.center.dx, closeTo(first.center.dx, 0.01));
      expect(second.top, greaterThan(first.bottom));
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('the preview shows the items of a page in column strips', (
      WidgetTester tester,
    ) async {
      final BarcodeLabelSheet sheet = qr.copyWith(
        rows: 4,
        order: LabelOrder.columnStrips,
      );
      await tester.binding.setSurfaceSize(const Size(420, 700));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              child: BarcodeLabelSheetView(
                sheet: sheet,
                items: _items(22),
                page: 1,
              ),
            ),
          ),
        ),
      );
      for (int i = 0; i < 100; i++) {
        if (find.byType(BarcodeView).evaluate().length == 10) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byType(BarcodeView), findsNWidgets(10));
      // Page 2: column 1 holds items 5-8, column 3 items 21 and 22.
      expect(find.text('SKU-0001'), findsNothing);
      expect(find.text('SKU-0009'), findsNothing);
      final double mm = 420 / sheet.paper.width;
      for (final (String item, int slot) in <(String, int)>[
        ('SKU-0005', 0),
        ('SKU-0008', 3),
        ('SKU-0013', 4),
        ('SKU-0021', 8),
        ('SKU-0022', 9),
      ]) {
        final Rect label = sheet.labelRect(slot);
        final Offset at = tester.getCenter(find.text(item));
        expect(
          Rect.fromLTRB(
            label.left * mm,
            label.top * mm,
            label.right * mm,
            label.bottom * mm,
          ).contains(at),
          isTrue,
          reason: item,
        );
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('the preview encodes under a logo as the files do', (
      WidgetTester tester,
    ) async {
      final BarcodeLabelSheet sheet = qr.copyWith(style: withLogo);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 420,
            child: BarcodeLabelSheetView(sheet: sheet, items: _items(2)),
          ),
        ),
      );
      for (int i = 0; i < 100; i++) {
        if (find.byType(BarcodeView).evaluate().length == 2) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final BarcodeView view = tester.widget<BarcodeView>(
        find.byType(BarcodeView).first,
      );
      expect(view.symbol!.errorCorrection, ErrorCorrection.high);
      expect(view.style.logo, withLogo.logo);
    });
  });
}
