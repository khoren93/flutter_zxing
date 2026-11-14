// ScannerController and the widgets that show it (barcode_scanner.dart, a
// part of this library so that it can reach the controller's internals).
library;

import 'dart:async';
import 'dart:math' as math;

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
import '../errors.dart';
import '../reading/reader_options.dart';
import 'camera/camera_source.dart';
import 'frame_geometry.dart';
import 'scan_window.dart';

part 'barcode_scanner.dart';

/// Creates the camera of a controller; replaced in tests.
CameraSource Function() _cameraFactory = CameraSource.create;

/// The clock of [DetectionMode.distinct] and of the outlines; replaced in
/// tests.
DateTime Function() _now = DateTime.now;

/// How long a barcode must be out of view before [DetectionMode.distinct]
/// reports it again.
const Duration _distinctGap = Duration(seconds: 1);

/// How long an outline stays after its barcode was last seen, so that a
/// frame that misses the code does not make it flicker.
const Duration _outlineHold = Duration(milliseconds: 300);

/// Engine failures in a row after which the scanner gives up.
const int _maxEngineFailures = 3;

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
       _facing = facing,
       super(ScannerState(facing: facing)) {
    _readOptions = _engineOptions();
  }

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

  // --- internals ---------------------------------------------------------

  CameraFacing _facing;
  late EngineReadOptions _readOptions;
  CameraSource? _source;
  CameraCapabilities _capabilities = const CameraCapabilities();

  // Identifies the current camera session: bumped by every start and stop,
  // so that a decode loop or an open that outlived its session stops.
  int _session = 0;
  Completer<void>? _resumed;
  int _engineFailures = 0;
  bool _disposed = false;

  final StreamController<BarcodeCapture> _barcodes =
      StreamController<BarcodeCapture>.broadcast();
  final StreamController<ScannerFrameSample> _samples =
      StreamController<ScannerFrameSample>.broadcast();

  // What the overlay shows: the latest barcodes, in the display frame.
  final ValueNotifier<_Visible?> _visible = ValueNotifier<_Visible?>(null);
  DateTime _lastFound = DateTime.fromMillisecondsSinceEpoch(0);

  // DetectionMode.distinct: when each barcode in view was last seen.
  final Map<String, DateTime> _seen = <String, DateTime>{};

  // Reported by the BarcodeScanner widgets showing this controller.
  _View? _view;
  int _widgets = 0;
  bool _startedByWidget = false;

  // Background handling (pauseInBackground).
  AppLifecycleListener? _lifecycle;
  ScannerStatus? _statusBeforeHide;

  EngineReadOptions _engineOptions() => EngineReadOptions.from(
    _formats,
    _options,
    // The first barcode of each frame: on a frame with a code that is often
    // several times faster than looking for more.
    maxSymbols: 1,
  );

  // Applies changed settings to a running scanner.
  void _onConfigChanged() {
    _readOptions = _engineOptions();
    _seen.clear();
  }

  void _set(ScannerState state) {
    if (!_disposed) {
      value = state;
    }
  }

  /// Barcodes found in the camera frames, according to [detection].
  Stream<BarcodeCapture> get barcodes => _barcodes.stream;

  /// Opens the camera and starts decoding.
  ///
  /// Errors (no permission, no camera) do not throw: they are reported in
  /// [ScannerState.error] and the status becomes [ScannerStatus.error].
  Future<void> start() async {
    if (_disposed ||
        value.status == ScannerStatus.starting ||
        value.status == ScannerStatus.running ||
        value.status == ScannerStatus.paused) {
      return;
    }
    if (pauseInBackground) {
      _lifecycle ??= AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    }
    final int session = ++_session;
    _engineFailures = 0;
    _set(ScannerState(status: ScannerStatus.starting, facing: _facing));
    final CameraSource source = _source ??= _cameraFactory();
    source.previewTransform.removeListener(_onPreviewChanged);
    try {
      final CameraCapabilities capabilities = await source.open(
        _facing,
        resolution,
      );
      if (session != _session || _disposed) {
        await source.close();
        return;
      }
      _capabilities = capabilities;
    } on Object catch (e) {
      if (session == _session) {
        await _fail(
          e is ScannerException ? e : CameraFailureException('$e'),
          session,
        );
      }
      return;
    }
    source.previewTransform.addListener(_onPreviewChanged);
    _set(
      ScannerState(
        status: ScannerStatus.running,
        torch: _capabilities.hasTorch ? TorchState.off : TorchState.unavailable,
        maxZoom: math.max(1, _capabilities.maxZoom),
        facing: _facing,
        previewSize: source.previewTransform.value?.displaySize,
      ),
    );
    unawaited(_loop(session, source));
  }

  /// Stops decoding and releases the camera.
  Future<void> stop() async {
    _session++;
    _wakeUp();
    _clearResults();
    final CameraSource? source = _source;
    source?.previewTransform.removeListener(_onPreviewChanged);
    _set(ScannerState(facing: _facing));
    await source?.close();
  }

  /// Stops decoding but keeps the camera and the preview running, e.g. while
  /// a result sheet is shown.
  Future<void> pause() async {
    if (value.status == ScannerStatus.running) {
      _set(value.copyWith(status: ScannerStatus.paused));
    }
  }

  /// Resumes decoding after [pause] (or after a [DetectionMode.once] result).
  Future<void> resume() async {
    if (value.status == ScannerStatus.paused) {
      _seen.clear();
      _set(value.copyWith(status: ScannerStatus.running));
      _wakeUp();
    }
  }

  /// Turns the torch on or off. No-op if [ScannerState.torch] is
  /// [TorchState.unavailable].
  Future<void> setTorch(bool enabled) async {
    final CameraSource? source = _source;
    if (source == null || value.torch == TorchState.unavailable) {
      return;
    }
    try {
      await source.setTorch(enabled);
      _set(value.copyWith(torch: enabled ? TorchState.on : TorchState.off));
    } on Object {
      // The camera says it has no torch after all.
      _set(value.copyWith(torch: TorchState.unavailable));
    }
  }

  /// Turns the torch on if it is off, and off if it is on.
  Future<void> toggleTorch() => setTorch(value.torch != TorchState.on);

  /// Zooms to [zoom], clamped to 1.0 … [ScannerState.maxZoom].
  Future<void> setZoom(double zoom) async {
    final CameraSource? source = _source;
    final double clamped = zoom.clamp(1.0, math.max(1.0, value.maxZoom));
    if (source == null || !value.status.hasCamera) {
      return;
    }
    await source.setZoom(clamped);
    _set(value.copyWith(zoom: clamped));
  }

  /// Focuses and meters exposure at [point], given as fractions of the
  /// preview (0, 0 is top-left, 1, 1 is bottom-right). `BarcodeScanner`
  /// calls this on tap.
  Future<void> setFocusPoint(Offset point) async {
    if (value.status.hasCamera) {
      await _source?.setFocusPoint(
        Offset(point.dx.clamp(0, 1), point.dy.clamp(0, 1)),
      );
    }
  }

  /// Switches to the camera with [facing], or to the other one if `null`.
  Future<void> switchCamera([CameraFacing? facing]) async {
    final CameraFacing target =
        facing ??
        (_facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back);
    if (target == _facing) {
      return;
    }
    _facing = target;
    final ScannerStatus status = value.status;
    if (status.hasCamera || status == ScannerStatus.starting) {
      await stop();
      await start();
      if (status == ScannerStatus.paused) {
        await pause();
      }
    } else {
      _set(value.copyWith(facing: target));
    }
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _session++;
    _wakeUp();
    _lifecycle?.dispose();
    final CameraSource? source = _source;
    source?.previewTransform.removeListener(_onPreviewChanged);
    unawaited(source?.close());
    _disposed = true;
    unawaited(_barcodes.close());
    unawaited(_samples.close());
    _visible.dispose();
    super.dispose();
  }

  // --- decoding ------------------------------------------------------------

  Future<void> _loop(int session, CameraSource source) async {
    while (session == _session && !_disposed) {
      if (value.status == ScannerStatus.paused) {
        await (_resumed ??= Completer<void>()).future;
        continue;
      }
      final CameraFrame? frame = await source.nextFrame();
      if (frame == null || session != _session || _disposed) {
        return;
      }
      if (value.status != ScannerStatus.running) {
        continue;
      }
      final (bool visible, Rect? crop) = _cropFor(frame.transform);
      if (!visible) {
        continue; // the scan window shows none of the frame
      }
      final Stopwatch clock = Stopwatch()..start();
      final EngineReadResult result;
      try {
        result = await frame.read(BarcodeEngine.scanner, crop, _readOptions);
      } on ScannerException catch (e) {
        await _fail(e, session);
        return;
      } on Object catch (e) {
        // The engine restarts itself on the next call; give up only if it
        // keeps failing.
        if (++_engineFailures >= _maxEngineFailures) {
          await _fail(
            CameraFailureException('The barcode engine failed: $e'),
            session,
          );
          return;
        }
        continue;
      }
      _engineFailures = 0;
      if (session != _session || _disposed) {
        return;
      }
      _onFrame(frame.transform, result, crop, clock.elapsedMicroseconds);
    }
  }

  /// The pixels of [frame] to decode: the scan window as the user sees it.
  /// The first value is `false` if the window shows none of the frame.
  (bool, Rect?) _cropFor(FrameTransform frame) {
    final Size display = frame.displaySize;
    final _View? view = _view;
    final FrameTransform? preview = _source?.previewTransform.value;
    Rect window;
    if (view == null || preview == null) {
      window = _scanWindow.resolve(display);
    } else {
      // The preview may come in another size than the frames (but shows the
      // same picture): scale between the two.
      final Size shown = preview.displaySize;
      final Rect? inPreview = PreviewFit(
        shown,
        view.size,
        view.fit,
      ).rectToFrame(_scanWindow.resolve(view.size));
      if (inPreview == null) {
        return (false, null);
      }
      final double sx = display.width / shown.width;
      final double sy = display.height / shown.height;
      window = Rect.fromLTRB(
        inPreview.left * sx,
        inPreview.top * sy,
        inPreview.right * sx,
        inPreview.bottom * sy,
      );
    }
    final Rect? crop = pixelCrop(frame.rectToFrame(window), frame.frameSize);
    if (crop == null) {
      return (false, null);
    }
    return (true, crop == Offset.zero & frame.frameSize ? null : crop);
  }

  void _onFrame(
    FrameTransform frame,
    EngineReadResult result,
    Rect? crop,
    int micros,
  ) {
    final Size display = frame.displaySize;
    final List<Barcode> barcodes = <Barcode>[
      for (final Barcode b in result.barcodes)
        if (b.isValid) frame.barcodeToDisplay(b),
    ];
    final DateTime now = _now();
    if (_samples.hasListener) {
      _samples.add(
        ScannerFrameSample(
          found: barcodes.isNotEmpty,
          engineMicros: result.engineMicros,
          roundTripMicros: micros,
          frameSize: frame.frameSize,
          crop: crop,
        ),
      );
    }
    if (barcodes.isNotEmpty) {
      _lastFound = now;
      _visible.value = _Visible(barcodes, display);
    } else if (_visible.value != null &&
        now.difference(_lastFound) > _outlineHold) {
      _visible.value = null;
    }

    _seen.removeWhere(
      (String _, DateTime seen) => now.difference(seen) > _distinctGap,
    );
    if (barcodes.isEmpty) {
      return;
    }
    switch (_detection) {
      case DetectionMode.continuous:
        _emit(barcodes, display, now);
      case DetectionMode.once:
        _emit(barcodes, display, now);
        unawaited(pause());
      case DetectionMode.distinct:
        final List<Barcode> fresh = <Barcode>[
          for (final Barcode b in barcodes)
            if (!_seen.containsKey(_keyOf(b))) b,
        ];
        for (final Barcode b in barcodes) {
          _seen[_keyOf(b)] = now;
        }
        if (fresh.isNotEmpty) {
          _emit(fresh, display, now);
        }
    }
  }

  static String _keyOf(Barcode b) =>
      '${b.format.index}|${b.text}|${b.bytes.length}';

  void _emit(List<Barcode> barcodes, Size display, DateTime now) {
    if (!_barcodes.isClosed) {
      _barcodes.add(
        BarcodeCapture(barcodes: barcodes, imageSize: display, time: now),
      );
    }
  }

  Future<void> _fail(ScannerException error, int session) async {
    if (session != _session) {
      return;
    }
    _session++;
    _clearResults();
    final CameraSource? source = _source;
    source?.previewTransform.removeListener(_onPreviewChanged);
    _set(
      ScannerState(status: ScannerStatus.error, error: error, facing: _facing),
    );
    await source?.close();
  }

  void _wakeUp() {
    final Completer<void>? resumed = _resumed;
    _resumed = null;
    resumed?.complete();
  }

  void _clearResults() {
    _seen.clear();
    if (!_disposed) {
      _visible.value = null;
    }
  }

  void _onPreviewChanged() {
    final Size? size = _source?.previewTransform.value?.displaySize;
    if (size != null && value.status.hasCamera) {
      _set(value.copyWith(previewSize: size));
    }
  }

  // --- background ----------------------------------------------------------

  void _onHide() {
    final ScannerStatus status = value.status;
    if (status.hasCamera || status == ScannerStatus.starting) {
      _statusBeforeHide = status == ScannerStatus.paused
          ? ScannerStatus.paused
          : ScannerStatus.running;
      unawaited(stop());
    }
  }

  void _onShow() {
    final ScannerStatus? before = _statusBeforeHide;
    _statusBeforeHide = null;
    if (before != null && value.status == ScannerStatus.idle) {
      unawaited(
        start().then((_) {
          if (before == ScannerStatus.paused) {
            return pause();
          }
        }),
      );
    }
  }

  // --- widgets ---------------------------------------------------------------

  void _attach() {
    _widgets++;
    if (autoStart && value.status == ScannerStatus.idle) {
      _startedByWidget = true;
      unawaited(start());
    }
  }

  void _detach() {
    _widgets--;
    if (_widgets == 0) {
      _view = null;
      if (_startedByWidget && !_disposed) {
        _startedByWidget = false;
        unawaited(stop());
      }
    }
  }

  void _layout(Size size, BoxFit fit) => _view = _View(size, fit);
}

