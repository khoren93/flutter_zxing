// What the use cases need from the scanner: a value back from the result
// sheet (openScanner, ScannerResult.finish), one kind of content
// (scanContent, acceptOnly), the default sheet from a resultBuilder, one
// filled button, a way out of a kiosk, and the check's verdict on
// collected codes.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import 'fake_camera.dart';

const Size _phone = Size(390, 844);

Barcode _barcode(String text) => Barcode(
  format: BarcodeFormat.qrCode,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: const BarcodePosition(
    topLeft: Offset(150, 330),
    topRight: Offset(240, 330),
    bottomRight: Offset(240, 420),
    bottomLeft: Offset(150, 420),
  ),
  symbologyIdentifier: ']Q1',
);

/// An app whose routes have no transitions.
Widget _app(WidgetBuilder home) => WidgetsApp(
  color: const Color(0xFF000000),
  pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
      PageRouteBuilder<T>(
        settings: settings,
        pageBuilder:
            (BuildContext context, Animation<double> _, Animation<double> _) =>
                builder(context),
      ),
  home: Builder(builder: home),
);

/// [child] on a 390 × 844 phone.
Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: _phone),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

const String _wifi = 'WIFI:T:WPA;S:Cafe;P:secret123;;';

void main() {
  late FakeCamera camera;
  DateTime now = DateTime(2026);

  setUp(() {
    camera = FakeCamera(transform: const FrameTransform(_phone));
    ScannerControllerDebug.cameraFactory = () => camera;
    ScannerControllerDebug.clock = () => now;
  });

  tearDown(() {
    ScannerControllerDebug.cameraFactory = null;
    ScannerControllerDebug.clock = null;
  });

  Future<void> phone(WidgetTester tester) async {
    tester.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> push(WidgetTester tester, List<Barcode> barcodes) async {
    camera.push(barcodes);
    await tester.pump();
    await tester.pump();
  }

  Future<void> wait(WidgetTester tester, int ms) async {
    for (int t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void later() => now = now.add(const Duration(seconds: 3));

  Future<void> open(
    WidgetTester tester,
    VoidCallback Function(BuildContext) onTap,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      _app(
        (BuildContext context) =>
            GestureDetector(onTap: onTap(context), child: const Text('open')),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await wait(tester, 400);
  }

  testWidgets('openScanner returns what the sheet finishes with', (
    WidgetTester tester,
  ) async {
    final Completer<int?> returned = Completer<int?>();
    await open(
      tester,
      (BuildContext context) =>
          () => returned.complete(
            openScanner<int>(
              context,
              template: ScannerTemplate.minimal(
                check: (Barcode b) =>
                    const ScanVerdict.accept(title: 'Anna', data: 1240),
                actionsBuilder: (BuildContext context, ScannerResult result) =>
                    <ScannerAction>[
                      ScannerAction(
                        label: 'Attach',
                        primary: true,
                        onPressed: () => result.finish(result.verdict?.data),
                      ),
                      ScannerAction.scanAgain(result.scanAgain),
                    ],
              ),
            ),
          ),
    );
    await push(tester, <Barcode>[_barcode('4006123456789012')]);
    await wait(tester, 800);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
    await tester.tap(find.text('Attach'));
    await wait(tester, 800);
    expect(await returned.future, 1240);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('scanContent refuses other content and returns its kind', (
    WidgetTester tester,
  ) async {
    final Completer<WifiContent?> returned = Completer<WifiContent?>();
    await open(
      tester,
      (BuildContext context) =>
          () => returned.complete(
            scanContent<WifiContent>(
              context,
              reject: const ScanVerdict.reject(title: 'Not a Wi‑Fi code'),
            ),
          ),
    );
    await push(tester, <Barcode>[_barcode('hello')]);
    await wait(tester, 300);
    expect(find.text('Not a Wi‑Fi code'), findsOneWidget);
    // Still scanning.
    expect(find.text('open'), findsNothing);
    later();
    await push(tester, <Barcode>[_barcode(_wifi)]);
    await wait(tester, 1200);
    final WifiContent? wifi = await returned.future;
    expect(wifi?.ssid, 'Cafe');
    expect(wifi?.password, 'secret123');
  });

  testWidgets('acceptOnly refuses with the default text', (
    WidgetTester tester,
  ) async {
    final ScannerCheck check = acceptOnly<WifiContent>();
    expect(check(_barcode(_wifi)), isNull);
    expect(check(_barcode('hello')), const ScanVerdict.reject());
  });

  testWidgets('a sheet fills only its first primary button', (
    WidgetTester tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      _host(
        BarcodeScanner(
          template: ScannerTemplate.minimal(
            actionsBuilder: (BuildContext context, ScannerResult result) =>
                <ScannerAction>[
                  ScannerAction(label: 'Pay', primary: true, onPressed: () {}),
                  ...result.defaultActions,
                ],
          ),
        ),
      ),
    );
    await tester.pump();
    await push(tester, <Barcode>[_barcode('hello')]);
    await wait(tester, 800);
    final List<ScannerActionButton> buttons = tester
        .widgetList<ScannerActionButton>(find.byType(ScannerActionButton))
        .toList();
    expect(buttons.map((ScannerActionButton b) => b.label), contains('Pay'));
    expect(
      buttons
          .where((ScannerActionButton b) => b.primary)
          .map((ScannerActionButton b) => b.label),
      <String>['Pay'],
    );
  });

  testWidgets('a resultBuilder returns null for the default sheet', (
    WidgetTester tester,
  ) async {
    await phone(tester);
    await tester.pumpWidget(
      _host(
        BarcodeScanner(
          template: ScannerTemplate.minimal(
            resultBuilder: (BuildContext context, ScannerResult result) =>
                result.barcode.text == 'mine' ? const Text('My sheet') : null,
          ),
        ),
      ),
    );
    await tester.pump();
    await push(tester, <Barcode>[_barcode('other')]);
    await wait(tester, 800);
    expect(find.byType(BarcodeResultSheet), findsOneWidget);
    expect(find.text('My sheet'), findsNothing);
  });

  testWidgets('a long press in the corner leaves a kiosk', (
    WidgetTester tester,
  ) async {
    final Completer<Object?> returned = Completer<Object?>();
    await open(
      tester,
      (BuildContext context) =>
          () => returned.complete(
            openScanner<Object>(
              context,
              template: const ScannerTemplate.kiosk(hiddenExit: true),
            ),
          ),
    );
    final TestGesture press = await tester.startGesture(const Offset(20, 20));
    await wait(tester, 1000);
    expect(find.text('open'), findsNothing);
    await wait(tester, 1200);
    await press.up();
    await wait(tester, 400);
    expect(find.text('open'), findsOneWidget);
    expect(await returned.future, isNull);
  });

  testWidgets('collected codes keep what the check found', (
    WidgetTester tester,
  ) async {
    await phone(tester);
    List<CollectedBarcode>? done;
    await tester.pumpWidget(
      _host(
        BarcodeScanner(
          template: ScannerTemplate.retail(
            formats: const <BarcodeFormat>{BarcodeFormat.qrCode},
            check: (Barcode b) => ScanVerdict.accept(data: 'item ${b.text}'),
            onDone: (List<CollectedBarcode> items) => done = items,
          ),
        ),
      ),
    );
    await tester.pump();
    await push(tester, <Barcode>[_barcode('one')]);
    await wait(tester, 400);
    await tester.tap(find.text('Done'));
    await wait(tester, 400);
    expect(done?.single.verdict?.data, 'item one');
  });
}
