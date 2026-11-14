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

  @override
  Future<CameraCapabilities> open(
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
    _latest = image;
    _received++;
    final Completer<void>? waiter = _waiter;
    _waiter = null;
    waiter?.complete();
  }

  @override
  Future<void> close() async {
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
        _taken = _received;
        return _NativeFrame(
          image,
          _transformOf(Size(image.width.toDouble(), image.height.toDouble())),
        );
      }
      await (_waiter ??= Completer<void>()).future;
    }
  }

  void _updatePreview() {
    final Size? size = _camera?.value.previewSize;
    _preview.value = size == null || _description == null
        ? null
        : _transformOf(size, preview: true);
  }

  /// How a frame (or, with [preview], the preview) of [size] as delivered
  /// is shown.
  FrameTransform _transformOf(Size size, {bool preview = false}) {
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
    if (_ios && preview) {
      // iOS delivers frames already turned to the UI (and mirrored for the
      // front camera), and the preview shows those frames; but previewSize
      // is reported in the sensor's landscape shape.
      final bool landscape = orientationDegrees(_ui) % 180 != 0;
      final double long = size.longestSide;
      final double short = size.shortestSide;
      return FrameTransform(landscape ? Size(long, short) : Size(short, long));
    }
    return FrameTransform(size);
  }

  @override
  Widget buildPreview() {
    final CameraController? camera = _camera;
    return camera == null ? const SizedBox.shrink() : CameraPreview(camera);
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
  _NativeFrame(this._image, this.transform);

  final CameraImage _image;

  @override
  final FrameTransform transform;

  @override
  Future<EngineReadResult> read(
    BarcodeEngine engine,
    Rect? crop,
    EngineReadOptions options,
  ) {
    final PixelLayout layout = switch (_image.format.group) {
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
    );
  }
}
