part of 'scanner_controller.dart';

/// The camera state of a [ScannerController].
@immutable
final class ScannerState {
  /// Creates a state.
  const ScannerState({
    this.status = ScannerStatus.idle,
    this.error,
    this.torch = TorchState.unavailable,
    this.autoZoom = AutoZoomState.unavailable,
    this.zoom = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.telephotoZoom,
    this.facing = CameraFacing.back,
    this.canSwitchCamera = false,
    this.previewSize,
  });

  /// What the scanner is doing.
  final ScannerStatus status;

  /// Why the scanner stopped, when [status] is [ScannerStatus.error].
  final ScannerException? error;

  /// Torch availability and state.
  final TorchState torch;

  /// Whether the scanner picks the lens and zoom by itself; see
  /// [ScannerController.setAutoZoom].
  final AutoZoomState autoZoom;

  /// Current zoom factor, in terms of the main camera.
  final double zoom;

  /// Smallest supported zoom factor: below 1 when the camera can go wider
  /// than the main lens (an iPhone's ultra-wide camera: 0.5).
  final double minZoom;

  /// Largest supported zoom factor.
  final double maxZoom;

  /// With a separate telephoto camera (iPhone Pro models): the zoom at which
  /// it takes over, e.g. 4 (3 or 5 on other models); zooms from it on use
  /// it. `null` without one.
  final double? telephotoZoom;

  /// The camera in use.
  final CameraFacing facing;

  /// Whether the device has a camera on the other side for
  /// [ScannerController.switchCamera]. Known once a camera has opened, and
  /// kept while it is closed; `false` before.
  final bool canSwitchCamera;

  /// Size of the camera preview in its display orientation, once running.
  final Size? previewSize;

  /// Whether frames are being decoded.
  bool get isScanning => status == ScannerStatus.running;

  /// Creates a copy with the given fields replaced.
  ScannerState copyWith({
    ScannerStatus? status,
    ScannerException? error,
    TorchState? torch,
    AutoZoomState? autoZoom,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    double? telephotoZoom,
    CameraFacing? facing,
    bool? canSwitchCamera,
    Size? previewSize,
  }) => ScannerState(
    status: status ?? this.status,
    error: error ?? this.error,
    torch: torch ?? this.torch,
    autoZoom: autoZoom ?? this.autoZoom,
    zoom: zoom ?? this.zoom,
    minZoom: minZoom ?? this.minZoom,
    maxZoom: maxZoom ?? this.maxZoom,
    telephotoZoom: telephotoZoom ?? this.telephotoZoom,
    facing: facing ?? this.facing,
    canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
    previewSize: previewSize ?? this.previewSize,
  );

  @override
  bool operator ==(Object other) =>
      other is ScannerState &&
      other.status == status &&
      other.error == error &&
      other.torch == torch &&
      other.autoZoom == autoZoom &&
      other.zoom == zoom &&
      other.minZoom == minZoom &&
      other.maxZoom == maxZoom &&
      other.telephotoZoom == telephotoZoom &&
      other.facing == facing &&
      other.canSwitchCamera == canSwitchCamera &&
      other.previewSize == previewSize;

  @override
  int get hashCode => Object.hash(
    status,
    error,
    torch,
    autoZoom,
    zoom,
    minZoom,
    maxZoom,
    telephotoZoom,
    facing,
    canSwitchCamera,
    previewSize,
  );
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

/// Whether the scanner picks the lens and zoom by itself.
enum AutoZoomState {
  /// The camera does not report its focus: only iPhones do.
  unavailable,

  /// Off: the zoom stays where it is set.
  off,

  /// On: the ultra-wide camera when a code is too close for the main lens
  /// to focus, a longer zoom when it is far.
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
  /// view for a moment (about a second), and after a pause: on
  /// [ScannerController.resume], the codes in view are reported anew. The
  /// default.
  distinct,

  /// Every frame that contains a barcode (about 30 times per second).
  continuous,

  /// The first barcode, then decoding pauses until
  /// [ScannerController.resume]. For "scan one code and continue" flows.
  once,
}
