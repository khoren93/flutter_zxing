// Create → Many codes: the mode switch, the sources, the check and the
// skip, the sheet and the wide layout.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
import 'dart:io';

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing_example/demo/create_page.dart';
import 'package:flutter_zxing_example/demo/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uri _batchLink = Uri.parse('https://demo.example/?tab=create&mode=batch');

/// Tall enough that the one-column list builds every section.
const Size _phone = Size(430, 5200);

Future<void> _show(
  WidgetTester tester, {
  Size size = _phone,
  bool wide = false,
  Uri? link,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: demoTheme(Brightness.light),
      home: Scaffold(
        body: CreatePage(
          wide: wide,
          link: link ?? Uri.parse('https://demo.example/?tab=create'),
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// Lets the debounce run and the engine answer (encoding is real async),
/// until no check is running.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (i >= 2 && find.text('Checking…').evaluate().isEmpty) {
      return;
    }
  }
}

/// Roboto from the Flutter SDK, as on a device: the test font draws every
/// glyph as a square, wider than any real text, and would overflow the
/// pills and menus.
Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    return;
  }
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
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

Future<void> _many(WidgetTester tester) async {
  await tester.tap(find.text('Many codes'));
  await _settle(tester);
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await _settle(tester);
}

Future<void> _pickFormat(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Format'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await _settle(tester);
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    // Starts the engine here, outside any test's fake clock: its replies
    // then reach every test, not only the first.
    await const BarcodeWriter(BarcodeFormat.qrCode).encode('warm up');
  });
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('switches modes and keeps the style', (
    WidgetTester tester,
  ) async {
    await _show(tester);
    // The preset strip comes before the editor's own "Dots" (modules).
    await tester.tap(find.text('Dots').first);
    await _settle(tester);
    await _many(tester);
    expect(find.text('The first of 1,000 codes'), findsOneWidget);
    final BarcodeView first = tester.widget<BarcodeView>(
      find.byWidgetPredicate(
        (Widget w) => w is BarcodeView && w.data == 'AA000001',
      ),
    );
    expect(first.style.moduleShape, BarcodeStyle.dots.moduleShape);
    expect(first.style.color, BarcodeStyle.dots.color);
    await tester.tap(find.text('One code'));
    await _settle(tester);
    expect(find.text('The first of 1,000 codes'), findsNothing);
    expect(find.text('In your app'.toUpperCase()), findsOneWidget);
  });

  testWidgets('Numbered shows the range and the count', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    expect(find.text('AA000001 · AA000002 … AA001000'), findsOneWidget);
    expect(find.text('1,000 codes'), findsOneWidget);
    expect(find.text('All 1,000 fit · QR Code'), findsOneWidget);
    await _enter(tester, 'How many', '25');
    await _enter(tester, 'Start', '10');
    await _enter(tester, 'Step', '5');
    expect(find.text('AA000010 · AA000015 … AA000130'), findsOneWidget);
    expect(find.text('25 codes'), findsOneWidget);
    await _enter(tester, 'Pattern', 'AA');
    // Under the field and in place of the first code.
    expect(find.textContaining('has no placeholder'), findsWidgets);
    expect(find.text('No codes'), findsWidgets);
  });

  testWidgets('Check digit GS1 appends a valid digit', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    await _enter(tester, 'Pattern', '400638{n:6}');
    await _enter(tester, 'Start', '133393');
    await tester.tap(find.text('GS1'));
    await _settle(tester);
    // The first code's line, and its caption on the page.
    expect(find.text('4006381333931'), findsWidgets);
    expect(CheckDigit.gs1.isValid('4006381333931'), isTrue);
    expect(
      find.text('4006381333931 · 4006381333948 … 4006381343923'),
      findsOneWidget,
    );
  });

  testWidgets('List and CSV give their items', (WidgetTester tester) async {
    await _show(tester, link: _batchLink);
    await tester.tap(find.text('List'));
    await _settle(tester);
    await _enter(tester, 'Codes', ' A1 \nB2\n\nC3\n');
    expect(find.text('3 codes'), findsOneWidget);
    expect(find.text('One code a line · 3 codes'), findsOneWidget);
    expect(find.text('A1'), findsWidgets);

    await tester.tap(find.text('CSV'));
    await _settle(tester);
    await _enter(
      tester,
      'CSV',
      'Name;EAN\n"Tea; green";4006381333931\nCoffee;4006381333948\n',
    );
    expect(find.text('3 rows · separator semicolon'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Name'), findsOneWidget);
    // The first column at first: the names.
    expect(find.text('2 codes'), findsOneWidget);
    expect(find.text('Tea; green'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'EAN'));
    await _settle(tester);
    expect(find.text('4006381333931'), findsWidgets);
    // Without a header, the names row is an item too.
    await tester.tap(find.text('First row is a header'));
    await _settle(tester);
    expect(find.text('3 codes'), findsOneWidget);
    expect(find.text('EAN'), findsWidgets);
  });

  testWidgets('a code that does not fit is shown, and skipping removes it', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    await tester.tap(find.text('List'));
    await _settle(tester);
    await _enter(tester, 'Codes', '4006381333931\nAB-1\n4006381333948');
    await _pickFormat(tester, 'EAN-13');
    expect(find.text('Row 2, “AB-1”'), findsOneWidget);
    expect(find.textContaining('EAN-13 takes digits only'), findsOneWidget);
    expect(find.text('Row 2 does not fit'), findsOneWidget);
    await tester.tap(find.text('Skip rows that do not fit'));
    await _settle(tester);
    expect(find.text('Row 2, “AB-1”'), findsNothing);
    expect(find.text('2 codes'), findsOneWidget);
    expect(find.textContaining('1 skipped'), findsOneWidget);
    expect(find.text('All 2 fit · EAN-13'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(find.text('Row 2, “AB-1”'), findsOneWidget);
  });

  testWidgets('the sheet settings change the page count', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    // 1,000 codes, 3 x 8 on a page.
    expect(find.text('Page 1 of 42 · 24 labels a page'), findsOneWidget);
    expect(find.text('Share PDF · 42 pages'), findsOneWidget);
    await tester.tap(find.byTooltip('Codes across: more'));
    await _settle(tester);
    expect(find.text('Page 1 of 32 · 32 labels a page'), findsOneWidget);
    await tester.tap(find.byTooltip('Rows on a page: fewer'));
    await _settle(tester);
    expect(find.text('Page 1 of 36 · 28 labels a page'), findsOneWidget);
    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();
    expect(find.text('Page 2 of 36 · 28 labels a page'), findsOneWidget);
    expect(find.byType(BarcodeLabelSheetView), findsOneWidget);
  });

  testWidgets('the sheet has no Text or Card section; the first code drops '
      'the style\'s text', (WidgetTester tester) async {
    await _show(tester);
    expect(find.text('CARD'), findsOneWidget);
    await _enter(tester, 'Above', 'Hello');
    await _many(tester);
    expect(find.text('CARD'), findsNothing);
    expect(find.widgetWithText(TextField, 'Above'), findsNothing);
    final BarcodeView first = tester.widget<BarcodeView>(
      find.byWidgetPredicate(
        (Widget w) => w is BarcodeView && w.data == 'AA000001',
      ),
    );
    expect(first.style.title, isNull);
    expect(first.style.card, isNull);
    // One code keeps it.
    await tester.tap(find.text('One code'));
    await _settle(tester);
    expect(find.widgetWithText(TextField, 'Hello'), findsOneWidget);
  });

  testWidgets('the caption size shows while the caption is on', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    BarcodeLabelSheet sheet() => tester
        .widget<BarcodeLabelSheetView>(find.byType(BarcodeLabelSheetView))
        .sheet;
    expect(find.text('TEXT SIZE'), findsOneWidget);
    expect(find.text('3 mm'), findsOneWidget);
    final Finder slider = find.byWidgetPredicate(
      (Widget w) => w is Slider && w.min == 2 && w.max == 6,
    );
    tester.widget<Slider>(slider).onChanged!(4.5);
    await _settle(tester);
    expect(find.text('4.5 mm'), findsOneWidget);
    expect(sheet().captionSize, 4.5);
    await tester.tap(find.text('Text under each code'));
    await _settle(tester);
    expect(find.text('TEXT SIZE'), findsNothing);
    expect(slider, findsNothing);
    expect(sheet().caption, isFalse);
  });

  testWidgets('the order: rows, columns or column strips', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    expect(find.text('Left to right, then the next row'), findsOneWidget);
    await tester.tap(find.text('Column strips'));
    await _settle(tester);
    expect(find.textContaining('cut a stack of sheets'), findsOneWidget);
    final BarcodeLabelSheetView view = tester.widget<BarcodeLabelSheetView>(
      find.byType(BarcodeLabelSheetView),
    );
    expect(view.sheet.order, LabelOrder.columnStrips);
    // 1,000 codes on 42 pages: page 1's second label is the second code,
    // the top of its second column the 337th.
    expect(view.sheet.itemAt(0, 1, 1000), 1);
    expect(view.sheet.itemAt(0, 8, 1000), 336);
  });

  testWidgets('the page zooms, and opens full screen with paging', (
    WidgetTester tester,
  ) async {
    await _show(tester, link: _batchLink);
    final Finder zoom = find.ancestor(
      of: find.byType(BarcodeLabelSheetView),
      matching: find.byType(InteractiveViewer),
    );
    expect(zoom, findsOneWidget);
    expect(tester.widget<InteractiveViewer>(zoom).maxScale, 6);
    // A double tap zooms in to 3x; the codes are drawn for that scale.
    final TransformationController controller = tester
        .widget<InteractiveViewer>(zoom)
        .transformationController!;
    final Offset center = tester.getCenter(zoom);
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(3, 1e-6));
    expect(
      MediaQuery.devicePixelRatioOf(
        tester.element(find.byType(BarcodeLabelSheetView)),
      ),
      closeTo(3, 1e-6),
    );
    // Again: back to 1x.
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(controller.value.getMaxScaleOnAxis(), closeTo(1, 1e-6));

    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 42'), findsOneWidget);
    final Finder full = find.ancestor(
      of: find.byType(BarcodeLabelSheetView),
      matching: find.byType(InteractiveViewer),
    );
    expect(full, findsOneWidget);
    await tester.tap(find.byTooltip('Next page').last);
    await tester.pump();
    expect(find.text('Page 2 of 42'), findsOneWidget);
    expect(
      tester.widget<BarcodeLabelSheetView>(find.byType(BarcodeLabelSheetView)),
      isA<BarcodeLabelSheetView>().having(
        (BarcodeLabelSheetView v) => v.page,
        'page',
        1,
      ),
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    // The preview follows.
    expect(find.text('Page 2 of 42 · 24 labels a page'), findsOneWidget);
  });

  test('a PNG says its dpi', () async {
    final Uint8List png = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).toPng('AA000001', moduleSize: 4);
    final Uint8List marked = pngWithDpi(pngWithDpi(png, 600), 300);
    final ByteData data = ByteData.sublistView(marked);
    final List<String> chunks = <String>[];
    int at = 8;
    while (at < marked.length) {
      final int length = data.getUint32(at);
      final String type = String.fromCharCodes(marked, at + 4, at + 8);
      chunks.add(type);
      if (type == 'pHYs') {
        expect(data.getUint32(at + 8), 11811); // 300 dpi in pixels a metre
        expect(data.getUint8(at + 16), 1);
        expect(
          data.getUint32(at + 17),
          getCrc32(Uint8List.sublistView(marked, at + 4, at + 17)),
        );
      }
      at += 12 + length;
    }
    expect(chunks.take(2), <String>['IHDR', 'pHYs']);
    expect(chunks.where((String c) => c == 'pHYs'), hasLength(1));
    expect(chunks.last, 'IEND');
  });

  test('a link opens Many codes only when it asks', () {
    expect(opensManyCodes(_batchLink), isTrue);
    expect(
      opensManyCodes(Uri.parse('https://demo.example/?tab=create')),
      isFalse,
    );
  });

  testWidgets('the deep link opens Many codes', (WidgetTester tester) async {
    await _show(tester, link: _batchLink);
    expect(find.text('The first of 1,000 codes'), findsOneWidget);
    expect(find.text('Sheet'.toUpperCase()), findsOneWidget);
  });

  testWidgets('wide: the code above the page, both on the right', (
    WidgetTester tester,
  ) async {
    const Size size = Size(1400, 900);
    await _show(tester, size: size, wide: true, link: _batchLink);
    final Rect code = tester.getRect(find.text('The first of 1,000 codes'));
    final Rect page = tester.getRect(find.byType(BarcodeLabelSheetView));
    final Rect codes = tester.getRect(find.text('Codes'.toUpperCase()));
    expect(code.left, greaterThan(size.width / 2));
    expect(page.left, greaterThan(size.width / 2));
    expect(codes.left, lessThan(size.width / 2));
    expect(code.bottom, lessThan(page.top));
    expect(find.text('Share PDF · 42 pages'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(BarcodeLabelSheetView),
        matching: find.byType(InteractiveViewer),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Full screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
