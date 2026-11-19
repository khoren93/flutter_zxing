// BarcodeView on the real engine: sizes, states, semantics, and every style
// rendered to pixels and read back with BarcodeReader.
@Tags(<String>['native'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

final GlobalKey _boundary = GlobalKey();

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: RepaintBoundary(key: _boundary, child: child),
  ),
);

/// Pumps until the engine has encoded every BarcodeView on screen.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 100; i++) {
    final bool waiting = tester
        .widgetList<BarcodeView>(find.byType(BarcodeView))
        .any(
          (BarcodeView v) => find
              .descendant(
                of: find.byWidget(v),
                matching: find.byType(CustomPaint),
              )
              .evaluate()
              .isEmpty,
        );
    if (!waiting) {
      await tester.pump();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

/// What the screen shows, read back with the reader. Capture and read run
/// in separate runAsync calls: a reader call that waits behind the capture
/// in one call never completes under the test's fake clock.
Future<Barcode?> _readScreen(WidgetTester tester) async {
  final RenderRepaintBoundary boundary =
      _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final PixelBuffer? pixels = await tester.runAsync<PixelBuffer>(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData rgba = (await image.toByteData())!;
    image.dispose();
    return PixelBuffer(
      rgba.buffer.asUint8List(),
      width: image.width,
      height: image.height,
      layout: PixelLayout.rgba,
    );
  });
  return tester.runAsync<Barcode?>(
    () => const BarcodeReader().readPixels(pixels!),
  );
}

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

/// The CustomPaint of the BarcodeView.
Finder get _paint => find.descendant(
  of: find.byType(BarcodeView),
  matching: find.byType(CustomPaint),
);

