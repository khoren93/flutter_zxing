import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../errors.dart';
import '../reading/reader_options.dart';
import 'scan_window.dart';

/// Drives the camera of a `BarcodeScanner` and decodes its frames.
///
/// Frames are decoded as fast as the camera delivers them, one at a time,
/// in the background; there is no fixed delay and no frame queue.
///
/// ```dart
/// final controller = ScannerController(formats: {BarcodeFormat.qrCode});
///
/// BarcodeScanner(controller: controller);
/// controller.barcodes.listen((capture) => print(capture.barcode.text));
/// await controller.toggleTorch();
///
/// controller.dispose(); // releases the camera
/// ```
///
/// The current camera state is the [value] ([ScannerState]); listen to the
/// controller (or use `ValueListenableBuilder`) to rebuild on changes.
class ScannerController extends ValueNotifier<ScannerState> {
  /// Creates a controller. The camera opens when the first `BarcodeScanner`
  /// using it is shown (if [autoStart]) or when [start] is called.
  ScannerController({
    Set<BarcodeFormat>? formats,
    ReaderOptions options = const ReaderOptions.camera(),
    DetectionMode detection = DetectionMode.distinct,
    ScanWindow scanWindow = const ScanWindow.centered(),
    this.facing = CameraFacing.back,
    this.resolution = CameraResolution.hd,
    this.autoStart = true,
    this.pauseInBackground = true,
  }) : _formats = formats,
       _options = options,
       _detection = detection,
       _scanWindow = scanWindow,
       super(const ScannerState());

  /// Formats to look for; `null` means all. Fewer formats decode faster.
  /// Can be changed while scanning.
  Set<BarcodeFormat>? get formats => _formats;
  set formats(Set<BarcodeFormat>? value) {
    _formats = value;
    _onConfigChanged();
  }

  Set<BarcodeFormat>? _formats;

  /// Search strategies per frame. Can be changed while scanning.
  ReaderOptions get options => _options;
  set options(ReaderOptions value) {
    _options = value;
    _onConfigChanged();
  }

  ReaderOptions _options;

  /// When a barcode is reported. Can be changed while scanning.
  DetectionMode get detection => _detection;
  set detection(DetectionMode value) {
    _detection = value;
    _onConfigChanged();
  }

  DetectionMode _detection;

  /// The part of the preview that is decoded. Can be changed while scanning.
  ScanWindow get scanWindow => _scanWindow;
  set scanWindow(ScanWindow value) {
    _scanWindow = value;
    _onConfigChanged();
  }

  ScanWindow _scanWindow;

  /// The camera opened by [start]. See [switchCamera].
  final CameraFacing facing;

  /// The camera resolution requested by [start].
  final CameraResolution resolution;

  /// Whether a `BarcodeScanner` starts the camera when it is shown.
  final bool autoStart;

  /// Release the camera while the app is in the background and reopen it
  /// when the app returns.
  final bool pauseInBackground;

  // Applies changed settings to a running scanner (stage 5).
  void _onConfigChanged() {}

  /// Barcodes found in the camera frames, according to [detection].
  Stream<BarcodeCapture> get barcodes => throw UnimplementedError('Stage 5');

  /// Opens the camera and starts decoding.
  ///
  /// Errors (no permission, no camera) do not throw: they are reported in
  /// [ScannerState.error] and the status becomes [ScannerStatus.error].
  Future<void> start() => throw UnimplementedError('Stage 5');

  /// Stops decoding and releases the camera.
  Future<void> stop() => throw UnimplementedError('Stage 5');

  /// Stops decoding but keeps the camera and the preview running, e.g. while
  /// a result sheet is shown.
  Future<void> pause() => throw UnimplementedError('Stage 5');

  /// Resumes decoding after [pause] (or after a [DetectionMode.once] result).
  Future<void> resume() => throw UnimplementedError('Stage 5');

  /// Turns the torch on or off. No-op if [ScannerState.torch] is
  /// [TorchState.unavailable].
  Future<void> setTorch(bool enabled) => throw UnimplementedError('Stage 5');

  /// Turns the torch on if it is off, and off if it is on.
  Future<void> toggleTorch() => throw UnimplementedError('Stage 5');

  /// Zooms to [zoom], clamped to 1.0 … [ScannerState.maxZoom].
  Future<void> setZoom(double zoom) => throw UnimplementedError('Stage 5');

