// The picture of the code found in the scan window: drawn exactly where it
// can be, else the sharpest cut-out of the frames read in the moment after
// the code, lightly sharpened.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerControllerGlimpse;
import 'package:flutter_zxing/src/scanning/snapshot.dart';

import 'fake_camera.dart';

const Size _phone = Size(390, 844);
const Rect _a = Rect.fromLTWH(200, 400, 300, 300);
const int _w = 720;
const int _h = 1280;

/// A frame of 12 px squares, black and white: a sharp code.
PixelBuffer _sharp() {
  final Uint8List b = Uint8List(_w * _h);
  for (int y = 0; y < _h; y++) {
    for (int x = 0; x < _w; x++) {
      b[y * _w + x] = ((x ~/ 12) + (y ~/ 12)).isEven ? 30 : 220;
    }
  }
  return PixelBuffer(b, width: _w, height: _h);
}

/// A frame of 12 px stripes smeared sideways, as by motion: every row the
/// same, so that it is told from [_sharp] by its rows.
PixelBuffer _blurred() {
  final Uint8List row = Uint8List(_w);
  for (int x = 0; x < _w; x++) {
    int sum = 0;
    for (int i = -7; i <= 7; i++) {
      sum += ((x + i).clamp(0, _w - 1) ~/ 12).isEven ? 30 : 220;
    }
    row[x] = sum ~/ 15;
  }
  final Uint8List b = Uint8List(_w * _h);
  for (int y = 0; y < _h; y++) {
    b.setRange(y * _w, (y + 1) * _w, row);
  }
  return PixelBuffer(b, width: _w, height: _h);
}

Barcode _code(
  BarcodeFormat format,
  String text, {
  BarcodeSymbol? symbol,
  Rect rect = _a,
}) => Barcode(
  format: format,
  text: text,
  bytes: Uint8List(0),
  position: BarcodePosition(
    topLeft: rect.topLeft,
    topRight: rect.topRight,
    bottomRight: rect.bottomRight,
    bottomLeft: rect.bottomLeft,
  ),
  symbol: symbol,
);

BarcodeSymbol _grid() => BarcodeSymbol(
  format: BarcodeFormat.qrCode,
  width: 21,
  height: 21,
  modules: Uint8List.fromList(
    List<int>.generate(21 * 21, (int i) => (i * 7919) % 3 == 0 ? 1 : 0),
  ),
);

Finder get _flight => find.byWidgetPredicate(
  (Widget w) => w.runtimeType.toString() == '_CutOutFlight',
);

Finder get _exact => find.descendant(
  of: _flight,
  matching: find.byKey(const ValueKey<String>('exact')),
);

double _opacityOf(WidgetTester t, Finder f) => t
    .widget<Opacity>(
      find.descendant(of: f, matching: find.byType(Opacity)).first,
    )
    .opacity;

/// The cut-out shown on top in the window.
ui.Image _windowImage(WidgetTester t) => t
    .widgetList<RawImage>(
      find.descendant(of: _flight, matching: find.byType(RawImage)),
    )
    .last
    .image!;

/// The mean step from one row to the next of the red channel of [image].
Future<double> _rowSteps(WidgetTester t, ui.Image image) async {
  final ByteData data = (await t.runAsync<ByteData?>(image.toByteData))!;
  int sum = 0;
  for (int y = 0; y < image.height - 1; y++) {
    for (int x = 0; x < image.width; x++) {
      final int i = (y * image.width + x) * 4;
      sum += (data.getUint8(i) - data.getUint8(i + image.width * 4)).abs();
    }
  }
  return sum / ((image.height - 1) * image.width);
}

