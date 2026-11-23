// The scanner's customization: icons of an icon font and an icon set in the
// theme, the window's and the scrim's colors and the brackets' geometry,
// and where a template puts its controls.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing/src/scanning/ui/window_overlay.dart'
    show BracketsPainter, WindowScrim;

import 'fake_camera.dart';

const Size _phone = Size(390, 844);
const Size _phoneLandscape = Size(844, 390);
const Size _tablet = Size(820, 1180);
const EdgeInsets _notch = EdgeInsets.only(top: 47, bottom: 34);
const EdgeInsets _notchLandscape = EdgeInsets.only(left: 47, right: 47);

// Glyphs of a made-up icon font: what matters is that they are drawn.
const IconData _flashOn = IconData(0xe001, fontFamily: 'TestIcons');
const IconData _flashOff = IconData(0xe002, fontFamily: 'TestIcons');
const IconData _gallery = IconData(0xe003, fontFamily: 'TestIcons');
const IconData _flip = IconData(0xe004, fontFamily: 'TestIcons');
const IconData _back = IconData(0xe005, fontFamily: 'TestIcons');
const IconData _copy = IconData(0xe006, fontFamily: 'TestIcons');

Widget _host(
  Widget child, {
  Size size = _phone,
  EdgeInsets safe = EdgeInsets.zero,
  TextScaler textScaler = TextScaler.noScaling,
}) => MediaQuery(
  data: MediaQueryData(
    size: size,
    padding: safe,
    viewPadding: safe,
    textScaler: textScaler,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

/// The glyphs of the icons drawn in [finder]'s subtree.
List<int> _glyphs(WidgetTester t, Finder finder) => <int>[
  for (final RichText text in t.widgetList<RichText>(
    find.descendant(
      of: find.descendant(of: finder, matching: find.byType(ScannerIcon)),
      matching: find.byType(RichText),
    ),
  ))
    if (text.text case TextSpan(:final String text?)) text.runes.single,
];

/// The icons drawn in [finder]'s subtree.
List<ScannerIconData> _icons(WidgetTester t, Finder finder) =>
    <ScannerIconData>[
      for (final ScannerIcon icon in t.widgetList<ScannerIcon>(
        find.descendant(of: finder, matching: find.byType(ScannerIcon)),
      ))
        icon.icon,
    ];

bool _overlaps(Rect a, Rect b) =>
    a.intersect(b).width > 0.5 && a.intersect(b).height > 0.5;

void main() {
  group('icons', () {
    testWidgets('an icon of an icon font is drawn as its glyph', (
      WidgetTester t,
    ) async {
      await t.pumpWidget(
        _host(
          const Center(
            child: ScannerIcon(
              ScannerIconData.fromIconData(_flashOn),
              size: 30,
              color: Color(0xFF123456),
            ),
          ),
        ),
      );
      final RichText text = t.widget(find.byType(RichText));
      final TextStyle style = text.text.style!;
      expect((text.text as TextSpan).text, String.fromCharCode(0xe001));
      expect(style.fontFamily, 'TestIcons');
      expect(style.fontSize, 30);
      expect(style.color, const Color(0xFF123456));
      // In the same box as a path icon.
      expect(t.getSize(find.byType(ScannerIcon)), const Size.square(30));
      expect(
        find.descendant(
          of: find.byType(ScannerIcon),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('a path icon is painted as before', (WidgetTester t) async {
      await t.pumpWidget(
        _host(const Center(child: ScannerIcon(ScannerIcons.close))),
      );
      expect(find.byType(RichText), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ScannerIcon),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    test('font icons compare by their glyph', () {
      expect(
        const ScannerIconData.fromIconData(_flashOn),
        const ScannerIconData.fromIconData(_flashOn),
      );
      expect(
        const ScannerIconData.fromIconData(_flashOn),
        isNot(const ScannerIconData.fromIconData(_flashOff)),
      );
      expect(const ScannerIconData.fromIconData(_flashOn).glyph, _flashOn);
      expect(ScannerIcons.torchOn.glyph, isNull);
    });

    test('a set keeps the built-in icons it leaves out, and merges', () {
      const ScannerIconSet empty = ScannerIconSet();
      expect(empty.torchOn, ScannerIcons.torchOn);
      expect(empty.copied, ScannerIcons.check);
      expect(empty.cameraError, ScannerIcons.cameraAlert);
      const ScannerIconSet app = ScannerIconSet(
        torchOn: ScannerIconData.fromIconData(_flashOn),
        close: ScannerIconData.fromIconData(_back),
      );
      const ScannerIconSet screen = ScannerIconSet(
        close: ScannerIcons.close,
        photo: ScannerIconData.fromIconData(_gallery),
      );
      final ScannerIconSet merged = app.merge(screen);
      expect(merged.torchOn, const ScannerIconData.fromIconData(_flashOn));
      expect(merged.close, ScannerIcons.close);
      expect(merged.photo, const ScannerIconData.fromIconData(_gallery));
      expect(merged.switchCamera, ScannerIcons.switchCamera);
      // Themes merge their sets icon by icon.
      final ScannerTheme theme = const ScannerTheme(
        icons: app,
      ).merge(const ScannerTheme(icons: screen));
      expect(theme.icons, merged);
      expect(
        const ScannerTheme(icons: app).merge(const ScannerTheme()).icons,
        app,
      );
      expect(const ScannerTheme(icons: app), const ScannerTheme(icons: app));
      expect(
        const ScannerTheme(icons: app),
        isNot(const ScannerTheme(icons: screen)),
      );
    });

    testWidgets('the theme icons reach the scanner buttons', (
      WidgetTester t,
    ) async {
      final FakeCamera camera = FakeCamera(
        transform: const FrameTransform(_phone),
      );
      ScannerControllerDebug.cameraFactory = () => camera;
      addTearDown(() => ScannerControllerDebug.cameraFactory = null);
      final ScannerController controller = ScannerController();
      await t.pumpWidget(
        _host(
          BarcodeScanner(
            controller: controller,
            template: ScannerTemplate.minimal(onClose: () {}),
            theme: const ScannerTheme(
              icons: ScannerIconSet(
                torchOn: ScannerIconData.fromIconData(_flashOn),
                torchOff: ScannerIconData.fromIconData(_flashOff),
                photo: ScannerIconData.fromIconData(_gallery),
                switchCamera: ScannerIconData.fromIconData(_flip),
                close: ScannerIconData.fromIconData(_back),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      expect(_glyphs(t, find.byType(TorchButton)), <int>[0xe002]);
      expect(_glyphs(t, find.byType(PickImageButton)), <int>[0xe003]);
      expect(_glyphs(t, find.byType(SwitchCameraButton)), <int>[0xe004]);
      expect(_glyphs(t, find.byType(ScannerCloseButton)), <int>[0xe005]);
      await t.tap(find.byType(TorchButton));
      await t.pump();
      await t.pump();
      expect(_glyphs(t, find.byType(TorchButton)), <int>[0xe001]);
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async => controller.dispose());
    });

    testWidgets('the theme icons reach the result sheet', (
      WidgetTester t,
    ) async {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async => null,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      const ScannerIconData copy = ScannerIconData.fromIconData(_copy);
      const ScannerIconData copied = ScannerIconData(stroke: 'M4 12h16');
      final Barcode barcode = Barcode(
        format: BarcodeFormat.qrCode,
        text: 'hello',
        bytes: Uint8List.fromList(utf8.encode('hello')),
        position: const BarcodePosition(
          topLeft: Offset.zero,
          topRight: Offset(10, 0),
          bottomRight: Offset(10, 10),
          bottomLeft: Offset(0, 10),
        ),
      );
      await t.pumpWidget(
        _host(
          ScannerScope(
            theme: const ScannerTheme(
              icons: ScannerIconSet(
                copy: copy,
                copied: copied,
                close: ScannerIconData.fromIconData(_back),
              ),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: BarcodeResultSheet(
                barcode,
                header: ResultHeader.none,
                actions: <ScannerAction>[
                  ScannerAction(label: 'Open', onPressed: () {}),
                  const ScannerAction.copy('hello'),
                ],
                onScanAgain: () {},
              ),
            ),
          ),
        ),
      );
      final Finder copyButton = find.widgetWithText(
        ScannerActionButton,
        'Copy',
      );
      expect(_icons(t, copyButton), <ScannerIconData>[copy]);
      // The close in the sheet's corner.
      expect(_glyphs(t, find.byType(BarcodeResultSheet)), contains(0xe005));
      await t.tap(copyButton);
      await t.pump();
      expect(
        _icons(t, find.widgetWithText(ScannerActionButton, 'Copied')),
        <ScannerIconData>[copied],
      );
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('window', () {
    test('the colors and the brackets default as before', () {
      const ScannerTheme light = ScannerTheme(brightness: Brightness.light);
      const ScannerTheme dark = ScannerTheme(brightness: Brightness.dark);
      expect(light.windowColor, const Color(0xFFFFFFFF));
      expect(light.scrimColor, const Color(0x8006090D));
      expect(dark.scrimColor, const Color(0x94000000));
      expect(light.resolvedBracketWidth, 5);
      expect(light.bracketLength, isNull);
    });

    test('the colors and the brackets merge', () {
      final ScannerTheme theme = const ScannerTheme(
        window: Color(0xFFFF0000),
        bracketWidth: 3,
      ).merge(const ScannerTheme(scrim: Color(0x80000000), bracketLength: 30));
      expect(theme.windowColor, const Color(0xFFFF0000));
      expect(theme.scrimColor, const Color(0x80000000));
      expect(theme.resolvedBracketWidth, 3);
      expect(theme.bracketLength, 30);
      expect(
        theme.copyWith(window: const Color(0xFF00FF00)).windowColor,
        const Color(0xFF00FF00),
      );
    });

    test('a bracket length gives the arms that length', () {
      const Rect window = Rect.fromLTWH(0, 0, 300, 300);
      double length(double? arm) => BracketsPainter.bracketPath(
        window,
        24,
        arm: arm,
      ).computeMetrics().fold(0, (double sum, PathMetric m) => sum + m.length);
      // Four corners, each a quarter circle and two arms.
      double expected(double arm) => 4 * (math.pi / 2 * 24 + 2 * arm);
      expect(length(30), moreOrLessEquals(expected(30), epsilon: 2));
      // Without one: 22 % of the shorter side, at most 44.
      expect(length(null), moreOrLessEquals(expected(44), epsilon: 2));
    });

    testWidgets('the window and scrim colors and the brackets reach the '
        'painters', (WidgetTester t) async {
      final FakeCamera camera = FakeCamera(
        transform: const FrameTransform(_phone),
      );
      ScannerControllerDebug.cameraFactory = () => camera;
      addTearDown(() => ScannerControllerDebug.cameraFactory = null);
      final ScannerController controller = ScannerController();
      await t.pumpWidget(
        _host(
          BarcodeScanner(
            controller: controller,
            theme: const ScannerTheme(
              window: Color(0xFFFFCC00),
              scrim: Color(0xB0102030),
              bracketWidth: 8,
              bracketLength: 30,
              scrimBlur: false,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump();
      final BracketsPainter brackets =
          t
                  .widgetList<CustomPaint>(find.byType(CustomPaint))
                  .firstWhere((CustomPaint p) => p.painter is BracketsPainter)
                  .painter!
              as BracketsPainter;
      expect(brackets.color, const Color(0xFFFFCC00));
      expect(brackets.strokeWidth, 8);
      expect(brackets.armLength, 30);
      final RenderObject bracketsBox = t
          .renderObjectList<RenderCustomPaint>(find.byType(CustomPaint))
          .firstWhere((RenderCustomPaint r) => r.painter is BracketsPainter);
      expect(
        bracketsBox,
        paints..path(color: const Color(0xFFFFCC00), strokeWidth: 8),
      );
      expect(
        t.renderObject(
          find.descendant(
            of: find.byType(WindowScrim),
            matching: find.byType(CustomPaint),
          ),
        ),
        paints..path(color: const Color(0xB0102030)),
      );
      await t.pumpWidget(const SizedBox());
      await t.runAsync(() async => controller.dispose());
    });
  });

  group('controls layout', () {
    late FakeCamera camera;

    setUp(() {
      camera = FakeCamera(
        transform: const FrameTransform(_phone),
        capabilities: const CameraCapabilities(
          hasTorch: true,
          maxZoom: 10,
          hasOtherFacing: true,
        ),
      );
      ScannerControllerDebug.cameraFactory = () => camera;
    });
    tearDown(() => ScannerControllerDebug.cameraFactory = null);

    /// Opens [template] with every control on a [size] screen; returns the
    /// scan window.
    Future<Rect> open(
      WidgetTester t,
      ScannerTemplate template, {
      Size size = _phone,
      EdgeInsets safe = _notch,
      TextScaler textScaler = TextScaler.noScaling,
      ScannerOverlayBuilder? foregroundBuilder,
    }) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final ScannerTemplate full = template.copyWith(
        onClose: () => () {},
        photoButton: true,
        zoomButtons: true,
        switchCameraButton: true,
      );
      final ScannerController controller = ScannerController.fromTemplate(full);
      addTearDown(() => t.runAsync(() async => controller.dispose()));
      await t.pumpWidget(
        _host(
          BarcodeScanner(
            controller: controller,
            template: full,
            foregroundBuilder: foregroundBuilder,
          ),
          size: size,
          safe: safe,
          textScaler: textScaler,
        ),
      );
      await t.pump();
      await t.pump();
      return full.scanWindow.resolve(size);
    }

    Rect rect(WidgetTester t, Type type) => t.getRect(find.byType(type));

    /// The controls and the hint stay clear of the window and each other.
    void clear(WidgetTester t, Rect window) {
      final List<Rect> controls = <Rect>[
        rect(t, PickImageButton),
        rect(t, ZoomButtons),
        rect(t, SwitchCameraButton),
        rect(t, TorchButton),
        rect(t, ScannerCloseButton),
      ];
      final Rect hint = rect(t, ScannerHint);
      for (final Rect control in controls) {
        expect(_overlaps(control, window), isFalse, reason: '$control');
        expect(_overlaps(control, hint), isFalse, reason: '$control');
      }
      for (int i = 0; i < controls.length; i++) {
        for (int j = i + 1; j < controls.length; j++) {
          expect(_overlaps(controls[i], controls[j]), isFalse);
        }
      }
    }

    testWidgets('adaptive: a row at the bottom in portrait', (
      WidgetTester t,
    ) async {
      final Rect window = await open(t, const ScannerTemplate.minimal());
      final Rect photo = rect(t, PickImageButton);
      final Rect flip = rect(t, SwitchCameraButton);
      expect(photo.bottom, _phone.height - _notch.bottom - 24);
      expect(photo.left, 40);
      expect(flip.right, _phone.width - 40);
      expect(rect(t, ZoomButtons).center.dy, photo.center.dy);
      // The torch at the top right.
      expect(
        rect(t, TorchButton).topRight,
        Offset(_phone.width - 20, _notch.top + 12),
      );
      clear(t, window);
    });

    testWidgets('adaptive: a column at the right in landscape', (
      WidgetTester t,
    ) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(),
        size: _phoneLandscape,
        safe: _notchLandscape,
      );
      final Rect photo = rect(t, PickImageButton);
      final Rect flip = rect(t, SwitchCameraButton);
      expect(photo.left, greaterThan(window.right));
      expect(photo.center.dx, moreOrLessEquals(flip.center.dx));
      expect(flip.top, greaterThan(photo.bottom));
      clear(t, window);
    });

    testWidgets('sideColumn: beside the window where there is room', (
      WidgetTester t,
    ) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.sideColumn,
        ),
        size: _tablet,
      );
      final Rect photo = rect(t, PickImageButton);
      final Rect zoom = rect(t, ZoomButtons);
      final Rect flip = rect(t, SwitchCameraButton);
      expect(photo.left, greaterThanOrEqualTo(window.right + 12));
      expect(flip.right, lessThanOrEqualTo(_tablet.width - 20));
      // Within the window's height, from top to bottom.
      expect(photo.top, greaterThanOrEqualTo(window.top));
      expect(flip.bottom, lessThanOrEqualTo(window.bottom));
      expect(zoom.top, greaterThan(photo.bottom));
      expect(flip.top, greaterThan(zoom.bottom));
      clear(t, window);
    });

    testWidgets('sideColumn: the bottom row on a phone in portrait', (
      WidgetTester t,
    ) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.sideColumn,
        ),
      );
      expect(
        rect(t, PickImageButton).bottom,
        _phone.height - _notch.bottom - 24,
      );
      clear(t, window);
    });

    testWidgets('sideColumn: the column in landscape', (WidgetTester t) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.sideColumn,
        ),
        size: _phoneLandscape,
        safe: _notchLandscape,
      );
      expect(rect(t, PickImageButton).left, greaterThan(window.right));
      clear(t, window);
    });

    testWidgets('topBar: a row under the top bar', (WidgetTester t) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.topBar,
        ),
      );
      final Rect close = rect(t, ScannerCloseButton);
      final Rect photo = rect(t, PickImageButton);
      expect(photo.top, close.bottom + 12);
      expect(photo.bottom, lessThanOrEqualTo(window.top - 12));
      expect(rect(t, SwitchCameraButton).top, photo.top);
      expect(rect(t, ZoomButtons).center.dy, photo.center.dy);
      clear(t, window);
    });

    testWidgets('topBar: below a title in large text', (WidgetTester t) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.topBar,
          title: 'Scan the code on the parcel label',
        ),
        textScaler: const TextScaler.linear(1.6),
      );
      final Rect title = t.getRect(
        find.ancestor(
          of: find.text('Scan the code on the parcel label'),
          matching: find.byType(ScannerHint),
        ),
      );
      final Rect photo = rect(t, PickImageButton);
      // The title wraps onto two lines: the row goes below it.
      expect(title.height, greaterThan(60));
      expect(photo.top, greaterThanOrEqualTo(title.bottom));
      expect(_overlaps(photo, window), isFalse);
    });

    testWidgets('topBar: below the hidden exit corner', (WidgetTester t) async {
      await open(
        t,
        const ScannerTemplate(
          controlsLayout: ScannerControlsLayout.topBar,
          scanWindow: ScanWindow.centered(alignment: Alignment(0, 0.4)),
        ).copyWith(hiddenExit: true),
      );
      expect(
        rect(t, PickImageButton).top,
        greaterThanOrEqualTo(_notch.top + 88),
      );
    });

    testWidgets('topBar: the bottom row with a window high up', (
      WidgetTester t,
    ) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.payment(
          controlsLayout: ScannerControlsLayout.topBar,
        ),
      );
      expect(rect(t, PickImageButton).top, greaterThan(window.bottom));
      expect(_overlaps(rect(t, PickImageButton), window), isFalse);
    });

    testWidgets('topBar: the column in landscape', (WidgetTester t) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.topBar,
        ),
        size: _phoneLandscape,
        safe: _notchLandscape,
      );
      expect(rect(t, PickImageButton).left, greaterThan(window.right));
      clear(t, window);
    });

    testWidgets('the torch with the controls: last of the row and the column', (
      WidgetTester t,
    ) async {
      Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          torchPosition: ScannerTorchPosition.withControls,
        ),
      );
      Rect torch = rect(t, TorchButton);
      final Rect flip = rect(t, SwitchCameraButton);
      expect(torch.center.dy, flip.center.dy);
      expect(torch.right, _phone.width - 40);
      expect(torch.left, greaterThanOrEqualTo(flip.right + 8));
      // The zoom stays in the middle.
      expect(
        rect(t, ZoomButtons).center.dx,
        moreOrLessEquals(_phone.width / 2),
      );
      clear(t, window);

      window = await open(
        t,
        const ScannerTemplate.minimal(
          torchPosition: ScannerTorchPosition.withControls,
        ),
        size: _phoneLandscape,
        safe: _notchLandscape,
      );
      torch = rect(t, TorchButton);
      expect(torch.top, greaterThan(rect(t, SwitchCameraButton).bottom));
      expect(torch.left, greaterThan(window.right));
      clear(t, window);
    });

    testWidgets('the torch stays at the top in a list', (WidgetTester t) async {
      await open(
        t,
        const ScannerTemplate.retail(
          torchPosition: ScannerTorchPosition.withControls,
        ),
      );
      expect(rect(t, TorchButton).top, _notch.top + 12);
    });

    testWidgets('the controls hide under a result sheet', (
      WidgetTester t,
    ) async {
      final Rect window = await open(
        t,
        const ScannerTemplate.minimal(
          controlsLayout: ScannerControlsLayout.topBar,
          torchPosition: ScannerTorchPosition.withControls,
        ),
      );
      expect(find.byType(PickImageButton).hitTestable(), findsOneWidget);
      camera.push(<Barcode>[fakeBarcode('A', window.deflate(60))]);
      for (int i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(BarcodeResultSheet), findsOneWidget);
      expect(find.byType(PickImageButton).hitTestable(), findsNothing);
      expect(find.byType(TorchButton).hitTestable(), findsNothing);
    });

    testWidgets('buttons of your own over the window, the built-in ones off', (
      WidgetTester t,
    ) async {
      t.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      const ScannerTemplate template = ScannerTemplate.minimal(
        torchButton: false,
        photoButton: false,
        zoomButtons: false,
        switchCameraButton: false,
      );
      final ScannerController controller = ScannerController.fromTemplate(
        template,
      );
      addTearDown(() => t.runAsync(() async => controller.dispose()));
      await t.pumpWidget(
        _host(
          BarcodeScanner(
            controller: controller,
            template: template,
            foregroundBuilder: (BuildContext context, ScannerLayout layout) =>
                Positioned(
                  left: layout.scanWindow.left,
                  top: layout.scanWindow.bottom + 64,
                  child: TorchButton(layout.controller),
                ),
          ),
          safe: _notch,
        ),
      );
      await t.pump();
      await t.pump();
      final Rect window = template.scanWindow.resolve(_phone);
      expect(find.byType(TorchButton), findsOneWidget);
      expect(find.byType(PickImageButton), findsNothing);
      expect(
        rect(t, TorchButton).topLeft,
        Offset(window.left, window.bottom + 64),
      );
      await t.tap(find.byType(TorchButton));
      await t.pump();
      expect(controller.value.torch, TorchState.on);
    });
  });
}
