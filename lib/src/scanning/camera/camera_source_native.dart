// The camera on Android, iOS and the desktop, through the camera plugin
// (camera_desktop on macOS, Linux and Windows).
//
// Only the scanned plane is read: the luminance (Y) plane of YUV frames, the
// BGRA plane on the desktop. The engine copies just the scan window of it,
// once, into native memory (NativeBackend.readPixels).
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart';

import '../../engine/engine.dart';
import '../../engine/engine_protocol.dart';
import '../../errors.dart';
import '../../reading/pixel_buffer.dart';
import '../frame_geometry.dart';
import '../scanner_controller.dart';
import 'camera_source.dart';

/// The camera of this platform.
CameraSource createCameraSource() => NativeCameraSource();

/// A camera through the camera plugin.
final class NativeCameraSource implements CameraSource {
  CameraController? _camera;
  CameraDescription? _description;
  CameraImage? _latest;
  int _latestAt = 0;
  int _received = 0;
  int _taken = 0;
  Completer<void>? _waiter;
  Orientation _uiShape = Orientation.portrait;
  DeviceOrientation _ui = DeviceOrientation.portraitUp;
  final ValueNotifier<FrameTransform?> _preview =
      ValueNotifier<FrameTransform?>(null);

  static bool get _android => defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  ValueListenable<FrameTransform?> get previewTransform => _preview;

  @override
  Orientation get uiShape => _uiShape;

  @override
  set uiShape(Orientation value) {
    _uiShape = value;
    _updateOrientation();
  }

  /// Works out the UI orientation again from the UI's shape and the device
  /// orientation the camera reports.
  void _updateOrientation() {
    final CameraController? camera = _camera;
    final DeviceOrientation ui = uiOrientation(
      camera?.value.deviceOrientation ?? DeviceOrientation.portraitUp,
      _uiShape,
    );
    if (ui == _ui) {
      return;
    }
    _ui = ui;
    if (camera != null && _ios) {
      // iOS turns the frames to the device orientation; keep them in the
      // UI's, so that a portrait-only app does not show a sideways preview
      // when the phone is turned.
      unawaited(camera.lockCaptureOrientation(ui).catchError((Object _) {}));
    }
    _updatePreview();
  }

  /// Opening and closing cameras, one at a time across all sources: a
  /// scanner rebuilt in a new place (a phone turned to landscape) opens
  /// the camera while the old one is still closing it, and on iOS the
  /// camera plugin's `initialize` then never finishes.
  static Future<void> _cameraQueue = Future<void>.value();

  static Future<T> _oneAtATime<T>(Future<T> Function() task) {
    final Future<T> result = _cameraQueue.then((_) => task());
    _cameraQueue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  Future<CameraCapabilities> open(
    CameraFacing facing,
    CameraResolution resolution,
  ) => _oneAtATime(() => _open(facing, resolution));

  Future<CameraCapabilities> _open(
    CameraFacing facing,
    CameraResolution resolution,
  ) async {
    final List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } on CameraException catch (e) {
      throw cameraError(e.code, e.description);
    }
    final CameraLensDirection wanted = facing == CameraFacing.back
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    // Desktop webcams are "external" or "front": use one when the back
    // camera is asked for.
    final CameraDescription? description =
        cameras
            .where((CameraDescription c) => c.lensDirection == wanted)
            .firstOrNull ??
        (facing == CameraFacing.back ? cameras.firstOrNull : null);
    if (description == null) {
      throw CameraNotFoundException(
        cameras.isEmpty ? 'No camera available' : 'No ${facing.name} camera',
      );
    }
    final CameraController camera = CameraController(
      description,
      switch (resolution) {
        CameraResolution.sd => ResolutionPreset.medium,
        CameraResolution.hd => ResolutionPreset.high,
        CameraResolution.fullHd => ResolutionPreset.veryHigh,
      },
      enableAudio: false,
      // The Y plane comes first; desktop cameras send BGRA whatever is asked.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await camera.initialize();
      _ui = uiOrientation(camera.value.deviceOrientation, _uiShape);
      if (_ios) {
        await camera.lockCaptureOrientation(_ui);
      }
      await camera.startImageStream(_onImage);
    } on CameraException catch (e) {
      await camera.dispose();
      throw cameraError(e.code, e.description);
    } on Object {
      await camera.dispose();
      rethrow;
    }
    _camera = camera;
    _description = description;
    camera.addListener(_updateOrientation);
    _updatePreview();
    double minZoom = 1;
    double maxZoom = 1;
    try {
      minZoom = await camera.getMinZoomLevel();
      maxZoom = await camera.getMaxZoomLevel();
    } on Object {
      // Not supported (desktop): no zoom.
    }
    return CameraCapabilities(
      hasTorch:
          (_android || _ios) &&
          description.lensDirection == CameraLensDirection.back,
      minZoom: minZoom,
      maxZoom: maxZoom < minZoom ? minZoom : maxZoom,
    );
  }

