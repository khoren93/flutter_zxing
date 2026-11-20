// The demo's Scan tab on a fake camera.
import 'dart:typed_data';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing_example/demo/history.dart';
import 'package:flutter_zxing_example/demo/scan_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The package's own fake camera.
// ignore: avoid_relative_lib_imports
import '../../test/scanning/fake_camera.dart';

const Size _phone = Size(390, 844);

Barcode _code(String text, {BarcodeFormat format = BarcodeFormat.qrCode}) =>
    Barcode(
      format: format,
      text: text,
      bytes: Uint8List.fromList(text.codeUnits),
      position: const BarcodePosition(
        topLeft: Offset(150, 380),
        topRight: Offset(240, 380),
        bottomRight: Offset(240, 470),
        bottomLeft: Offset(150, 470),
      ),
    );

void main() {
  late FakeCamera camera;
  DateTime now = DateTime(2026);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    HistoryStore.instance.clear();
    camera = FakeCamera(transform: const FrameTransform(_phone));
    ScannerControllerDebug.cameraFactory = () => camera;
    ScannerControllerDebug.clock = () => now;
  });

  tearDown(() {
    ScannerControllerDebug.cameraFactory = null;
    ScannerControllerDebug.clock = null;
  });

  Future<void> open(WidgetTester tester) async {
    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const ScanPage()),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^Scanner template: ')));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(label));
    await settle(tester);
  }

  Future<void> push(WidgetTester tester, List<Barcode> barcodes) async {
    camera.push(barcodes);
    await tester.pump();
    await tester.pump();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  List<String> history() => <String>[
    for (final HistoryItem i in HistoryStore.instance.items) i.barcode.text,
  ];

  testWidgets('a template that faces the user turns the camera', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(camera.opened.last, CameraFacing.back);
    await pick(tester, 'Kiosk');
    expect(camera.opened.last, CameraFacing.front);
    await pick(tester, 'Minimal');
    expect(camera.opened.last, CameraFacing.back);
    await close(tester);
  });

  testWidgets('a second Done saves only the codes added since', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await pick(tester, 'Retail');
    final Barcode a = _code('5901234123457', format: BarcodeFormat.ean13);
    final Barcode b = _code('4006381333931', format: BarcodeFormat.ean13);
    await push(tester, <Barcode>[a]);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(history(), <String>[a.text]);
    now = now.add(const Duration(seconds: 2));
    await push(tester, <Barcode>[]);
    now = now.add(const Duration(seconds: 2));
    await push(tester, <Barcode>[b]);
    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(history(), <String>[b.text, a.text]);
    await close(tester);
  });

  testWidgets('check-in keeps only the codes it lets in', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await pick(tester, 'Event check-in');
    await push(tester, <Barcode>[_code('WIFI:S:Home;T:WPA;P:secret;;')]);
    await settle(tester);
    expect(find.text('Not a ticket'), findsOneWidget);
    expect(history(), isEmpty);
    await close(tester);
  });
}
