// The template overlay on a fake camera: labels, verdicts, results that
// close the screen or wait for the app.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
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

Widget _host(Widget child, {EdgeInsets safe = EdgeInsets.zero}) => MediaQuery(
  data: MediaQueryData(size: _phone, padding: safe, viewPadding: safe),
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
  }) async {
    t.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        BarcodeScanner(controller: c, template: template, onDetect: onDetect),
        safe: safe,
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
}
