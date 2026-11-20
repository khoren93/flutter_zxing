// ScannerController on a fake camera: lifecycle, detection modes, the scan
// window, torch, zoom and errors.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
      stopInBackground: false,
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
      expect(c.facing, CameraFacing.front);
      expect(c.value.status, ScannerStatus.running);
      await c.switchCamera(CameraFacing.front); // already: nothing
      expect(camera.opened, hasLength(2));
    });

    test('switchCamera without another camera does nothing', () async {
      camera.capabilities = const CameraCapabilities(hasTorch: true);
      final ScannerController c = create();
      expect(c.value.canSwitchCamera, isFalse, reason: 'not known yet');
      await c.start();
      expect(c.value.canSwitchCamera, isFalse);
      await c.switchCamera();
      expect(camera.opened, <CameraFacing>[CameraFacing.back]);
      expect(c.facing, CameraFacing.back);
      expect(c.value.status, ScannerStatus.running);
      // Kept while the camera is closed.
      await c.stop();
      await c.switchCamera(CameraFacing.front);
      expect(c.facing, CameraFacing.back);
    });

    test('canSwitchCamera reports the other camera', () async {
      final ScannerController c = create();
      await c.start();
      expect(c.value.canSwitchCamera, isTrue);
      await c.stop();
      expect(c.value.canSwitchCamera, isTrue, reason: 'kept while closed');
    });

    test(
      'a camera missing only when opened: the old one opens again',
      () async {
        // The capabilities claim a front camera that does not open.
        camera.missing = <CameraFacing>{CameraFacing.front};
        final ScannerController c = create();
        await c.start();
        await c.pause();
        await c.switchCamera();
        expect(camera.opened, <CameraFacing>[
          CameraFacing.back,
          CameraFacing.front,
          CameraFacing.back,
        ]);
        expect(c.facing, CameraFacing.back);
        expect(c.value.status, ScannerStatus.paused);
        expect(c.value.error, isNull);
        expect(c.value.canSwitchCamera, isFalse);
      },
    );

    test('facing follows switchCamera while the camera is closed', () async {
      final ScannerController c = create();
      expect(c.facing, CameraFacing.back);
      await c.switchCamera();
      expect(c.facing, CameraFacing.front);
      expect(c.value.facing, CameraFacing.front);
      await c.start();
      expect(camera.opened, <CameraFacing>[CameraFacing.front]);
    });

    group('while the camera opens', () {
      test('dispose leaves no camera open', () async {
        final ScannerController c = ScannerController(stopInBackground: false);
        camera.openGate = Completer<void>();
        final Future<void> started = c.start();
        c.dispose();
        camera.openGate!.complete();
        await started;
        await pumpEventQueue();
        expect(camera.isOpen, isFalse);
        expect(camera.closed, greaterThanOrEqualTo(1));
        expect(camera.disposed, isTrue);
        final FakeFrame frame = camera.push();
        await pumpEventQueue();
        expect(frame.wasRead, isFalse);
      });

      test('stop leaves the camera closed', () async {
        final ScannerController c = create();
        camera.openGate = Completer<void>();
        final Future<void> started = c.start();
        final Future<void> stopped = c.stop();
        camera.openGate!.complete();
        await started;
        await stopped;
        expect(c.value.status, ScannerStatus.idle);
        expect(camera.isOpen, isFalse);
      });

      test('switchCamera opens the other camera', () async {
        final ScannerController c = create();
        camera.openGate = Completer<void>();
        final Future<void> started = c.start();
        final Future<void> switched = c.switchCamera();
        camera.openGate!.complete();
        await started;
        await switched;
        expect(camera.opened, <CameraFacing>[
          CameraFacing.back,
          CameraFacing.front,
        ]);
        expect(c.value.status, ScannerStatus.running);
        expect(c.value.facing, CameraFacing.front);
        expect(camera.isOpen, isTrue);
      });

      test('a stop and a start keep the camera of the start', () async {
        final ScannerController c = create();
        camera.openGate = Completer<void>();
        final Future<void> first = c.start();
        unawaited(c.stop());
        final Future<void> second = c.start();
        camera.openGate!.complete();
        await first;
        await second;
        await pumpEventQueue();
        expect(c.value.status, ScannerStatus.running);
        expect(camera.isOpen, isTrue);
        final FakeFrame frame = camera.push(<Barcode>[qr]);
        await pumpEventQueue();
        expect(frame.wasRead, isTrue);
      });
    });

    group('while a lens switch closes the camera', () {
      setUp(() {
        camera.capabilities = const CameraCapabilities(
          maxZoom: 10,
          ultraWide: 0.5,
        );
      });

      test('stop leaves the camera closed', () async {
        final ScannerController c = create();
        await c.start();
        camera.closeGate = Completer<void>();
        final Future<void> zoomed = c.setZoom(0.5);
        await pumpEventQueue();
        final Future<void> stopped = c.stop();
        camera.closeGate!.complete();
        await zoomed;
        await stopped;
        await pumpEventQueue();
        expect(c.value.status, ScannerStatus.idle);
        expect(camera.isOpen, isFalse);
        expect(camera.lenses, <CameraLens>[CameraLens.main]);
      });

      test('dispose leaves the camera closed', () async {
        final ScannerController c = ScannerController(stopInBackground: false);
        await c.start();
        camera.closeGate = Completer<void>();
        final Future<void> zoomed = c.setZoom(0.5);
        await pumpEventQueue();
        c.dispose();
        camera.closeGate!.complete();
        await zoomed;
        await pumpEventQueue();
        expect(camera.isOpen, isFalse);
      });
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

  group('camera errors', () {
    test('a camera taken by another app stops the scanner', () async {
      final ScannerController c = create();
      await c.start();
      camera.fail(const CameraInUseException());
      await pumpEventQueue();
      expect(c.value.status, ScannerStatus.error);
      expect(c.value.error, isA<CameraInUseException>());
      expect(camera.isOpen, isFalse);
    });

    test('platform errors map to the exception that fits', () {
      final Map<(String, String?), Type> cases = <(String, String?), Type>{
        ('CameraAccessDenied', 'denied'): CameraPermissionException,
        ('NotAllowedError', null): CameraPermissionException,
        ('NotFoundError', null): CameraNotFoundException,
        ('OverconstrainedError', null): CameraNotFoundException,
        // camera_desktop.
        ('camera_not_found', 'No camera'): CameraNotFoundException,
        ('no_camera', null): CameraNotFoundException,
        ('NotReadableError', 'Could not start video source'):
            CameraInUseException,
        ('CameraAccess', 'CAMERA_IN_USE (4): connect'): CameraInUseException,
        (
          'cameraError',
          'The camera was already in use, possibly by a higher-priority '
              'camera client.',
        ): CameraInUseException,
        (
          'cameraError',
          'The limit number of open cameras has been reached, and more '
              'cameras cannot be opened until other instances are closed.',
        ): CameraInUseException,
        ('SecurityError', null): CameraUnsupportedException,
        ('NotSupportedError', null): CameraUnsupportedException,
        ('AbortError', null): CameraFailureException,
        ('cameraError', 'Configuring the camera has failed.'):
            CameraFailureException,
      };
      cases.forEach(((String, String?) input, Type type) {
        expect(
          cameraError(input.$1, input.$2).runtimeType,
          type,
          reason: '$input',
        );
      });
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

    test('an empty or unreadable filter throws at once', () {
      for (final Set<BarcodeFormat> formats in <Set<BarcodeFormat>>[
        <BarcodeFormat>{},
        <BarcodeFormat>{BarcodeFormat.isbn},
        <BarcodeFormat>{BarcodeFormat.qrCode, BarcodeFormat.ean2},
        <BarcodeFormat>{BarcodeFormat.unknown},
      ]) {
        expect(
          () => ScannerController(formats: formats),
          throwsArgumentError,
          reason: '$formats',
        );
      }
      final ScannerController c = create();
      c.formats = <BarcodeFormat>{BarcodeFormat.qrCode};
      expect(
        () => c.formats = <BarcodeFormat>{BarcodeFormat.isbn},
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            contains('isbn'),
          ),
        ),
      );
      expect(() => c.formats = <BarcodeFormat>{}, throwsArgumentError);
      // The filter in use stays.
      expect(c.formats, <BarcodeFormat>{BarcodeFormat.qrCode});
      c.formats = null;
      expect(c.formats, isNull);
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

    test('a centered window of no size is refused', () {
      double none() => 0;
      expect(
        () => ScanWindow.centered(aspectRatio: none()),
        throwsAssertionError,
      );
      expect(() => ScanWindow.centered(width: none()), throwsAssertionError);
      expect(
        ScanWindow.centered(width: 1 + none()).resolve(const Size(100, 100)),
        const Rect.fromLTWH(0, 0, 100, 100),
      );
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

      test('the torch switched while a lens opens comes on there', () async {
        camera.capabilities = const CameraCapabilities(
          hasTorch: true,
          maxZoom: 10,
          ultraWide: 0.5,
        );
        final ScannerController c = create();
        await c.start();
        camera.closeGate = Completer<void>();
        final Future<void> zoomed = c.setZoom(0.5);
        await pumpEventQueue();
        await c.setTorch(true);
        camera.closeGate!.complete();
        await zoomed;
        expect(camera.lenses.last, CameraLens.ultraWide);
        expect(camera.torch, isTrue);
        expect(c.value.torch, TorchState.on);
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

  group('initial zoom and torch', () {
    ScannerController make({double? initialZoom, bool torch = false}) {
      final ScannerController c = ScannerController(
        stopInBackground: false,
        initialZoom: initialZoom,
        torch: torch,
      );
      controllers.add(c);
      return c;
    }

    test('every start zooms to the initial zoom', () async {
      final ScannerController c = make(initialZoom: 2);
      await c.start();
      expect(c.value.zoom, 2);
      expect(camera.zoom, 2);
      await c.setZoom(3);
      await c.switchCamera();
      expect(c.value.zoom, 2, reason: 'after switchCamera');
      await c.stop();
      await c.start();
      expect(c.value.zoom, 2, reason: 'after stop and start');
      // Clamped to what the camera can do.
      final ScannerController far = make(initialZoom: 10);
      await far.start();
      expect(far.value.zoom, 4);
    });

    test('changing the initial zoom while open zooms there', () async {
      final ScannerController c = make();
      await c.start();
      expect(c.value.zoom, 1);
      c.initialZoom = 3;
      await pumpEventQueue();
      expect(c.value.zoom, 3);
      c.initialZoom = null;
      await pumpEventQueue();
      expect(c.value.zoom, 1);
    });

    test('the initial zoom leaves automatic zoom on', () async {
      camera
        ..capabilities = const CameraCapabilities(
          maxZoom: 10,
          ultraWide: 0.5,
          ultraWideFocusesCloser: true,
        )
        ..lens = 0.3;
      final ScannerController c = make(initialZoom: 2);
      await c.start();
      expect(c.value.autoZoom, AutoZoomState.on);
      expect(c.value.zoom, 2);
      await c.setZoom(1.5);
      expect(c.value.autoZoom, AutoZoomState.off, reason: 'zoomed by hand');
    });

    test('a stop while the torch comes on leaves the closed state', () async {
      final ScannerController c = make(torch: true);
      camera.torchGate = Completer<void>();
      final Future<void> started = c.start();
      await pumpEventQueue();
      await c.stop();
      camera.torchGate!.complete();
      await started;
      expect(c.value.status, ScannerStatus.idle);
      expect(c.value.torch, const ScannerState().torch);
    });

    test('the torch comes on at every start and keeps the choice', () async {
      final ScannerController c = make(torch: true);
      await c.start();
      expect(c.value.torch, TorchState.on);
      expect(camera.torch, isTrue);
      await c.stop();
      await c.start();
      expect(c.value.torch, TorchState.on, reason: 'opened again');
      await c.setTorch(false);
      await c.stop();
      await c.start();
      expect(c.value.torch, TorchState.off, reason: 'turned off by hand');
      await c.setTorch(true);
      // The front camera has no torch; back on the back camera it is on.
      camera.capabilities = const CameraCapabilities(hasOtherFacing: true);
      await c.switchCamera();
      expect(c.value.torch, TorchState.unavailable);
      camera.capabilities = const CameraCapabilities(
        hasTorch: true,
        hasOtherFacing: true,
      );
      await c.switchCamera();
      expect(c.value.torch, TorchState.on);
    });
  });

  group('templates', () {
    test('fromTemplate takes the camera settings of the template', () {
      const ScannerTemplate small = ScannerTemplate.small();
      final ScannerController c = ScannerController.fromTemplate(small);
      controllers.add(c);
      expect(c.formats, small.formats);
      expect(c.scanWindow, small.scanWindow);
      expect(c.detection, small.detection);
      expect(c.maxBarcodes, small.maxBarcodes);
      expect(c.initialZoom, 2);
      expect(c.facing, CameraFacing.back);

      final ScannerController kiosk = ScannerController.fromTemplate(
        const ScannerTemplate.kiosk(),
        autoStart: false,
      );
      controllers.add(kiosk);
      expect(kiosk.facing, CameraFacing.front);
      expect(kiosk.autoStart, isFalse);
    });
  });

  group('lastFrameImage', () {
    testWidgets('the last decoded frame in color, as the preview shows it', (
      WidgetTester tester,
    ) async {
      final ScannerController c = create();
      await tester.runAsync(() async {
        await c.start();
        expect(await c.lastFrameImage(), isNull, reason: 'no frame yet');
        camera.push(
          const <Barcode>[],
          null,
          false,
          PixelBuffer(Uint8List(640 * 480), width: 640, height: 480),
        );
        await pumpEventQueue();
        final ui.Image? image = await c.lastFrameImage();
        // The frame is turned a quarter: 480 × 640 on screen.
        expect(image?.width, 480);
        expect(image?.height, 640);
        image?.dispose();
      });
    });

    test('let go of when the camera stops or switches', () async {
      final ScannerController c = create();
      PixelBuffer pixels() =>
          PixelBuffer(Uint8List(640 * 480), width: 640, height: 480);
      await c.start();
      camera.push(const <Barcode>[], null, false, pixels());
      await pumpEventQueue();
      await c.switchCamera();
      expect(await c.lastFrameImage(), isNull, reason: 'another camera');
      camera.push(const <Barcode>[], null, false, pixels());
      await pumpEventQueue();
      await c.stop();
      expect(await c.lastFrameImage(), isNull, reason: 'stopped');
    });

    test('null where frames are not in memory', () async {
      final ScannerController c = create();
      await c.start();
      camera.push();
      await pumpEventQueue();
      expect(await c.lastFrameImage(), isNull);
    });
  });
}
