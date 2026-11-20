// NativeCameraSource on a fake camera plugin: which camera opens, frames,
// opening and closing in order, camera errors, the torch, zoom and focus.
import 'dart:async';
import 'dart:math' show Point;

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source.dart';
import 'package:flutter_zxing/src/scanning/camera/camera_source_native.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

const CameraDescription _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
const CameraDescription _front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

/// A camera plugin that behaves like camera_android_camerax for what the
/// source uses.
final class _FakePlatform extends CameraPlatform
    with MockPlatformInterfaceMixin {
  List<CameraDescription> cameras = <CameraDescription>[_back, _front];
  bool streaming = true;
  bool zoomImplemented = true;

  /// Thrown by setFocusPoint, like a camera with a fixed focus.
  Exception? focusError;

  /// Whether setFlashMode reports a failure as a camera error only, as
  /// CameraX does on a camera without a flash unit.
  bool torchFailsAsError = false;

  /// While set, initializeCamera waits for it.
  Completer<void>? initializeGate;

  final List<String> created = <String>[];
  final Set<int> disposed = <int>{};
  final List<Point<double>?> exposurePoints = <Point<double>?>[];
  double? zoom;
  FlashMode? flash;

  int _nextId = 1;
  final Map<int, StreamController<CameraInitializedEvent>> _initialized =
      <int, StreamController<CameraInitializedEvent>>{};
  final Map<int, StreamController<CameraImageData>> _frames =
      <int, StreamController<CameraImageData>>{};
  final Map<int, StreamController<CameraErrorEvent>> _errors =
      <int, StreamController<CameraErrorEvent>>{};
  final StreamController<DeviceOrientationChangedEvent> _orientation =
      StreamController<DeviceOrientationChangedEvent>.broadcast();

  int get lastId => _nextId - 1;

  /// Sends a frame of the camera [id].
  void frame(
    int id, {
    ImageFormatGroup group = ImageFormatGroup.yuv420,
    Object? raw = 35,
  }) {
    _frames[id]?.add(
      CameraImageData(
        format: CameraImageFormat(group, raw: raw),
        planes: <CameraImagePlane>[
          CameraImagePlane(bytes: Uint8List(64 * 48 * 4), bytesPerRow: 64),
        ],
        width: 64,
        height: 48,
      ),
    );
  }

  /// Reports [description] as an error of the camera [id].
  void error(int id, String description) =>
      _errors[id]?.add(CameraErrorEvent(id, description));

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async {
    created.add(cameraDescription.name);
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
    if (initializeGate != null) {
      await initializeGate!.future;
    }
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
  bool supportsImageStreaming() => streaming;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) => _frames[cameraId]?.stream ?? const Stream<CameraImageData>.empty();

  @override
  Future<double> getMaxZoomLevel(int cameraId) async => 8;

  @override
  Future<double> getMinZoomLevel(int cameraId) async => 1;

  @override
  Future<void> setZoomLevel(int cameraId, double zoom) async {
    if (!zoomImplemented) {
      throw UnimplementedError('setZoomLevel() is not implemented.');
    }
    this.zoom = zoom;
  }

  @override
  Future<void> setFlashMode(int cameraId, FlashMode mode) async {
    if (torchFailsAsError && mode == FlashMode.torch) {
      error(cameraId, 'No flash unit');
      return;
    }
    flash = mode;
  }

  @override
  Future<void> setFocusPoint(int cameraId, Point<double>? point) async {
    if (focusError != null) {
      throw focusError!;
    }
  }

  @override
  Future<void> setExposurePoint(int cameraId, Point<double>? point) async =>
      exposurePoints.add(point);

  @override
  Widget buildPreview(int cameraId) => const SizedBox();

  @override
  Future<void> dispose(int cameraId) async {
    disposed.add(cameraId);
    await _initialized.remove(cameraId)?.close();
    await _frames.remove(cameraId)?.close();
    // The error stream stays open, as CameraController waits for its first
    // event.
    _errors.remove(cameraId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;
  late NativeCameraSource source;

  setUp(() {
    platform = _FakePlatform();
    CameraPlatform.instance = platform;
    source = NativeCameraSource();
  });

  tearDown(() async {
    await source.close();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<CameraCapabilities> open([CameraFacing facing = CameraFacing.back]) =>
      source.open(facing, CameraResolution.hd);

  test('opens the camera of the side and hands out its frames', () async {
    final CameraCapabilities capabilities = await open();
    expect(platform.created, <String>['back']);
    expect(capabilities.hasTorch, isTrue);
    expect(capabilities.maxZoom, 8);
    expect(capabilities.hasOtherFacing, isTrue);
    // Android frames come in the sensor's orientation.
    expect(source.previewTransform.value?.rotation, 90);

    final Future<CameraFrame?> next = source.nextFrame();
    platform.frame(platform.lastId);
    final CameraFrame? frame = await next;
    expect(frame?.pixels?.layout, PixelLayout.luminance);
    expect(frame?.dropped, 0);

    // Frames replaced before they were asked for are counted.
    for (int i = 0; i < 3; i++) {
      platform.frame(platform.lastId);
    }
    expect((await source.nextFrame())?.dropped, 2);
  });

  test('a close asked for while the camera opens closes it', () async {
    platform.initializeGate = Completer<void>();
    final Future<void> opened = open();
    final Future<void> closed = source.close();
    platform.initializeGate!.complete();
    await opened;
    await closed;
    expect(platform.disposed, <int>{platform.lastId});
    expect(await source.nextFrame(), isNull);
  });

  test('an open while another camera is open closes that one', () async {
    await open();
    final int first = platform.lastId;
    await open(CameraFacing.front);
    expect(platform.disposed, <int>{first});
    expect(platform.created, <String>['back', 'front']);
  });

  test('a camera taken by another app fails the next frame', () async {
    await open();
    final int id = platform.lastId;
    // A first error that does not end the camera, then one that does: the
    // camera plugin keeps only the first.
    platform.error(id, 'Focus was cancelled');
    await pumpEventQueue();
    platform.error(
      id,
      'The camera was already in use, possibly by a higher-priority camera '
      'client.',
    );
    await pumpEventQueue();
    expect(source.nextFrame(), throwsA(isA<CameraInUseException>()));
  });

  test('a torch that reports its failure as an error is unavailable', () async {
    await open();
    await source.setTorch(true);
    expect(platform.flash, FlashMode.torch);
    await source.setTorch(false);
    platform.torchFailsAsError = true;
    expect(source.setTorch(true), throwsA(isA<CameraUnsupportedException>()));
  });

  test('a plugin without frames is reported as unsupported', () async {
    platform.streaming = false;
    expect(open(), throwsA(isA<CameraUnsupportedException>()));
  });

  test('a camera that cannot zoom keeps its zoom', () async {
    platform.zoomImplemented = false;
    await open();
    await source.setZoom(2);
    expect(platform.zoom, isNull);
  });

  test('a camera with a fixed focus still meters on the point', () async {
    await open();
    platform.focusError = CameraException('setFocusPointFailed', 'fixed');
    await source.setFocusPoint(const Offset(0.25, 0.75));
    expect(platform.exposurePoints, <Point<double>>[
      const Point<double>(0.25, 0.75),
    ]);
  });

  test('frames are counted anew for each camera', () async {
    await open();
    platform.frame(platform.lastId);
    await source.nextFrame();
    platform.frame(platform.lastId);
    platform.frame(platform.lastId);
    await source.close();
    await open();
    platform.frame(platform.lastId);
    expect((await source.nextFrame())?.dropped, 0);
  });

  test('frames the engine cannot read fail', () async {
    await open();
    platform.frame(platform.lastId, group: ImageFormatGroup.jpeg);
    final CameraFrame? frame = await source.nextFrame();
    expect(() => frame?.pixels, throwsA(isA<CameraFailureException>()));
  });

  test('desktop: the back camera is any camera, BGRA as labelled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    platform.cameras = const <CameraDescription>[
      CameraDescription(
        name: 'webcam',
        lensDirection: CameraLensDirection.external,
        sensorOrientation: 0,
      ),
    ];
    final CameraCapabilities capabilities = await open();
    expect(platform.created, <String>['webcam']);
    expect(capabilities.hasTorch, isFalse);
    expect(capabilities.hasOtherFacing, isFalse);
    platform.frame(
      platform.lastId,
      group: ImageFormatGroup.bgra8888,
      raw: 'RGBA',
    );
    expect((await source.nextFrame())?.pixels?.layout, PixelLayout.rgba);
    platform.frame(platform.lastId, group: ImageFormatGroup.bgra8888, raw: 0);
    expect((await source.nextFrame())?.pixels?.layout, PixelLayout.bgra);
    expect(open(CameraFacing.front), throwsA(isA<CameraNotFoundException>()));
  });
}
