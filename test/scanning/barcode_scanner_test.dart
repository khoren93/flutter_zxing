// BarcodeScanner on a fake camera: the preview, the overlay layout in widget
// coordinates, gestures and errors.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
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
  });
}
