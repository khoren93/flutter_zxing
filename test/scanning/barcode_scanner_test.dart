// BarcodeScanner on a fake camera: the preview, the overlay layout in widget
// coordinates, gestures and errors.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart'
    show FrameTransform;
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import 'fake_camera.dart';

void main() {
  late FakeCamera camera;

  setUp(() {
    camera = FakeCamera();
    ScannerControllerDebug.cameraFactory = () => camera;
  });

  tearDown(() => ScannerControllerDebug.cameraFactory = null);

  /// [child] filling a 400 x 800 portrait screen.
  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(400, 800)),
      child: child,
    ),
  );

  Future<void> portrait(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('without a controller it opens the camera and releases it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(host(const BarcodeScanner()));
    await tester.pump();
    expect(camera.isOpen, isTrue);
    expect(find.byKey(const ValueKey<String>('fake preview')), findsOneWidget);
    expect(find.byType(ScannerOverlay), findsOneWidget);

    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump();
    expect(camera.isOpen, isFalse);
  });

  testWidgets('rebuilds the preview when it turns but keeps its shape', (
    WidgetTester tester,
  ) async {
    // On iOS the preview is turned for an instant while the UI has turned
    // and the frames have not yet; then the frames turn and the preview no
    // longer is. The shape shown stays the same, but the preview has to
    // follow, or it stays a quarter turn off.
    await portrait(tester);
    await tester.pumpWidget(host(const BarcodeScanner()));
    await tester.pump();
    final int builds = camera.previewBuilds;

    camera.turn(const FrameTransform(Size(480, 640)));
    await tester.pump();
    expect(camera.previewBuilds, greaterThan(builds));
  });

  testWidgets('reports detections and outlines them where they show', (
    WidgetTester tester,
  ) async {
    await portrait(tester);
    final ScannerController controller = ScannerController(
      detection: DetectionMode.continuous,
      scanWindow: const ScanWindow.full(),
    );
    addTearDown(controller.dispose);
    final List<BarcodeCapture> captures = <BarcodeCapture>[];
    late ScannerLayout layout;
    await tester.pumpWidget(
      host(
        BarcodeScanner(
          controller: controller,
          onDetect: captures.add,
          overlayBuilder: (BuildContext context, ScannerLayout l) {
            layout = l;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    // A code at (100, 200)-(200, 300) of the 640 x 480 frame; turned by 90
    // degrees it spans (180, 100)-(280, 200) of the 480 x 640 display frame.
    camera.push(<Barcode>[
      fakeBarcode('outlined', const Rect.fromLTRB(100, 200, 200, 300)),
    ]);
    await tester.pump();
    await tester.pump();
    expect(captures.single.barcode.text, 'outlined');

    // Covering 400 x 800 scales the display frame by 1.25 and cuts 100 px
    // off each side: x' = x * 1.25 - 100, y' = y * 1.25.
    expect(layout.size, const Size(400, 800));
    expect(layout.scanWindow, const Rect.fromLTWH(0, 0, 400, 800));
    final Rect bounds = layout.barcodes.single.bounds;
    expect(bounds.left, closeTo(125, 1e-9));
    expect(bounds.top, closeTo(125, 1e-9));
    expect(bounds.right, closeTo(250, 1e-9));
    expect(bounds.bottom, closeTo(250, 1e-9));
    expect(layout.state.isScanning, isTrue);
  });

  testWidgets('follows the codes in view from frame to frame', (
    WidgetTester tester,
  ) async {
    await portrait(tester);
    DateTime now = DateTime(2026);
    ScannerControllerDebug.clock = () => now;
    addTearDown(() => ScannerControllerDebug.clock = null);
    final ScannerController controller = ScannerController(
      scanWindow: const ScanWindow.full(),
    );
    addTearDown(controller.dispose);
    late ScannerLayout layout;
    await tester.pumpWidget(
      host(
        BarcodeScanner(
          controller: controller,
          overlayBuilder: (BuildContext context, ScannerLayout l) {
            layout = l;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump();
    Future<void> frame(List<Barcode> barcodes, {int ms = 100}) async {
      now = now.add(Duration(milliseconds: ms));
      camera.push(barcodes);
      await tester.pump();
      await tester.pump();
    }

    List<String> shown() => <String>[
      for (final VisibleBarcode b in layout.barcodes)
        '${b.id}:${b.barcode.text}',
    ];

    // Two codes with the same content, and another.
    final Barcode a1 = fakeBarcode('same', const Rect.fromLTRB(20, 20, 80, 80));
    final Barcode a2 = fakeBarcode(
      'same',
      const Rect.fromLTRB(300, 20, 360, 80),
    );
    final Barcode b = fakeBarcode(
      'other',
      const Rect.fromLTRB(20, 300, 80, 360),
    );
    await frame(<Barcode>[a1, a2, b]);
    final List<String> first = shown();
    expect(first, hasLength(3));
    expect(
      layout.barcodes.map((VisibleBarcode v) => v.id).toSet(),
      hasLength(3),
    );
    final Map<int, Offset> where = <int, Offset>{
      for (final VisibleBarcode v in layout.barcodes) v.id: v.bounds.center,
    };

    // Found in another order, or one missed for a moment: nothing changes,
    // and each code keeps its own id, matched by where it is.
    await frame(<Barcode>[b, a2, a1]);
    expect(shown(), first);
    await frame(<Barcode>[a2, b]);
    expect(shown(), first);
    for (final VisibleBarcode v in layout.barcodes) {
      expect((v.bounds.center - where[v.id]!).distance, lessThan(1));
    }

    // Out of view for long enough: gone, the others stay in order.
    await frame(<Barcode>[a2, b], ms: 600);
    expect(shown(), <String>[first[1], first[2]]);
    await frame(const <Barcode>[], ms: 600);
    expect(layout.barcodes, isEmpty);
  });

  testWidgets('a tap focuses where the user tapped', (
    WidgetTester tester,
  ) async {
    await portrait(tester);
    await tester.pumpWidget(host(const BarcodeScanner()));
    await tester.pump();
    // Covering cuts 80 display pixels off each side: the widget's left edge
    // shows column 80 of 480.
    await tester.tapAt(const Offset(0, 400));
    await tester.pump();
    expect(camera.focus!.dx, closeTo(80 / 480, 1e-9));
    expect(camera.focus!.dy, closeTo(0.5, 1e-9));
  });

  testWidgets('the error builder replaces the preview', (
    WidgetTester tester,
  ) async {
    camera.openError = const CameraPermissionException();
    await tester.pumpWidget(
      host(
        BarcodeScanner(
          errorBuilder: (BuildContext context, ScannerException error) =>
              Text('error: ${error.runtimeType}'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('error: CameraPermissionException'), findsOneWidget);
  });

  testWidgets('a controller of its own is not disposed with the widget', (
    WidgetTester tester,
  ) async {
    final ScannerController controller = ScannerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(BarcodeScanner(controller: controller)));
    await tester.pump();
    expect(controller.value.isScanning, isTrue);
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump();
    // Started by the widget, so stopped with it, but still usable.
    expect(controller.value.status, ScannerStatus.idle);
    await controller.start();
    expect(controller.value.isScanning, isTrue);
    await controller.stop();
  });

  testWidgets('a camera that stops sending frames is opened again', (
    WidgetTester tester,
  ) async {
    final ScannerController controller = ScannerController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(BarcodeScanner(controller: controller)));
    await tester.pump();
    expect(camera.opened, hasLength(1));
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(camera.opened, hasLength(2));
    expect(controller.value.isScanning, isTrue);
    expect(controller.cameraRestarts, 1);
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump();
  });

  testWidgets('a stuck engine is replaced and scanning goes on', (
    WidgetTester tester,
  ) async {
    final ScannerController controller = ScannerController(
      detection: DetectionMode.continuous,
    );
    addTearDown(controller.dispose);
    final List<BarcodeCapture> captures = <BarcodeCapture>[];
    await tester.pumpWidget(
      host(BarcodeScanner(controller: controller, onDetect: captures.add)),
    );
    await tester.pump();
    camera.push(const <Barcode>[], null, true);
    await tester.pump(const Duration(seconds: 6));
    expect(controller.engineRestarts, 1);
    camera.push(<Barcode>[
      fakeBarcode('after', const Rect.fromLTWH(200, 200, 80, 80)),
    ]);
    await tester.pump();
    await tester.pump();
    expect(captures.single.barcode.text, 'after');
    await tester.pumpWidget(host(const SizedBox()));
    await tester.pump();
  });
}