  void _onImage(CameraImage image) {
    final CameraImage? previous = _latest;
    _latest = image;
    _latestAt = cameraClock.elapsedMicroseconds;
    _received++;
    // On iOS the preview shows these very buffers, so their shape decides
    // how it is turned.
    if (_ios &&
        (previous == null ||
            previous.width != image.width ||
            previous.height != image.height)) {
      _updatePreview();
    }
    final Completer<void>? waiter = _waiter;
    _waiter = null;
    waiter?.complete();
  }

  @override
  Future<void> close() {
    // Frames stop being waited for at once; the camera closes in turn.
    final Completer<void>? waiter = _waiter;
    _waiter = null;
    waiter?.complete();
    return _oneAtATime(_close);
  }

  Future<void> _close() async {
    final CameraController? camera = _camera;
    _camera = null;
    _description = null;
    _latest = null;
    _preview.value = null;
    final Completer<void>? waiter = _waiter;
    _waiter = null;
    waiter?.complete();
    if (camera != null) {
      camera.removeListener(_updateOrientation);
      try {
        if (camera.value.isStreamingImages) {
          await camera.stopImageStream();
        }
      } on Object {
        // Disposing stops it anyway.
      }
      await camera.dispose();
    }
  }

  @override
  Future<CameraFrame?> nextFrame() async {
    while (true) {
      final CameraDescription? description = _description;
      if (_camera == null || description == null) {
        return null;
      }
      final CameraImage? image = _latest;
      if (image != null && _received != _taken) {
        final int dropped = _taken == 0 ? 0 : _received - _taken - 1;
        _taken = _received;
        return _NativeFrame(
          image,
          _transformOf(Size(image.width.toDouble(), image.height.toDouble())),
          arrivalMicros: _latestAt,
          dropped: dropped,
          // iOS mirrors the front camera's frames themselves; flipped back,
          // codes that are not read mirrored (Data Matrix) are read too.
          mirrored:
              _ios && description.lensDirection == CameraLensDirection.front,
        );
      }
      await (_waiter ??= Completer<void>()).future;
    }
  }

  void _updatePreview() {
    if (_description == null) {
      _preview.value = null;
      return;
    }
    if (_ios) {
      // Known from the first frame on (see _transformOf).
      final CameraImage? image = _latest;
      _preview.value = image == null
          ? null
          : _transformOf(Size(image.width.toDouble(), image.height.toDouble()));
      return;
    }
    final Size? size = _camera?.value.previewSize;
    _preview.value = size == null ? null : _transformOf(size);
  }