/// A code of 25 × 25 squares, smeared sideways over [smear] pixels as by
/// motion, cut out and straightened from a slight perspective.
GrayImage _crop(int smear) {
  const int modules = 25;
  const int size = 320;
  final math.Random random = math.Random(7);
  final List<bool> dark = List<bool>.generate(
    modules * modules,
    (_) => random.nextBool(),
  );
  final Uint8List sharp = Uint8List(size * size)
    ..fillRange(0, size * size, 220);
  const double module = 10;
  const double origin = (size - modules * module) / 2;
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final int mx = ((x - origin) / module).floor();
      final int my = ((y - origin) / module).floor();
      if (mx >= 0 && my >= 0 && mx < modules && my < modules) {
        sharp[y * size + x] = dark[my * modules + mx] ? 30 : 220;
      }
    }
  }
  final Uint8List pixels = Uint8List(size * size);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      int sum = 0;
      for (int i = 0; i < smear; i++) {
        sum += sharp[y * size + (x + i - smear ~/ 2).clamp(0, size - 1)];
      }
      pixels[y * size + x] = smear == 0 ? sharp[y * size + x] : sum ~/ smear;
    }
  }
  final FrameCut cut = FrameCut(pixels, size, size, Offset.zero);
  return straighten(cut, const <Offset>[
    Offset(20, 24),
    Offset(300, 18),
    Offset(296, 302),
    Offset(24, 296),
  ])!;
}

