// The camera behind ScannerController: the camera plugin on native
// platforms, getUserMedia and a <video> element on the web. Internal: the
// controller only talks to this interface, so a zero-copy camera of our own
// can replace the plugin later without touching it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../engine/engine.dart';
import '../../engine/engine_protocol.dart';
import '../../errors.dart';
import '../../reading/pixel_buffer.dart';
import '../frame_geometry.dart';
import '../scanner_controller.dart';
import '../snapshot.dart';
import 'camera_source_stub.dart'
    if (dart.library.js_interop) 'camera_source_web.dart'
    if (dart.library.ffi) 'camera_source_native.dart'
    as platform;
import 'frame_colors.dart';

/// The clock of frame arrival times, shared by the cameras and the
/// controller (microseconds since the first use).
final Stopwatch cameraClock = Stopwatch()..start();

/// Runs the opening and closing of a camera one after the other, in the
/// order they were asked for: a [CameraSource.close] asked for while the
/// camera opens closes the camera that open brings, and an open asked for
/// while it closes waits until it is closed.
final class CameraTurns {
  /// The last task asked for; `null` once it is done.
  Future<void>? _last;

  /// Runs [task] after the tasks asked for before it: at once if there are
  /// none.
  Future<T> run<T>(Future<T> Function() task) {
    final Future<void>? last = _last;
    final Future<T> result = last == null ? task() : last.then((_) => task());
    final Future<void> done = result.then<void>((_) {}, onError: (Object _) {});
    _last = done;
    unawaited(
      done.then((_) {
        if (identical(_last, done)) {
          _last = null;
        }
      }),
    );
    return result;
  }
}

/// What an opened camera can do.
@immutable
final class CameraCapabilities {
  /// Creates capabilities.
  const CameraCapabilities({
    this.hasTorch = false,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.ultraWide,
    this.ultraWideFocusesCloser = false,
    this.telephoto,
    this.hasOtherFacing = false,
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

  /// Whether the [ultraWide] camera focuses closer than the main one (macro:
  /// iPhone 13 Pro and later Pro models, iPhone 16 and later). Older ones
  /// have a fixed focus: no help close up.
  final bool ultraWideFocusesCloser;

  /// With a separate telephoto camera on the same side (iPhone Pro models):
  /// its zoom in the main camera's terms, e.g. 4 (3 or 5 on other models).
  /// `null` without one.
  final double? telephoto;

  /// Whether the device has a camera on the other side to switch to: a
  /// different camera than this one.
  final bool hasOtherFacing;
}

/// Where a camera's lens is focused (iPhones: AVCaptureDevice).
@immutable
final class LensFocus {
  /// Creates a focus.
  const LensFocus(
    this.position, {
    this.adjusting = false,
    this.minimumDistance,
  });

  /// The lens position: 0.0 is the nearest the lens can focus, 1.0 far. Not
  /// a distance; the same distance reads differently on other cameras.
  final double position;

  /// Whether the camera is focusing now.
  final bool adjusting;

  /// The nearest the camera can focus, in millimeters, where known.
  final int? minimumDistance;
}

/// The physical cameras of one side, on iPhones.
enum CameraLens {
  /// The main (wide) camera.
  main,

  /// The ultra-wide camera ([CameraCapabilities.ultraWide]).
  ultraWide,

  /// The telephoto camera ([CameraCapabilities.telephoto]).
  telephoto,
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
  /// frames: its [lens] where a side has several (see
  /// [CameraCapabilities.ultraWide] and [CameraCapabilities.telephoto]).
  /// Throws a [ScannerException] if it cannot.
  ///
  /// Opens and closes run one after the other in the order they were asked
  /// for ([CameraTurns]); a camera still open is closed first.
  Future<CameraCapabilities> open(
    CameraFacing facing,
    CameraResolution resolution, {
    CameraLens lens = CameraLens.main,
  });

  /// Releases the camera: also the one an [open] asked for before brings.
  /// A pending [nextFrame] completes with `null` at once.
  Future<void> close();

  /// Lets go of what the source holds besides the camera (the web's
  /// `<video>` element), after the last [close]. The source is not used
  /// again.
  void dispose();

  /// A frame newer than the last one handed out; waits for the camera.
  /// `null` once the camera is closed. Throws a [ScannerException] when the
  /// camera fails after it opened (another app took it).
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

  /// Where the open camera's lens is focused; `null` where unknown: only
  /// iPhones report it. Read on every frame by the automatic zoom.
  LensFocus? lensFocus();
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

  /// The frame in color, to freeze it on screen; `null` without [pixels].
  FrameColors? get colors {
    final PixelBuffer? pixels = this.pixels;
    return pixels == null ? null : FrameColors.of(pixels);
  }

  /// The grayscale part of the frame around [positions] (frame pixels), for
  /// cut-outs of the codes found: from [pixels] where they are in memory.
  /// Asked right after [read] found the codes.
  FrameCut? cut(List<BarcodePosition> positions, {List<bool>? linear}) {
    final PixelBuffer? pixels = this.pixels;
    return pixels == null ? null : cutFrame(pixels, positions, linear: linear);
  }

  /// When the frame reached Dart, on [cameraClock].
  int get arrivalMicros;

  /// Frames the camera delivered since the previous frame handed out, that
  /// were replaced before they could be decoded (0 where unknown); counted
  /// anew for each camera opened.
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
  // Letters only: "CAMERA_IN_USE", "cameraInUse" and "already in use" alike,
  // "camera_not_found" (camera_desktop) like "NotFoundError".
  final RegExp other = RegExp('[^a-z]');
  final String c = code.toLowerCase().replaceAll(other, '');
  final String all = text.toLowerCase().replaceAll(other, '');
  if ((c.contains('denied') ||
          c.contains('restricted') ||
          c.contains('permission') ||
          c.contains('notallowed')) &&
      !c.contains('ongoing')) {
    return CameraPermissionException(text);
  }
  if (c.contains('notfound') ||
      c.contains('nocamera') ||
      c.contains('overconstrained')) {
    return CameraNotFoundException(text);
  }
  if (c.contains('notreadable') ||
      c.contains('trackstart') ||
      all.contains('camerainuse') ||
      all.contains('camerasinuse') ||
      all.contains('alreadyinuse') ||
      all.contains('numberofopencameras')) {
    return CameraInUseException(text);
  }
  if (c.contains('security') ||
      c.contains('notsupported') ||
      c.contains('insecure')) {
    return CameraUnsupportedException(text);
  }
  return CameraFailureException(text);
}
