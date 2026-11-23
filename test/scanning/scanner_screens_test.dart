// The scanner screens as an app uses them: scanBarcode with a template of
// its own, a ScannerScope around the scanner, a scanner under another page,
// checks while collecting, the builders of the result sheet.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing/src/scanning/ui/pressable.dart';

import 'fake_camera.dart';

const Size _phone = Size(390, 844);

Barcode _barcode(
  String text, {
  Rect rect = const Rect.fromLTWH(150, 330, 90, 90),
}) => Barcode(
  format: BarcodeFormat.qrCode,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: BarcodePosition(
    topLeft: rect.topLeft,
    topRight: rect.topRight,
    bottomRight: rect.bottomRight,
    bottomLeft: rect.bottomLeft,
  ),
  symbologyIdentifier: ']Q1',
);

/// [child] on a 390 × 844 phone with a notch.
Widget _host(Widget child, {TextScaler textScaler = TextScaler.noScaling}) =>
    MediaQuery(
      data: MediaQueryData(
        size: _phone,
        padding: const EdgeInsets.only(top: 47, bottom: 34),
        viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
        textScaler: textScaler,
      ),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
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

  /// Lets timers and animations run for [ms] milliseconds.
  Future<void> wait(WidgetTester tester, int ms) async {
    for (int t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Codes of the next frame move on, so that distinct detection reports
  /// them again.
  void later() => now = now.add(const Duration(seconds: 3));

  group('scanBarcode', () {
    testWidgets('keeps the template: its mode, large hint and texts', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      Barcode? result;
      await tester.pumpWidget(
        _app(
          (BuildContext context) => GestureDetector(
            onTap: () async => result = await scanBarcode(
              context,
              template: const ScannerTemplate.pick().copyWith(
                largeHint: true,
                title: () => 'Pick one',
              ),
            ),
            child: const Text('scan'),
          ),
        ),
      );
      await tester.tap(find.text('scan'));
      await tester.pump();
      await wait(tester, 400);
      // The large hint of the template.
      expect(find.text('Pick one'), findsOneWidget);
      // Pick: a label on each of two codes, a tap on one returns it.
      await push(tester, <Barcode>[
        _barcode('first', rect: const Rect.fromLTWH(40, 300, 90, 90)),
        _barcode('second', rect: const Rect.fromLTWH(240, 300, 90, 90)),
      ]);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsOneWidget);
      await tester.tap(find.text('second'));
      await wait(tester, 1200);
      expect(result?.text, 'second');
    });

    testWidgets('a collecting template returns the first code', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      Barcode? result;
      await tester.pumpWidget(
        _app(
          (BuildContext context) => GestureDetector(
            onTap: () async => result = await scanBarcode(
              context,
              template: const ScannerTemplate.retail(),
              formats: const <BarcodeFormat>{BarcodeFormat.qrCode},
            ),
            child: const Text('scan'),
          ),
        ),
      );
      await tester.tap(find.text('scan'));
      await tester.pump();
      await wait(tester, 400);
      expect(find.byType(BarcodeListSheet), findsNothing);
      await push(tester, <Barcode>[_barcode('one')]);
      await wait(tester, 1200);
      expect(result?.text, 'one');
    });

    testWidgets('a check-in template shows no counter for one code', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _app(
          (BuildContext context) => GestureDetector(
            onTap: () => scanBarcode(
              context,
              template: ScannerTemplate.checkIn(
                check: (Barcode b) => const ScanVerdict.accept(title: 'In'),
              ),
            ),
            child: const Text('scan'),
          ),
        ),
      );
      await tester.tap(find.text('scan'));
      await tester.pump();
      await wait(tester, 400);
      expect(find.text('0 checked in'), findsNothing);
    });

    testWidgets('takes the theme and texts of the scope around the caller', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          (BuildContext context) => ScannerScope(
            theme: const ScannerTheme(accent: Color(0xFFFF6A1A)),
            strings: const ScannerStrings(close: 'Schließen'),
            child: Builder(
              builder: (BuildContext context) => GestureDetector(
                onTap: () => scanBarcode(context),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('scan'));
      await tester.pump();
      await wait(tester, 400);
      expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
      final ScannerTheme theme = ScannerTheme.of(
        tester.element(find.byType(ScannerCloseButton)),
      );
      expect(theme.accent, const Color(0xFFFF6A1A));
      semantics.dispose();
    });
  });

  group('collect with a check', () {
    testWidgets('a refused code stays out of the list, a flagged one is in', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.retail(
              formats: const <BarcodeFormat>{BarcodeFormat.qrCode},
              check: (Barcode b) => switch (b.text) {
                'bad' => const ScanVerdict.reject(title: 'Not ours'),
                'old' => const ScanVerdict.warn(
                  title: 'Seen',
                  message: 'Counted before',
                ),
                _ => null,
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('bad')]);
      await tester.pump();
      expect(find.text('Not ours'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
      later();
      await push(tester, <Barcode>[]);
      later();
      await push(tester, <Barcode>[_barcode('old')]);
      await tester.pump();
      expect(find.text('Seen · Counted before'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      later();
      await push(tester, <Barcode>[]);
      later();
      await push(tester, <Barcode>[_barcode('good')]);
      await tester.pump();
      expect(find.text('2 items'), findsOneWidget);
      await wait(tester, 3200);
    });
  });

  group('one code with a check', () {
    testWidgets('the sheet shows what the check said, its data goes to the '
        'buttons', (WidgetTester tester) async {
      await phone(tester);
      ScannerResult? shown;
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.minimal(
              formats: const <BarcodeFormat>{BarcodeFormat.qrCode},
              check: (Barcode b) async => const ScanVerdict.accept(
                title: 'Anna Petrova',
                message: '1240 points',
                data: 1240,
              ),
              actionsBuilder: (BuildContext context, ScannerResult result) {
                shown = result;
                return result.defaultActions;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('4006123456789012')]);
      await wait(tester, 600);
      expect(find.text('Anna Petrova'), findsOneWidget);
      expect(find.text('1240 points'), findsOneWidget);
      expect(shown?.verdict?.data, 1240);
      expect(shown?.verdict?.kind, ScanVerdictKind.accept);
    });

    testWidgets('without a check there is no verdict', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      ScannerResult? shown;
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.minimal(
              formats: const <BarcodeFormat>{BarcodeFormat.qrCode},
              actionsBuilder: (BuildContext context, ScannerResult result) {
                shown = result;
                return result.defaultActions;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('one')]);
      await wait(tester, 600);
      expect(shown, isNotNull);
      expect(shown?.verdict, isNull);
    });
  });

  group('stopped camera', () {
    testWidgets('does not say the camera is starting', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController();
      await tester.pumpWidget(_host(BarcodeScanner(controller: controller)));
      await tester.pump();
      expect(controller.value.status, ScannerStatus.running);
      await tester.runAsync(controller.stop);
      await tester.pump();
      expect(controller.value.status, ScannerStatus.idle);
      expect(find.byType(ScannerPlaceholder), findsOneWidget);
      expect(find.text('Starting the camera…'), findsNothing);
      // Started again: it says so while the camera opens.
      final Completer<void> opening = Completer<void>();
      camera.openGate = opening;
      unawaited(controller.start());
      await tester.pump();
      expect(find.text('Starting the camera…'), findsOneWidget);
      opening.complete();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    });

    testWidgets('a template does not say so either', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController(autoStart: false);
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            controller: controller,
            template: const ScannerTemplate.minimal(),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ScannerPlaceholder), findsOneWidget);
      expect(find.text('Starting the camera…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  group('ScannerScope around BarcodeScanner', () {
    testWidgets('scope, then the template, then the scanner own theme', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ScannerScope(
            theme: const ScannerTheme(
              accent: Color(0xFFFF6A1A),
              windowRadius: 6,
              brightness: Brightness.light,
            ),
            strings: const ScannerStrings(close: 'Schließen'),
            child: BarcodeScanner(
              // The template's theme is dark.
              template: ScannerTemplate.retail(onClose: () {}),
              theme: const ScannerTheme(windowRadius: 2),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Schließen'), findsOneWidget);
      final ScannerTheme theme = ScannerTheme.of(
        tester.element(find.byType(ScannerCloseButton)),
      );
      expect(theme.accent, const Color(0xFFFF6A1A));
      expect(theme.brightness, Brightness.dark);
      expect(theme.windowRadius, 2);
      semantics.dispose();
    });

    testWidgets('strings passed to the scanner win over the scope', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ScannerScope(
            strings: const ScannerStrings(close: 'Schließen'),
            child: BarcodeScanner(
              template: ScannerTemplate.minimal(onClose: () {}),
              strings: const ScannerStrings(close: 'Fermer'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Fermer'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('preset texts', () {
    test('come from the strings; an empty string hides them', () {
      const ScannerStrings de = ScannerStrings(
        titlePayment: 'Mit QR bezahlen',
        hintCode: 'Kamera auf einen Code richten',
      );
      expect(
        const ScannerTemplate.payment().resolveTitle(de),
        'Mit QR bezahlen',
      );
      expect(
        const ScannerTemplate.minimal().resolveHint(de),
        'Kamera auf einen Code richten',
      );
      expect(
        const ScannerTemplate.minimal().resolveHint(const ScannerStrings()),
        'Point the camera at a code',
      );
      // Set by the app: wins; empty: none.
      expect(
        const ScannerTemplate.payment(title: 'Pay').resolveTitle(de),
        'Pay',
      );
      expect(const ScannerTemplate.payment(title: '').resolveTitle(de), isNull);
      // Kept through copyWith, cleared back to the preset's with null.
      final ScannerTemplate copy = const ScannerTemplate.kiosk().copyWith(
        hint: () => 'Hier scannen',
      );
      expect(copy.resolveTitle(const ScannerStrings()), 'Scan your ticket');
      expect(copy.resolveHint(de), 'Hier scannen');
      expect(
        copy.copyWith(hint: () => null).resolveHint(const ScannerStrings()),
        'Hold the code up to the camera',
      );
      // The plain constructor has none.
      expect(const ScannerTemplate().resolveHint(de), isNull);
    });

    test('copyWith of the strings replaces some texts', () {
      final ScannerStrings strings = const ScannerStrings().copyWith(
        scanAgain: 'Next',
        itemCount: (int n) => '$n Stück',
      );
      expect(strings.scanAgain, 'Next');
      expect(strings.itemCount(3), '3 Stück');
      expect(strings.close, const ScannerStrings().close);
      expect(const ScannerStrings().copyWith(), const ScannerStrings());
    });

    testWidgets('the scanner shows them in the language of its strings', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(
            template: ScannerTemplate.payment(),
            strings: ScannerStrings(titlePayment: 'Mit QR bezahlen'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mit QR bezahlen'), findsOneWidget);
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(template: ScannerTemplate.payment(title: '')),
        ),
      );
      await tester.pump();
      expect(find.text('Pay with QR'), findsNothing);
      expect(find.byType(ScannerHint), findsNothing);
    });

    testWidgets('ScanFieldButton hints from the strings', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final TextEditingController field = TextEditingController();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _app(
          (BuildContext context) => ScannerScope(
            strings: const ScannerStrings(hintField: 'Code anvisieren'),
            child: Center(child: ScanFieldButton(controller: field)),
          ),
        ),
      );
      await tester.tap(find.byType(ScanFieldButton));
      await tester.pump();
      await wait(tester, 400);
      expect(find.text('Code anvisieren'), findsOneWidget);
    });

    testWidgets('a copy button: null label is "Copy", empty shows the icon', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ScannerActions(<ScannerAction>[
            ScannerAction.copy('a'),
            ScannerAction.copy('b', label: ''),
          ]),
        ),
      );
      expect(find.text('Copy'), findsOneWidget);
      // The second has its icon alone, and says what it does.
      expect(find.bySemanticsLabel('Copy'), findsNWidgets(2));
      semantics.dispose();
    });
  });

  group('result builders', () {
    testWidgets('get the capture, the cut-out and the default actions', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      ScannerResult? seen;
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.payment(
              resultBuilder: (BuildContext context, ScannerResult result) {
                seen = result;
                return const SizedBox(height: 120, width: 300);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      const String epc =
          'BCD\n002\n1\nSCT\n\nKaffeehaus Lumen\nDE89370400440532013000\n'
          'EUR4.80\n\n\nA7F3-21';
      await push(tester, <Barcode>[_barcode(epc)]);
      await wait(tester, 800);
      final ScannerResult result = seen!;
      expect(result.barcode.text, epc);
      expect(result.capture.barcodes.single.text, epc);
      expect(result.close, isNull);
      // The smart copy of the default sheet: the IBAN alone.
      expect(result.defaultActions, hasLength(2));
      expect(result.defaultActions.first.label, 'Copy IBAN');
      expect(result.defaultActions.last.label, 'Scan again');
      // A tap around the sheet scans again, with a builder of one's own.
      seen = null;
      await tester.tapAt(const Offset(195, 120));
      await wait(tester, 400);
      expect(seen, isNull);
      expect(
        tester
            .widget<BarcodeScanner>(find.byType(BarcodeScanner))
            .template!
            .resultBuilder,
        isNotNull,
      );
      await push(tester, <Barcode>[_barcode('next')]);
      await wait(tester, 800);
      expect(seen?.barcode.text, 'next');
    });

    testWidgets('in pick mode close goes back to the codes', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      ScannerResult? seen;
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.pick(
              resultBuilder: (BuildContext context, ScannerResult result) {
                seen = result;
                return const SizedBox(height: 120, width: 300);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[
        _barcode('first', rect: const Rect.fromLTWH(40, 300, 90, 90)),
        _barcode('second', rect: const Rect.fromLTWH(240, 300, 90, 90)),
      ]);
      await tester.tap(find.text('first'));
      await wait(tester, 800);
      expect(seen?.barcode.text, 'first');
      expect(seen?.close, isNotNull);
      expect(seen?.scanAgain, isNot(seen?.close));
    });
  });

  group('result header', () {
    testWidgets('icon, card and none', (WidgetTester tester) async {
      Future<void> sheet(ResultHeader header) => tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.bottomCenter,
            child: BarcodeResultSheet(
              _barcode('https://example.com'),
              header: header,
            ),
          ),
        ),
      );
      await sheet(ResultHeader.picture);
      expect(find.byType(BarcodeThumbnail), findsOneWidget);
      await sheet(ResultHeader.icon);
      expect(find.byType(BarcodeThumbnail), findsNothing);
      expect(find.byType(ScannerBadge), findsOneWidget);
      await sheet(ResultHeader.none);
      expect(find.byType(BarcodeThumbnail), findsNothing);
      expect(find.byType(ScannerBadge), findsNothing);
      await sheet(ResultHeader.card);
      expect(find.text('Card number'), findsOneWidget);
    });

    testWidgets('tones of a chip and a badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: <Widget>[
              ScannerChip('a'),
              ScannerChip('b', tone: ScannerTone.danger),
              ScannerBadge(icon: ScannerIcons.alert, tone: ScannerTone.warning),
            ],
          ),
        ),
      );
      final ScannerTheme theme = ScannerTheme.of(
        tester.element(find.text('a')),
      );
      Color colorOf(Finder f) =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: f,
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as ShapeDecoration)
              .color!;
      expect(colorOf(find.text('a')), theme.lockSoftColor);
      expect(colorOf(find.text('b')), theme.dangerColor.withValues(alpha: 0.2));
      expect(
        colorOf(find.byType(ScannerIcon)),
        theme.signalColor.withValues(alpha: 0.2),
      );
    });
  });

  test('a verdict names its kind as its constructor', () {
    expect(const ScanVerdict.accept().kind, ScanVerdictKind.accept);
    expect(const ScanVerdict.warn().kind, ScanVerdictKind.warn);
    expect(const ScanVerdict.reject().kind, ScanVerdictKind.reject);
    expect(
      const ScanVerdict.warn(title: 'T').toString(),
      'ScanVerdict.warn(T)',
    );
  });

  group('hidden scanner', () {
    testWidgets('pauses, lets the camera go and goes on when shown', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController();
      final List<String> found = <String>[];
      bool shown = true;
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              set = setState;
              return TickerMode(
                enabled: shown,
                child: BarcodeScanner(
                  controller: controller,
                  onDetect: (BarcodeCapture c) => found.add(c.barcode.text),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(controller.value.status, ScannerStatus.running);
      set(() => shown = false);
      await tester.pump();
      expect(controller.value.status, ScannerStatus.paused);
      await push(tester, <Barcode>[_barcode('unseen')]);
      expect(found, isEmpty);
      expect(camera.isOpen, isTrue);
      // A few seconds later the camera is released.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(controller.value.status, ScannerStatus.idle);
      expect(camera.isOpen, isFalse);
      set(() => shown = true);
      await tester.pump();
      await tester.pump();
      expect(controller.value.status, ScannerStatus.running);
      expect(camera.isOpen, isTrue);
      later();
      await push(tester, <Barcode>[_barcode('seen')]);
      expect(found, <String>['seen']);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    });

    testWidgets('a quick look elsewhere keeps the camera', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController();
      bool shown = true;
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              set = setState;
              return TickerMode(
                enabled: shown,
                child: BarcodeScanner(controller: controller),
              );
            },
          ),
        ),
      );
      await tester.pump();
      final int opens = camera.opened.length;
      set(() => shown = false);
      await tester.pump(const Duration(seconds: 1));
      set(() => shown = true);
      // Past the moment it would have been released; frames keep coming.
      for (int i = 0; i < 5; i++) {
        await push(tester, <Barcode>[]);
        await tester.pump(const Duration(milliseconds: 600));
      }
      expect(controller.value.status, ScannerStatus.running);
      expect(camera.opened.length, opens);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    });

    testWidgets('a paused scanner stays paused after it shows again', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController();
      bool shown = true;
      late StateSetter set;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              set = setState;
              return TickerMode(
                enabled: shown,
                child: BarcodeScanner(controller: controller),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await controller.pause();
      set(() => shown = false);
      for (int i = 0; i < 7; i++) {
        await push(tester, <Barcode>[]);
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pump();
      expect(camera.isOpen, isFalse);
      set(() => shown = true);
      await tester.pump();
      await tester.pump();
      expect(camera.isOpen, isTrue);
      expect(controller.value.status, ScannerStatus.paused);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    });

    testWidgets('a scanner hidden from the start does not open the camera', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const TickerMode(enabled: false, child: BarcodeScanner())),
      );
      await tester.pump();
      await tester.pump();
      expect(camera.isOpen, isFalse);
    });

    testWidgets('under another page it pauses; back on top it scans', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController();
      late BuildContext home;
      await tester.pumpWidget(
        _app((BuildContext context) {
          home = context;
          return BarcodeScanner(controller: controller);
        }),
      );
      await tester.pump();
      expect(controller.value.status, ScannerStatus.running);
      unawaited(
        Navigator.of(home).push(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> _,
                  Animation<double> _,
                ) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(controller.value.status, ScannerStatus.paused);
      await tester.pump(const Duration(seconds: 4));
      expect(camera.isOpen, isFalse);
      Navigator.of(home).pop();
      await tester.pump();
      await tester.pump();
      expect(controller.value.status, ScannerStatus.running);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    });

    testWidgets('pauseWhenHidden: false keeps scanning', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final ScannerController controller = ScannerController();
      await tester.pumpWidget(
        _host(
          TickerMode(
            enabled: false,
            child: BarcodeScanner(
              controller: controller,
              pauseWhenHidden: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 4));
      expect(controller.value.status, ScannerStatus.running);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async => controller.dispose());
    });
  });

  group('foregroundBuilder', () {
    testWidgets('lies over the template, in its theme, in every state', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final Completer<void> opening = Completer<void>();
      camera.openGate = opening;
      final List<ScannerStatus> states = <ScannerStatus>[];
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: const ScannerTemplate.retail(),
            foregroundBuilder: (BuildContext context, ScannerLayout layout) {
              states.add(layout.state.status);
              return Positioned(
                left: 0,
                top: 0,
                child: Text(
                  'mine',
                  style: TextStyle(color: ScannerTheme.of(context).inkColor),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text('mine'), findsOneWidget);
      expect(states.last, ScannerStatus.starting);
      opening.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('mine'), findsOneWidget);
      expect(states.last, ScannerStatus.running);
      // In the template's dark theme.
      expect(
        ScannerTheme.of(tester.element(find.text('mine'))).brightness,
        Brightness.dark,
      );
      // Over the template's overlay.
      final Offset mine = tester.getTopLeft(find.text('mine'));
      expect(
        tester.hitTestOnBinding(mine).path.first.target,
        tester.renderObject(find.text('mine')),
      );
    });
  });

  group('open settings', () {
    testWidgets('the template error card offers the settings', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      int opened = 0;
      camera.openError = const CameraPermissionException();
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.minimal(onOpenSettings: () => opened++),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Open Settings'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      expect(opened, 1);
    });

    testWidgets('the scanner own wins, also without a template', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      int opened = 0;
      camera.openError = const CameraPermissionException();
      await tester.pumpWidget(
        _host(BarcodeScanner(onOpenSettings: () => opened++)),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Open Settings'));
      expect(opened, 1);
    });
  });

  group('accessibility', () {
    testWidgets('a long title in large text is not cut', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.payment(
              title: 'Pay the invoice with QR',
              onClose: () {},
            ),
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      final Finder title = find.text('Pay the invoice with QR');
      final RenderParagraph paragraph = tester.renderObject(title);
      expect(paragraph.didExceedMaxLines, isFalse);
      final Rect hint = tester.getRect(
        find.ancestor(of: title, matching: find.byType(ScannerHint)),
      );
      // The text fits in its pill, which is taller than the bar.
      expect(paragraph.size.height, greaterThan(48));
      expect(hint.height, greaterThanOrEqualTo(paragraph.size.height));
    });

    testWidgets('tap targets are at least 48 × 48', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final TextEditingController field = TextEditingController();
      addTearDown(field.dispose);
      await tester.pumpWidget(
        _host(
          Stack(
            children: <Widget>[
              const BarcodeScanner(template: ScannerTemplate.small()),
              Align(
                alignment: Alignment.topLeft,
                child: ScanFieldButton(controller: field),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(ScanFieldButton),
            matching: find.byType(Pressable),
          ),
        ),
        const Size(48, 48),
      );
      final Finder zoom = find.descendant(
        of: find.byType(ZoomButtons),
        matching: find.byType(Pressable),
      );
      expect(zoom, findsWidgets);
      for (final Element e in zoom.evaluate()) {
        final Size size = e.size!;
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      // The close of a sheet that does not scan again by itself.
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.bottomCenter,
            child: BarcodeResultSheet(
              _barcode('x'),
              actions: const <ScannerAction>[ScannerAction.copy('x')],
              onScanAgain: () {},
            ),
          ),
        ),
      );
      final Finder close = find.byWidgetPredicate(
        (Widget w) => w is Pressable && w.shape is CircleBorder,
      );
      expect(tester.getSize(close), const Size(48, 48));
    });

    testWidgets('a list row follows the text direction', (
      WidgetTester tester,
    ) async {
      Future<Rect> row(TextDirection direction) async {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(size: _phone),
            child: Directionality(
              textDirection: direction,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BarcodeListSheet(
                  items: <CollectedBarcode>[
                    CollectedBarcode(_barcode('one'), 1),
                  ],
                ),
              ),
            ),
          ),
        );
        return tester.getRect(find.byType(BarcodeThumbnail));
      }

      final Rect ltr = await row(TextDirection.ltr);
      final Rect rtl = await row(TextDirection.rtl);
      // Mirrored: the same gap to the start edge.
      final Rect sheet = tester.getRect(find.byType(BarcodeListSheet));
      expect(sheet.right - rtl.right, moreOrLessEquals(ltr.left - sheet.left));
    });
  });
}