void main() {
  group('the sharpness score', () {
    test('ranks a cut-out smeared by motion below a sharp one', () {
      final List<double> scores = <double>[
        for (final int smear in <int>[0, 3, 7, 13]) sharpness(_crop(smear)),
      ];
      for (int i = 1; i < scores.length; i++) {
        expect(scores[i], lessThan(scores[i - 1] * 0.8), reason: '$scores');
      }
    });

    test('takes well under a few milliseconds on a 256 px cut-out', () {
      final GrayImage crop = _crop(3);
      expect(crop.width, greaterThanOrEqualTo(256));
      for (int i = 0; i < 20; i++) {
        sharpness(crop);
        unsharpMask(crop);
      }
      const int runs = 100;
      final Stopwatch score = Stopwatch()..start();
      for (int i = 0; i < runs; i++) {
        sharpness(crop);
      }
      score.stop();
      final Stopwatch sharpen = Stopwatch()..start();
      for (int i = 0; i < runs; i++) {
        unsharpMask(crop);
      }
      sharpen.stop();
      final double scoreMs = score.elapsedMicroseconds / runs / 1000;
      final double sharpenMs = sharpen.elapsedMicroseconds / runs / 1000;
      // ignore: avoid_print
      print(
        'cut-out ${crop.width} × ${crop.height}: score '
        '${scoreMs.toStringAsFixed(3)} ms, sharpen '
        '${sharpenMs.toStringAsFixed(3)} ms',
      );
      expect(scoreMs, lessThan(2));
      expect(sharpenMs, lessThan(4));
    });
  });

  group('the unsharp mask', () {
    test('steepens an edge without a halo, and leaves flat gray alone', () {
      const int width = 40;
      const int height = 8;
      final Uint8List pixels = Uint8List(width * height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          // A soft edge from 80 to 170 over 4 pixels.
          pixels[y * width + x] = 80 + (x - 18).clamp(0, 4) * 90 ~/ 4;
        }
      }
      final GrayImage image = GrayImage(pixels, width, height);
      final GrayImage sharper = unsharpMask(image);
      expect(image.pixels, pixels, reason: 'the image is kept');
      final List<int> before = pixels.sublist(4 * width, 5 * width);
      final List<int> after = sharper.pixels.sublist(4 * width, 5 * width);
      // Flat on either side: unchanged.
      expect(after.sublist(0, 16), before.sublist(0, 16));
      expect(after.sublist(25), before.sublist(25));
      // The edge is steeper: darker below it, lighter above.
      expect(after[18], lessThan(before[18]));
      expect(after[22], greaterThan(before[22]));
      // No halo: nothing goes far past the two grays.
      expect(after.reduce(math.min), greaterThanOrEqualTo(80 - 25));
      expect(after.reduce(math.max), lessThanOrEqualTo(170 + 25));
      expect(sharpness(sharper), greaterThan(sharpness(image)));
    });
  });

  group('in the window', () {
    late FakeCamera camera;
    late ScannerController c;
    late int detected;

    setUp(() {
      detected = 0;
      camera = FakeCamera(transform: const FrameTransform(Size(720, 1280)));
      ScannerControllerDebug.cameraFactory = () => camera;
      c = ScannerController(
        scanWindow: const ScanWindow.full(),
        maxBarcodes: null,
      );
    });
    tearDown(() => ScannerControllerDebug.cameraFactory = null);

    Future<void> open(WidgetTester t, {ScannerWindowPicture? picture}) async {
      t.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: _phone),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: BarcodeScanner(
              controller: c,
              template: const ScannerTemplate(scanWindow: ScanWindow.full()),
              theme: ScannerTheme(windowPicture: picture),
              onDetect: (_) => detected++,
            ),
          ),
        ),
      );
      await t.pump();
    }

    Future<void> close(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async => c.dispose());
    }

    /// Lets the cut-out be made (real time) and the flight start.
    Future<void> cutOut(WidgetTester t) async {
      for (int i = 0; i < 20 && _flight.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await t.pump();
      }
    }

    Future<void> settle(WidgetTester t) async {
      for (int i = 0; i < 8; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a QR code turns into its modules once it landed', (
      WidgetTester t,
    ) async {
      await open(t);
      final BarcodeSymbol symbol = _grid();
      camera.push(
        <Barcode>[_code(BarcodeFormat.qrCode, 'Q', symbol: symbol)],
        null,
        false,
        _sharp(),
      );
      await t.pump();
      await t.pump();
      expect(detected, 1);
      expect(c.value.status, ScannerStatus.paused);
      // A code drawn exactly needs no sharper frame: none is read.
      expect(c.glimpsing, isFalse);
      await cutOut(t);
      expect(_flight, findsOneWidget);
      // On its way, the cut-out.
      expect(_opacityOf(t, _exact), 0);
      await t.pump(const Duration(milliseconds: 380));
      await t.pump(const Duration(milliseconds: 150));
      expect(_opacityOf(t, _exact), 1);
      final BarcodeView drawn = t.widget<BarcodeView>(
        find.descendant(of: _exact, matching: find.byType(BarcodeView)),
      );
      expect(drawn.symbol, symbol);
      expect(drawn.style.quietZone, isFalse);
      // Landed, the cut-out is no longer drawn under it.
      expect(
        find.descendant(of: _flight, matching: find.byType(RawImage)),
        findsNothing,
      );
      final FakeFrame later = camera.push(
        <Barcode>[_code(BarcodeFormat.qrCode, 'Q', symbol: symbol)],
        null,
        false,
        _sharp(),
      );
      await settle(t);
      expect(later.wasRead, isFalse);
      expect(detected, 1);
      await close(t);
    });

    testWidgets('reduce motion shows the modules at once', (
      WidgetTester t,
    ) async {
      t.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
      t.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: _phone, disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: BarcodeScanner(
              controller: c,
              template: const ScannerTemplate(scanWindow: ScanWindow.full()),
            ),
          ),
        ),
      );
      await t.pump();
      camera.push(
        <Barcode>[_code(BarcodeFormat.qrCode, 'Q', symbol: _grid())],
        null,
        false,
        _sharp(),
      );
      await t.pump();
      await t.pump();
      await cutOut(t);
      expect(_opacityOf(t, _exact), 1);
      await close(t);
    });

    testWidgets('an EAN-13 turns into the code drawn again', (
      WidgetTester t,
    ) async {
      await open(t);
      camera.push(
        <Barcode>[_code(BarcodeFormat.ean13, '5901234123457')],
        null,
        false,
        _sharp(),
      );
      await t.pump();
      await t.pump();
      expect(c.glimpsing, isFalse);
      await cutOut(t);
      await t.pump(const Duration(milliseconds: 380));
      await t.pump(const Duration(milliseconds: 150));
      expect(_opacityOf(t, _exact), 1);
      final BarcodeView drawn = t.widget<BarcodeView>(
        find.descendant(of: _exact, matching: find.byType(BarcodeView)),
      );
      expect(drawn.symbol, isNull);
      expect(drawn.data, '5901234123457');
      expect(drawn.writer!.format, BarcodeFormat.ean13);
      expect(drawn.writer!.showText, isTrue);
      await close(t);
    });

    testWidgets('photo keeps the cut-out', (WidgetTester t) async {
      await open(t, picture: ScannerWindowPicture.photo);
      camera.push(
        <Barcode>[_code(BarcodeFormat.qrCode, 'Q', symbol: _grid())],
        null,
        false,
        _sharp(),
      );
      await t.pump();
      await t.pump();
      await cutOut(t);
      await settle(t);
      expect(_flight, findsOneWidget);
      expect(_exact, findsNothing);
      expect(
        find.descendant(of: _flight, matching: find.byType(RawImage)),
        findsOneWidget,
      );
      await close(t);
    });

    testWidgets('none shows nothing in the window', (WidgetTester t) async {
      await open(t, picture: ScannerWindowPicture.none);
      camera.push(
        <Barcode>[_code(BarcodeFormat.qrCode, 'Q', symbol: _grid())],
        null,
        false,
        _sharp(),
      );
      await t.pump();
      await t.pump();
      await settle(t);
      expect(detected, 1);
      expect(_flight, findsNothing);
      // The result still shows.
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      await close(t);
    });

    testWidgets('a code without an exact picture keeps the sharpest frame '
        'read in the moment after it', (WidgetTester t) async {
      await open(t);
      // A QR code without its modules is pictured by its cut-out.
      final Barcode code = _code(BarcodeFormat.qrCode, 'C');
      camera.push(<Barcode>[code], null, false, _blurred());
      await t.pump();
      await t.pump();
      expect(detected, 1);
      expect(c.value.status, ScannerStatus.paused);
      expect(c.glimpsing, isTrue);
      await cutOut(t);
      expect(await _rowSteps(t, _windowImage(t)), lessThan(2));
      // The camera, paused, reads a sharper frame of the code.
      final FakeFrame sharp = camera.push(
        <Barcode>[code],
        null,
        false,
        _sharp(),
      );
      await t.pump();
      expect(sharp.wasRead, isTrue);
      await settle(t);
      expect(detected, 1, reason: 'onDetect is told once');
      expect(await _rowSteps(t, _windowImage(t)), greaterThan(20));
      // The sheet shows it too.
      final BarcodeThumbnail thumbnail = t.widget<BarcodeThumbnail>(
        find.byType(BarcodeThumbnail),
      );
      expect(await _rowSteps(t, thumbnail.cutOut!), greaterThan(20));
      // The moment is over: the paused camera reads no more.
      expect(c.glimpsing, isFalse);
      final FakeFrame after = camera.push(
        <Barcode>[code],
        null,
        false,
        _blurred(),
      );
      await settle(t);
      expect(after.wasRead, isFalse);
      expect(c.value.status, ScannerStatus.paused);
      await close(t);
    });

    testWidgets('a blurrier frame read after it does not replace it', (
      WidgetTester t,
    ) async {
      await open(t);
      final Barcode code = _code(BarcodeFormat.qrCode, 'C');
      camera.push(<Barcode>[code], null, false, _sharp());
      await t.pump();
      await t.pump();
      await cutOut(t);
      final ui.Image first = _windowImage(t);
      camera.push(<Barcode>[code], null, false, _blurred());
      await t.pump();
      await settle(t);
      expect(_windowImage(t).isCloneOf(first), isTrue);
      await close(t);
    });

    for (final (String event, Future<void> Function(WidgetTester) stop)
        in <(String, Future<void> Function(WidgetTester))>[
          ('the scanner resumes', (_) => c.resume()),
          ('the camera stops, as in the background', (_) => c.stop()),
          (
            'the scanner is gone',
            (WidgetTester t) async {
              await t.pumpWidget(const SizedBox());
            },
          ),
        ]) {
      testWidgets('the extra reading stops when $event', (
        WidgetTester t,
      ) async {
        await open(t);
        final Barcode code = _code(BarcodeFormat.qrCode, 'C');
        camera.push(<Barcode>[code], null, false, _blurred());
        await t.pump();
        await t.pump();
        expect(c.glimpsing, isTrue);
        await stop(t);
        expect(c.glimpsing, isFalse);
        await close(t);
      });
    }
  });
}
