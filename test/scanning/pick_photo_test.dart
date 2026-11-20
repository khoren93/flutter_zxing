// ScannerTemplate.pick with a photo, on the real engine: several codes open
// with a label each, one code is the result at once.
@Tags(<String>['native'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing/src/scanning/snapshot.dart';

import 'fake_camera.dart';

const Size _phone = Size(390, 844);

/// A white 800 × 420 page with a QR code for each of [texts], side by side.
Future<Uint8List> _page(List<String> texts) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawRect(
      const Rect.fromLTWH(0, 0, 800, 420),
      Paint()..color = const Color(0xFFFFFFFF),
    );
  for (final (int i, String text) in texts.indexed) {
    final BarcodeImage code = await const BarcodeWriter(
      BarcodeFormat.qrCode,
    ).toImage(text, size: 300);
    final ui.Codec codec = await ui.instantiateImageCodec(await code.toPng());
    final ui.FrameInfo frame = await codec.getNextFrame();
    codec.dispose();
    canvas.drawImage(frame.image, Offset(50 + i * 400, 60), Paint());
    frame.image.dispose();
  }
  final ui.Image page = await recorder.endRecording().toImage(800, 420);
  final ByteData? png = await page.toByteData(format: ui.ImageByteFormat.png);
  page.dispose();
  return png!.buffer.asUint8List();
}

/// A JPEG start with an EXIF segment holding [orientation].
Uint8List _jpegHeader(int orientation, {bool bigEndian = false}) {
  final Endian endian = bigEndian ? Endian.big : Endian.little;
  final ByteData tiff = ByteData(26)
    ..setUint16(0, bigEndian ? 0x4D4D : 0x4949)
    ..setUint16(2, 42, endian)
    ..setUint32(4, 8, endian)
    ..setUint16(8, 1, endian)
    ..setUint16(10, 0x0112, endian)
    ..setUint16(12, 3, endian)
    ..setUint32(14, 1, endian)
    ..setUint16(18, orientation, endian);
  return Uint8List.fromList(<int>[
    0xFF, 0xD8, // Start of the image.
    0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // A segment to step over.
    0xFF, 0xE1, 0x00, 8 + 26,
    0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // "Exif"
    ...tiff.buffer.asUint8List(),
    0xFF, 0xDA, 0x00, 0x02, // The pixels.
  ]);
}

void main() {
  setUpAll(warmUpBarcodeEngine);

  group('on a photo', () {
    late FakeCamera camera;
    late ScannerController controller;

    setUp(() {
      camera = FakeCamera(transform: const FrameTransform(_phone));
      ScannerControllerDebug.cameraFactory = () => camera;
      controller = ScannerController(maxBarcodes: null);
    });

    tearDown(() {
      ScannerControllerDebug.cameraFactory = null;
    });

    Future<void> open(
      WidgetTester tester, {
      ScannerTemplate template = const ScannerTemplate.pick(),
    }) async {
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: _phone,
            padding: EdgeInsets.only(top: 47, bottom: 34),
            viewPadding: EdgeInsets.only(top: 47, bottom: 34),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: BarcodeScanner(controller: controller, template: template),
          ),
        ),
      );
      await tester.pump();
    }

    /// Reads a page of [texts] and waits until [shown] is on screen.
    Future<void> read(
      WidgetTester tester,
      List<String> texts,
      Finder shown,
    ) async {
      await tester.runAsync(() async {
        await controller.readImage(await _page(texts));
      });
      for (int i = 0; i < 100 && shown.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(shown, findsWidgets);
    }

    /// Takes the scanner off the screen, with the images it holds.
    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    }

    /// Waits until the result sheet of a picked code shows, its picture
    /// loaded off the test clock.
    Future<void> sheet(WidgetTester tester) async {
      final Finder shown = find.byType(BarcodeResultSheet);
      for (int i = 0; i < 200 && shown.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('has a photo button', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester);
      expect(find.bySemanticsLabel('Read a code from a photo'), findsOneWidget);
      semantics.dispose();
      await close(tester);
    });

    testWidgets('several codes: a label each, a tap picks one', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await read(tester, <String>['left', 'right'], find.text('right'));
      expect(find.text('left'), findsOneWidget);
      expect(find.text('2 codes'), findsOneWidget);
      expect(controller.value.status, ScannerStatus.paused);
      // Nothing is picked by itself.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BarcodeResultSheet), findsNothing);
      // Each label is over its code.
      expect(
        tester.getCenter(find.text('left')).dx,
        lessThan(_phone.width / 2),
      );
      expect(
        tester.getCenter(find.text('right')).dx,
        greaterThan(_phone.width / 2),
      );

      await tester.tap(find.text('right'));
      await sheet(tester);
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      expect(
        tester
            .widget<BarcodeResultSheet>(find.byType(BarcodeResultSheet))
            .barcode
            .text,
        'right',
      );
      await close(tester);
    });

    testWidgets('a tap on the code itself picks it', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await read(tester, <String>['left', 'right'], find.text('left'));
      // Under the label.
      await tester.tapAt(
        tester.getCenter(find.text('left')) + const Offset(0, 50),
      );
      await sheet(tester);
      expect(
        tester
            .widget<BarcodeResultSheet>(find.byType(BarcodeResultSheet))
            .barcode
            .text,
        'left',
      );
      await close(tester);
    });

    /// Lets the picture of a picked code load and the sheet move.
    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    String shownResult(WidgetTester tester) => tester
        .widget<BarcodeResultSheet>(find.byType(BarcodeResultSheet))
        .barcode
        .text;

    testWidgets('closing a result goes back to the codes of the photo', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final List<String> picked = <String>[];
      await open(
        tester,
        template: ScannerTemplate.pick(
          onPick: (Barcode barcode, BarcodeCapture capture) {
            expect(capture.barcodes, hasLength(2));
            picked.add(barcode.text);
          },
        ),
      );
      await read(tester, <String>['left', 'right'], find.text('right'));
      // Reading the photo picks nothing.
      expect(picked, isEmpty);

      await tester.tap(find.text('right'));
      await settle(tester);
      expect(shownResult(tester), 'right');
      await tester.tap(find.bySemanticsLabel('Back to the codes'));
      await settle(tester);
      expect(find.byType(BarcodeResultSheet), findsNothing);
      expect(find.text('2 codes'), findsOneWidget);
      expect(controller.value.status, ScannerStatus.paused);

      // Another one; a tap around its sheet goes back too.
      await tester.tap(find.text('left'));
      await settle(tester);
      expect(shownResult(tester), 'left');
      await tester.tapAt(const Offset(195, 120));
      await settle(tester);
      expect(find.byType(BarcodeResultSheet), findsNothing);
      expect(find.text('right'), findsOneWidget);
      expect(picked, <String>['right', 'left']);

      // "Scan again" leaves the photo.
      await tester.tap(find.text('right'));
      await settle(tester);
      await tester.tap(find.text('Scan again'));
      await settle(tester);
      expect(find.text('left'), findsNothing);
      expect(controller.value.status, ScannerStatus.running);
      semantics.dispose();
      await close(tester);
    });

    testWidgets('a refused code is not reported as picked', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await open(
        tester,
        template: ScannerTemplate.pick(
          check: (Barcode barcode) => barcode.text == 'left'
              ? const ScanVerdict.reject(title: 'No')
              : const ScanVerdict.accept(),
          onPick: (Barcode barcode, BarcodeCapture _) =>
              picked.add(barcode.text),
        ),
      );
      await read(tester, <String>['left', 'right'], find.text('left'));
      await tester.tap(find.text('left'));
      await settle(tester);
      expect(picked, isEmpty);
      expect(find.byType(BarcodeResultSheet), findsNothing);
      // Still on the photo.
      expect(find.text('right'), findsOneWidget);
      expect(controller.value.status, ScannerStatus.paused);
      await close(tester);
    });

    testWidgets('one code on a photo is reported as picked', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await open(
        tester,
        template: ScannerTemplate.pick(
          onPick: (Barcode barcode, BarcodeCapture _) =>
              picked.add(barcode.text),
        ),
      );
      await read(tester, <String>['alone'], find.byType(BarcodeResultSheet));
      expect(picked, <String>['alone']);
      await close(tester);
    });

    testWidgets('back to the camera', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester);
      await read(tester, <String>['left', 'right'], find.text('left'));
      await tester.tap(find.bySemanticsLabel('Back to the camera'));
      await tester.pump();
      await tester.pump();
      expect(find.text('left'), findsNothing);
      expect(find.bySemanticsLabel('Back to the camera'), findsNothing);
      expect(find.bySemanticsLabel('Read a code from a photo'), findsOneWidget);
      expect(controller.value.status, ScannerStatus.running);
      semantics.dispose();
      await close(tester);
    });

    testWidgets('one code is the result at once', (WidgetTester tester) async {
      await open(tester);
      await read(tester, <String>['alone'], find.byType(BarcodeResultSheet));
      expect(find.bySemanticsLabel('Back to the camera'), findsNothing);
      await close(tester);
    });
  });

  group('EXIF orientation', () {
    test('is read from a JPEG in either byte order', () {
      for (int orientation = 1; orientation <= 8; orientation++) {
        expect(exifOrientation(_jpegHeader(orientation)), orientation);
        expect(
          exifOrientation(_jpegHeader(orientation, bigEndian: true)),
          orientation,
        );
      }
    });

    test('is 1 for anything else', () {
      expect(exifOrientation(Uint8List(0)), 1);
      expect(exifOrientation(Uint8List.fromList(<int>[0x89, 0x50, 1, 2])), 1);
      expect(exifOrientation(_jpegHeader(9)), 1);
      // Cut off anywhere, it never throws.
      final Uint8List whole = _jpegHeader(6);
      for (int end = 0; end < whole.length; end++) {
        expect(
          exifOrientation(Uint8List.sublistView(whole, 0, end)),
          anyOf(1, 6),
        );
      }
    });

    test('moves a point to where it shows', () {
      const Size size = Size(40, 30);
      const Offset p = Offset(10, 5);
      const Map<int, Offset> shown = <int, Offset>{
        1: Offset(10, 5),
        2: Offset(30, 5),
        3: Offset(30, 25),
        4: Offset(10, 25),
        5: Offset(5, 10),
        6: Offset(25, 10),
        7: Offset(25, 30),
        8: Offset(5, 30),
      };
      shown.forEach((int orientation, Offset expected) {
        expect(orientedPoint(p, size, orientation), expected);
        final Size turned = orientedSize(size, orientation);
        expect(turned, orientation >= 5 ? const Size(30, 40) : size);
      });
    });
  });
}