void main() {
  const String url = 'https://pub.dev/packages/flutter_zxing';

  // Start the engine outside the tests' fake clock: an engine started inside
  // one test delivers its replies into that test's zone, which is gone by
  // the next test.
  setUpAll(warmUpBarcodeEngine);

  testWidgets('a QR code fills the given width, square', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const BarcodeView(url, width: 240)));
    await _settle(tester);
    expect(tester.getSize(_paint), const Size(240, 240));
    expect((await _readScreen(tester))?.text, url);
  });

  testWidgets('a linear barcode keeps its aspect ratio and shows its text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BarcodeView(
          '4006381333931',
          format: BarcodeFormat.ean13,
          showText: true,
          width: 300,
        ),
      ),
    );
    await _settle(tester);
    final Size size = tester.getSize(_paint);
    expect(size.width, 300);
    expect(size.height, inExclusiveRange(60, 300));
    final Barcode? read = await _readScreen(tester);
    expect(read?.format, BarcodeFormat.ean13);
    expect(read?.text, '4006381333931');
  });

  testWidgets('modules lie on the device pixel grid', (
    WidgetTester tester,
  ) async {
    // A fractional pixel ratio and a place between two device pixels: the
    // bars must still be pure black and white, not blurred at their edges.
    const double ratio = 2.25;
    tester.view
      ..devicePixelRatio = ratio
      ..physicalSize = const Size(400, 200) * ratio;
    addTearDown(tester.view.reset);
    final GlobalKey page = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(400, 200),
          devicePixelRatio: ratio,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: page,
            child: const ColoredBox(
              color: Color(0xFFFFFFFF),
              child: Padding(
                padding: EdgeInsets.fromLTRB(10.3, 20.7, 0, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: BarcodeView(
                    '4006381333931',
                    format: BarcodeFormat.ean13,
                    width: 233.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    final RenderRepaintBoundary boundary =
        page.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final Uint8List rgba = (await tester.runAsync<Uint8List>(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: ratio);
      final ByteData bytes = (await image.toByteData())!;
      image.dispose();
      return bytes.buffer.asUint8List();
    }))!;
    int grey = 0;
    for (int i = 0; i < rgba.length; i += 4) {
      if (rgba[i] > 30 && rgba[i] < 225) {
        grey++;
      }
    }
    expect(grey, 0);
  });

  testWidgets('without a size it fills the constraints', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180, maxHeight: 400),
          child: const BarcodeView(url),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.getSize(_paint), const Size(180, 180));
  });

  testWidgets('holds a square space while the first symbol is encoded', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const BarcodeView('first show', width: 120)));
    expect(_paint, findsNothing);
    expect(tester.getSize(find.byType(BarcodeView)), const Size(120, 120));
    await _settle(tester);
  });

  testWidgets('a symbol shown before paints in the first frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const BarcodeView('cached', width: 100)));
    await _settle(tester);
    await tester.pumpWidget(_host(const SizedBox()));
    await tester.pumpWidget(_host(const BarcodeView('cached', width: 100)));
    expect(_paint, findsOneWidget);
  });

  testWidgets('new data keeps the old symbol until the new one is ready', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(const BarcodeView('old data', width: 160)));
    await _settle(tester);
    await tester.pumpWidget(_host(const BarcodeView('new data', width: 160)));
    expect(_paint, findsOneWidget);
    expect((await _readScreen(tester))?.text, 'old data');
    await _settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect((await _readScreen(tester))?.text, 'new data');
  });

  testWidgets('invalid data shows the errorBuilder', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        BarcodeView(
          'not digits',
          format: BarcodeFormat.ean13,
          width: 200,
          errorBuilder: (BuildContext context, BarcodeWriteException error) =>
              const Text('cannot encode'),
        ),
      ),
    );
    for (
      int i = 0;
      i < 50 && find.text('cannot encode').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.text('cannot encode'), findsOneWidget);
  });

  testWidgets('binary data', (WidgetTester tester) async {
    final Uint8List data = Uint8List.fromList(<int>[0, 1, 2, 0xFE, 0xFF]);
    await tester.pumpWidget(
      _host(
        BarcodeView.bytes(data, format: BarcodeFormat.dataMatrix, width: 160),
      ),
    );
    await _settle(tester);
    expect((await _readScreen(tester))?.bytes, data);
  });

  testWidgets('semantics: a labelled image', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const BarcodeView('hello', width: 120)));
    await _settle(tester);
    expect(
      tester.getSemantics(find.byType(BarcodeView)),
      matchesSemantics(label: 'QR Code barcode: hello', isImage: true),
    );
    await tester.pumpWidget(
      _host(const BarcodeView('hello', width: 120, semanticLabel: 'Ticket')),
    );
    await _settle(tester);
    expect(
      tester.getSemantics(find.byType(BarcodeView)),
      matchesSemantics(label: 'Ticket', isImage: true),
    );
    handle.dispose();
  });

  testWidgets('in a Column, the width decides the size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[BarcodeView(url)],
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.getSize(_paint), const Size(300, 300));
  });

  testWidgets('a directional gradient paints', (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        const BarcodeView(
          url,
          width: 240,
          style: BarcodeStyle(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: <Color>[Color(0xFF0B3D91), Color(0xFF00735D)],
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect((await _readScreen(tester))?.text, url);
  });

  testWidgets('bytes changed in place are encoded again', (
    WidgetTester tester,
  ) async {
    final Uint8List data = Uint8List.fromList(<int>[1, 2, 3]);
    await tester.pumpWidget(
      _host(
        BarcodeView.bytes(data, format: BarcodeFormat.dataMatrix, width: 160),
      ),
    );
    await _settle(tester);
    expect((await _readScreen(tester))?.bytes, <int>[1, 2, 3]);
    data[0] = 9;
    await tester.pumpWidget(
      _host(
        BarcodeView.bytes(data, format: BarcodeFormat.dataMatrix, width: 160),
      ),
    );
    for (int i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    expect((await _readScreen(tester))?.bytes, <int>[9, 2, 3]);
  });

  group('styled QR codes still read', () {
    for (final ModuleShape modules in ModuleShape.values) {
      for (final FinderShape finders in FinderShape.values) {
        testWidgets('${modules.name} modules, ${finders.name} finders', (
          WidgetTester tester,
        ) async {
          await tester.pumpWidget(
            _host(
              BarcodeView(
                url,
                width: 240,
                style: BarcodeStyle(moduleShape: modules, finderShape: finders),
              ),
            ),
          );
          await _settle(tester);
          expect((await _readScreen(tester))?.text, url);
        });
      }
    }

    testWidgets('colors and a gradient', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const BarcodeView(
            url,
            width: 240,
            style: BarcodeStyle(
              backgroundColor: Color(0xFFF7F5F0),
              gradient: LinearGradient(
                colors: <Color>[Color(0xFF0B3D91), Color(0xFF00735D)],
              ),
              moduleShape: ModuleShape.rounded,
              finderShape: FinderShape.rounded,
            ),
          ),
        ),
      );
      await _settle(tester);
      expect((await _readScreen(tester))?.text, url);
    });

    testWidgets('a logo, with the error correction it needs', (
      WidgetTester tester,
    ) async {
      final Uint8List png = (await tester.runAsync(_logoPng))!;
      await tester.pumpWidget(
        _host(
          BarcodeView(
            url,
            width: 240,
            style: BarcodeStyle(
              moduleShape: ModuleShape.circle,
              finderShape: FinderShape.circle,
              logo: BarcodeLogo(MemoryImage(png), size: 0.25),
            ),
          ),
        ),
      );
      await _settle(tester);
      // Let the logo decode and paint.
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      final Barcode? read = await _readScreen(tester);
      expect(read?.text, url);
      expect(read?.ecLevel, 'H');
    });

    testWidgets('Data Matrix and Aztec with every module shape', (
      WidgetTester tester,
    ) async {
      // One data region and several.
      const String long =
          'flutter_zxing reads and writes barcodes on every platform. '
          'flutter_zxing reads and writes barcodes on every platform.';
      for (final (BarcodeFormat format, String data)
          in <(BarcodeFormat, String)>[
            (BarcodeFormat.dataMatrix, 'flutter_zxing'),
            (BarcodeFormat.dataMatrix, long),
            (BarcodeFormat.aztec, 'flutter_zxing'),
            (BarcodeFormat.aztec, long),
          ]) {
        for (final ModuleShape modules in ModuleShape.values) {
          await tester.pumpWidget(
            _host(
              BarcodeView(
                data,
                // A new state each time: no previous symbol to fall back on.
                key: ValueKey<String>('${format.name} $data ${modules.name}'),
                format: format,
                width: 300,
                style: BarcodeStyle(moduleShape: modules),
              ),
            ),
          );
          await _settle(tester);
          expect(
            (await _readScreen(tester))?.text,
            data,
            reason: '${format.name}, ${data.length} chars, ${modules.name}',
          );
        }
      }
    });
  });

  group('title, caption and card', () {
    const BarcodeStyle style = BarcodeStyle(
      moduleShape: ModuleShape.rounded,
      title: BarcodeCaption('Studio 5G', size: 0.06),
      caption: BarcodeCaption('@flutterdev', size: 0.06),
      card: BarcodeCard(elevation: 0.04),
    );

    testWidgets('taller than wide; still reads', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const BarcodeView(url, width: 260, style: style)),
      );
      await _settle(tester);
      final Size size = tester.getSize(find.byType(BarcodeView));
      expect(size.width, 260);
      expect(size.height, greaterThan(300));
      expect((await _readScreen(tester))?.text, url);
    });

    testWidgets('the text is in the label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const BarcodeView('hello', width: 200, style: style)),
      );
      await _settle(tester);
      expect(
        tester.getSemantics(find.byType(BarcodeView)),
        matchesSemantics(
          label: 'Studio 5G. QR Code barcode: hello. @flutterdev',
          isImage: true,
        ),
      );
      handle.dispose();
    });
  });
}
