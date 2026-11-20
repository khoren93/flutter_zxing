// The template overlay on a fake camera: labels, verdicts, results that
// close the screen or wait for the app.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import 'fake_camera.dart';

const Size _phone = Size(390, 844);
const Rect _a = Rect.fromLTWH(200, 400, 300, 300);

PixelBuffer _pixels() {
  final Uint8List b = Uint8List(720 * 1280);
  for (int i = 0; i < b.length; i++) {
    b[i] = (i ~/ 7).isEven ? 30 : 220;
  }
  return PixelBuffer(b, width: 720, height: 1280);
}

Widget _host(
  Widget child, {
  EdgeInsets safe = EdgeInsets.zero,
  Size size = _phone,
}) => MediaQuery(
  data: MediaQueryData(size: size, padding: safe, viewPadding: safe),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

Future<void> _settle(WidgetTester t, [int n = 10]) async {
  for (int i = 0; i < n; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeCamera camera;
  late ScannerController c;

  setUp(() {
    camera = FakeCamera(transform: const FrameTransform(Size(720, 1280)));
    ScannerControllerDebug.cameraFactory = () => camera;
    c = ScannerController(
      scanWindow: const ScanWindow.full(),
      maxBarcodes: null,
    );
  });
  tearDown(() => ScannerControllerDebug.cameraFactory = null);

  Future<void> open(
    WidgetTester t,
    ScannerTemplate template, {
    ValueChanged<BarcodeCapture>? onDetect,
    EdgeInsets safe = EdgeInsets.zero,
    Size size = _phone,
  }) async {
    t.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        BarcodeScanner(controller: c, template: template, onDetect: onDetect),
        safe: safe,
        size: size,
      ),
    );
    await t.pump();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async => c.dispose());
  }

  Future<void> code(WidgetTester t, [String text = 'A', Rect r = _a]) async {
    camera.push(<Barcode>[fakeBarcode(text, r)], null, false, _pixels());
    await t.pump();
    await t.pump();
  }

  testWidgets('a long pick label is cut between characters', (
    WidgetTester t,
  ) async {
    await open(t, const ScannerTemplate.pick());
    await code(t, '${'a' * 26}😀tail');
    expect(find.text('${'a' * 26}😀…'), findsOneWidget);
    await close(t);
  });

  testWidgets('a pick label stays below the top bar under a notch', (
    WidgetTester t,
  ) async {
    const EdgeInsets notch = EdgeInsets.only(top: 59, bottom: 34);
    await open(t, const ScannerTemplate.pick(), safe: notch);
    // A code near the top of the view: its label would go above it.
    await code(t, 'A', const Rect.fromLTWH(300, 200, 200, 200));
    final Rect label = t.getRect(find.text('A'));
    // The top bar ends 60 below the safe area.
    expect(label.top, greaterThanOrEqualTo(notch.top + 60));
    await close(t);
  });

  testWidgets('four zoom presets fit between the bottom buttons', (
    WidgetTester t,
  ) async {
    // An Android camera that zooms out: 0.6×, 1×, 2×, 4×.
    camera.capabilities = const CameraCapabilities(
      minZoom: 0.6,
      maxZoom: 10,
      hasOtherFacing: true,
    );
    await open(
      t,
      const ScannerTemplate(
        photoButton: true,
        zoomButtons: true,
        switchCameraButton: true,
      ),
      size: const Size(360, 780),
    );
    await t.pump();
    expect(find.text('0.6×'), findsOneWidget);
    final Rect zoom = t.getRect(find.byType(ZoomButtons));
    final Rect photo = t.getRect(find.byType(PickImageButton));
    final Rect flip = t.getRect(find.byType(SwitchCameraButton));
    expect(zoom.left, greaterThanOrEqualTo(photo.right));
    expect(zoom.right, lessThanOrEqualTo(flip.left));
    expect(zoom.center.dx, moreOrLessEquals(180, epsilon: 0.5));
    await close(t);
  });

  testWidgets('a verdict equal to the one before shows anew', (
    WidgetTester t,
  ) async {
    await open(
      t,
      ScannerTemplate.checkIn(
        check: (_) => const ScanVerdict.reject(title: 'Invalid ticket'),
      ),
    );
    await code(t);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(ScannerSheet), findsOneWidget);
    await code(t, 'B', _a.shift(const Offset(0, 320)));
    await t.pump(const Duration(milliseconds: 50));
    // The new sheet comes in while the one before leaves.
    expect(find.byType(ScannerSheet), findsNWidgets(2));
    await t.pump(const Duration(seconds: 3));
    await close(t);
  });

  testWidgets('a flagged code shows its verdict and is taken', (
    WidgetTester t,
  ) async {
    final List<String> haptics = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(
      t,
      ScannerTemplate.minimal(
        check: (_) =>
            const ScanVerdict.warn(title: 'Ticket used', message: 'at 9:30'),
      ),
    );
    await code(t);
    await _settle(t, 6);
    expect(find.text('Ticket used · at 9:30'), findsOneWidget);
    expect(haptics, <String>['HapticFeedbackType.heavyImpact']);
    expect(find.byType(BarcodeResultSheet), findsOneWidget);
    await close(t);
  });
}
