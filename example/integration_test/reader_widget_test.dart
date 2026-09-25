/// ReaderWidget integration tests
///
/// Drive `ReaderWidget` with frames from a fake camera, decoded by the real
/// native library, on each supported platform.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const int frameWidth = 320;
const int frameHeight = 240;

/// A camera with one lens whose image stream carries only what the test emits.
class FakeCameraPlatform extends CameraPlatform
    with MockPlatformInterfaceMixin {
  int _nextId = 1;
  final Map<int, StreamController<CameraInitializedEvent>> _initialized =
      <int, StreamController<CameraInitializedEvent>>{};
  final Map<int, StreamController<CameraImageData>> _frames =
      <int, StreamController<CameraImageData>>{};
  // Never closed: `CameraController.initialize` awaits `onCameraError(...).first`.
  final Map<int, StreamController<CameraErrorEvent>> _errors =
      <int, StreamController<CameraErrorEvent>>{};
  final StreamController<DeviceOrientationChangedEvent> _orientation =
      StreamController<DeviceOrientationChangedEvent>.broadcast();

  /// Delivers a YUV420 frame whose luminance plane is [luminance].
  void emitFrame(Uint8List luminance) {
    for (final StreamController<CameraImageData> frames in _frames.values) {
      frames.add(
        CameraImageData(
          format: const CameraImageFormat(ImageFormatGroup.yuv420, raw: 35),
          planes: <CameraImagePlane>[
            CameraImagePlane(bytes: luminance, bytesPerRow: frameWidth),
          ],
          width: frameWidth,
          height: frameHeight,
        ),
      );
    }
  }

  @override
  Future<List<CameraDescription>> availableCameras() async =>
      const <CameraDescription>[
        CameraDescription(
          name: 'back',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 0,
        ),
      ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
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
        frameWidth.toDouble(),
        frameHeight.toDouble(),
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
  Future<double> getMaxZoomLevel(int cameraId) async => 1.0;

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1.0;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {}

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {}

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.green);

  @override
  Future<void> dispose(int cameraId) async {
    await _initialized.remove(cameraId)?.close();
    await _frames.remove(cameraId)?.close();
    _errors.remove(cameraId);
  }
}

/// A blank frame with a QR code in the middle.
Uint8List frameWithCode() {
  final Encode enc = zx.encodeBarcode(
    contents: 'overlay',
    params: EncodeParams(
      format: Format.qrCode,
      width: 160,
      height: 160,
      margin: 10,
    ),
  );
  expect(enc.isValid, isTrue);
  final int w = enc.width!;
  final int h = enc.height!;
  final Uint8List frame = blankFrame();
  final int left = (frameWidth - w) ~/ 2;
  final int top = (frameHeight - h) ~/ 2;
  for (int y = 0; y < h; y++) {
    frame.setRange(
      (top + y) * frameWidth + left,
      (top + y) * frameWidth + left + w,
      enc.data!,
      y * w,
    );
  }
  return frame;
}

Uint8List blankFrame() =>
    Uint8List(frameWidth * frameHeight)
      ..fillRange(0, frameWidth * frameHeight, 255);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeCameraPlatform platform;

  setUp(() {
    platform = FakeCameraPlatform();
    CameraPlatform.instance = platform;
  });

  /// Keeps emitting [frame] and pumping until [done] holds.
  ///
  /// Frames that arrive while the previous one is still being decoded are
  /// dropped by the widget, so a single frame is not enough.
  Future<void> feedUntil(
    WidgetTester tester,
    Uint8List frame,
    bool Function() done,
  ) async {
    final Stopwatch watch = Stopwatch()..start();
    while (!done()) {
      if (watch.elapsed > const Duration(seconds: 20)) {
        fail('timed out');
      }
      platform.emitFrame(frame);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  }

  // The overlay is drawn only when the whole frame is scanned: in multi-scan
  // mode, or in single-scan mode with no crop.
  for (final bool isMultiScan in <bool>[false, true]) {
    final String mode = isMultiScan ? 'multi-scan' : 'single-scan';

    testWidgets('$mode: the overlay leaves with the code', (
      WidgetTester tester,
    ) async {
      int failures = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReaderWidget(
              isMultiScan: isMultiScan,
              cropPercent: 0,
              codeFormat: Format.qrCode,
              scanDelay: const Duration(milliseconds: 10),
              scanDelaySuccess: const Duration(milliseconds: 10),
              onScanFailure: (_) => failures++,
              onMultiScanFailure: (_) => failures++,
            ),
          ),
        ),
      );
      // The camera is up once blank frames start coming back as failures.
      await feedUntil(tester, blankFrame(), () => failures > 0);

      await feedUntil(
        tester,
        frameWithCode(),
        () => find.byType(MultiResultOverlay).evaluate().isNotEmpty,
      );

      // The code has left the frame. Nothing else rebuilds the widget here, so
      // the overlay has to go on its own (#252).
      failures = 0;
      await feedUntil(tester, blankFrame(), () => failures > 0);
      await tester.pump();
      expect(find.byType(MultiResultOverlay), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
