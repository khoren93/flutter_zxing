import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraController, CameraPreview;
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A camera platform that behaves like a real one for the parts [ReaderWidget]
/// drives: two lenses, an image stream, a preview widget and zoom/flash.
class FakeCameraPlatform extends CameraPlatform
    with MockPlatformInterfaceMixin {
  FakeCameraPlatform({
    this.flashModeSupported = true,
    this.zoomLevelsSupported = true,
    this.minZoomLevel = 1.0,
    this.maxZoomLevel = 4.0,
  });

  /// Devices without a torch make `setFlashMode` throw `setFlashModeFailed`.
  final bool flashModeSupported;

  /// Some devices reject the zoom queries, which used to abort camera setup.
  final bool zoomLevelsSupported;

  /// The zoom range every camera reports.
  final double minZoomLevel;
  final double maxZoomLevel;

  /// The zoom level last applied to each camera.
  final Map<int, double> zoomLevels = <int, double>{};

  int _nextId = 1;
  final Set<int> disposedCameras = <int>{};
  int createdCameras = 0;

  /// Preview widgets built for a camera that was already disposed. Building one
  /// is exactly the failure reported in the camera-toggle crash.
  int previewsBuiltForDisposedCamera = 0;

  final Map<int, StreamController<CameraInitializedEvent>> _initialized =
      <int, StreamController<CameraInitializedEvent>>{};
  final Map<int, StreamController<CameraImageData>> _frames =
      <int, StreamController<CameraImageData>>{};
  // `CameraController.initialize` awaits `onCameraError(...).first`, so this
  // has to stay open rather than being an already-closed empty stream.
  final Map<int, StreamController<CameraErrorEvent>> _errors =
      <int, StreamController<CameraErrorEvent>>{};
  final StreamController<DeviceOrientationChangedEvent> _orientation =
      StreamController<DeviceOrientationChangedEvent>.broadcast();

  /// Delivers a frame to whoever is listening to the image stream.
  void emitFrame(int cameraId, {int width = 64, int height = 48}) {
    _frames[cameraId]?.add(
      CameraImageData(
        format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
        planes: <CameraImagePlane>[
          CameraImagePlane(
            bytes: Uint8List(width * height),
            bytesPerRow: width,
          ),
        ],
        width: width,
        height: height,
      ),
    );
  }

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: 'back',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
        CameraDescription(
          name: 'front',
          lensDirection: CameraLensDirection.front,
          sensorOrientation: 270,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    createdCameras++;
    final int id = _nextId++;
    _initialized[id] = StreamController<CameraInitializedEvent>.broadcast(
      sync: true,
    );
    _frames[id] = StreamController<CameraImageData>.broadcast(sync: true);
    _errors[id] = StreamController<CameraErrorEvent>.broadcast();
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    _initialized[cameraId]?.add(
      CameraInitializedEvent(
        cameraId,
        640,
        480,
        ExposureMode.auto,
        true,
        FocusMode.auto,
        true,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      _initialized[cameraId]?.stream ??
      const Stream<CameraInitializedEvent>.empty();

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      _errors[cameraId]?.stream ?? const Stream<CameraErrorEvent>.empty();

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      _orientation.stream;

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => _frames[cameraId]?.stream ?? const Stream<CameraImageData>.empty();

  @override
  Future<double> getMaxZoomLevel(int cameraId) async {
    if (!zoomLevelsSupported) {
      throw CameraException(
        'Uninitialized CameraController',
        'getMaxZoomLevel() was called on an uninitialized CameraController.',
      );
    }
    return maxZoomLevel;
  }

  @override
  Future<double> getMinZoomLevel(int cameraId) async {
    if (!zoomLevelsSupported) {
      throw CameraException(
        'Uninitialized CameraController',
        'getMinZoomLevel() was called on an uninitialized CameraController.',
      );
    }
    return minZoomLevel;
  }

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {
    zoomLevels[cameraId] = zoom;
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    if (!flashModeSupported) {
      throw CameraException(
        'setFlashModeFailed',
        'Device does not support flash mode',
      );
    }
  }

  @override
  Widget buildPreview(int cameraId) {
    if (disposedCameras.contains(cameraId)) {
      previewsBuiltForDisposedCamera++;
    }
    return const ColoredBox(color: Colors.green);
  }

  @override
  Future<void> dispose(int cameraId) async {
    disposedCameras.add(cameraId);
    await _initialized.remove(cameraId)?.close();
    await _frames.remove(cameraId)?.close();
    // `_errors` is deliberately left open: `CameraController.initialize` awaits
    // `onCameraError(...).first`, and closing an error stream that never
    // emitted would complete that with "Bad state: No element". A real camera
    // never closes it either.
    _errors.remove(cameraId);
  }
}

void main() {
  late FakeCameraPlatform platform;

  setUp(() {
    platform = FakeCameraPlatform();
    CameraPlatform.instance = platform;
  });

  /// Pumps until the widget has finished starting or swapping its camera.
  ///
  /// Camera teardown is bounded by a timeout, so a fake platform whose
  /// `stopImageStream` never answers still lets the widget move on -- this has
  /// to pump past that timeout.
  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Removes the widget and pumps until its teardown timers have fired, so the
  /// test does not end with timers still pending.
  Future<void> disposeReader(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  }

  Future<void> pumpReader(WidgetTester tester, {Widget? widget}) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: widget ?? const ReaderWidget())),
    );
    await settle(tester);
  }

  testWidgets('shows the camera preview once the camera is initialized', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester);

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(platform.createdCameras, 1);
    expect(tester.takeException(), isNull);

    await disposeReader(tester);
  });

  testWidgets('switching cameras opens the next one and releases the old', (
    WidgetTester tester,
  ) async {
    // Note: this covers the camera swap end to end, but it does not reproduce
    // the reported `buildPreview() was called on a disposed CameraController`
    // crash. That is a race between a `ValueListenableBuilder` rebuild that
    // `stopImageStream()` scheduled and the controller being disposed, and the
    // deterministic clock in widget tests does not land inside that window.
    await pumpReader(tester);
    expect(find.byType(CameraPreview), findsOneWidget);

    await tester.tap(find.byIcon(Icons.switch_camera));
    await settle(tester);

    expect(
      platform.previewsBuiltForDisposedCamera,
      0,
      reason: 'a preview was built for a camera that had been disposed',
    );
    expect(tester.takeException(), isNull);
    expect(platform.createdCameras, 2, reason: 'the second camera was opened');
    expect(platform.disposedCameras, <int>{
      1,
    }, reason: 'the first was released');
    expect(find.byType(CameraPreview), findsOneWidget);

    await disposeReader(tester);
  });

  testWidgets('switching cameras repeatedly stays stable', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester);

    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.switch_camera));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'toggle ${i + 1}');
    }

    expect(platform.previewsBuiltForDisposedCamera, 0);

    await disposeReader(tester);
  });

  testWidgets('disposing the widget tears the camera down cleanly', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(CameraPreview), findsOneWidget);

    await disposeReader(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(CameraPreview), findsNothing);
    expect(platform.previewsBuiltForDisposedCamera, 0);
    expect(platform.disposedCameras, isNotEmpty, reason: 'camera released');
  });

  testWidgets('a failing zoom query does not abort camera setup', (
    WidgetTester tester,
  ) async {
    // Regression test: `getMaxZoomLevel()` was the one unguarded platform call
    // after several awaits, so when it threw
    // "getMaxZoomLevel() was called on an uninitialized CameraController"
    // the whole setup was abandoned and the widget ended up with no camera.
    platform = FakeCameraPlatform(zoomLevelsSupported: false);
    CameraPlatform.instance = platform;

    await pumpReader(tester);

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeReader(tester);
  });

  testWidgets('a reversed zoom range does not abort camera setup', (
    WidgetTester tester,
  ) async {
    // `clamp` throws when its lower bound is above its upper one.
    platform = FakeCameraPlatform(minZoomLevel: 4.0, maxZoomLevel: 1.0);
    CameraPlatform.instance = platform;

    await pumpReader(tester);

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(platform.zoomLevels[1], 1.0);

    await disposeReader(tester);
  });

  testWidgets('switching cameras keeps the zoom level', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester);

    // Pinch out.
    final Offset center = tester.getCenter(find.byType(ReaderWidget));
    final TestGesture first = await tester.startGesture(
      center - const Offset(20, 0),
    );
    final TestGesture second = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 2,
    );
    for (int i = 0; i < 4; i++) {
      await first.moveBy(const Offset(-10, 0));
      await second.moveBy(const Offset(10, 0));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pump();

    final double zoom = platform.zoomLevels[1]!;
    expect(zoom, greaterThan(1.0));

    await tester.tap(find.byIcon(Icons.switch_camera));
    await settle(tester);

    expect(platform.zoomLevels[2], zoom);

    await disposeReader(tester);
  });

  testWidgets('opening the reader a second time brings the camera back', (
    WidgetTester tester,
  ) async {
    await pumpReader(tester);
    expect(find.byType(CameraPreview), findsOneWidget);

    await disposeReader(tester);

    await pumpReader(tester);
    expect(find.byType(CameraPreview), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(platform.createdCameras, 2);

    await disposeReader(tester);
  });

  testWidgets('the crop overlay follows the widget box, not the screen', (
    WidgetTester tester,
  ) async {
    // Regression test for a non-full-screen ReaderWidget: the cut-out used to
    // be sized and centred against `MediaQuery.size`, so inside a smaller box
    // it was drawn in the wrong place and did not match where scanning happens.
    tester.view.physicalSize = const Size(1000, 2000);
    addTearDown(tester.view.reset);

    const double boxWidth = 300;
    const double boxHeight = 400;
    await pumpReader(
      tester,
      widget: const Center(
        child: SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: ReaderWidget(cropPercent: 0.4),
        ),
      ),
    );

    final Finder overlay = find.byWidgetPredicate(
      (Widget w) =>
          w is Container &&
          w.decoration is ShapeDecoration &&
          (w.decoration! as ShapeDecoration).shape is ScannerOverlayBorder,
    );
    expect(overlay, findsOneWidget);

    final ScannerOverlayBorder border =
        ((tester.widget<Container>(overlay).decoration!) as ShapeDecoration)
                .shape
            as ScannerOverlayBorder;

    // 40% of the widget's shorter side (300), not of the screen's (1000).
    expect(border.cutOutSize, closeTo(120, 0.01));

    // And the painted cut-out sits in the middle of the widget.
    final Rect overlayRect = tester.getRect(overlay);
    final Rect cutOut = border
        .getInnerPath(Offset.zero & overlayRect.size)
        .getBounds();
    expect(cutOut.center.dx, closeTo(boxWidth / 2, 0.01));
    expect(cutOut.center.dy, closeTo(boxHeight / 2, 0.01));
    expect(cutOut.width, closeTo(120, 0.01));

    await disposeReader(tester);
  });

  testWidgets('a desktop window losing focus keeps scanning', (
    WidgetTester tester,
  ) async {
    // A desktop window goes inactive as soon as it is not the focused one, and
    // opening the camera again takes about a second.
    CameraController? created;
    await pumpReader(
      tester,
      widget: ReaderWidget(
        onControllerCreated: (CameraController? controller, Exception? _) =>
            created = controller,
      ),
    );
    expect(created?.value.isStreamingImages, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);

    expect(created?.value.isStreamingImages, isTrue);
    expect(find.byType(CameraPreview), findsOneWidget);

    await disposeReader(tester);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('a mobile app going inactive stops scanning', (
    WidgetTester tester,
  ) async {
    // On a phone `inactive` means the app is on its way to the background,
    // where it must let go of the camera.
    CameraController? created;
    await pumpReader(
      tester,
      widget: ReaderWidget(
        onControllerCreated: (CameraController? controller, Exception? _) =>
            created = controller,
      ),
    );
    expect(created?.value.isStreamingImages, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await settle(tester);

    expect(created?.value.isStreamingImages, isFalse);

    await disposeReader(tester);
  }, variant: TargetPlatformVariant.mobile());

  testWidgets('the flash button is hidden on desktop', (
    WidgetTester tester,
  ) async {
    // Desktop cameras have no torch, but asking to turn one off succeeds, so
    // the widget cannot find out by trying.
    await pumpReader(tester);

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.byIcon(Icons.flash_off), findsNothing);
    expect(find.byIcon(Icons.flash_on), findsNothing);

    await disposeReader(tester);
  }, variant: TargetPlatformVariant.desktop());

  testWidgets('a device without flash still initializes the camera', (
    WidgetTester tester,
  ) async {
    // Regression test: `setFlashMode` throwing `setFlashModeFailed` must not
    // abort controller initialization, and the flash button must disappear.
    platform = FakeCameraPlatform(flashModeSupported: false);
    CameraPlatform.instance = platform;

    await pumpReader(tester);

    expect(find.byType(CameraPreview), findsOneWidget);
    expect(find.byIcon(Icons.flash_off), findsNothing);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(tester.takeException(), isNull);

    await disposeReader(tester);
  });
}
