// The camera behind ScannerController: the camera plugin on native
// platforms, getUserMedia and a <video> element on the web. Internal: the
// controller only talks to this interface, so a zero-copy camera of our own
// can replace the plugin later without touching it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../engine/engine.dart';
import '../../engine/engine_protocol.dart';
import '../../errors.dart';
import '../../reading/pixel_buffer.dart';
import '../frame_geometry.dart';
import '../scanner_controller.dart';
import 'camera_source_stub.dart'
    if (dart.library.js_interop) 'camera_source_web.dart'
    if (dart.library.ffi) 'camera_source_native.dart'
    as platform;

/// The clock of frame arrival times, shared by the cameras and the
/// controller (microseconds since the first use).
final Stopwatch cameraClock = Stopwatch()..start();

/// What an opened camera can do.
@immutable
final class CameraCapabilities {
  /// Creates capabilities.
  const CameraCapabilities({
    this.hasTorch = false,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.ultraWide,
  });

  /// Whether the camera has a torch that can be switched.
  final bool hasTorch;

  /// Smallest zoom factor.
  final double minZoom;

  /// Largest zoom factor.
  final double maxZoom;

  /// With a separate ultra-wide camera on the same side (iPhones): how much
  /// of the main camera's view it shows at its own zoom 1, e.g. 0.5 for
  /// twice as wide; it focuses much closer (macro). `null` without one.
  final double? ultraWide;
}

/// A platform camera that hands out its newest frame on request.
///
/// The controller pulls frames, one in flight at a time, instead of the
/// camera pushing them: the decode rate adapts to the device and no queue
/// can build up. Frames that arrive while one is being decoded replace each
/// other.
abstract class CameraSource {
  /// The camera of the current platform.
  static CameraSource create() => platform.createCameraSource();

  /// Opens the camera with [facing] at about [resolution] and starts the
  /// frames; the ultra-wide camera with [ultraWide] (see
  /// [CameraCapabilities.ultraWide]). Throws a [ScannerException] if it
  /// cannot.
  Future<CameraCapabilities> open(
    CameraFacing facing,
    CameraResolution resolution, {
    bool ultraWide = false,
  });

  /// Releases the camera. A pending [nextFrame] completes with `null`.
  Future<void> close();

  /// A frame newer than the last one handed out; waits for the camera.
  /// `null` once the camera is closed.
  Future<CameraFrame?> nextFrame();

  /// How the preview shows the camera image, once it is known: its size as
  /// delivered, and how it is turned and mirrored on screen. Changes with
  /// [uiOrientation].
  ValueListenable<FrameTransform?> get previewTransform;

  /// The shape of the app's UI (from `MediaQuery`). With the device
  /// orientation the camera reports it gives the orientation the UI is drawn
  /// in ([uiOrientation]), which decides how the preview and the frames are
  /// turned. Portrait until set.
  Orientation get uiShape;
  set uiShape(Orientation value);

  /// The camera preview, laid out at `previewTransform.displaySize`; the
  /// scanner widget scales and clips it.
  Widget buildPreview();

  /// Switches the torch.
  Future<void> setTorch(bool on);

  /// Zooms to [zoom] (within the capabilities).
  Future<void> setZoom(double zoom);

  /// Focuses and meters at [point], in fractions of the preview as shown.
  Future<void> setFocusPoint(Offset point);
}

/// One camera frame, ready to decode.
abstract class CameraFrame {
  /// The frame's size as delivered, and how it is shown.
  FrameTransform get transform;

  /// The frame's pixels where they are in memory (native platforms), for
  /// cut-outs of the codes found and for saving a frame while debugging;
  /// `null` on the web.
  PixelBuffer? get pixels;

  /// Whether [pixels] are a mirror image of the scene (the front camera on
  /// iOS).
  bool get mirrored;

  /// When the frame reached Dart, on [cameraClock].
  int get arrivalMicros;

  /// Frames the camera delivered since the previous frame handed out, that
  /// were replaced before they could be decoded (0 where unknown).
  int get dropped;

  /// Decodes [crop] of the frame (pixels of the delivered frame, `null` for
  /// all of it). Positions in the result are in the delivered frame.
  Future<EngineReadResult> read(
    BarcodeEngine engine,
    Rect? crop,
    EngineReadOptions options,
  );
}

/// The [ScannerException] for an error of the camera plugin or the
/// browser, from its error [code] and [message].
ScannerException cameraError(String code, String? message) {
  final String text = message == null || message.isEmpty
      ? code
      : '$code: $message';
  final String c = code.toLowerCase();
  if ((c.contains('denied') ||
          c.contains('restricted') ||
          c.contains('permission') ||
          c.contains('notallowed')) &&
      !c.contains('ongoing')) {
    return CameraPermissionException(text);
  }
  if (c.contains('notfound') || c.contains('nocamera')) {
    return CameraNotFoundException(text);
  }
  return CameraFailureException(text);
}
