// Automatic zoom and the physical cameras: the step rule (auto_lens.dart)
// and ScannerController on a fake camera that reports its lens position.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/auto_lens.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug;

import 'fake_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('autoLensTarget', () {
    // Its own numbers: AutoLensTuning is for tuning on a phone.
    const List<AutoLensStep> steps = <AutoLensStep>[
      AutoLensStep(CameraLens.ultraWide, up: 0.7),
      AutoLensStep(CameraLens.main, down: 0.05, up: 0.5),
      AutoLensStep(CameraLens.main, zoom: 2, down: 0.3, up: 0.8),
      AutoLensStep(CameraLens.telephoto, down: 0.05),
    ];
    final AutoLensZooms all = autoLensZooms(ultraWide: 0.5, telephoto: 4);
    double? target(double zoom, double lens, [AutoLensZooms? zooms]) =>
        autoLensTarget(zoom, lens, zooms ?? all, steps: steps);

    test('the main camera at its nearest focus: the ultra-wide camera', () {
      expect(target(1, 0), 0.5);
      expect(target(1, 0.05), 0.5);
      expect(target(1, 0.1), isNull);
    });

    test('the ultra-wide camera focused far: back to the main one', () {
      expect(target(0.5, 0.65), isNull);
      expect(target(0.5, 0.8), 1);
    });

    test('farther: the main camera at 2×, then the telephoto camera', () {
      expect(target(1, 0.6), 2);
      expect(target(2, 0.6), isNull, reason: 'between the thresholds');
      expect(target(2, 0.9), 4);
      expect(target(2, 0.2), 1);
      expect(target(4, 0.6), isNull);
      expect(target(4, 0.02), 2);
    });

    test('cameras a phone does not have are skipped', () {
      expect(target(1, 0, autoLensZooms()), isNull);
      expect(target(2, 0.9, autoLensZooms(ultraWide: 0.5)), isNull);
      expect(target(2, 0.9, autoLensZooms(telephoto: 5)), 5);
    });

    test('a 2× telephoto camera replaces the main camera at 2×', () {
      final AutoLensZooms zooms = autoLensZooms(telephoto: 2);
      expect(target(1, 0.6, zooms), 2);
      expect(target(2, 0.02, zooms), 1, reason: 'the telephoto step');
    });

    test('a zoom set by hand is not a camera', () {
      expect(target(1.6, 0), isNull);
      expect(isAutoLensZoom(1.6, all), isFalse);
      expect(isAutoLensZoom(4, all), isTrue);
      expect(isAutoLensZoom(2, all), isTrue);
    });
  });

  group('ScannerController', () {
    late FakeCamera camera;
    late DateTime now;
    final List<ScannerController> controllers = <ScannerController>[];

    setUp(() {
      camera = FakeCamera()
        ..capabilities = const CameraCapabilities(
          maxZoom: 10,
          ultraWide: 0.5,
          ultraWideFocusesCloser: true,
          telephoto: 4,
        )
        ..lens = 0.3;
      now = DateTime(2026, 11, 17, 12);
      ScannerControllerDebug.cameraFactory = () => camera;
      ScannerControllerDebug.clock = () => now;
    });

    tearDown(() {
      for (final ScannerController c in controllers) {
        c.dispose();
      }
      controllers.clear();
      ScannerControllerDebug.cameraFactory = null;
      ScannerControllerDebug.clock = null;
    });

    Future<ScannerController> started({bool autoZoom = true}) async {
      final ScannerController c = ScannerController(
        pauseInBackground: false,
        autoZoom: autoZoom,
      );
      controllers.add(c);
      await c.start();
      return c;
    }

    /// [count] frames, [step] apart.
    Future<void> frames(
      int count, {
      Duration step = const Duration(milliseconds: 100),
      List<Barcode> barcodes = const <Barcode>[],
    }) async {
      for (int i = 0; i < count; i++) {
        now = now.add(step);
        camera.push(barcodes);
        await pumpEventQueue();
      }
    }

    test('on by default where the camera reports its focus', () async {
      final ScannerController c = await started();
      expect(c.value.autoZoom, AutoZoomState.on);
      expect(c.value.telephotoZoom, 4);
    });

    test('unavailable without a lens position', () async {
      camera.lens = null;
      final ScannerController c = await started();
      expect(c.value.autoZoom, AutoZoomState.unavailable);
      await c.setAutoZoom(true);
      expect(c.value.autoZoom, AutoZoomState.unavailable);
    });

    test('too close: the ultra-wide camera, and back when farther', () async {
      final ScannerController c = await started();
      camera.lens = 0;
      await frames(3);
      expect(camera.lenses, <CameraLens>[
        CameraLens.main,
      ], reason: 'held 400 ms first');
      await frames(5);
      expect(camera.lenses, <CameraLens>[
        CameraLens.main,
        CameraLens.ultraWide,
      ]);
      expect(c.value.zoom, 0.5);

      // The ultra-wide camera focuses farther than the main one could.
      camera.lens = 0.9;
      await frames(10);
      expect(camera.lenses, hasLength(2), reason: 'settling');
      await frames(20);
      expect(camera.lenses.last, CameraLens.main);
      expect(c.value.zoom, 1);
      expect(c.value.autoZoom, AutoZoomState.on);
    });

    test('far: 2×, then the telephoto camera; back when too close', () async {
      final ScannerController c = await started();
      camera.lens = 0.9;
      await frames(15);
      expect(camera.lenses, <CameraLens>[CameraLens.main]);
      expect(c.value.zoom, 2, reason: "the main camera's own 2×");
      await frames(30);
      expect(camera.lenses.last, CameraLens.telephoto);
      expect(camera.zoom, 1, reason: "the telephoto camera's own 1×");
      expect(c.value.zoom, 4);

      camera.lens = 0;
      await frames(25);
      expect(camera.lenses.last, CameraLens.main);
      expect(c.value.zoom, 2);
    });

    test('a fixed-focus ultra-wide camera is no help close up', () async {
      camera.capabilities = const CameraCapabilities(
        maxZoom: 10,
        ultraWide: 0.5,
        telephoto: 4,
      );
      final ScannerController c = await started();
      expect(c.value.minZoom, 0.5, reason: 'still a 0.5× preset');
      camera.lens = 0;
      await frames(20);
      expect(camera.lenses, <CameraLens>[CameraLens.main]);
      expect(c.value.zoom, 1);
    });

    test('one camera: 2× of it when far', () async {
      camera.capabilities = const CameraCapabilities(maxZoom: 10);
      final ScannerController c = await started();
      expect(c.value.autoZoom, AutoZoomState.on);
      camera.lens = 0.9;
      await frames(15);
      expect(c.value.zoom, 2);
      expect(camera.lenses, <CameraLens>[CameraLens.main]);
    });

    test('no change while codes are being read', () async {
      final ScannerController c = await started();
      camera.lens = 0;
      await frames(
        20,
        barcodes: <Barcode>[
          fakeBarcode('x', const Rect.fromLTWH(200, 200, 80, 80)),
        ],
      );
      expect(camera.lenses, <CameraLens>[CameraLens.main]);
      expect(c.value.zoom, 1);
    });

    test('zooming by hand turns it off; turning it on starts at 1×', () async {
      final ScannerController c = await started();
      await c.setZoom(1.6);
      expect(c.value.autoZoom, AutoZoomState.off);
      camera.lens = 0;
      await frames(20);
      expect(c.value.zoom, 1.6);

      camera.lens = 0.3;
      await c.toggleAutoZoom();
      expect(c.value.autoZoom, AutoZoomState.on);
      expect(c.value.zoom, 1);
    });

    test('off from the start when asked', () async {
      final ScannerController c = await started(autoZoom: false);
      expect(c.value.autoZoom, AutoZoomState.off);
      camera.lens = 0;
      await frames(20);
      expect(camera.lenses, <CameraLens>[CameraLens.main]);
    });

    test('zooms from the telephoto camera on use it', () async {
      final ScannerController c = await started(autoZoom: false);
      await c.setZoom(4);
      expect(camera.lenses.last, CameraLens.telephoto);
      expect(camera.zoom, 1);
      await c.setZoom(6);
      expect(camera.lenses, hasLength(2), reason: 'same camera');
      expect(camera.zoom, closeTo(1.5, 1e-9));
      expect(c.value.zoom, 6);
      await c.setZoom(3);
      expect(camera.lenses.last, CameraLens.main);
      expect(camera.zoom, 3);
    });
  });
}
