// The diagnostics page: its numbers, its settings and the page itself on a
// fake camera.
import 'dart:io';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
// ignore: implementation_imports
import 'package:flutter_zxing/src/engine/engine_protocol.dart';
// ignore: implementation_imports
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;
import 'package:flutter_zxing_example/diagnostics/diag_metrics.dart';
import 'package:flutter_zxing_example/diagnostics/diag_runs.dart';
import 'package:flutter_zxing_example/diagnostics/diag_settings.dart';
import 'package:flutter_zxing_example/diagnostics/diagnostics_page.dart';
import 'package:flutter_zxing_example/diagnostics/frame_recorder.dart';
import 'package:flutter_zxing_example/diagnostics/recording.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The package's own fake camera.
// ignore: avoid_relative_lib_imports
import '../../test/scanning/fake_camera.dart';

void main() {
  group('settings', () {
    test('start as the scanner\'s defaults', () {
      const DiagSettings s = DiagSettings();
      expect(s.readerOptions, const ReaderOptions.camera());
      expect(s.engineFlags, 0);
    });

    test('downscale settings become engine flags', () {
      expect(
        const DiagSettings(
          downscaleFactor: 2,
          downscaleThreshold: 360,
        ).engineFlags,
        fzxDownscaleFlags(factor: 2, threshold: 360),
      );
    });

    test('every setting is saved with a run', () {
      final Map<String, Object> json = const DiagSettings(
        tryInvert: true,
        binarizer: Binarizer.globalHistogram,
        maxBarcodes: 0,
      ).toJson();
      expect(json['tryInvert'], isTrue);
      expect(json['binarizer'], 'globalHistogram');
      expect(json['maxBarcodes'], 0);
    });
  });

  group('numbers', () {
    DiagSample sample(int atMs, int engineMs, {bool found = false}) =>
        DiagSample(
          atMicros: atMs * 1000,
          engineMicros: engineMs * 1000,
          latencyMicros: engineMs * 2000,
          found: found,
        );

    test('percentiles of the decoded frames', () {
      final DiagSnapshot s = DiagSnapshot.of(<DiagSample>[
        for (int i = 1; i <= 100; i++) sample(i * 10, i, found: i.isEven),
      ], firstReadMs: 120);
      expect(s.decodeP50Ms, closeTo(50, 1));
      expect(s.decodeP95Ms, closeTo(95, 1));
      expect(s.decodeMaxMs, 100);
      expect(s.withCodePercent, 50);
      expect(s.firstReadMs, 120);
      expect(s.fps, 100);
    });

    test('nothing decoded yet', () {
      expect(DiagSnapshot.of(const <DiagSample>[]).reads, 0);
    });

    test('the share of the device needs the number of cores', () {
      expect(const DiagSnapshot(cpuPercent: 200, cores: 8).devicePercent, 25);
      expect(const DiagSnapshot(cpuPercent: 200).devicePercent, isNull);
    });

    test('extra metadata', () {
      expect(extraValue('{"UEC":0.25,"DataMask":3}', 'UEC'), '0.25');
      expect(extraValue('{"UEC":0.25}', 'DataMask'), isNull);
      expect(extraValue('', 'UEC'), isNull);
      expect(extraValue('not json', 'UEC'), isNull);
    });
  });

  group('runs', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    DiagRun run(String label) => DiagRun(
      time: DateTime(2026, 11, 18),
      label: label,
      device: 'test',
      build: 'debug',
      engine: zxingCppVersion,
      settings: const <String, Object?>{'tryInvert': false},
      numbers: const <String, Object?>{'decodeP50Ms': 1.5},
    );

    test('are kept across launches, newest first', () async {
      final DiagRunStore store = DiagRunStore();
      await store.add(run('first'));
      await store.add(run('second'));
      final DiagRunStore again = DiagRunStore();
      await again.load();
      expect(again.runs.map((DiagRun r) => r.label), <String>[
        'second',
        'first',
      ]);
    });

    test('a comparison lists what differs', () {
      expect(
        differences(
          <String, Object?>{'a': 1, 'b': 2},
          <String, Object?>{'a': 1, 'b': 3},
        ),
        <(String, String, String)>[('b', '2', '3')],
      );
    });
  });

  group('recorder', () {
    late FakeCamera camera;
    late ScannerController controller;
    late FrameRecorder recorder;

    setUp(() async {
      camera = FakeCamera();
      ScannerControllerDebug.cameraFactory = () => camera;
      controller = ScannerController();
      recorder = FrameRecorder()..attach(controller);
      await controller.start();
    });

    tearDown(() {
      recorder.dispose();
      controller.dispose();
      ScannerControllerDebug.cameraFactory = null;
    });

    PixelBuffer pixels() =>
        PixelBuffer(Uint8List(640 * 480), width: 640, height: 480);

    test('keeps nothing until it is armed', () async {
      camera.push(const <Barcode>[], null, false, pixels());
      await pumpEventQueue();
      expect(recorder.frameCount, 0);
      expect(recorder.take(const DiagSettings()), isNull);
    });

    test('keeps the decoded window with what was read', () async {
      recorder.armed = true;
      camera.push(
        <Barcode>[fakeBarcode('code', const Rect.fromLTWH(200, 200, 80, 80))],
        null,
        false,
        pixels(),
      );
      await pumpEventQueue();
      expect(recorder.frameCount, 1);
      final RecordedFrame frame = recorder
          .take(const DiagSettings(tryInvert: true))!
          .frames
          .single;
      expect(frame.pixels, hasLength(frame.width * frame.height));
      expect(frame.reads.single.text, 'code');
    });

    test('disarming lets go of the frames', () async {
      recorder.armed = true;
      camera.push(const <Barcode>[], null, false, pixels());
      await pumpEventQueue();
      recorder.armed = false;
      expect(recorder.frameCount, 0);
      expect(recorder.bytes, 0);
    });
  });

  group('page', () {
    late FakeCamera camera;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => Directory.systemTemp.createTempSync('diag').path,
          );
      camera = FakeCamera();
      ScannerControllerDebug.cameraFactory = () => camera;
    });

    tearDown(() => ScannerControllerDebug.cameraFactory = null);

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const DiagnosticsPage()),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a switch changes the next frame\'s read', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.runAsync(() async {
        camera.push();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      final Finder invert = find.widgetWithText(SwitchListTile, 'tryInvert');
      await tester.ensureVisible(invert);
      await tester.pump();
      await tester.tap(invert);
      await tester.pump();
      late FakeFrame frame;
      await tester.runAsync(() async {
        frame = camera.push();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      expect(frame.options!.flags & FzxFlags.tryInvert, FzxFlags.tryInvert);
      await close(tester);
    });

    testWidgets('the numbers follow the decoded frames', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.runAsync(() async {
        for (int i = 0; i < 6; i++) {
          camera.push(<Barcode>[
            fakeBarcode('code', const Rect.fromLTWH(200, 200, 80, 80)),
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('100%'), findsOneWidget);
      await close(tester);
    });

    for (final Size size in const <Size>[Size(393, 851), Size(851, 393)]) {
      testWidgets('fits a ${size.width.round()}×${size.height.round()} '
          'screen with the numbers open', (WidgetTester tester) async {
        await open(tester);
        tester.view.physicalSize = size * tester.view.devicePixelRatio;
        await tester.pump();
        await tester.tap(find.byType(ExpansionTile));
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        await close(tester);
      });
    }

    testWidgets('opened from another page, it leads back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DiagnosticsPage(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byIcon(Icons.arrow_back));
      for (int i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(DiagnosticsPage), findsNothing);
      await close(tester);
    });

    testWidgets('an A/B run shows both sides', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pump();
      expect(find.text('Edit A'), findsOneWidget);
      expect(find.text('Edit B'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.compare_arrows));
      await tester.pump();
      expect(find.text('Edit B'), findsNothing);
      await close(tester);
    });

    testWidgets('a saved run appears in the list', (WidgetTester tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.bookmark_add_outlined));
      await tester.pump();
      await tester.tap(find.text('Runs'));
      // The tabs slide over; the scanner's window keeps animating.
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('1 saved'), findsOneWidget);
      await close(tester);
    });
  });
}