  /// How a frame (and the preview) of [size] as delivered is shown.
  FrameTransform _transformOf(Size size) {
    final CameraDescription description = _description!;
    final bool front = description.lensDirection == CameraLensDirection.front;
    if (_android) {
      // Frames come in the sensor's orientation; the preview turns them
      // (and mirrors the front camera) as Android's camera formula says.
      return FrameTransform(
        size,
        rotation: androidFrameRotation(
          sensorOrientation: description.sensorOrientation,
          ui: _ui,
          front: front,
        ),
        mirrored: front,
      );
    }
    if (_ios) {
      // iOS turns the frames to the locked capture orientation itself (and
      // mirrors the front camera), and the preview shows those frames as
      // they are. Except when the connection cannot be turned: the front
      // camera of an iPhone 17 Pro Max sends landscape frames to a portrait
      // UI. So the frame's shape decides, not the orientation asked for
      // (rule 5 of the prototype); this preview then turns them too.
      return FrameTransform(size, rotation: iosFrameRotation(size, _ui));
    }
    return FrameTransform(size);
  }

  @override
  Widget buildPreview() {
    final CameraController? camera = _camera;
    if (camera == null) {
      return const SizedBox.shrink();
    }
    final int rotation = _ios ? (_preview.value?.rotation ?? 0) : 0;
    // Android's preview turns itself; on iOS a frame the system did not turn
    // is turned here, as the scanner turns its frames.
    return rotation == 0
        ? CameraPreview(camera)
        : RotatedBox(
            quarterTurns: rotation ~/ 90,
            child: CameraPreview(camera),
          );
  }

  @override
  Future<void> setTorch(bool on) async {
    final CameraController? camera = _camera;
    if (camera == null) {
      return;
    }
    try {
      await camera.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    } on CameraException catch (e) {
      throw cameraError(e.code, e.description);
    }
  }

  @override
  Future<void> setZoom(double zoom) async {
    try {
      await _camera?.setZoomLevel(zoom);
    } on CameraException {
      // The camera rejected the value: keep the current zoom.
    }
  }

  @override
  Future<void> setFocusPoint(Offset point) async {
    final CameraController? camera = _camera;
    if (camera == null) {
      return;
    }
    try {
      await camera.setFocusPoint(point);
      await camera.setExposurePoint(point);
    } on Object {
      // Not every camera can focus or meter on a point.
    }
  }
}

final class _NativeFrame implements CameraFrame {
  _NativeFrame(
    this._image,
    this.transform, {
    required this.arrivalMicros,
    required this.dropped,
    this.mirrored = false,
  });

  @override
  final int arrivalMicros;

  @override
  final int dropped;

  final CameraImage _image;

  @override
  final bool mirrored;

  @override
  final FrameTransform transform;

  @override
  PixelBuffer? get pixels {
    final Plane plane = _image.planes.first;
    return PixelBuffer(
      plane.bytes,
      width: _image.width,
      height: _image.height,
      layout: _layout,
      rowStride: plane.bytesPerRow,
    );
  }

  PixelLayout get _layout => switch (_image.format.group) {
    ImageFormatGroup.yuv420 || ImageFormatGroup.nv21 => PixelLayout.luminance,
    // camera_desktop 1.x sends RGBA on Linux and Windows while labelling
    // it bgra8888; the byte order it used is only in `raw`.
    ImageFormatGroup.bgra8888 =>
      _image.format.raw == 'RGBA' ? PixelLayout.rgba : PixelLayout.bgra,
    ImageFormatGroup.jpeg ||
    ImageFormatGroup.unknown => throw CameraFailureException(
      'The camera sends ${_image.format.group.name} frames, which cannot '
      'be scanned',
    ),
  };

  @override
  Future<EngineReadResult> read(
    BarcodeEngine engine,
    Rect? crop,
    EngineReadOptions options,
  ) {
    final PixelLayout layout = _layout;
    final Plane plane = _image.planes.first;
    return engine.readPixels(
      PixelBuffer(
        plane.bytes,
        width: _image.width,
        height: _image.height,
        layout: layout,
        rowStride: plane.bytesPerRow,
        crop: crop,
      ),
      options,
      mirrored: mirrored,
    );
  }
}