extension on ScannerStatus {
  /// Whether the camera is open.
  bool get hasCamera =>
      this == ScannerStatus.running || this == ScannerStatus.paused;
}

/// The latest barcodes of a controller, for the overlay.
@immutable
final class _Visible {
  const _Visible(this.barcodes, this.frameSize);

  /// Positions in the display frame of [frameSize].
  final List<Barcode> barcodes;
  final Size frameSize;
}

/// Where a `BarcodeScanner` shows the preview.
@immutable
final class _View {
  const _View(this.size, this.fit);
  final Size size;
  final BoxFit fit;
}

/// Timing of one decoded camera frame. Not part of the public API: the
/// example app's benchmark reads it through [ScannerControllerDebug].
@immutable
final class ScannerFrameSample {
  /// Creates a sample.
  const ScannerFrameSample({
    required this.found,
    required this.engineMicros,
    required this.roundTripMicros,
    required this.frameSize,
    this.crop,
  });

  /// Whether the frame had a barcode.
  final bool found;

  /// Time inside the engine.
  final int engineMicros;

  /// From handing the frame to the engine to its result on this isolate.
  final int roundTripMicros;

  /// Size of the frame as delivered.
  final Size frameSize;

  /// The decoded part of the frame, `null` for all of it.
  final Rect? crop;
}

/// Hooks for tests and the example's benchmark. Not exported.
extension ScannerControllerDebug on ScannerController {
  /// Replaces the camera of controllers started afterwards; `null` restores
  /// the platform camera.
  static set cameraFactory(CameraSource Function()? factory) =>
      _cameraFactory = factory ?? CameraSource.create;

  /// Replaces the clock of every controller; `null` restores the real one.
  static set clock(DateTime Function()? now) => _now = now ?? DateTime.now;

  /// Timing of every decoded frame.
  Stream<ScannerFrameSample> get frameSamples => _samples.stream;
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
