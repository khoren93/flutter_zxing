// ScannerController on a fake camera: lifecycle, detection modes, the scan
// window, torch, zoom and errors.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/frame_geometry.dart';
import 'package:flutter_zxing/src/scanning/scanner_controller.dart'
    show ScannerControllerDebug, ScannerFrameSample;

import 'fake_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCamera camera;
  late DateTime now;
  final List<ScannerController> controllers = <ScannerController>[];

  ScannerController create({
    DetectionMode detection = DetectionMode.distinct,
    ScanWindow scanWindow = const ScanWindow.centered(),
  }) {
    final ScannerController c = ScannerController(
      detection: detection,
      scanWindow: scanWindow,
      pauseInBackground: false,
    );
    controllers.add(c);
    return c;
  }

  setUp(() {
    camera = FakeCamera();
    now = DateTime(2026, 11, 15, 12);
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

  /// A barcode in the middle of the default scan window.
  final Barcode qr = fakeBarcode(
    'hello',
    const Rect.fromLTWH(200, 200, 80, 80),
  );

  group('lifecycle', () {
    test('start opens the camera and reports what it can do', () async {
      final ScannerController c = create();
      expect(c.value.status, ScannerStatus.idle);
      await c.start();
      expect(c.value.status, ScannerStatus.running);
      expect(c.value.isScanning, isTrue);
      expect(c.value.torch, TorchState.off);
      expect(c.value.maxZoom, 4);
      expect(c.value.previewSize, const Size(480, 640));
      expect(camera.opened, <CameraFacing>[CameraFacing.back]);
    });

    test('stop releases the camera', () async {
      final ScannerController c = create();
      await c.start();
      await c.stop();
      expect(c.value.status, ScannerStatus.idle);
      expect(camera.isOpen, isFalse);
    });

    test('a denied permission is reported in the state', () async {
      camera.openError = const CameraPermissionException();
      final ScannerController c = create();
      await c.start();
      expect(c.value.status, ScannerStatus.error);
      expect(c.value.error, isA<CameraPermissionException>());
      // Starting again tries again.
      await c.start();
      expect(c.value.status, ScannerStatus.running);
      expect(c.value.error, isNull);
    });

    test('switchCamera reopens the other camera', () async {
      final ScannerController c = create();
      await c.start();
      await c.switchCamera();
      expect(camera.opened, <CameraFacing>[
        CameraFacing.back,
        CameraFacing.front,
      ]);
      expect(c.value.facing, CameraFacing.front);
      expect(c.value.status, ScannerStatus.running);
      await c.switchCamera(CameraFacing.front); // already: nothing
      expect(camera.opened, hasLength(2));
    });

    test('an engine that keeps failing stops the scanner', () async {
      final ScannerController c = create();
      await c.start();
      for (int i = 0; i < 3; i++) {
        camera.push(const <Barcode>[], const EngineException('crashed'));
        await pumpEventQueue();
      }
      expect(c.value.status, ScannerStatus.error);
      expect(c.value.error, isA<CameraFailureException>());
      expect(camera.isOpen, isFalse);
    });
  });

  group('detection', () {
    test('distinct reports a barcode once while it stays in view', () async {
      final ScannerController c = create();
      final List<BarcodeCapture> captures = <BarcodeCapture>[];
      c.barcodes.listen(captures.add);
      await c.start();
      for (int i = 0; i < 3; i++) {
        camera.push(<Barcode>[qr]);
        await pumpEventQueue();
        now = now.add(const Duration(milliseconds: 100));
      }
      expect(captures, hasLength(1));
      // Out of view for a moment, then back: reported again.
      now = now.add(const Duration(seconds: 2));
      camera.push();
      await pumpEventQueue();
      camera.push(<Barcode>[qr]);
      await pumpEventQueue();
      expect(captures, hasLength(2));
    });

    test('continuous reports every frame', () async {
      final ScannerController c = create(detection: DetectionMode.continuous);
      final List<BarcodeCapture> captures = <BarcodeCapture>[];
      c.barcodes.listen(captures.add);
      await c.start();
      for (int i = 0; i < 3; i++) {
        camera.push(<Barcode>[qr]);
        await pumpEventQueue();
      }
      expect(captures, hasLength(3));
    });

    test('once pauses after the first barcode until resume', () async {
      final ScannerController c = create(detection: DetectionMode.once);
      final List<BarcodeCapture> captures = <BarcodeCapture>[];
      c.barcodes.listen(captures.add);
      await c.start();
      camera.push(<Barcode>[qr]);
      await pumpEventQueue();
      expect(captures, hasLength(1));
      expect(c.value.status, ScannerStatus.paused);
      final FakeFrame skipped = camera.push(<Barcode>[qr]);
      await pumpEventQueue();
      expect(skipped.wasRead, isFalse);
      await c.resume();
      camera.push(<Barcode>[qr]);
      await pumpEventQueue();
      expect(captures, hasLength(2));
    });

    test('positions are reported in the frame as it is shown', () async {
      final ScannerController c = create(detection: DetectionMode.continuous);
      final Completer<BarcodeCapture> capture = Completer<BarcodeCapture>();
      c.barcodes.listen(capture.complete);
      await c.start();
      camera.push(<Barcode>[qr]);
      final BarcodeCapture result = await capture.future;
      // The fake camera turns its 640x480 frames by 90 degrees.
      expect(result.imageSize, const Size(480, 640));
      expect(
        result.barcode.position.topLeft,
        const FrameTransform(
          Size(640, 480),
          rotation: 90,
        ).toDisplay(const Offset(200, 200)),
      );
    });

    test('looks for the first barcode unless told otherwise', () async {
      final ScannerController c = create();
      await c.start();
      final FakeFrame first = camera.push();
      await pumpEventQueue();
      expect(first.options!.maxSymbols, 1);
      c.maxBarcodes = null;
      final FakeFrame all = camera.push();
      await pumpEventQueue();
      expect(all.options!.maxSymbols, 0);
      c.maxBarcodes = 5;
      final FakeFrame five = camera.push();
      await pumpEventQueue();
      expect(five.options!.maxSymbols, 5);
      expect(() => c.maxBarcodes = 0, throwsRangeError);
    });

    test('changing the formats applies to the next frame', () async {
      final ScannerController c = create();
      await c.start();
      c.formats = <BarcodeFormat>{BarcodeFormat.ean13};
      expect(c.formats, <BarcodeFormat>{BarcodeFormat.ean13});
    });
  });

  group('scan window', () {
    test('only the window is decoded, in the frame as delivered', () async {
      final ScannerController c = create();
      await c.start();
      final FakeFrame frame = camera.push();
      await pumpEventQueue();
      // 70% of the 480 x 640 display frame, centred: 336 x 336 at (72, 152);
      // in the 640 x 480 frame, turned back, (152, 72) to (488, 408).
      expect(frame.crop, const Rect.fromLTRB(152, 72, 488, 408));
    });

    test('the full window decodes the whole frame', () async {
      final ScannerController c = create(scanWindow: const ScanWindow.full());
      await c.start();
      final FakeFrame frame = camera.push();
      await pumpEventQueue();
      expect(frame.wasRead, isTrue);
      expect(frame.crop, isNull);
    });
  });

  group('camera controls', () {
    test(
      'the torch toggles, and disappears if the camera rejects it',
      () async {
        final ScannerController c = create();
        await c.start();
        await c.toggleTorch();
        expect(c.value.torch, TorchState.on);
        expect(camera.torch, isTrue);
        await c.toggleTorch();
        expect(c.value.torch, TorchState.off);
        camera.torchError = const CameraFailureException('no torch');
        await c.setTorch(true);
        expect(c.value.torch, TorchState.unavailable);
      },
    );

    test('zoom is clamped to what the camera can do', () async {
      final ScannerController c = create();
      await c.start();
      await c.setZoom(10);
      expect(c.value.zoom, 4);
      expect(camera.zoom, 4);
      await c.setZoom(0.2);
      expect(c.value.zoom, 1);
    });

    group('lenses', () {
      test('below 1: the ultra-wide camera, without a restart', () async {
        camera.capabilities = const CameraCapabilities(
          hasTorch: true,
          maxZoom: 10,
          ultraWide: 0.5,
        );
        final ScannerController c = create();
        final List<ScannerStatus> statuses = <ScannerStatus>[];
        await c.start();
        expect(c.value.minZoom, 0.5);
        await c.setTorch(true);
        c.addListener(() => statuses.add(c.value.status));
        await c.setZoom(0.5);
        expect(camera.lenses, <CameraLens>[
          CameraLens.main,
          CameraLens.ultraWide,
        ]);
        expect(camera.zoom, 1);
        expect(c.value.zoom, 0.5);
        expect(camera.torch, isTrue);
        expect(statuses, everyElement(ScannerStatus.running));
        // Frames come from the new lens.
        final FakeFrame frame = camera.push();
        await pumpEventQueue();
        expect(frame.wasRead, isTrue);

        await c.setZoom(0.7);
        expect(camera.lenses, hasLength(2), reason: 'same lens');
        expect(camera.zoom, closeTo(1.4, 1e-9));
        await c.setZoom(2);
        expect(camera.lenses, <CameraLens>[
          CameraLens.main,
          CameraLens.ultraWide,
          CameraLens.main,
        ]);
        expect(camera.zoom, 2);
        expect(c.value.zoom, 2);
      });

      test('zooms sent while a lens opens: only the last one', () async {
        camera.capabilities = const CameraCapabilities(
          maxZoom: 10,
          ultraWide: 0.5,
        );
        final ScannerController c = create();
        await c.start();
        // A pinch across 1×: none of these is awaited.
        final List<Future<void>> zooms = <Future<void>>[
          for (final double z in <double>[0.5, 1.2, 0.6, 1.5, 0.8, 3])
            c.setZoom(z),
        ];
        await Future.wait(zooms);
        expect(camera.lenses, <CameraLens>[
          CameraLens.main,
          CameraLens.ultraWide,
          CameraLens.main,
        ]);
        expect(c.value.zoom, 3);
        expect(camera.zoom, 3);
        expect(c.value.status, ScannerStatus.running);
        final FakeFrame frame = camera.push();
        await pumpEventQueue();
        expect(frame.wasRead, isTrue);
      });
    });

    test('focus points are clamped to the preview', () async {
      final ScannerController c = create();
      await c.start();
      await c.setFocusPoint(const Offset(1.5, 0.25));
      expect(camera.focus, const Offset(1, 0.25));
    });
  });

  group('hooks of the diagnostics page', () {
    test('engine flags reach every read', () async {
      final ScannerController c = create();
      await c.start();
      final int flags = fzxDownscaleFlags(factor: 2, threshold: 240);
      c.engineFlags = flags;
      final FakeFrame frame = camera.push();
      await pumpEventQueue();
      expect(frame.options!.flags & flags, flags);
    });

    test('a read interval spaces the reads', () async {
      final ScannerController c = create();
      await c.start();
      c.readInterval = const Duration(milliseconds: 40);
      camera.push();
      await pumpEventQueue();
      final FakeFrame next = camera.push();
      await pumpEventQueue();
      expect(next.wasRead, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(next.wasRead, isTrue);
    });

    test('frame samples count the codes that were not decoded', () async {
      final ScannerController c = create();
      final List<ScannerFrameSample> samples = <ScannerFrameSample>[];
      c.frameSamples.listen(samples.add);
      await c.start();
      camera.push(<Barcode>[
        qr,
        Barcode(
          format: BarcodeFormat.qrCode,
          text: '',
          bytes: qr.bytes,
          position: qr.position,
          error: const BarcodeError(BarcodeErrorKind.checksum, 'damaged'),
        ),
      ]);
      await pumpEventQueue();
      expect(samples.single.failed, 1);
      expect(samples.single.found, isTrue);
    });
  });
}
