// The scanner's themed widgets and templates on a fake camera: theme
// colors, icons, the scan window, the template screens and their states,
// result sheets for every kind of content.
import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing/src/scanning/ui/scanner_icons.dart' show svgPath;
import 'package:flutter_zxing/src/scanning/ui/window_overlay.dart'
    show WindowScrim;

import 'fake_camera.dart';

const Size _phone = Size(390, 844);

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

Barcode _barcode(
  String text, {
  BarcodeFormat format = BarcodeFormat.qrCode,
  Rect rect = const Rect.fromLTWH(150, 330, 90, 90),
  String id = ']Q1',
  Uint8List? bytes,
  BarcodeContentType type = BarcodeContentType.text,
}) => Barcode(
  format: format,
  text: text,
  bytes: bytes ?? Uint8List.fromList(utf8.encode(text)),
  position: BarcodePosition(
    topLeft: rect.topLeft,
    topRight: rect.topRight,
    bottomRight: rect.bottomRight,
    bottomLeft: rect.bottomLeft,
  ),
  symbologyIdentifier: id,
  contentType: type,
);

/// [child] on a 390 × 844 phone with a notch.
Widget _host(Widget child, {bool reduceMotion = false}) => MediaQuery(
  data: MediaQueryData(
    size: _phone,
    padding: const EdgeInsets.only(top: 47, bottom: 34),
    viewPadding: const EdgeInsets.only(top: 47, bottom: 34),
    disableAnimations: reduceMotion,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  group('ScannerTheme', () {
    test('merges non-null fields', () {
      const ScannerTheme base = ScannerTheme(
        brightness: Brightness.dark,
        windowRadius: 12,
      );
      final ScannerTheme merged = base.merge(
        const ScannerTheme(accent: Color(0xFFFF6A1A)),
      );
      expect(merged.brightness, Brightness.dark);
      expect(merged.windowRadius, 12);
      expect(merged.accent, const Color(0xFFFF6A1A));
      expect(base.merge(null), same(base));
    });

    test('derives readable accent colors for any accent', () {
      const List<Color> accents = <Color>[
        ScannerTheme.defaultAccent,
        Color(0xFFFF6A1A),
        Color(0xFF4D8DFF),
        Color(0xFFFFEB3B),
        Color(0xFF0B3D91),
        Color(0xFF000000),
        Color(0xFFFFFFFF),
      ];
      for (final Color accent in accents) {
        final ScannerTheme light = ScannerTheme(
          accent: accent,
          brightness: Brightness.light,
        );
        final ScannerTheme dark = ScannerTheme(
          accent: accent,
          brightness: Brightness.dark,
        );
        expect(
          _contrast(light.lockInkColor, const Color(0xFFF4F6F9)),
          greaterThanOrEqualTo(4.5),
          reason: '$accent on light glass',
        );
        expect(
          _contrast(dark.lockInkColor, const Color(0xFF101318)),
          greaterThanOrEqualTo(4.5),
          reason: '$accent on dark glass',
        );
        expect(
          _contrast(light.onLockColor, accent),
          greaterThanOrEqualTo(3),
          reason: 'text on $accent',
        );
      }
      // Bright accents get dark text, deep ones white.
      expect(
        const ScannerTheme(
          accent: Color(0xFF2EE6B5),
        ).onLockColor.computeLuminance(),
        lessThan(0.05),
      );
      expect(
        const ScannerTheme(accent: Color(0xFF0B3D91)).onLockColor,
        const Color(0xFFFFFFFF),
      );
    });

    test('status colors: defaults, own colors and text on them', () {
      const ScannerTheme theme = ScannerTheme(brightness: Brightness.light);
      expect(theme.warningColor, theme.signalColor);
      expect(theme.dangerColor, const Color(0xFFFF4D42));
      const ScannerTheme own = ScannerTheme(
        warning: Color(0xFFFFEB3B),
        danger: Color(0xFF8B0000),
        brightness: Brightness.dark,
      );
      expect(own.warningColor, const Color(0xFFFFEB3B));
      expect(_contrast(own.onWarningColor, own.warningColor), greaterThan(4.5));
      expect(_contrast(own.onDangerColor, own.dangerColor), greaterThan(4.5));
      expect(
        _contrast(own.dangerInkColor, const Color(0xFF101318)),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        const ScannerTheme(
          danger: Color(0xFF8B0000),
        ).merge(const ScannerTheme(warning: Color(0xFF00FF00))),
        const ScannerTheme(
          danger: Color(0xFF8B0000),
          warning: Color(0xFF00FF00),
        ),
      );
    });

    test('blur off makes the glass more opaque', () {
      expect(
        const ScannerTheme(blur: false).glassColor.a,
        greaterThan(const ScannerTheme().glassColor.a),
      );
      expect(const ScannerTheme(blur: false).glassFilter, isNull);
      expect(const ScannerTheme().glassFilter, isNotNull);
    });
  });

  group('icons', () {
    test('every icon parses and stays in its 24 x 24 box', () {
      const List<ScannerIconData> icons = <ScannerIconData>[
        ScannerIcons.close,
        ScannerIcons.torchOff,
        ScannerIcons.torchOn,
        ScannerIcons.photo,
        ScannerIcons.switchCamera,
        ScannerIcons.qrCode,
        ScannerIcons.barcode,
        ScannerIcons.open,
        ScannerIcons.copy,
        ScannerIcons.check,
        ScannerIcons.wifi,
        ScannerIcons.link,
        ScannerIcons.contact,
        ScannerIcons.event,
        ScannerIcons.email,
        ScannerIcons.phone,
        ScannerIcons.sms,
        ScannerIcons.location,
        ScannerIcons.parcel,
        ScannerIcons.text,
        ScannerIcons.binary,
        ScannerIcons.cameraOff,
        ScannerIcons.cameraAlert,
        ScannerIcons.payment,
        ScannerIcons.otp,
        ScannerIcons.esim,
        ScannerIcons.crypto,
        ScannerIcons.wifiDevice,
        ScannerIcons.smartHome,
        ScannerIcons.boardingPass,
        ScannerIcons.driverLicense,
        ScannerIcons.vehicle,
        ScannerIcons.book,
        ScannerIcons.faceTime,
        ScannerIcons.messenger,
        ScannerIcons.profile,
        ScannerIcons.video,
        ScannerIcons.music,
        ScannerIcons.apps,
        ScannerIcons.review,
        ScannerIcons.show,
        ScannerIcons.hide,
        ScannerIcons.add,
        ScannerIcons.alert,
        ScannerIcons.person,
        ScannerIcons.closer,
        ScannerIcons.card,
        ScannerIcons.scan,
      ];
      for (final ScannerIconData icon in icons) {
        for (final String data in <String>[icon.stroke, icon.fill]) {
          if (data.isEmpty) {
            continue;
          }
          final Rect bounds = svgPath(data).getBounds();
          expect(
            const Rect.fromLTWH(
                  0,
                  0,
                  24,
                  24,
                ).inflate(0.01).contains(bounds.topLeft) &&
                const Rect.fromLTWH(
                  0,
                  0,
                  24,
                  24,
                ).inflate(0.01).contains(bounds.bottomRight),
            isTrue,
            reason: '$data: $bounds',
          );
        }
      }
    });

    test('arcs, relative commands and implicit line-tos', () {
      expect(
        svgPath('M2 2h10v10H2z').getBounds(),
        const Rect.fromLTRB(2, 2, 12, 12),
      );
      expect(
        svgPath('M2 2 12 2 12 12').getBounds(),
        const Rect.fromLTRB(2, 2, 12, 12),
      );
      // A half circle of radius 5 from (0, 5) to (10, 5) over the top.
      final Rect arc = svgPath('M0 5a5 5 0 0 1 10 0').getBounds();
      expect(arc.top, closeTo(0, 1e-6));
      expect(arc.bottom, closeTo(5, 1e-6));
      expect(() => svgPath('M0 0T1 1'), throwsFormatException);
    });

    test('minified arcs and malformed data (found in review)', () {
      // SVGO packs the arc flags: "0110 0" is flags 0 and 1, then 10 0.
      final Rect arc = svgPath('M0 5a5 5 0 0110 0').getBounds();
      expect(arc.right, closeTo(10, 1e-6));
      expect(arc.top, closeTo(0, 1e-6));
      // Numbers after Z used to loop forever.
      expect(() => svgPath('M0 0h4v4z 1 1'), throwsFormatException);
      expect(() => svgPath('5 5'), throwsFormatException);
      expect(() => svgPath('M0 0a5 5 0 2 1 10 0'), throwsFormatException);
    });
  });

  group('ScanWindow.centered', () {
    test('alignment moves the window', () {
      const ScanWindow high = ScanWindow.centered(
        alignment: Alignment.topCenter,
      );
      expect(high.resolve(_phone), const Rect.fromLTWH(58.5, 0, 273, 273));
      expect(
        const ScanWindow.centered().resolve(_phone),
        const Rect.fromLTWH(58.5, 285.5, 273, 273),
      );
    });

    test('landscape keeps the same margin on the short side', () {
      final Rect window = const ScanWindow.centered().resolve(
        const Size(844, 390),
      );
      expect(window.height, closeTo(273, 1e-9));
      expect(window.width, closeTo(273, 1e-9));
      expect(window.center, const Offset(422, 195));
      final Rect wide = const ScanWindow.centered(
        width: 0.9,
        aspectRatio: 3,
      ).resolve(const Size(844, 390));
      expect(wide.width, closeTo(759.6, 1e-9));
    });
  });

  group('templates on a fake camera', () {
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

    testWidgets('minimal: buttons, hint and their labels', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          BarcodeScanner(template: ScannerTemplate.minimal(onClose: () {})),
        ),
      );
      await tester.pump();
      expect(find.text('Point the camera at a code'), findsOneWidget);
      expect(find.bySemanticsLabel('Close the scanner'), findsOneWidget);
      expect(find.bySemanticsLabel('Turn on the torch'), findsOneWidget);
      expect(find.bySemanticsLabel('Read a code from a photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Switch camera'), findsOneWidget);
      expect(find.text('1×'), findsOneWidget);
      expect(find.text('2×'), findsOneWidget);
      expect(find.text('4×'), findsOneWidget);
      // Every button is at least 44 × 44.
      for (final Element button in find.byType(ScannerButton).evaluate()) {
        final Size size = tester.getSize(find.byWidget(button.widget));
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      semantics.dispose();
    });

    testWidgets('no close button without a way to close', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      expect(find.byType(ScannerCloseButton), findsNothing);
    });

    testWidgets('the torch and zoom buttons drive the camera', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Turn on the torch'));
      await tester.pump();
      expect(camera.torch, isTrue);
      expect(find.bySemanticsLabel('Turn off the torch'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Turn off the torch')),
        matchesSemantics(
          label: 'Turn off the torch',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasToggledState: true,
          isToggled: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );

      await tester.tap(find.text('2×'));
      await tester.pump();
      expect(camera.zoom, 2);
      // A pinched zoom between presets shows the actual factor.
      await tester.runAsync(() async {});
      final ScannerController controller =
          tester
              .state<State<BarcodeScanner>>(find.byType(BarcodeScanner))
              .widget
              .controller ??
          _findController(tester);
      await controller.setZoom(2.6);
      await tester.pump();
      expect(find.text('2.6×'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a code locks, pauses and shows its sheet; scan again', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final List<BarcodeCapture> captures = <BarcodeCapture>[];
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: const ScannerTemplate.minimal(),
            onDetect: captures.add,
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('https://pub.dev/packages/x')]);
      expect(captures, hasLength(1));
      final ScannerController controller = _findController(tester);
      expect(controller.value.status, ScannerStatus.paused);
      // The sheet waits for the brackets to land.
      expect(find.byType(BarcodeResultSheet), findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      expect(find.text('LINK'), findsOneWidget);
      expect(find.text('pub.dev'), findsOneWidget);
      expect(find.text('QR Code'), findsOneWidget);
      // The hint and the bottom buttons give way to the sheet.
      expect(
        tester
            .widget<AnimatedOpacity>(
              find
                  .ancestor(
                    of: find.byType(PickImageButton),
                    matching: find.byType(AnimatedOpacity),
                  )
                  .first,
            )
            .opacity,
        0,
      );

      await tester.tap(find.text('Scan again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BarcodeResultSheet), findsNothing);
      expect(controller.value.status, ScannerStatus.running);
    });

    testWidgets('a tap on the camera around the result scans again', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.minimal(
              actionsBuilder: (_, Barcode b, _) => <ScannerAction>[
                ScannerAction(label: 'Open', primary: true, onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('https://pub.dev/packages/x')]);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BarcodeResultSheet), findsNothing);
      expect(_findController(tester).value.status, ScannerStatus.running);
    });

    testWidgets('the code found is cut out and flies into the window', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      // A grey frame with a white square where the code is.
      final Uint8List gray = Uint8List(390 * 844)..fillRange(0, 390 * 844, 80);
      for (int y = 360; y < 440; y++) {
        gray.fillRange(y * 390 + 240, y * 390 + 320, 230);
      }
      camera.push(
        <Barcode>[_barcode('fly', rect: const Rect.fromLTWH(250, 370, 60, 60))],
        null,
        false,
        PixelBuffer(gray, width: 390, height: 844),
      );
      await tester.pump();
      await tester.pump();
      // The cut-out is made off the test clock.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      // The flight starts on the next frame and takes 360 ms.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 400));
      // The card in the window (the sheet's picture is the same cut-out).
      final Finder cutOut = find.byWidgetPredicate(
        (Widget w) => w is RawImage && w.fit == BoxFit.fill,
      );
      expect(cutOut, findsOneWidget);
      expect(find.byType(BarcodeThumbnail), findsOneWidget);
      final ScannerLayout layout = ScannerLayout(
        size: _phone,
        scanWindow: const ScannerTemplate.minimal().scanWindow.resolve(_phone),
        barcodes: const <VisibleBarcode>[],
        state: const ScannerState(),
        controller: _findController(tester),
      );
      // Settled in the middle of the window, inside it.
      final Rect rect = tester.getRect(cutOut);
      expect(layout.scanWindow.contains(rect.center), isTrue);
      expect((rect.center - layout.scanWindow.center).distance, lessThan(2));
      expect(rect.width, greaterThan(layout.scanWindow.width * 0.6));
      // The brackets frame the window; the outline is gone.
      expect(
        tester
            .widget<ScanWindowOverlay>(find.byType(ScanWindowOverlay))
            .settled,
        isTrue,
      );
      expect(find.byType(BarcodeOutlines), findsNothing);
      // A dark plate covers the whole window, edge to edge (no ring of
      // bright camera between it and the scrim), under the brackets.
      final Finder plate = find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).color?.toARGB32() ==
                const Color(0xFF06090D).withValues(alpha: 0.82).toARGB32(),
      );
      expect(plate, findsOneWidget);
      expect(tester.getRect(plate), layout.scanWindow);
      final List<Element> order = find
          .byWidgetPredicate(
            (Widget w) => w == tester.widget(plate) || w is ScannerOverlay,
          )
          .evaluate()
          .toList();
      expect(order.first.widget, tester.widget(plate));

      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Scan again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(RawImage), findsNothing);
      expect(
        tester
            .widget<ScanWindowOverlay>(find.byType(ScanWindowOverlay))
            .settled,
        isFalse,
      );
    });

    testWidgets('without a cut-out (the web) the brackets stay on the code', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('no pixels')]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(BarcodeOutlines), findsOneWidget);
    });

    testWidgets('custom actions and result sheets', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      int opened = 0;
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.content(
              actionsBuilder:
                  (BuildContext context, Barcode barcode, VoidCallback again) =>
                      <ScannerAction>[
                        ScannerAction(
                          label: 'Connect',
                          primary: true,
                          onPressed: () => opened++,
                        ),
                        ScannerAction.copy(barcode.text),
                      ],
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[
        _barcode('WIFI:S:Lumen Guest;T:WPA;P:espresso;;'),
      ]);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('WI‑FI NETWORK'), findsOneWidget);
      expect(find.text('Lumen Guest'), findsOneWidget);
      expect(find.text('WPA · password in the code'), findsOneWidget);
      expect(find.byType(ScannerBadge), findsOneWidget);
      await tester.tap(find.text('Connect'));
      expect(opened, 1);

      // The content template's theme is dark.
      final BuildContext sheet = tester.element(find.byType(ScannerSheet));
      expect(ScannerTheme.of(sheet).isDark, isTrue);
    });

    testWidgets('retail collects codes with counts', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      List<CollectedBarcode>? done;
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.retail(
              title: 'Shelf B-12',
              onDone: (List<CollectedBarcode> items) => done = items,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Shelf B-12'), findsOneWidget);
      expect(find.text('0 items'), findsOneWidget);
      expect(find.text('Codes you scan appear here'), findsOneWidget);

      final Barcode a = _barcode(
        '5901234123457',
        format: BarcodeFormat.ean13,
        id: ']E0',
      );
      final Barcode b = _barcode(
        '4006381333931',
        format: BarcodeFormat.ean13,
        id: ']E0',
        rect: const Rect.fromLTWH(220, 160, 120, 60),
      );
      await push(tester, <Barcode>[a, b]);
      expect(find.text('2 items'), findsOneWidget);
      // Scanned again after it was out of view for a while.
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[]);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[a]);
      expect(find.text('3 items'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // The latest is listed first.
      expect(
        tester.getTopLeft(find.text('5901234123457')).dy,
        lessThan(tester.getTopLeft(find.text('4006381333931')).dy),
      );
      // No hint and no lock in this template: brackets stay on the window.
      expect(find.byType(ScannerHint), findsOneWidget); // the title only

      await tester.tap(find.text('Done'));
      expect(done!.map((CollectedBarcode i) => i.count), <int>[2, 1]);
    });

    testWidgets('the theme merges onto the template theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(
            template: ScannerTemplate.retail(),
            theme: ScannerTheme(accent: Color(0xFFFF6A1A)),
          ),
        ),
      );
      await tester.pump();
      final ScannerTheme theme = ScannerTheme.of(
        tester.element(find.byType(BarcodeListSheet)),
      );
      expect(theme.isDark, isTrue);
      expect(theme.lockColor, const Color(0xFFFF6A1A));
    });

    testWidgets('the camera around the window is blurred, unless turned off', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      Finder scrimBlur() => find.descendant(
        of: find.byType(WindowScrim),
        matching: find.byType(BackdropFilter),
      );
      expect(scrimBlur(), findsOneWidget);
      final ClipPath clip = tester.widget(
        find.descendant(
          of: find.byType(WindowScrim),
          matching: find.byType(ClipPath),
        ),
      );
      final Path path = clip.clipper!.getClip(_phone);
      final Rect window = const ScannerTemplate.minimal().scanWindow.resolve(
        _phone,
      );
      expect(path.contains(window.center), isFalse);
      expect(path.contains(const Offset(10, 10)), isTrue);
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(
            template: ScannerTemplate.minimal(),
            theme: ScannerTheme(scrimBlur: false),
          ),
        ),
      );
      await tester.pump();
      expect(scrimBlur(), findsNothing);
    });

    testWidgets('a template configures the scanner own controller', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.retail())),
      );
      await tester.pump();
      final ScannerController controller = _findController(tester);
      expect(controller.maxBarcodes, isNull);
      expect(controller.detection, DetectionMode.distinct);
      expect(controller.formats, contains(BarcodeFormat.eanUpc));
      expect(controller.scanWindow, const ScannerTemplate.retail().scanWindow);

      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.payment())),
      );
      expect(identical(_findController(tester), controller), isTrue);
      expect(controller.maxBarcodes, 1);
      expect(controller.detection, DetectionMode.once);
      expect(controller.formats, <BarcodeFormat>{BarcodeFormat.qrCode});
    });

    testWidgets('sound: a click when a code locks, none by default', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      Iterable<MethodCall> sounds() =>
          calls.where((MethodCall c) => c.method == 'SystemSound.play');

      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('quiet')]);
      expect(sounds(), isEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(template: ScannerTemplate.minimal(sound: true)),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('loud')]);
      expect(sounds().single.arguments, 'SystemSoundType.click');
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('while starting: the window breathes, then the camera', (
      WidgetTester tester,
    ) async {
      final ScannerController controller = ScannerController(autoStart: false);
      addTearDown(controller.dispose);
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
      expect(find.text('Starting the camera…'), findsOneWidget);
      await controller.start();
      await tester.pump();
      expect(find.byType(ScannerPlaceholder), findsNothing);
      expect(find.byType(ScannerOverlay), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await controller.stop();
    });

    testWidgets('errors: a card with a retry and the close button', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      camera.openError = const CameraPermissionException();
      await tester.pumpWidget(
        _host(
          BarcodeScanner(template: ScannerTemplate.minimal(onClose: () {})),
        ),
      );
      await tester.pump();
      expect(find.text('Camera access is off'), findsOneWidget);
      expect(find.text('Choose a photo'), findsOneWidget);
      expect(find.byType(ScannerCloseButton), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      expect(camera.opened, hasLength(2));
      expect(find.text('Camera access is off'), findsNothing);
    });

    testWidgets('a missing camera without a template', (
      WidgetTester tester,
    ) async {
      camera.openError = const CameraNotFoundException();
      await tester.pumpWidget(_host(const BarcodeScanner()));
      await tester.pump();
      expect(find.text("The camera isn't available"), findsOneWidget);
      expect(find.text('Choose a photo'), findsNothing);
    });

    testWidgets('strings replace every text', (WidgetTester tester) async {
      camera.openError = const CameraPermissionException();
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(
            template: ScannerTemplate.retail(),
            strings: ScannerStrings(
              permissionTitle: 'Kamera aus',
              tryAgain: 'Nochmal',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Kamera aus'), findsOneWidget);
      expect(find.text('Nochmal'), findsOneWidget);
    });

    testWidgets('reduce motion: nothing keeps animating', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BarcodeScanner(template: ScannerTemplate.minimal()),
          reduceMotion: true,
        ),
      );
      await tester.pump();
      // Would time out with the breathing brackets.
      await tester.pumpAndSettle();
      expect(find.byType(ScanWindowOverlay), findsOneWidget);
    });

    testWidgets('scanBarcode returns the code after the lock', (
      WidgetTester tester,
    ) async {
      Barcode? result;
      bool returned = false;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          pageRouteBuilder:
              <T>(RouteSettings settings, WidgetBuilder builder) =>
                  PageRouteBuilder<T>(
                    settings: settings,
                    pageBuilder:
                        (
                          BuildContext context,
                          Animation<double> _,
                          Animation<double> _,
                        ) => builder(context),
                  ),
          home: Builder(
            builder: (BuildContext context) => GestureDetector(
              onTap: () async {
                result = await scanBarcode(context, hint: 'Find the QR');
                returned = true;
              },
              child: const Text('scan'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Find the QR'), findsOneWidget);
      // A page that can be popped has a close button.
      expect(find.byType(ScannerCloseButton), findsOneWidget);
      await push(tester, <Barcode>[_barcode('hello')]);
      // No sheet: the brackets lock and the page closes.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BarcodeResultSheet), findsNothing);
      expect(returned, isTrue);
      expect(result!.text, 'hello');
      expect(camera.isOpen, isFalse);
    });
  });

  group('stage 11 templates on a fake camera', () {
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

    Future<void> phone(WidgetTester tester, [Size size = _phone]) async {
      tester.view
        ..physicalSize = size
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

    Widget app(Widget Function(BuildContext context) home) => WidgetsApp(
      color: const Color(0xFF000000),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
            settings: settings,
            pageBuilder:
                (
                  BuildContext context,
                  Animation<double> _,
                  Animation<double> _,
                ) => builder(context),
          ),
      home: Builder(builder: home),
    );

    test('presets configure detection, formats and the camera', () {
      final ScannerTemplate checkIn = ScannerTemplate.checkIn(
        check: (Barcode b) => null,
      );
      expect(checkIn.mode, ScannerMode.continuous);
      expect(checkIn.detection, DetectionMode.distinct);
      expect(checkIn.maxBarcodes, 1);
      expect(checkIn.counter, isTrue);
      expect(const ScannerTemplate.pick().maxBarcodes, isNull);
      expect(const ScannerTemplate.logistics().mode, ScannerMode.collect);
      expect(const ScannerTemplate.kiosk().facing, CameraFacing.front);
      expect(const ScannerTemplate.kiosk().largeHint, isTrue);
      expect(const ScannerTemplate.small().initialZoom, 2);
      expect(const ScannerTemplate.signIn().closeOnResult, isTrue);
      expect(const ScannerTemplate.loyalty().resultAsCard, isTrue);
      expect(const ScannerTemplate.minimal().detection, DetectionMode.once);
      expect(
        ScannerTemplate.minimal(check: (Barcode b) => null).detection,
        DetectionMode.distinct,
      );
      final ScannerTemplate copy = const ScannerTemplate.minimal().copyWith(
        mode: ScannerMode.pick,
        initialZoom: 3,
      );
      expect(copy.mode, ScannerMode.pick);
      expect(copy.initialZoom, 3);
    });

    testWidgets('small starts zoomed in, kiosk on the front camera', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.small())),
      );
      await tester.pump();
      await tester.pump();
      expect(camera.zoom, 2);
      expect(find.text('Move closer'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.kiosk())),
      );
      await tester.pump();
      expect(camera.opened.last, CameraFacing.front);
      // Large title and hint, no buttons.
      expect(find.text('Scan your ticket'), findsOneWidget);
      expect(find.text('Hold the code up to the camera'), findsOneWidget);
      expect(find.byType(ScannerHint), findsNothing);
      expect(find.byType(ScannerButton), findsNothing);
    });

    testWidgets('a refused code flashes and scanning goes on', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final List<String> checked = <String>[];
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.minimal(
              check: (Barcode b) async {
                checked.add(b.text);
                return b.text.startsWith('ok')
                    ? null
                    : const ScanVerdict.reject(
                        title: 'Not ours',
                        message: 'Try another',
                      );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('bad')]);
      await tester.pump();
      expect(checked, <String>['bad']);
      expect(find.text('Not ours · Try another'), findsOneWidget);
      final ScannerController controller = _findController(tester);
      expect(controller.value.status, ScannerStatus.running);
      expect(find.byType(BarcodeResultSheet), findsNothing);
      // The same code in view is not checked again.
      await push(tester, <Barcode>[_barcode('bad')]);
      expect(checked, <String>['bad']);

      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[]);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[_barcode('ok-1')]);
      await tester.pump();
      expect(controller.value.status, ScannerStatus.paused);
      await wait(tester, 800);
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      expect(find.text('ok-1'), findsOneWidget);
      await wait(tester, 3000);
    });

    testWidgets('check-in: verdicts, colors and the counter', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.checkIn(
              check: (Barcode b) => switch (b.text) {
                'T-1' => const ScanVerdict.accept(
                  title: 'Anna Petrova',
                  message: 'Row 4, seat 12',
                ),
                'T-2' => const ScanVerdict.warn(
                  title: 'Anna Petrova',
                  message: 'Already checked in',
                ),
                _ => const ScanVerdict.reject(title: 'Invalid ticket'),
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0 checked in'), findsOneWidget);
      expect(find.text('Point at the ticket'), findsOneWidget);

      await push(tester, <Barcode>[_barcode('T-1')]);
      await tester.pump();
      expect(find.text('ACCEPTED'), findsOneWidget);
      expect(find.text('Anna Petrova'), findsOneWidget);
      expect(find.text('Row 4, seat 12'), findsOneWidget);
      expect(find.text('1 checked in'), findsOneWidget);
      final ScannerController controller = _findController(tester);
      expect(controller.value.status, ScannerStatus.running);
      // The brackets take the verdict's color.
      expect(
        ScannerTheme.of(
          tester.element(find.byType(ScanWindowOverlay)),
        ).lockColor,
        ScannerTheme.defaultAccent,
      );

      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[]);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[_barcode('T-2')]);
      await tester.pump();
      expect(find.text('CHECK THIS CODE'), findsOneWidget);
      expect(find.text('1 checked in'), findsOneWidget);
      expect(
        ScannerTheme.of(
          tester.element(find.byType(ScanWindowOverlay)),
        ).lockColor,
        const ScannerTheme().warningColor,
      );

      await push(tester, <Barcode>[_barcode('T-9')]);
      await tester.pump();
      expect(find.text('NOT ACCEPTED'), findsOneWidget);
      expect(find.text('Invalid ticket'), findsOneWidget);
      expect(
        ScannerTheme.of(
          tester.element(find.byType(ScanWindowOverlay)),
        ).lockColor,
        const ScannerTheme().dangerColor,
      );
      // The verdict hides by itself.
      await wait(tester, 2600);
      expect(find.text('Invalid ticket'), findsNothing);
      expect(find.text('Point at the ticket'), findsOneWidget);
    });

    testWidgets('pick: a label on every code, a tap picks one', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.pick())),
      );
      await tester.pump();
      expect(find.text('Tap a code'), findsOneWidget);
      expect(find.byType(WindowScrim), findsNothing);
      await push(tester, <Barcode>[
        _barcode('https://www.flutter.dev/x'),
        _barcode(
          'WIFI:T:WPA;S:Office;P:secret;;',
          rect: const Rect.fromLTWH(200, 500, 100, 100),
        ),
      ]);
      expect(find.text('2 codes'), findsOneWidget);
      expect(find.text('flutter.dev'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^2\. Wi')), findsOneWidget);
      // Nothing is picked by itself.
      expect(find.byType(BarcodeResultSheet), findsNothing);
      await tester.tap(find.text('Office'));
      await tester.pump();
      final ScannerController controller = _findController(tester);
      expect(controller.value.status, ScannerStatus.paused);
      await wait(tester, 800);
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      expect(find.text('WI‑FI NETWORK'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('pick: closing a result goes back to the codes in view', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      final List<String> picked = <String>[];
      await tester.pumpWidget(
        _host(
          BarcodeScanner(
            template: ScannerTemplate.pick(
              onPick: (Barcode barcode, BarcodeCapture _) =>
                  picked.add(barcode.text),
            ),
          ),
        ),
      );
      await tester.pump();
      final List<Barcode> codes = <Barcode>[
        _barcode('https://www.flutter.dev/x'),
        _barcode(
          'WIFI:T:WPA;S:Office;P:secret;;',
          rect: const Rect.fromLTWH(200, 500, 100, 100),
        ),
      ];
      await push(tester, codes);
      expect(picked, isEmpty);
      await tester.tap(find.text('Office'));
      await wait(tester, 800);
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      final ScannerController controller = _findController(tester);
      expect(controller.value.status, ScannerStatus.paused);

      await tester.tap(find.bySemanticsLabel('Back to the codes'));
      await wait(tester, 500);
      expect(find.byType(BarcodeResultSheet), findsNothing);
      expect(controller.value.status, ScannerStatus.running);
      await push(tester, codes);
      await tester.tap(find.text('flutter.dev'));
      await wait(tester, 800);
      expect(picked, <String>[
        'WIFI:T:WPA;S:Office;P:secret;;',
        'https://www.flutter.dev/x',
      ]);
      semantics.dispose();
    });

    testWidgets('pick: two codes alike get a label each, numbers stay', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.pick())),
      );
      await tester.pump();
      final Barcode a = _barcode('https://www.flutter.dev/x');
      final Barcode b = _barcode(
        'https://www.flutter.dev/x',
        rect: const Rect.fromLTWH(200, 500, 100, 100),
      );
      final Barcode c = _barcode(
        'WIFI:T:WPA;S:Office;P:secret;;',
        rect: const Rect.fromLTWH(40, 500, 100, 100),
      );
      await push(tester, <Barcode>[a, b, c]);
      expect(find.text('3 codes'), findsOneWidget);
      expect(find.text('flutter.dev'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      String numberOf(String label) => tester
          .widget<Text>(
            find.descendant(
              of: find.ancestor(
                of: find.text(label),
                matching: find.byType(Row),
              ),
              matching: find.textContaining(RegExp(r'^\d+$')),
            ),
          )
          .data!;
      expect(numberOf('Office'), '3');
      // The engine finds them in another order: the numbers stay.
      await push(tester, <Barcode>[c, b, a]);
      expect(numberOf('Office'), '3');
      expect(find.text('flutter.dev'), findsNWidgets(2));
    });

    testWidgets('fullscreen: no window until a code locks', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.fullscreen())),
      );
      await tester.pump();
      expect(find.byType(WindowScrim), findsNothing);
      await push(tester, <Barcode>[_barcode('hello')]);
      await wait(tester, 800);
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
    });

    testWidgets('sign in: the screen closes with the code accepted', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      Barcode? result;
      await tester.pumpWidget(
        app(
          (BuildContext context) => GestureDetector(
            onTap: () async {
              result = await Navigator.of(context).push<Barcode>(
                PageRouteBuilder<Barcode>(
                  pageBuilder:
                      (
                        BuildContext context,
                        Animation<double> _,
                        Animation<double> _,
                      ) => BarcodeScanner(
                        template: ScannerTemplate.signIn(
                          check: (Barcode b) =>
                              b.text.startsWith('https://example.com/')
                              ? null
                              : const ScanVerdict.reject(
                                  title: 'Not a sign-in code',
                                ),
                        ),
                      ),
                ),
              );
            },
            child: const Text('sign in'),
          ),
        ),
      );
      await tester.tap(find.text('sign in'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Scan to sign in'), findsOneWidget);
      await push(tester, <Barcode>[_barcode('https://evil.test/')]);
      await tester.pump();
      expect(find.text('Not a sign-in code'), findsOneWidget);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[]);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[_barcode('https://example.com/d?c=1')]);
      await wait(tester, 1200);
      expect(result!.text, 'https://example.com/d?c=1');
      expect(find.text('sign in'), findsOneWidget);
    });

    testWidgets('ScanFieldButton fills its field from a sheet scanner', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      final TextEditingController field = TextEditingController();
      addTearDown(field.dispose);
      Barcode? scanned;
      await tester.pumpWidget(
        app(
          (BuildContext context) => Center(
            child: ScanFieldButton(
              controller: field,
              title: 'Tracking number',
              check: (Barcode b) => b.text.length == 16
                  ? null
                  : const ScanVerdict.reject(title: 'Not a tracking number'),
              valueOf: (Barcode b) => b.text.toUpperCase(),
              onScanned: (Barcode b) => scanned = b,
            ),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Scan a code: Tracking number'),
        findsOneWidget,
      );
      await tester.tap(find.byType(ScanFieldButton));
      await tester.pump();
      await wait(tester, 400);
      expect(find.text('Tracking number'), findsOneWidget);
      // A sheet: the page under it stays.
      expect(find.byType(ScanFieldButton), findsOneWidget);
      await push(tester, <Barcode>[_barcode('short')]);
      await tester.pump();
      expect(find.text('Not a tracking number'), findsOneWidget);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[]);
      now = now.add(const Duration(seconds: 2));
      await push(tester, <Barcode>[_barcode('1z999aa10123456x')]);
      await wait(tester, 1200);
      expect(field.text, '1Z999AA10123456X');
      expect(field.selection.baseOffset, 16);
      expect(scanned!.text, '1z999aa10123456x');
      expect(find.text('Tracking number'), findsNothing);
      semantics.dispose();
    });

    testWidgets('loyalty: the card number large, in groups', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.loyalty())),
      );
      await tester.pump();
      await push(tester, <Barcode>[
        _barcode('6034992144770815', format: BarcodeFormat.code128, id: ']C0'),
      ]);
      await wait(tester, 800);
      expect(find.text('LOYALTY CARD'), findsOneWidget);
      expect(find.text('Card number'), findsOneWidget);
      expect(find.text('6034 9921 4477 0815'), findsOneWidget);
    });

    testWidgets('logistics: SSCC and GS1 fields in the list', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.logistics())),
      );
      await tester.pump();
      await push(tester, <Barcode>[
        _barcode(
          '(00)106141412345678908',
          format: BarcodeFormat.code128,
          id: ']C1',
          type: BarcodeContentType.gs1,
        ),
        _barcode(
          '(02)09501101530003(37)24(10)LOT-0423',
          format: BarcodeFormat.code128,
          id: ']C1',
          type: BarcodeContentType.gs1,
          rect: const Rect.fromLTWH(20, 160, 300, 60),
        ),
      ]);
      expect(find.text('106141412345678908'), findsOneWidget);
      expect(find.textContaining('SSCC'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
    });

    testWidgets('kiosk in landscape: the panel at the side', (
      WidgetTester tester,
    ) async {
      await phone(tester, const Size(1180, 820));
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1180, 820)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: BarcodeScanner(template: ScannerTemplate.kiosk()),
          ),
        ),
      );
      await tester.pump();
      await wait(tester, 400);
      expect(
        tester.getCenter(find.text('Scan your ticket')).dx,
        greaterThan(590),
      );
    });
  });

  group('found in review', () {
    late FakeCamera camera;
    final DateTime now = DateTime(2026);

    setUp(() {
      camera = FakeCamera(transform: const FrameTransform(_phone));
      ScannerControllerDebug.cameraFactory = () => camera;
      ScannerControllerDebug.clock = () => now;
    });

    tearDown(() {
      ScannerControllerDebug.cameraFactory = null;
      ScannerControllerDebug.clock = null;
    });

    Future<void> phone(WidgetTester tester, {Size size = _phone}) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> push(WidgetTester tester, List<Barcode> barcodes) async {
      camera.push(barcodes);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a template built anew on every rebuild keeps distinct mode', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      int detections = 0;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                BarcodeScanner(
                  // Not const: a new template on every build.
                  template: ScannerTemplate.retail(onDone: (_) {}),
                  onDetect: (_) => setState(() => detections++),
                ),
          ),
        ),
      );
      await tester.pump();
      final Barcode code = _barcode('5901234123457', id: ']E0');
      for (int i = 0; i < 5; i++) {
        await push(tester, <Barcode>[code]);
      }
      expect(detections, 1);
      expect(find.text('1 item'), findsOneWidget);
    });

    testWidgets('closing scanBarcode during the lock keeps the page below', (
      WidgetTester tester,
    ) async {
      Barcode? result;
      bool returned = false;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFF000000),
          pageRouteBuilder:
              <T>(RouteSettings settings, WidgetBuilder builder) =>
                  PageRouteBuilder<T>(
                    settings: settings,
                    pageBuilder:
                        (
                          BuildContext context,
                          Animation<double> _,
                          Animation<double> _,
                        ) => builder(context),
                  ),
          home: Builder(
            builder: (BuildContext context) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder:
                      (
                        BuildContext context,
                        Animation<double> _,
                        Animation<double> _,
                      ) => GestureDetector(
                        onTap: () async {
                          result = await scanBarcode(context);
                          returned = true;
                        },
                        child: const Text('middle'),
                      ),
                ),
              ),
              child: const Text('home'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('middle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await push(tester, <Barcode>[_barcode('hello')]);
      // The user closes the scanner before the lock delay is over.
      await tester.tap(find.byType(ScannerCloseButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(returned, isTrue);
      expect(result, isNull);
      expect(find.text('middle'), findsOneWidget);
    });

    testWidgets('landscape: the window moves aside for the sheet and back', (
      WidgetTester tester,
    ) async {
      const Size landscape = Size(844, 390);
      camera = FakeCamera(transform: const FrameTransform(landscape));
      await phone(tester, size: landscape);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      Rect window() => tester
          .widget<ScannerOverlay>(find.byType(ScannerOverlay))
          .layout
          .scanWindow;
      // Searching: in the middle.
      expect(window().center.dx, closeTo(422, 0.5));
      // The zoom presets stand in a column at the right.
      expect(tester.getCenter(find.byType(ZoomButtons)).dx, greaterThan(700));
      await push(tester, <Barcode>[_barcode('https://pub.dev/packages/x')]);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      // The sheet in the right half, the window in the middle of the left.
      final Rect sheet = tester.getRect(find.byType(BarcodeResultSheet));
      expect(sheet.left, greaterThanOrEqualTo(422));
      expect(window().center.dx, closeTo(211, 0.5));
      expect(window().right, lessThan(422));
      await tester.tap(find.text('Scan again'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(window().center.dx, closeTo(422, 0.5));
    });

    testWidgets('a tall sheet scrolls below the top bar', (
      WidgetTester tester,
    ) async {
      const Size small = Size(320, 568);
      await phone(tester, size: small);
      int closed = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: small,
            padding: EdgeInsets.only(top: 20),
            viewPadding: EdgeInsets.only(top: 20),
            textScaler: TextScaler.linear(2),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: BarcodeScanner(
              template: ScannerTemplate.content(onClose: () => closed++),
            ),
          ),
        ),
      );
      await tester.pump();
      await push(tester, <Barcode>[
        _barcode('WIFI:S:Lumen Guest;T:WPA;P:espresso-2026;;'),
      ]);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      final Rect sheet = tester.getRect(
        find.ancestor(
          of: find.byType(BarcodeResultSheet),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(sheet.top, greaterThanOrEqualTo(20 + 72 - 0.5));
      expect(sheet.bottom, lessThanOrEqualTo(small.height));
      // The close button stays reachable.
      await tester.tap(find.byType(ScannerCloseButton));
      expect(closed, 1);
      // And the rest of the sheet can be scrolled to.
      final ScrollableState scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(scroll.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('the preview comes back after a lens switch', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      camera
        ..capabilities = const CameraCapabilities(maxZoom: 10, ultraWide: 0.5)
        ..previewOnFirstFrame = true;
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      await push(tester, const <Barcode>[]);
      final Finder preview = find.byKey(const ValueKey<String>('fake preview'));
      expect(preview, findsOneWidget);
      // The new lens is open, its first frame not there yet, and the state
      // changes (the zoom): the scanner is rebuilt without a preview.
      await tester.tap(find.text('0.5×'));
      await tester.pump();
      await tester.pump();
      expect(camera.lenses.last, CameraLens.ultraWide);
      expect(preview, findsNothing);
      // Its first frame brings the preview back.
      await push(tester, const <Barcode>[]);
      expect(preview, findsOneWidget);
    });

    testWidgets('a wider lens adds a 0.5× preset', (WidgetTester tester) async {
      await phone(tester);
      camera.capabilities = const CameraCapabilities(
        hasTorch: true,
        maxZoom: 10,
        ultraWide: 0.5,
      );
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      expect(find.text('0.5×'), findsOneWidget);
      await tester.tap(find.text('0.5×'));
      await tester.pump();
      await tester.pump();
      expect(camera.lenses.last, CameraLens.ultraWide);
      expect(_findController(tester).value.zoom, 0.5);
    });

    testWidgets('glass outside a scanner follows the platform brightness', (
      WidgetTester tester,
    ) async {
      ScannerTheme? seen;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: Builder(
            builder: (BuildContext context) {
              seen = ScannerTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen!.isDark, isTrue);
    });

    testWidgets('an iPhone with three cameras: Auto and the cameras', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      camera
        ..capabilities = const CameraCapabilities(
          maxZoom: 10,
          ultraWide: 0.5,
          ultraWideFocusesCloser: true,
          telephoto: 4,
        )
        ..lens = 0.3;
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      for (final String preset in <String>['Auto', '0.5×', '1×', '4×']) {
        expect(find.text(preset), findsOneWidget, reason: preset);
      }
      expect(find.text('2×'), findsNothing, reason: 'not a camera');
      expect(_findController(tester).value.autoZoom, AutoZoomState.on);
      await tester.tap(find.text('4×'));
      await tester.pump();
      await tester.pump();
      expect(camera.lenses.last, CameraLens.telephoto);
      expect(_findController(tester).value.autoZoom, AutoZoomState.off);
      await tester.tap(find.text('Auto'));
      await tester.pump();
      await tester.pump();
      expect(_findController(tester).value.autoZoom, AutoZoomState.on);
    });

    testWidgets('a camera that zooms out (Android): all the presets, no Auto', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      camera.capabilities = const CameraCapabilities(minZoom: 0.6, maxZoom: 10);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      for (final String preset in <String>['0.6×', '1×', '2×', '4×']) {
        expect(find.text(preset), findsOneWidget, reason: preset);
      }
      expect(find.text('Auto'), findsNothing);
    });

    testWidgets('an iPhone with one camera: Auto and digital presets', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      camera
        ..capabilities = const CameraCapabilities(maxZoom: 10)
        ..lens = 0.3;
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      for (final String preset in <String>['Auto', '1×', '2×', '4×']) {
        expect(find.text(preset), findsOneWidget, reason: preset);
      }
    });

    testWidgets('zoom presets can be tapped by screen readers', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel('2×'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('2×'));
      await tester.pump();
      expect(camera.zoom, 2);
      semantics.dispose();
    });

    testWidgets('taps on a sheet do not focus the camera', (
      WidgetTester tester,
    ) async {
      await phone(tester);
      await tester.pumpWidget(
        _host(const BarcodeScanner(template: ScannerTemplate.minimal())),
      );
      await tester.pump();
      await push(tester, <Barcode>[_barcode('Hello')]);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('TEXT'));
      await tester.pump();
      expect(camera.focus, isNull);
      // Outside the sheet a tap scans again; then the camera focuses.
      await tester.tapAt(const Offset(195, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(BarcodeResultSheet), findsNothing);
      await tester.tapAt(const Offset(195, 200));
      await tester.pump();
      expect(camera.focus, isNotNull);
    });

    test('pause while the camera starts: it starts paused', () async {
      final ScannerController controller = ScannerController();
      addTearDown(controller.dispose);
      final Future<void> starting = controller.start();
      expect(controller.value.status, ScannerStatus.starting);
      await controller.pause();
      await starting;
      expect(controller.value.status, ScannerStatus.paused);
      await controller.resume();
      expect(controller.value.status, ScannerStatus.running);
      await controller.stop();
    });

    test('setting the same settings keeps distinct mode memory', () {
      final ScannerController controller = ScannerController(
        formats: <BarcodeFormat>{BarcodeFormat.qrCode},
      );
      addTearDown(controller.dispose);
      // Equal values are no change (a set with the same formats included).
      controller
        ..formats = <BarcodeFormat>{BarcodeFormat.qrCode}
        ..scanWindow = const ScanWindow.centered()
        ..detection = DetectionMode.distinct
        ..maxBarcodes = 1;
      expect(controller.formats, <BarcodeFormat>{BarcodeFormat.qrCode});
      expect(() => controller.maxBarcodes = 0, throwsRangeError);
    });

    test('equal strings are equal', () {
      final String close = <String>['Schließen'].join();
      expect(ScannerStrings(close: close), ScannerStrings(close: close));
      expect(
        ScannerStrings(close: close).hashCode,
        ScannerStrings(close: close).hashCode,
      );
      expect(
        const ScannerStrings(close: 'a'),
        isNot(const ScannerStrings(close: 'b')),
      );
    });
  });

  group('BarcodeThumbnail', () {
    BarcodeSymbol grid(BarcodeFormat format) => BarcodeSymbol(
      format: format,
      width: 21,
      height: 21,
      modules: Uint8List(21 * 21)..[0] = 1,
    );

    test('picks the exact grid, a redrawing or the cut-out', () {
      Barcode code(BarcodeFormat format, String text, {BarcodeSymbol? s}) =>
          Barcode(
            format: format,
            text: text,
            bytes: Uint8List(0),
            position: const BarcodePosition(
              topLeft: Offset.zero,
              topRight: Offset.zero,
              bottomRight: Offset.zero,
              bottomLeft: Offset.zero,
            ),
            symbol: s,
          );
      expect(
        BarcodeThumbnail.kindOf(
          code(BarcodeFormat.qrCode, 'x', s: grid(BarcodeFormat.qrCode)),
        ),
        BarcodeThumbnailKind.exact,
      );
      // A QR code without its grid (not read by the engine) is a cut-out.
      expect(
        BarcodeThumbnail.kindOf(code(BarcodeFormat.qrCode, 'x')),
        BarcodeThumbnailKind.cutOut,
      );
      for (final (BarcodeFormat format, String text)
          in <(BarcodeFormat, String)>[
            (BarcodeFormat.ean13, '5901234123457'),
            (BarcodeFormat.isbn, '9783161484100'),
            (BarcodeFormat.ean8, '96385074'),
            (BarcodeFormat.upcA, '036000291452'),
            (BarcodeFormat.upcE, '01234565'),
            (BarcodeFormat.itf14, '09501101530003'),
          ]) {
        expect(
          BarcodeThumbnail.kindOf(code(format, text)),
          BarcodeThumbnailKind.regenerated,
          reason: format.name,
        );
      }
      for (final (BarcodeFormat format, String text)
          in <(BarcodeFormat, String)>[
            // The add-on's digits follow in the text.
            (BarcodeFormat.ean13, '978073520044951299'),
            (BarcodeFormat.code128, 'LOT-2026-11-0042'),
            (BarcodeFormat.pdf417, 'flutter'),
            (BarcodeFormat.dataBarExpanded, '(01)90012345678908'),
          ]) {
        expect(
          BarcodeThumbnail.needsCutOut(code(format, text)),
          isTrue,
          reason: format.name,
        );
      }
      // MaxiCode's grid is hexagonal: drawn as squares it would not be it.
      expect(
        BarcodeThumbnail.kindOf(
          code(BarcodeFormat.maxiCode, 'x', s: grid(BarcodeFormat.maxiCode)),
        ),
        BarcodeThumbnailKind.cutOut,
      );
    });

    testWidgets('draws the grid as read', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: BarcodeThumbnail(
              Barcode(
                format: BarcodeFormat.qrCode,
                text: 'x',
                bytes: Uint8List(0),
                position: const BarcodePosition(
                  topLeft: Offset.zero,
                  topRight: Offset.zero,
                  bottomRight: Offset.zero,
                  bottomLeft: Offset.zero,
                ),
                symbol: grid(BarcodeFormat.qrCode),
              ),
            ),
          ),
        ),
      );
      final BarcodeView view = tester.widget(find.byType(BarcodeView));
      expect(view.symbol, isNotNull);
      expect(tester.getSize(find.byType(BarcodeThumbnail)), const Size(56, 56));
    });
  });

  group('BarcodeResultSheet', () {
    Future<void> show(WidgetTester tester, Barcode barcode) async {
      await tester.pumpWidget(
        _host(
          ScannerScope(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BarcodeResultSheet(barcode, onScanAgain: () {}),
            ),
          ),
        ),
      );
    }

    testWidgets('a one-time password: the secret only on request', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode(
          'otpauth://totp/GitHub:alice@example.com?secret=JBSWY3DPEHPK3PXP'
          '&issuer=GitHub',
        ),
      );
      expect(find.text('ONE-TIME PASSWORD'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
      expect(find.text('Time-based'), findsOneWidget);
      expect(find.textContaining('JBSW'), findsNothing);
      // Copying would copy the secret: only "Scan again".
      expect(find.text('Copy'), findsNothing);
      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('JBSW Y3DP EHPK 3PXP'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
    });

    testWidgets('a crypto payment: the amount large, the address', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode(
          'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.0015'
          '&label=Caf%C3%A9%20Lumen&message=Order%2012',
        ),
      );
      expect(find.text('CRYPTO PAYMENT · BITCOIN'), findsOneWidget);
      expect(find.text('Café Lumen'), findsOneWidget);
      expect(find.text('0.0015 BTC'), findsOneWidget);
      expect(find.text('Order 12'), findsOneWidget);
    });

    testWidgets('a link to a service: named after it, with its target', (
      WidgetTester tester,
    ) async {
      await show(tester, _barcode('https://wa.me/37491234567?text=Hi'));
      expect(find.text('WHATSAPP'), findsOneWidget);
      expect(find.text('+37491234567'), findsOneWidget);
      expect(find.text('Hi'), findsOneWidget);
      await show(tester, _barcode('https://www.instagram.com/flutter.dev'));
      expect(find.text('@flutter.dev'), findsOneWidget);
    });

    testWidgets('Matter: the setup code in two groups', (
      WidgetTester tester,
    ) async {
      await show(tester, _barcode('MT:Y.K9042C00KA0648G00'));
      expect(find.text('SMART HOME DEVICE · MATTER'), findsOneWidget);
      expect(find.text('2020-2021'), findsOneWidget);
      expect(find.text('0xFFF1'), findsOneWidget);
      expect(find.text('3840'), findsOneWidget);
    });

    testWidgets("a driver's license past its expiry date", (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode(
          '@\n\x1e\rANSI 636014080102DL00410288ZC03290015DLDAQD1234562\n'
          'DCSPUBLIC\nDACJOHN\nDADQUINCY\nDBB08311977\nDBA08312020\n'
          'DAJCA\nDCGUSA\r',
          format: BarcodeFormat.pdf417,
        ),
      );
      expect(find.text("DRIVER'S LICENSE · CA"), findsOneWidget);
      expect(find.text('JOHN QUINCY PUBLIC'), findsOneWidget);
      expect(find.text('31 Aug 1977'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('a book: the ISBN and its other numbers', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode('9780306406157', format: BarcodeFormat.ean13, id: ']E0'),
      );
      expect(find.text('BOOK'), findsOneWidget);
      expect(find.text('ISBN 9780306406157'), findsOneWidget);
      expect(find.text('0306406152'), findsOneWidget);
      expect(find.text('ISBN'), findsOneWidget);
    });

    testWidgets('a boarding pass with two flights', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode(
          'M2${'DESMARAIS/LUC'.padRight(20)}EABC123 YULFRAAC 0834 326J001A0025 '
          '100DEF456 FRAGVALH 3664 327C012C0026 100',
          format: BarcodeFormat.pdf417,
        ),
      );
      expect(find.text('BOARDING PASS · AC 834'), findsOneWidget);
      expect(find.text('YUL → FRA'), findsOneWidget);
      expect(find.text('Flight 1 of 2'), findsOneWidget);
      expect(find.text('1A'), findsOneWidget);
    });

    testWidgets('a VIN: the region, the number and what it says', (
      WidgetTester tester,
    ) async {
      await show(tester, _barcode('1M8GDM9AXKP042788'));
      expect(find.text('VEHICLE · VIN'), findsOneWidget);
      expect(find.text('North America'), findsOneWidget);
      expect(find.text('1M8GDM9AXKP042788'), findsOneWidget);
      expect(find.text('1989'), findsOneWidget);
    });

    testWidgets('a link: its host, the URL and the symbology', (
      WidgetTester tester,
    ) async {
      await show(tester, _barcode('https://www.example.com/a?b=c'));
      expect(find.text('LINK'), findsOneWidget);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.text('https://www.example.com/a?b=c'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Scan again'), findsOneWidget);
    });

    testWidgets('an open Wi‑Fi network', (WidgetTester tester) async {
      await show(tester, _barcode('WIFI:S:Cafe;T:nopass;;'));
      expect(find.text('Cafe'), findsOneWidget);
      expect(find.text('Open network'), findsOneWidget);
    });

    testWidgets('a contact', (WidgetTester tester) async {
      await show(
        tester,
        _barcode('MECARD:N:Doe,Jane;ORG:Acme;TEL:+15551234;EMAIL:j@a.co;;'),
      );
      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.textContaining('Acme'), findsOneWidget);
      expect(find.textContaining('+15551234'), findsOneWidget);
    });

    testWidgets('an event', (WidgetTester tester) async {
      await show(
        tester,
        _barcode(
          'BEGIN:VEVENT\nSUMMARY:Launch\nDTSTART:20261114T093000\n'
          'DTEND:20261114T110000\nLOCATION:Zurich\nEND:VEVENT',
        ),
      );
      expect(find.text('Launch'), findsOneWidget);
      expect(find.text('2026-11-14 09:30 – 11:00 · Zurich'), findsOneWidget);
    });

    testWidgets('e-mail, phone, SMS and a location', (
      WidgetTester tester,
    ) async {
      await show(tester, _barcode('mailto:a@b.co?subject=Hi'));
      expect(find.text('a@b.co'), findsOneWidget);
      expect(find.text('Hi'), findsOneWidget);
      await show(tester, _barcode('tel:+41441234567'));
      expect(find.text('PHONE'), findsOneWidget);
      expect(find.text('+41441234567'), findsOneWidget);
      await show(tester, _barcode('SMSTO:+4144:See you'));
      expect(find.text('TEXT MESSAGE'), findsOneWidget);
      expect(find.text('See you'), findsOneWidget);
      await show(tester, _barcode('geo:47.3769,8.5417'));
      expect(find.text('47.37690, 8.54170'), findsOneWidget);
    });

    testWidgets('GS1 elements in a grid', (WidgetTester tester) async {
      await show(
        tester,
        _barcode(
          '(01)09501101530003(17)261231',
          format: BarcodeFormat.dataMatrix,
          id: ']d2',
          bytes: Uint8List.fromList(latin1.encode('010950110153000317261231')),
          type: BarcodeContentType.gs1,
        ),
      );
      expect(find.text('GS1 · GTIN'), findsOneWidget);
      expect(find.text('09501101530003'), findsOneWidget);
      expect(find.text('EXPIRES'), findsOneWidget);
      expect(find.text('31 Dec 2026'), findsOneWidget);
    });

    testWidgets('GS1 of a medicine pack: batch, serial, expired', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode(
          '(01)09501101530003(17)250100(10)AB12C(21)7C4K9M2(240)X-1',
          format: BarcodeFormat.dataMatrix,
          id: ']d2',
          type: BarcodeContentType.gs1,
        ),
      );
      expect(find.text('09501101530003'), findsOneWidget);
      expect(find.text('31 Jan 2025'), findsOneWidget);
      expect(find.text('AB12C'), findsOneWidget);
      expect(find.text('7C4K9M2'), findsOneWidget);
      expect(find.text('(240)'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('binary data in hex', (WidgetTester tester) async {
      await show(
        tester,
        _barcode(
          '',
          bytes: Uint8List.fromList(List<int>.generate(30, (int i) => i)),
          type: BarcodeContentType.binary,
        ),
      );
      expect(find.text('30 bytes'), findsOneWidget);
      expect(find.textContaining('00 01 02'), findsOneWidget);
      expect(find.textContaining('…'), findsOneWidget);
    });

    testWidgets('text: one line as the title, more lines below it', (
      WidgetTester tester,
    ) async {
      await show(tester, _barcode('Hello'));
      expect(find.text('TEXT'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      const String long = 'register/ea3bc1a5-ff86-4b5e-96d5-d68785b9a6cc';
      await show(tester, _barcode(long));
      expect(find.text(long), findsOneWidget);
      await show(tester, _barcode('First line\nsecond line\nthird'));
      expect(find.text('First line'), findsOneWidget);
      expect(find.text('second line\nthird'), findsOneWidget);
    });

    testWidgets('actions that do not scan again get a close in the corner', (
      WidgetTester tester,
    ) async {
      int again = 0;
      Future<void> sheet(List<ScannerAction>? actions) => tester.pumpWidget(
        _host(
          ScannerScope(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BarcodeResultSheet(
                _barcode('https://example.com'),
                actions: actions,
                onScanAgain: () => again++,
              ),
            ),
          ),
        ),
      );
      final Finder close = find.bySemanticsLabel('Scan again');
      await sheet(<ScannerAction>[
        const ScannerAction.copy('https://example.com'),
        ScannerAction(label: 'Open', primary: true, onPressed: () {}),
      ]);
      expect(find.text('Scan again'), findsNothing);
      expect(close, findsOneWidget);
      await tester.tap(close);
      expect(again, 1);
      // The default buttons scan again themselves: no close.
      await sheet(null);
      expect(find.text('Scan again'), findsOneWidget);
      expect(close, findsOneWidget);
    });

    testWidgets('a SEPA payment: the amount, the IBAN grouped and copied', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      await show(
        tester,
        _barcode(
          'BCD\n002\n1\nSCT\nCOBADEFFXXX\nKaffeehaus Lumen\n'
          'DE89370400440532013000\nEUR12.50\n\n\nInvoice 42',
        ),
      );
      expect(find.text('PAYMENT · SEPA'), findsOneWidget);
      expect(find.text('Kaffeehaus Lumen'), findsOneWidget);
      expect(find.text('12.50 EUR'), findsOneWidget);
      expect(find.text('Invoice 42'), findsOneWidget);
      expect(find.text('DE89 3704 0044 0532 0130 00'), findsOneWidget);
      expect(find.text('EPC'), findsOneWidget);
      await tester.tap(find.text('Copy IBAN'));
      await tester.pump();
      final MethodCall copy = calls.singleWhere(
        (MethodCall c) => c.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map<Object?, Object?>)['text'],
        'DE89370400440532013000',
      );
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('a Swiss QR-bill: the reference as on the bill', (
      WidgetTester tester,
    ) async {
      await show(
        tester,
        _barcode(
          <String>[
            'SPC', '0200', '1', 'CH4431999123000889012', //
            'S', 'Robert Schneider AG', 'Rue du Lac', '1268', '2501', 'Biel',
            'CH', '', '', '', '', '', '', '', '1949.75', 'CHF', //
            'S', 'Pia-Maria Rutschmann-Schnyder', 'Grosse Marktgasse', '28',
            '9400', 'Rorschach', 'CH', //
            'QRR', '210000000003139471430009017', 'Order of 15 June 2020',
            'EPD',
          ].join('\n'),
        ),
      );
      expect(find.text('PAYMENT · QR-BILL'), findsOneWidget);
      expect(find.text('1949.75 CHF'), findsOneWidget);
      expect(find.text('21 00000 00003 13947 14300 09017'), findsOneWidget);
      expect(find.text('Rue du Lac 1268, 2501 Biel'), findsOneWidget);
      expect(find.text('Pia-Maria Rutschmann-Schnyder'), findsOneWidget);
    });

    testWidgets('an EMVCo code without an amount, money in a locale', (
      WidgetTester tester,
    ) async {
      final String body =
          '000201010211'
          '${_tlv('26', _tlv('00', 'SG.PAYNOW') + _tlv('02', '201403121W'))}'
          '52045812530370258'
          '02SG5913Lumen Pte Ltd6009Singapore6304';
      await show(tester, _barcode('$body${_crc(body)}'));
      expect(find.text('PAYMENT · PAYNOW'), findsOneWidget);
      expect(find.text('The payer enters the amount'), findsOneWidget);
      expect(find.text('Reusable'), findsOneWidget);
      expect(find.text('5812'), findsOneWidget);
      // No account to copy: the whole text.
      expect(find.text('Copy'), findsOneWidget);

      await tester.pumpWidget(
        _host(
          ScannerScope(
            strings: ScannerStrings(
              money: (String amount, String? currency) => currency == 'BRL'
                  ? 'R\$ ${amount.replaceAll('.', ',')}'
                  : amount,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BarcodeResultSheet(
                _barcode(
                  EmvPaymentContent.pix(
                    key: 'fulano@example.com',
                    name: 'Fulano de Tal',
                    city: 'SAO PAULO',
                    amount: '10.50',
                  ).toPayload(),
                ),
                onScanAgain: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text(r'R$ 10,50'), findsOneWidget);
      expect(find.text('Copy key'), findsOneWidget);
    });

    testWidgets('copy confirms and resets', (WidgetTester tester) async {
      final List<MethodCall> calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          calls.add(call);
          return null;
        },
      );
      await show(tester, _barcode('Hello'));
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
      expect(
        calls.where((MethodCall c) => c.method == 'Clipboard.setData'),
        hasLength(1),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Copy'), findsOneWidget);
    });
  });
}

/// The controller a `BarcodeScanner` created for itself.
ScannerController _findController(WidgetTester tester) =>
    tester
            .widget<ValueListenableBuilder<ScannerState>>(
              find
                  .byWidgetPredicate(
                    (Widget w) =>
                        w is ValueListenableBuilder<ScannerState> &&
                        w.valueListenable is ScannerController,
                  )
                  .first,
            )
            .valueListenable
        as ScannerController;

/// An EMVCo data object.
String _tlv(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

/// CRC-16/CCITT-FALSE, as EMVCo codes end.
String _crc(String text) {
  int crc = 0xFFFF;
  for (final int byte in utf8.encode(text)) {
    crc ^= byte << 8;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0
          ? ((crc << 1) ^ 0x1021) & 0xFFFF
          : (crc << 1) & 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}
