// The template overlay and the controller when events cross: a check that
// ends late, the app going away, a frame still being read.
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
const String _otp = 'otpauth://totp/A?secret=JBSWY3DPEHPK3PXP&issuer=Acme';

PixelBuffer _pixels() {
  final Uint8List b = Uint8List(720 * 1280);
  for (int i = 0; i < b.length; i++) {
    b[i] = (i ~/ 7).isEven ? 30 : 220;
  }
  return PixelBuffer(b, width: 720, height: 1280);
}

Widget _host(Widget child) => MediaQuery(
  data: const MediaQueryData(size: _phone),
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

void _life(WidgetTester t, List<AppLifecycleState> states) {
  states.forEach(t.binding.handleAppLifecycleStateChanged);
}

const List<AppLifecycleState> _hide = <AppLifecycleState>[
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
];
const List<AppLifecycleState> _show = <AppLifecycleState>[
  AppLifecycleState.inactive,
  AppLifecycleState.resumed,
];

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
  }) async {
    t.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        BarcodeScanner(controller: c, template: template, onDetect: onDetect),
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

  Future<void> backToCamera(WidgetTester t) async {
    final SemanticsHandle handle = t.ensureSemantics();
    await t.tap(find.bySemanticsLabel('Back to the camera'));
    await t.pump();
    handle.dispose();
  }

  testWidgets('a frozen frame lies exactly where the preview was', (
    WidgetTester t,
  ) async {
    await open(
      t,
      ScannerTemplate.pick(check: (_) => const ScanVerdict.reject()),
    );
    await code(t);
    await t.tap(find.text('A'));
    await _settle(t);
    final Rect frozen = t.getRect(find.byType(RawImage).first);
    const double scale = 844 / 1280;
    expect(frozen.width, moreOrLessEquals(720 * scale, epsilon: 0.01));
    expect(
      frozen.left,
      moreOrLessEquals((390 - 720 * scale) / 2, epsilon: 0.01),
    );
    await close(t);
  });

  testWidgets('a picked code that moved still has its picture', (
    WidgetTester t,
  ) async {
    Barcode? picked;
    BarcodeCapture? from;
    await open(
      t,
      ScannerTemplate.pick(
        onPick: (Barcode b, BarcodeCapture capture) {
          picked = b;
          from = capture;
        },
      ),
    );
    await code(t);
    await code(t, 'A', _a.shift(const Offset(1, 1)));
    await t.tap(find.text('A'));
    await _settle(t);
    expect(from!.barcodes, contains(picked));
    await close(t);
  });

  testWidgets('a resume in the background is not lost', (WidgetTester t) async {
    await open(
      t,
      const ScannerTemplate(
        resumeAfter: Duration(seconds: 1),
        scanWindow: ScanWindow.full(),
      ),
    );
    await code(t);
    await _settle(t);
    expect(c.value.status, ScannerStatus.paused);
    _life(t, _hide);
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    _life(t, _show);
    await _settle(t);
    expect(c.value.status, ScannerStatus.running);
    await close(t);
  });

  testWidgets('a resume while the camera reopens is not lost', (
    WidgetTester t,
  ) async {
    await open(
      t,
      ScannerTemplate.pick(check: (_) => const ScanVerdict.reject()),
    );
    await code(t);
    await t.tap(find.text('A'));
    await _settle(t);
    _life(t, _hide);
    await t.pump();
    camera.openGate = Completer<void>();
    _life(t, _show);
    await t.pump();
    await backToCamera(t);
    camera.openGate!.complete();
    camera.openGate = null;
    await _settle(t);
    expect(c.value.status, ScannerStatus.running);
    await close(t);
  });

  testWidgets('a paused scanner comes back paused', (WidgetTester t) async {
    await open(t, const ScannerTemplate.minimal());
    await c.pause();
    _life(t, _hide);
    await t.pump();
    _life(t, _show);
    await _settle(t);
    expect(c.value.status, ScannerStatus.paused);
    await close(t);
  });

  testWidgets('leaving pick on a frozen frame scans on', (
    WidgetTester t,
  ) async {
    await open(
      t,
      ScannerTemplate.pick(check: (_) => const ScanVerdict.reject()),
    );
    await code(t);
    await t.tap(find.text('A'));
    await _settle(t);
    expect(c.value.status, ScannerStatus.paused);
    await t.pumpWidget(
      _host(
        BarcodeScanner(
          controller: c,
          template: const ScannerTemplate.minimal(),
        ),
      ),
    );
    await _settle(t);
    expect(c.value.status, ScannerStatus.running);
    await close(t);
  });

  testWidgets('closeOnResult waits for a route opened over it', (
    WidgetTester t,
  ) async {
    t.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    Barcode? result;
    await t.pumpWidget(
      _host(
        Navigator(
          key: nav,
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            pageBuilder: (_, _, _) => const SizedBox(),
          ),
        ),
      ),
    );
    unawaited(
      nav.currentState!
          .push<Barcode>(
            PageRouteBuilder<Barcode>(
              pageBuilder: (_, _, _) => BarcodeScanner(
                controller: c,
                template: const ScannerTemplate.signIn(),
              ),
            ),
          )
          .then((Barcode? b) => result = b),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    await code(t);
    await t.pump(const Duration(milliseconds: 100));
    unawaited(
      nav.currentState!.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => const SizedBox(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    nav.currentState!.pop();
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(seconds: 2));
    expect(result?.text, 'A');
    await t.pumpWidget(const SizedBox());
    await t.runAsync(() async => c.dispose());
  });

  testWidgets('without a sheet every code after a resume is checked', (
    WidgetTester t,
  ) async {
    int checks = 0;
    await open(
      t,
      ScannerTemplate(
        scanWindow: const ScanWindow.full(),
        showResult: false,
        check: (_) {
          checks++;
          return const ScanVerdict.accept();
        },
      ),
    );
    await code(t);
    await _settle(t);
    await c.resume();
    await _settle(t);
    await code(t, 'B', _a.shift(const Offset(0, 300)));
    await _settle(t);
    expect(checks, 2);
    await close(t);
  });

  testWidgets('a check that ends after leaving the code is dropped', (
    WidgetTester t,
  ) async {
    final Completer<ScanVerdict?> verdict = Completer<ScanVerdict?>();
    final List<String> picked = <String>[];
    await open(
      t,
      ScannerTemplate.pick(
        check: (_) => verdict.future,
        onPick: (Barcode b, _) => picked.add(b.text),
      ),
    );
    await code(t);
    await t.tap(find.text('A'));
    await _settle(t);
    await backToCamera(t);
    await _settle(t);
    verdict.complete(const ScanVerdict.accept());
    await _settle(t);
    expect(picked, isEmpty);
    expect(find.byType(BarcodeResultSheet), findsNothing);
    expect(c.value.status, ScannerStatus.running);
    await close(t);
  });

  testWidgets('a camera stall during a pause does not end scanning', (
    WidgetTester t,
  ) async {
    final List<BarcodeCapture> got = <BarcodeCapture>[];
    await open(t, const ScannerTemplate.minimal(), onDetect: got.add);
    await t.pump(const Duration(seconds: 1));
    await c.pause();
    await t.pump(const Duration(seconds: 3));
    await c.resume();
    await t.pump();
    for (int i = 0; i < 5; i++) {
      await code(t);
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(got, isNotEmpty);
    await t.pump(const Duration(seconds: 10));
    await close(t);
  });

  testWidgets('outlines go when the frame changes size', (
    WidgetTester t,
  ) async {
    DateTime now = DateTime(2026);
    ScannerControllerDebug.clock = () => now;
    addTearDown(() => ScannerControllerDebug.clock = null);
    late ScannerLayout layout;
    t.view
      ..physicalSize = _phone
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      _host(
        BarcodeScanner(
          controller: c,
          overlayBuilder: (_, ScannerLayout l) {
            layout = l;
            return const SizedBox();
          },
        ),
      ),
    );
    await t.pump();
    await code(t);
    expect(layout.barcodes, hasLength(1));
    camera.turn(const FrameTransform(Size(1280, 720)));
    await t.pump();
    for (int i = 0; i < 10; i++) {
      now = now.add(const Duration(milliseconds: 100));
      camera.push();
      await t.pump();
      await t.pump();
    }
    expect(layout.barcodes, isEmpty);
    await close(t);
  });

  testWidgets('a frame read while pausing is not reported', (
    WidgetTester t,
  ) async {
    final List<BarcodeCapture> got = <BarcodeCapture>[];
    await open(
      t,
      const ScannerTemplate(
        mode: ScannerMode.collect,
        scanWindow: ScanWindow.full(),
      ),
      onDetect: got.add,
    );
    final FakeFrame frame = camera.push(<Barcode>[fakeBarcode('A', _a)]);
    frame.gate = Completer<void>();
    await t.pump();
    await c.pause();
    frame.gate!.complete();
    await t.pump();
    await t.pump();
    expect(got, isEmpty);
    await close(t);
  });

  testWidgets('a check that throws scans on', (WidgetTester t) async {
    final FlutterExceptionHandler? old = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = old);
    c = ScannerController(
      scanWindow: const ScanWindow.full(),
      detection: DetectionMode.once,
    );
    await open(
      t,
      ScannerTemplate.minimal(check: (_) => throw StateError('server down')),
    );
    await code(t);
    await _settle(t);
    FlutterError.onError = old;
    expect(c.value.status, ScannerStatus.running);
    await close(t);
  });

  group('a one-time password keeps its secret', () {
    List<String> leaks() => <String>[
      for (final Element e in find.byType(Text).evaluate())
        if (((e.widget as Text).data ?? '').contains('JBS'))
          (e.widget as Text).data!,
    ];

    Widget sheet(Widget child) =>
        _host(ScannerScope(child: SingleChildScrollView(child: child)));

    testWidgets('on a card sheet', (WidgetTester t) async {
      await t.pumpWidget(
        sheet(BarcodeResultSheet(fakeBarcode(_otp, _a), asCard: true)),
      );
      expect(leaks(), isEmpty);
      expect(find.text('Copy'), findsNothing);
    });

    testWidgets('in a list', (WidgetTester t) async {
      await t.pumpWidget(
        sheet(
          BarcodeListSheet(
            items: <CollectedBarcode>[
              CollectedBarcode(fakeBarcode(_otp, _a), 1),
            ],
          ),
        ),
      );
      expect(leaks(), isEmpty);
      expect(find.text('Acme'), findsOneWidget);
    });

    testWidgets('on a pick label', (WidgetTester t) async {
      await open(t, const ScannerTemplate.pick());
      await code(t, _otp);
      expect(leaks(), isEmpty);
      await close(t);
    });

    testWidgets('in a verdict', (WidgetTester t) async {
      await open(
        t,
        ScannerTemplate.checkIn(check: (_) => const ScanVerdict.accept()),
      );
      await code(t, _otp);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(leaks(), isEmpty);
      await t.pump(const Duration(seconds: 3));
      await close(t);
    });
  });
}