  /// Focuses and meters exposure at [point], given as fractions of the
  /// preview (0, 0 is top-left, 1, 1 is bottom-right). `BarcodeScanner`
  /// calls this on tap.
  Future<void> setFocusPoint(Offset point) =>
      throw UnimplementedError('Stage 5');

  /// Switches to the camera with [facing], or to the other one if `null`.
  Future<void> switchCamera([CameraFacing? facing]) =>
      throw UnimplementedError('Stage 5');
}

/// The camera state of a [ScannerController].
@immutable
final class ScannerState {
  /// Creates a state.
  const ScannerState({
    this.status = ScannerStatus.idle,
    this.error,
    this.torch = TorchState.unavailable,
    this.zoom = 1,
    this.maxZoom = 1,
    this.facing = CameraFacing.back,
    this.previewSize,
  });

  /// What the scanner is doing.
  final ScannerStatus status;

  /// Why the scanner stopped, when [status] is [ScannerStatus.error].
  final ScannerException? error;

  /// Torch availability and state.
  final TorchState torch;

  /// Current zoom factor.
  final double zoom;

  /// Largest supported zoom factor.
  final double maxZoom;

  /// The camera in use.
  final CameraFacing facing;

  /// Size of the camera preview in its display orientation, once running.
  final Size? previewSize;

  /// Whether frames are being decoded.
  bool get isScanning => status == ScannerStatus.running;

  /// Creates a copy with the given fields replaced.
  ScannerState copyWith({
    ScannerStatus? status,
    ScannerException? error,
    TorchState? torch,
    double? zoom,
    double? maxZoom,
    CameraFacing? facing,
    Size? previewSize,
  }) => ScannerState(
    status: status ?? this.status,
    error: error ?? this.error,
    torch: torch ?? this.torch,
    zoom: zoom ?? this.zoom,
    maxZoom: maxZoom ?? this.maxZoom,
    facing: facing ?? this.facing,
    previewSize: previewSize ?? this.previewSize,
  );

  @override
  bool operator ==(Object other) =>
      other is ScannerState &&
      other.status == status &&
      other.error == error &&
      other.torch == torch &&
      other.zoom == zoom &&
      other.maxZoom == maxZoom &&
      other.facing == facing &&
      other.previewSize == previewSize;

  @override
  int get hashCode =>
      Object.hash(status, error, torch, zoom, maxZoom, facing, previewSize);
}

/// What a [ScannerController] is doing.
enum ScannerStatus {
  /// The camera is closed.
  idle,

  /// The camera is opening.
  starting,

  /// The camera is open and frames are decoded.
  running,

  /// The camera is open, decoding is paused.
  paused,

  /// The camera could not be opened or failed; see [ScannerState.error].
  error,
}

/// Torch availability and state.
enum TorchState {
  /// The camera has no torch (or the platform does not expose it).
  unavailable,

  /// The torch is off.
  off,

  /// The torch is on.
  on,
}

/// Which camera to use.
enum CameraFacing {
  /// The camera on the back of the device.
  back,

  /// The camera facing the user. The preview is mirrored, like a mirror.
  front,
}

/// Camera resolution. Higher resolutions read smaller and denser codes but
/// decode each frame more slowly.
enum CameraResolution {
  /// About 640×480.
  sd,

  /// About 1280×720. The default: the best balance for barcodes.
  hd,

  /// About 1920×1080.
  fullHd,
}

/// When a [ScannerController] reports a barcode.
enum DetectionMode {
  /// Each barcode once. It is reported again only after it has been out of
  /// view for a moment (about a second). The default.
  distinct,

  /// Every frame that contains a barcode (about 30 times per second).
  continuous,

  /// The first barcode, then decoding pauses until
  /// [ScannerController.resume]. For "scan one code and continue" flows.
  once,
}

/// Barcodes found in one camera frame.
@immutable
final class BarcodeCapture {
  /// Creates a capture. [barcodes] must not be empty.
  const BarcodeCapture({
    required this.barcodes,
    required this.imageSize,
    required this.time,
  }) : assert(barcodes.length > 0, 'A capture has at least one barcode');

  /// The barcodes in the frame, at least one.
  final List<Barcode> barcodes;

  /// The first barcode: the one to use when you expect a single code.
  Barcode get barcode => barcodes.first;

  /// Size of the camera frame, in its display orientation. Barcode positions
  /// are in this coordinate space.
  final Size imageSize;

  /// When the frame was decoded.
  final DateTime time;
}
