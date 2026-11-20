// ScannerController and the widgets that show it (barcode_scanner.dart, a
// part of this library so that it can reach the controller's internals).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show compute, setEquals;
import 'package:flutter/widgets.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../engine/engine.dart';
import '../engine/engine_protocol.dart';
import '../errors.dart';
import '../reading/pixel_buffer.dart';
import '../reading/reader_options.dart';
import 'auto_lens.dart';
import 'camera/camera_source.dart';
import 'camera/frame_colors.dart';
import 'frame_geometry.dart';
import 'scan_window.dart';
import 'snapshot.dart';
import 'ui/scan_verdict.dart';
import 'ui/scanner_strings.dart';
import 'ui/scanner_template.dart';
import 'ui/scanner_theme.dart';
import 'ui/states.dart';
import 'ui/template_overlay.dart';
import 'ui/window_overlay.dart';

part 'barcode_scanner.dart';

/// Creates the camera of a controller; replaced in tests.
CameraSource Function() _cameraFactory = CameraSource.create;

/// The clock of [DetectionMode.distinct] and of the outlines; replaced in
/// tests.
DateTime Function() _now = DateTime.now;

/// How long a barcode must be out of view before [DetectionMode.distinct]
/// reports it again.
const Duration _distinctGap = Duration(seconds: 1);

/// How long an outline stays after its barcode was last seen, so that the
/// frames that miss the code do not make it flicker: with many codes in
/// view the engine misses one now and then for a few frames.
const Duration _outlineHold = Duration(milliseconds: 500);

/// Engine failures in a row after which the scanner gives up.
const int _maxEngineFailures = 3;

/// A camera that sends no frame for this long has stalled (an interruption,
/// the system under pressure): it is opened again.
const Duration _cameraStall = Duration(seconds: 3);

/// An engine that has not decoded a frame in this long is stuck: it is
/// replaced by a new one.
const Duration _decodeStall = Duration(seconds: 5);

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
    int? maxBarcodes = 1,
    CameraFacing facing = CameraFacing.back,
    this.resolution = CameraResolution.hd,
    this.autoStart = true,
    this.stopInBackground = true,
    bool autoZoom = true,
    double? initialZoom,
    bool torch = false,
  }) : _formats = _checkFormats(formats),
       _initialZoom = initialZoom,
       _autoZoom = autoZoom,
       _torch = torch,
       _options = options,
       _detection = detection,
       _scanWindow = scanWindow,
       _maxBarcodes = _checkMax(maxBarcodes),
       _facing = facing,
       super(ScannerState(facing: facing)) {
    _readOptions = _engineOptions();
  }

  /// Creates a controller with the camera settings of [template]: its
  /// scan window, formats, detection, maxBarcodes, facing and initialZoom,
  /// the settings `BarcodeScanner` gives the controller it creates for a
  /// template. For a controller of your own that the template's screen
  /// uses:
  ///
  /// ```dart
  /// late final controller = ScannerController.fromTemplate(template);
  ///
  /// BarcodeScanner(controller: controller, template: template);
  /// ```
  ///
  /// The other settings are those of the default constructor.
  factory ScannerController.fromTemplate(
    ScannerTemplate template, {
    ReaderOptions options = const ReaderOptions.camera(),
    CameraResolution resolution = CameraResolution.hd,
    bool autoStart = true,
    bool stopInBackground = true,
    bool autoZoom = true,
    bool torch = false,
  }) => ScannerController(
    formats: template.formats,
    options: options,
    detection: template.detection,
    scanWindow: template.scanWindow,
    maxBarcodes: template.maxBarcodes,
    facing: template.facing ?? CameraFacing.back,
    resolution: resolution,
    autoStart: autoStart,
    stopInBackground: stopInBackground,
    autoZoom: autoZoom,
    initialZoom: template.initialZoom,
    torch: torch,
  );

  /// [formats] after the check `BarcodeReader` makes: [ArgumentError] for
  /// an empty set and for a format that cannot be read.
  static Set<BarcodeFormat>? _checkFormats(Set<BarcodeFormat>? formats) {
    EngineReadOptions.formatsToEngine(formats);
    return formats;
  }

  static int? _checkMax(int? value) {
    if (value != null && value < 1) {
      throw RangeError.range(value, 1, null, 'maxBarcodes');
    }
    return value;
  }

  /// Formats to look for; `null` means all. Fewer formats decode faster.
  /// Can be changed while scanning.
  ///
  /// Throws [ArgumentError] for an empty set and for a format that cannot
  /// be read ([BarcodeFormat.canRead]: the EAN add-ons, `isbn`, `unknown`).
  Set<BarcodeFormat>? get formats => _formats;
  set formats(Set<BarcodeFormat>? value) {
    if (setEquals(_checkFormats(value), _formats)) {
      return;
    }
    _formats = value;
    _onConfigChanged();
  }

  Set<BarcodeFormat>? _formats;

  /// Search strategies per frame. Can be changed while scanning.
  ReaderOptions get options => _options;
  set options(ReaderOptions value) {
    if (value == _options) {
      return;
    }
    _options = value;
    _onConfigChanged();
  }

  ReaderOptions _options;

  /// When a barcode is reported. Can be changed while scanning.
  DetectionMode get detection => _detection;
  set detection(DetectionMode value) {
    if (value == _detection) {
      return;
    }
    _detection = value;
    _onConfigChanged();
  }

  DetectionMode _detection;

  /// The part of the preview that is decoded. Can be changed while scanning.
  ScanWindow get scanWindow => _scanWindow;
  set scanWindow(ScanWindow value) {
    if (value == _scanWindow) {
      return;
    }
    _scanWindow = value;
    _onConfigChanged();
  }

  ScanWindow _scanWindow;

  /// How many barcodes to look for in each frame; `null` for all of them.
  /// Can be changed while scanning.
  ///
  /// The default, 1, stops at the first barcode: a frame with a barcode is
  /// decoded several times faster than when looking for all of them, so it
  /// is reported sooner. Raise it to scan several codes at once (shelves,
  /// inventory). Throws [RangeError] below 1.
  int? get maxBarcodes => _maxBarcodes;
  set maxBarcodes(int? value) {
    if (_checkMax(value) == _maxBarcodes) {
      return;
    }
    _maxBarcodes = value;
    _onConfigChanged();
  }

  int? _maxBarcodes;

  /// The camera in use, or the one [start] opens: the `facing` given to the
  /// constructor until [switchCamera] changes it.
  CameraFacing get facing => _facing;

  /// The camera resolution requested by [start].
  final CameraResolution resolution;

  /// Whether a `BarcodeScanner` starts the camera when it is shown.
  final bool autoStart;

  /// The zoom every [start] sets, such as 2 for small codes; `null` starts
  /// at 1×. Set again after the app returns from the background and after
  /// [switchCamera], and clamped to what the camera can do. Changed while
  /// the camera is open, the camera zooms there at once.
  ///
  /// Unlike [setZoom] it leaves automatic zoom on: from one of its steps
  /// (1×, 2×, a camera's own zoom) automatic zoom moves on when the focus
  /// asks for it; from another zoom it waits until the zoom is set to one
  /// of them.
  double? get initialZoom => _initialZoom;
  set initialZoom(double? zoom) {
    if (zoom == _initialZoom) {
      return;
    }
    _initialZoom = zoom;
    if (value.status.hasCamera) {
      unawaited(_zoom(zoom ?? 1));
    }
  }

  double? _initialZoom;

  /// Release the camera while the app is in the background and open it
  /// again when the app returns: the camera is stopped, not paused, so that
  /// other apps can use it. A scanner paused before stays paused.
  final bool stopInBackground;

  // --- internals ---------------------------------------------------------

  CameraFacing _facing;

  /// Whether the torch should be on: the `torch` given to the constructor,
  /// then the last [setTorch]. Applied on every start.
  bool _torch;

  /// Whether the device has a camera on the other side; `null` until a
  /// camera has opened.
  bool? _otherFacing;

  /// Sides whose camera turned out missing when [switchCamera] opened it.
  final Set<CameraFacing> _missing = <CameraFacing>{};

  /// The state of a closed camera.
  ScannerState get _closed =>
      ScannerState(facing: _facing, canSwitchCamera: _otherFacing ?? false);

  late EngineReadOptions _readOptions;
  CameraSource? _source;
  CameraCapabilities _capabilities = const CameraCapabilities();

  // Identifies the current camera session: bumped by every start and stop,
  // so that a decode loop or an open that outlived its session stops.
  int _session = 0;
  Completer<void>? _resumed;
  int _engineFailures = 0;
  int _cameraRestarts = 0;
  int _engineRestarts = 0;
  (CameraFrame, Rect?)? _lastFrame;
  bool _disposed = false;

  final StreamController<BarcodeCapture> _barcodes =
      StreamController<BarcodeCapture>.broadcast();
  final StreamController<ScannerFrameSample> _samples =
      StreamController<ScannerFrameSample>.broadcast();

  // What the overlay shows: the latest barcodes, in the display frame.
  final ValueNotifier<_Visible?> _visible = ValueNotifier<_Visible?>(null);
  DateTime _lastFound = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_Track> _tracks = <_Track>[];
  int _nextTrack = 0;
  Size? _trackedIn;

  // DetectionMode.distinct: when each barcode in view was last seen.
  final Map<String, DateTime> _seen = <String, DateTime>{};

  // Reported by the BarcodeScanner widgets showing this controller.
  _View? _view;
  int _widgets = 0;
  bool _startedByWidget = false;

  // Background handling (stopInBackground).
  AppLifecycleListener? _lifecycle;
  ScannerStatus? _statusBeforeHide;

  // Set by ScannerControllerDebug, for the example's diagnostics page.
  int _debugEngineFlags = 0;
  Duration? _debugReadInterval;

  EngineReadOptions _engineOptions() => EngineReadOptions.from(
    _formats,
    _options,
    maxSymbols: _maxBarcodes ?? 0,
  ).withFlags(_debugEngineFlags);

  // Applies changed settings to a running scanner.
  void _onConfigChanged() {
    _readOptions = _engineOptions();
    _seen.clear();
  }

  // --- lenses ----------------------------------------------------------------

  /// See [CameraCapabilities.ultraWide]; `null` without an ultra-wide
  /// camera to switch to.
  double? _ultraWide;

  /// See [CameraCapabilities.telephoto]; `null` without a telephoto camera
  /// to switch to.
  double? _telephoto;

  /// See [CameraCapabilities.ultraWideFocusesCloser]: only then does
  /// automatic zoom go to the ultra-wide camera.
  bool _ultraWideFocusesCloser = false;

  /// The camera that is open. Zoom factors stay in the main camera's terms
  /// ([ScannerState.zoom] 0.5 is the ultra-wide camera's 1, 4 a 4×
  /// telephoto camera's 1).
  CameraLens _lens = CameraLens.main;

  /// The zoom of [lens]'s own 1, in the main camera's terms.
  double _lensZoom(CameraLens lens) => switch (lens) {
    CameraLens.main => 1,
    CameraLens.ultraWide => _ultraWide ?? 1,
    CameraLens.telephoto => _telephoto ?? 1,
  };

  /// The camera that shows [zoom]: below 1 the ultra-wide camera, from the
  /// telephoto camera's zoom on the telephoto camera, the main one between.
  CameraLens _lensFor(double zoom) {
    final double? telephoto = _telephoto;
    if (_ultraWide != null && zoom < 1 - 1e-6) {
      return CameraLens.ultraWide;
    }
    if (telephoto != null && zoom >= telephoto - 1e-6) {
      return CameraLens.telephoto;
    }
    return CameraLens.main;
  }

  /// Largest zoom factor of the lens that is open, in its own terms.
  double _lensMaxZoom = 1;

  Future<void>? _lensSwitch;

  /// The last zoom asked for by [setZoom] and not applied yet.
  double? _wantedZoom;
  Future<void>? _zoomWorker;

  // --- automatic zoom (the numbers are in auto_lens.dart) -------------------

  /// Whether automatic zoom is wanted: [setAutoZoom]; zooming by hand turns
  /// it off.
  bool _autoZoom;

  /// The step the lens position points to, and since when.
  double? _autoTarget;
  DateTime _autoSince = DateTime(0);

  /// When automatic zoom last changed the zoom.
  DateTime _autoChanged = DateTime(0);

  /// The cameras automatic zoom moves between: the ultra-wide one only
  /// where it focuses closer than the main one (a fixed-focus one is no
  /// help close up, and would be left again at once).
  AutoLensZooms get _autoLensZooms => autoLensZooms(
    ultraWide: _ultraWideFocusesCloser ? _ultraWide : null,
    telephoto: _telephoto,
  );

  /// Automatic zoom works with the back camera of an iPhone: the cameras
  /// that report their focus.
  AutoZoomState _autoZoomState(CameraSource source) =>
      _facing == CameraFacing.back && source.lensFocus() != null
      ? (_autoZoom ? AutoZoomState.on : AutoZoomState.off)
      : AutoZoomState.unavailable;

  /// After a decoded frame: moves to the zoom step the lens position points
  /// to, once it has pointed there long enough and no code is being read.
  void _autoZoomStep(CameraSource source) {
    if (value.autoZoom != AutoZoomState.on ||
        _lensSwitch != null ||
        _zoomWorker != null) {
      _autoTarget = null;
      return;
    }
    final double? lens = source.lensFocus()?.position;
    final DateTime now = _now();
    final double? target =
        lens == null ||
            now.difference(_autoChanged) < AutoLensTuning.settle ||
            now.difference(_lastFound) < AutoLensTuning.idle
        ? null
        : autoLensTarget(value.zoom, lens, _autoLensZooms);
    if (target != _autoTarget) {
      _autoTarget = target;
      _autoSince = now;
      return;
    }
    if (target == null ||
        now.difference(_autoSince) <
            (target < value.zoom
                ? AutoLensTuning.holdNear
                : AutoLensTuning.holdFar)) {
      return;
    }
    _autoTarget = null;
    _autoChanged = now;
    unawaited(_zoom(target).whenComplete(() => _autoChanged = _now()));
  }

  Future<void> _applyWantedZoom() async {
    while (!_disposed) {
      while (_lensSwitch != null) {
        await _lensSwitch;
      }
      final double? zoom = _wantedZoom;
      _wantedZoom = null;
      if (zoom == null || !value.status.hasCamera) {
        return;
      }
      await _switchLens(_lensFor(zoom), zoom);
    }
  }

  /// Opens [lens] at [zoom] (in the main camera's terms), keeping the
  /// scanner's state: no "starting" state in between, the torch stays on.
  Future<void> _switchLens(CameraLens lens, double zoom) => _lensSwitch ??=
      _doSwitchLens(lens, zoom).whenComplete(() => _lensSwitch = null);

  Future<void> _doSwitchLens(CameraLens lens, double zoom) async {
    final CameraSource? source = _source;
    if (source == null || !value.status.hasCamera) {
      return;
    }
    int session = _session;
    if (lens != _lens) {
      session = ++_session;
      _wakeUp();
      _clearResults();
      source.previewTransform.removeListener(_onPreviewChanged);
      try {
        await source.close();
        if (session != _session || _disposed) {
          // Stopped while the camera closed: its close came before this
          // open, so nothing would close the camera opened now.
          return;
        }
        final CameraCapabilities capabilities = await source.open(
          _facing,
          resolution,
          lens: lens,
        );
        if (session != _session || _disposed) {
          return; // stopped meanwhile: its close comes after this open
        }
        _lens = lens;
        _lensMaxZoom = capabilities.maxZoom;
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
      // The torch as chosen now: setTorch may have been called meanwhile,
      // and reached the camera that closed.
      if (_torch && value.torch != TorchState.unavailable) {
        await _setTorch(source, true);
        if (session != _session || _disposed) {
          return;
        }
      }
      _set(
        value.copyWith(previewSize: source.previewTransform.value?.displaySize),
      );
      unawaited(_loop(session, source));
    }
    final double lensZoom = _lensZoom(_lens);
    final double physical = (zoom / lensZoom).clamp(
      1.0,
      math.max(1.0, _lensMaxZoom),
    );
    await source.setZoom(physical);
    if (session == _session) {
      _set(value.copyWith(zoom: physical * lensZoom));
    }
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
  /// After a denied permission, the camera is tried again when the app
  /// returns to the foreground while a `BarcodeScanner` shows this
  /// controller: the user may have turned access on in the settings.
  Future<void> start() async {
    if (_disposed ||
        value.status == ScannerStatus.starting ||
        value.status == ScannerStatus.running ||
        value.status == ScannerStatus.paused) {
      return;
    }
    _lifecycle ??= AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    final int session = ++_session;
    _engineFailures = 0;
    _lens = CameraLens.main;
    _autoTarget = null;
    _autoChanged = DateTime(0);
    _set(_closed.copyWith(status: ScannerStatus.starting));
    final CameraSource source = _source ??= _cameraFactory();
    source.previewTransform.removeListener(_onPreviewChanged);
    try {
      final CameraCapabilities capabilities = await source.open(
        _facing,
        resolution,
      );
      if (session != _session || _disposed) {
        // Stopped meanwhile: the stop asked the camera to close after this
        // open. A close asked for now would come after a newer open, and
        // close that camera.
        return;
      }
      _capabilities = capabilities;
      _ultraWide = capabilities.ultraWide;
      _telephoto = capabilities.telephoto;
      _ultraWideFocusesCloser = capabilities.ultraWideFocusesCloser;
      _lensMaxZoom = capabilities.maxZoom;
      _otherFacing =
          capabilities.hasOtherFacing && !_missing.contains(_facing.other);
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
    final bool paused = _pauseWhenStarted;
    _pauseWhenStarted = false;
    _set(
      ScannerState(
        status: paused ? ScannerStatus.paused : ScannerStatus.running,
        torch: _capabilities.hasTorch ? TorchState.off : TorchState.unavailable,
        autoZoom: _autoZoomState(source),
        minZoom:
            _ultraWide ??
            (_capabilities.minZoom > 0.2
                ? math.min(1, _capabilities.minZoom)
                : 1),
        maxZoom: math.max(_telephoto ?? 1, _capabilities.maxZoom),
        telephotoZoom: _telephoto,
        facing: _facing,
        canSwitchCamera: _otherFacing ?? false,
        previewSize: source.previewTransform.value?.displaySize,
      ),
    );
    unawaited(_loop(session, source));
    if (_torch && _capabilities.hasTorch && session == _session) {
      await _setTorch(source, true);
    }
    final double? zoom = _initialZoom;
    if (zoom != null && session == _session && !_disposed) {
      await _zoom(zoom);
    }
  }

  /// Stops decoding and releases the camera.
  Future<void> stop() async {
    _session++;
    _pauseWhenStarted = false;
    _wakeUp();
    _clearResults();
    _lastFrame = null;
    final CameraSource? source = _source;
    source?.previewTransform.removeListener(_onPreviewChanged);
    _set(_closed);
    await source?.close();
  }

  /// Stops decoding but keeps the camera and the preview running, e.g. while
  /// a result sheet is shown. While the camera is starting, it starts
  /// paused.
  Future<void> pause() async {
    if (value.status == ScannerStatus.running) {
      _set(value.copyWith(status: ScannerStatus.paused));
    } else if (value.status == ScannerStatus.starting) {
      _pauseWhenStarted = true;
    }
  }

  /// Whether [pause] was called while the camera was starting.
  bool _pauseWhenStarted = false;

  /// Resumes decoding after [pause] (or after a [DetectionMode.once] result).
  Future<void> resume() async {
    _pauseWhenStarted = false;
    if (_statusBeforeHide == ScannerStatus.paused) {
      // In the background: the camera comes back scanning.
      _statusBeforeHide = ScannerStatus.running;
    }
    if (value.status == ScannerStatus.paused) {
      _seen.clear();
      _set(value.copyWith(status: ScannerStatus.running));
      _wakeUp();
    }
  }

  /// Reads the barcodes in an image file, such as a photo picked from the
  /// gallery, with this controller's [formats] and [maxBarcodes], and
  /// reports them on [barcodes] like a camera frame: `onDetect` and the
  /// scanner templates see them too. Returns the capture, or `null` when
  /// the image has no barcode.
  ///
  /// The image is searched as thoroughly as by `BarcodeReader` (inverted
  /// codes included), with the other [options] of this controller. With
  /// [DetectionMode.once], a barcode found pauses the camera like a camera
  /// result.
  ///
  /// Throws [ImageDecodeException] if [encodedImage] is not a readable
  /// image, and [EngineException] if the engine failed (the next call
  /// starts it again).
  Future<BarcodeCapture?> readImage(Uint8List encodedImage) async {
    final EngineReadResult result = await BarcodeEngine.shared.readImage(
      encodedImage,
      EngineReadOptions.from(
        _formats,
        _options.copyWith(tryInvert: true, tryRotate: true, tryDownscale: true),
        maxSymbols: _maxBarcodes ?? 0,
      ),
    );
    final List<Barcode> barcodes = <Barcode>[
      for (final Barcode b in result.barcodes)
        if (b.isValid) b,
    ];
    if (barcodes.isEmpty || _disposed) {
      return null;
    }
    final BarcodeCapture capture = BarcodeCapture._(
      barcodes: barcodes,
      imageSize: Size(
        result.imageWidth.toDouble(),
        result.imageHeight.toDouble(),
      ),
      time: _now(),
      source: CaptureSource.image,
      positions: <BarcodePosition>[
        for (final Barcode b in barcodes) b.position,
      ],
      encoded: encodedImage,
    );
    if (!_barcodes.isClosed) {
      _barcodes.add(capture);
    }
    if (_detection == DetectionMode.once) {
      await pause();
    }
    return capture;
  }

  /// The last decoded camera frame in color, turned and mirrored the way
  /// the preview shows it, at most 1280 pixels on its longest side: the
  /// whole picture a code was found in, for example to keep it with the
  /// result or to freeze the screen on it. After [pause] it is the frame
  /// decoded last before it.
  ///
  /// ```dart
  /// await controller.pause();
  /// final ui.Image? frame = await controller.lastFrameImage();
  /// ```
  ///
  /// Each call makes a new image, which the caller disposes. `null` before
  /// the first decoded frame, after [stop] and [switchCamera] until the
  /// next one, and on the web, where frames are not kept in memory. For one
  /// barcode, cut out and straightened, use [BarcodeCapture.snapshot].
  Future<ui.Image?> lastFrameImage() async {
    final CameraFrame? frame = _lastFrame?.$1;
    final FrameColors? colors = frame?.colors;
    if (frame == null || colors == null) {
      return null;
    }
    try {
      final (Uint8List rgba, int width, int height) = await compute(
        frameToRgba,
        (colors, frame.transform),
      );
      final Completer<ui.Image> image = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        rgba,
        width,
        height,
        ui.PixelFormat.rgba8888,
        image.complete,
      );
      return await image.future;
    } on Object {
      return null;
    }
  }

  /// Turns the torch on or off. No-op if [ScannerState.torch] is
  /// [TorchState.unavailable].
  ///
  /// The choice is kept: the torch comes on again when the camera opens
  /// again (after the background, [switchCamera] or [stop] and [start]).
  /// The constructor's `torch` is the choice before the first call.
  Future<void> setTorch(bool enabled) async {
    final CameraSource? source = _source;
    if (source == null || value.torch == TorchState.unavailable) {
      return;
    }
    _torch = enabled;
    await _setTorch(source, enabled);
  }

  Future<void> _setTorch(CameraSource source, bool enabled) async {
    final int session = _session;
    TorchState state;
    try {
      await source.setTorch(enabled);
      state = enabled ? TorchState.on : TorchState.off;
    } on Object {
      // The camera says it has no torch after all.
      state = TorchState.unavailable;
    }
    // A camera closed meanwhile has no torch to report.
    if (session == _session) {
      _set(value.copyWith(torch: state));
    }
  }

  /// Turns the torch on if it is off, and off if it is on.
  Future<void> toggleTorch() => setTorch(value.torch != TorchState.on);

  /// Zooms to [zoom], clamped to [ScannerState.minZoom] …
  /// [ScannerState.maxZoom]. Below 1 an iPhone's ultra-wide camera is used
  /// (0.5 is its whole view); it also focuses much closer. Turns automatic
  /// zoom off.
  Future<void> setZoom(double zoom) async {
    if (value.autoZoom == AutoZoomState.on) {
      await setAutoZoom(false);
    }
    await _zoom(zoom);
  }

  /// Turns automatic zoom on or off. While it is on, an iPhone's scanner
  /// picks the lens and zoom by itself from where the camera is focused: the
  /// ultra-wide camera when a code is too close for the main lens to focus,
  /// a longer zoom when it is far, never while codes are being read. Zooming
  /// by hand ([setZoom]) turns it off. Where the camera does not report its
  /// focus ([AutoZoomState.unavailable]) the choice is kept for later.
  Future<void> setAutoZoom(bool enabled) async {
    _autoZoom = enabled;
    _autoTarget = null;
    if (value.autoZoom == AutoZoomState.unavailable) {
      return;
    }
    _set(
      value.copyWith(autoZoom: enabled ? AutoZoomState.on : AutoZoomState.off),
    );
    // From a zoom set by hand, start over at 1×.
    if (enabled && !isAutoLensZoom(value.zoom, _autoLensZooms)) {
      await _zoom(1);
    }
  }

  /// Turns automatic zoom on if it is off, and off if it is on.
  Future<void> toggleAutoZoom() =>
      setAutoZoom(value.autoZoom != AutoZoomState.on);

  Future<void> _zoom(double zoom) async {
    final CameraSource? source = _source;
    final double clamped = zoom.clamp(
      value.minZoom,
      math.max(1.0, value.maxZoom),
    );
    if (source == null || !value.status.hasCamera) {
      return;
    }
    if (_ultraWide != null || _telephoto != null) {
      // Pinching sends many zooms while a lens opens: only the last one is
      // applied, so the lenses do not open one after the other.
      _wantedZoom = clamped;
      await (_zoomWorker ??= _applyWantedZoom().whenComplete(
        () => _zoomWorker = null,
      ));
      return;
    }
    final int session = _session;
    await source.setZoom(clamped);
    if (session == _session) {
      _set(value.copyWith(zoom: clamped));
    }
  }

  /// Focuses and meters exposure at [point], given as fractions of the
  /// camera preview as shown, not of the widget: (0, 0) is the preview's
  /// top-left corner, (1, 1) its bottom-right, also where the widget covers
  /// only part of it ([BoxFit.cover]). Values outside are clamped.
  /// `BarcodeScanner` calls this on tap; from a tap of your own, map the
  /// position with [ScannerLayout.previewRect]:
  ///
  /// ```dart
  /// final Rect preview = layout.previewRect!;
  /// controller.setFocusPoint(Offset(
  ///   (tap.dx - preview.left) / preview.width,
  ///   (tap.dy - preview.top) / preview.height,
  /// ));
  /// ```
  ///
  /// Does nothing where the camera cannot focus on a point (the web).
  Future<void> setFocusPoint(Offset point) async {
    if (value.status.hasCamera) {
      await _source?.setFocusPoint(
        Offset(point.dx.clamp(0, 1), point.dy.clamp(0, 1)),
      );
    }
  }

  /// Switches to the camera with [facing], or to the other one if `null`.
  ///
  /// Does nothing where the device has no camera on that side
  /// ([ScannerState.canSwitchCamera] is `false` once a camera has opened);
  /// if that turns out only when the camera opens, the camera that was
  /// open opens again. A paused scanner stays paused. While the camera is
  /// closed, only the camera [start] opens changes.
  Future<void> switchCamera([CameraFacing? facing]) async {
    final CameraFacing previous = _facing;
    final CameraFacing target = facing ?? previous.other;
    if (target == previous || _otherFacing == false) {
      return;
    }
    _facing = target;
    final ScannerStatus status = value.status;
    if (status.hasCamera || status == ScannerStatus.starting) {
      await stop();
      await start();
      if (value.status == ScannerStatus.error &&
          value.error is CameraNotFoundException &&
          _facing == target) {
        // No camera there after all: back to the one that worked.
        _missing.add(target);
        _facing = previous;
        await start();
      }
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
    _lastFrame = null;
    _lifecycle?.dispose();
    final CameraSource? source = _source;
    source?.previewTransform.removeListener(_onPreviewChanged);
    if (source != null) {
      unawaited(source.close().whenComplete(source.dispose));
    }
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
      final CameraFrame? frame;
      try {
        frame = await source.nextFrame().timeout(_cameraStall);
      } on ScannerException catch (e) {
        await _fail(e, session);
        return;
      } on TimeoutException {
        if (session != _session) {
          return;
        }
        if (value.status != ScannerStatus.running) {
          continue; // paused meanwhile: wait for the resume
        }
        debugPrint(
          'flutter_zxing: the camera sent no frame for '
          '${_cameraStall.inSeconds} s; opening it again',
        );
        _cameraRestarts++;
        unawaited(_reopen());
        return;
      }
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
        result = await frame
            .read(BarcodeEngine.scanner, crop, _readOptions)
            .timeout(_decodeStall);
      } on ScannerException catch (e) {
        await _fail(e, session);
        return;
      } on TimeoutException {
        // The frame stays with the stuck engine; the next one goes to a new
        // engine.
        debugPrint(
          'flutter_zxing: a frame took more than ${_decodeStall.inSeconds} s '
          'to decode; starting a new engine',
        );
        _engineRestarts++;
        unawaited(BarcodeEngine.scanner.shutdown());
        continue;
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
      if (value.status != ScannerStatus.running) {
        continue; // paused while it was decoded: nothing more is reported
      }
      _lastFrame = (frame, crop);
      _onFrame(frame, result, crop, clock.elapsedMicroseconds);
      _autoZoomStep(source);
      final Duration? interval = _debugReadInterval;
      if (interval != null && clock.elapsed < interval) {
        await Future<void>.delayed(interval - clock.elapsed);
      }
    }
  }

  /// Opens the camera again, keeping a paused scanner paused.
  Future<void> _reopen() async {
    final bool paused = value.status == ScannerStatus.paused;
    await stop();
    if (_disposed) {
      return;
    }
    await start();
    if (paused) {
      await pause();
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
    CameraFrame camera,
    EngineReadResult result,
    Rect? crop,
    int micros,
  ) {
    final FrameTransform frame = camera.transform;
    final Size display = frame.displaySize;
    final List<Barcode> found = <Barcode>[
      for (final Barcode b in result.barcodes)
        if (b.isValid) b,
    ];
    final List<Barcode> barcodes = <Barcode>[
      for (final Barcode b in found) frame.barcodeToDisplay(b),
    ];
    final DateTime now = _now();
    if (_samples.hasListener) {
      _samples.add(
        ScannerFrameSample(
          found: barcodes.isNotEmpty,
          engineMicros: result.engineMicros,
          roundTripMicros: micros,
          latencyMicros: cameraClock.elapsedMicroseconds - camera.arrivalMicros,
          dropped: camera.dropped,
          frameSize: frame.frameSize,
          crop: crop,
          failed: result.barcodes.length - found.length,
          details: result.details,
          reads: found,
        ),
      );
    }
    if (barcodes.isNotEmpty) {
      _lastFound = now;
    }
    _follow(barcodes, display, now);

    _seen.removeWhere(
      (String _, DateTime seen) => now.difference(seen) > _distinctGap,
    );
    if (barcodes.isEmpty) {
      return;
    }
    switch (_detection) {
      case DetectionMode.continuous:
        _emit(camera, found, barcodes, display, now);
      case DetectionMode.once:
        _emit(camera, found, barcodes, display, now);
        unawaited(pause());
      case DetectionMode.distinct:
        final List<int> fresh = <int>[
          for (int i = 0; i < barcodes.length; i++)
            if (!_seen.containsKey(_keyOf(barcodes[i]))) i,
        ];
        for (final Barcode b in barcodes) {
          _seen[_keyOf(b)] = now;
        }
        if (fresh.isNotEmpty) {
          _emit(
            camera,
            <Barcode>[for (final int i in fresh) found[i]],
            <Barcode>[for (final int i in fresh) barcodes[i]],
            display,
            now,
          );
        }
    }
  }

  static String _keyOf(Barcode b) =>
      '${b.format.index}|${b.text}|${b.bytes.length}';

  /// Matches the codes of a frame to the codes in view: each to the nearest
  /// one with the same content (two codes may have the same), a new one
  /// when there is none. A code the frame missed stays for [_outlineHold],
  /// so that codes neither flicker nor change their order.
  void _follow(List<Barcode> barcodes, Size frame, DateTime now) {
    if (_trackedIn != frame) {
      // Another camera or a turned device: positions start anew.
      _tracks.clear();
      _trackedIn = frame;
      _visible.value = null;
    }
    if (barcodes.isEmpty && _tracks.isEmpty) {
      return;
    }
    final double still = frame.shortestSide * 0.02;
    final List<_Track> open = List<_Track>.of(_tracks);
    for (final Barcode found in barcodes) {
      final Offset center = found.position.bounds.center;
      _Track? nearest;
      double distance = double.infinity;
      for (final _Track track in open) {
        if (track.barcode.format != found.format ||
            track.barcode.text != found.text) {
          continue;
        }
        final double d =
            (track.barcode.position.bounds.center - center).distance;
        if (d < distance) {
          nearest = track;
          distance = d;
        }
      }
      if (nearest == null) {
        _tracks.add(_Track(_nextTrack++, found, found.position.corners, now));
      } else {
        open.remove(nearest);
        nearest.update(found, now, still);
      }
    }
    final int before = _tracks.length;
    _tracks.removeWhere(
      (_Track track) => now.difference(track.seen) > _outlineHold,
    );
    if (barcodes.isEmpty && _tracks.length == before) {
      // Nothing moved.
      return;
    }
    _visible.value = _tracks.isEmpty
        ? null
        : _Visible(<_Seen>[for (final _Track t in _tracks) t.seenAs], frame);
  }

  /// Reports [barcodes] ([raw]: the same in frame pixels) with the part of
  /// the frame around them, for [BarcodeCapture.snapshot].
  void _emit(
    CameraFrame camera,
    List<Barcode> raw,
    List<Barcode> barcodes,
    Size display,
    DateTime now,
  ) {
    if (_barcodes.isClosed) {
      return;
    }
    final List<BarcodePosition> positions = <BarcodePosition>[
      for (final Barcode b in raw) b.position,
    ];
    _barcodes.add(
      BarcodeCapture._(
        barcodes: barcodes,
        imageSize: display,
        time: now,
        source: CaptureSource.camera,
        cut: camera.cut(
          positions,
          linear: <bool>[for (final Barcode b in raw) b.format.isLinear],
        ),
        positions: positions,
        mirrored: camera.mirrored,
      ),
    );
  }

  Future<void> _fail(ScannerException error, int session) async {
    if (session != _session) {
      return;
    }
    _session++;
    _clearResults();
    _lastFrame = null;
    final CameraSource? source = _source;
    source?.previewTransform.removeListener(_onPreviewChanged);
    _set(_closed.copyWith(status: ScannerStatus.error, error: error));
    await source?.close();
  }

  void _wakeUp() {
    final Completer<void>? resumed = _resumed;
    _resumed = null;
    resumed?.complete();
  }

  void _clearResults() {
    _seen.clear();
    _tracks.clear();
    if (!_disposed) {
      _visible.value = null;
    }
  }

  void _onPreviewChanged() {
    final Size? size = _source?.previewTransform.value?.displaySize;
    if (size != null && value.status.hasCamera && !_disposed) {
      final ScannerState before = value;
      _set(value.copyWith(previewSize: size));
      if (value == before) {
        // The preview is back at the same size (another lens opened, its
        // first frame arrived): a scanner built while it was missing shows
        // its placeholder until told.
        notifyListeners();
      }
    }
  }

  // --- background ----------------------------------------------------------

  void _onHide() {
    final ScannerStatus status = value.status;
    if (stopInBackground &&
        (status.hasCamera || status == ScannerStatus.starting)) {
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
      _pauseWhenStarted = before == ScannerStatus.paused;
      unawaited(start());
    } else if (_widgets > 0 &&
        value.status == ScannerStatus.error &&
        value.error is CameraPermissionException) {
      // Back from the settings, where camera access may have been turned
      // on.
      unawaited(start());
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

extension on CameraFacing {
  /// The camera on the other side.
  CameraFacing get other =>
      this == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
}

extension on ScannerStatus {
  /// Whether the camera is open.
  bool get hasCamera =>
      this == ScannerStatus.running || this == ScannerStatus.paused;
}

/// The barcodes in view of a controller, for the overlay.
@immutable
final class _Visible {
  const _Visible(this.barcodes, this.frameSize);

  /// In the order they came into view; positions in the display frame of
  /// [frameSize].
  final List<_Seen> barcodes;
  final Size frameSize;
}

/// A barcode in view as the overlay shows it.
@immutable
final class _Seen {
  const _Seen(this.id, this.barcode, this.corners);

  /// See [VisibleBarcode.id].
  final int id;
  final Barcode barcode;

  /// Smoothed corners in the display frame.
  final List<Offset> corners;
}

/// A barcode followed from frame to frame: the engine does not find every
/// code in every frame, and finds it a pixel or two off each time.
final class _Track {
  _Track(this.id, this.barcode, this.corners, this.seen);

  final int id;
  Barcode barcode;
  List<Offset> corners;
  DateTime seen;

  /// Takes [found], the same code in a newer frame: a small move is
  /// smoothed away, a large one followed at once. [still] is how far
  /// counts as small, in display frame pixels.
  void update(Barcode found, DateTime now, double still) {
    final List<Offset> next = found.position.corners;
    double moved = 0;
    for (int i = 0; i < 4; i++) {
      moved = math.max(moved, (next[i] - corners[i]).distance);
    }
    corners = moved > still
        ? next
        : <Offset>[
            for (int i = 0; i < 4; i++) Offset.lerp(corners[i], next[i], 0.5)!,
          ];
    barcode = found;
    seen = now;
  }

  _Seen get seenAs => _Seen(id, barcode, corners);
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
    this.latencyMicros = 0,
    this.dropped = 0,
    this.crop,
    this.failed = 0,
    this.details = const <EngineBarcodeDetails>[],
    this.reads = const <Barcode>[],
  });

  /// Whether the frame had a barcode.
  final bool found;

  /// Time inside the engine.
  final int engineMicros;

  /// From handing the frame to the engine to its result on this isolate.
  final int roundTripMicros;

  /// From the frame reaching Dart to its result on this isolate (the scan
  /// latency of the prototype's benchmark).
  final int latencyMicros;

  /// Frames the camera delivered before this one that were not decoded.
  final int dropped;

  /// Size of the frame as delivered.
  final Size frameSize;

  /// The decoded part of the frame, `null` for all of it.
  final Rect? crop;

  /// Barcodes found but not decoded ([ReaderOptions.returnErrors]).
  final int failed;

  /// The engine's details of the barcodes of this frame.
  final List<EngineBarcodeDetails> details;

  /// The barcodes decoded from this frame, in frame pixels.
  final List<Barcode> reads;
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

  /// Engine flags added to every read, see [fzxDownscaleFlags].
  set engineFlags(int flags) {
    _debugEngineFlags = flags;
    _onConfigChanged();
  }

  /// The shortest time from the start of one read to the next; `null` reads
  /// every frame the camera delivers.
  set readInterval(Duration? interval) => _debugReadInterval = interval;

  /// Whether the last decoded frame was read mirrored (a front camera).
  bool get lastFrameMirrored => _lastFrame?.$1.mirrored ?? false;

  /// The pixels of the last decoded frame and the part of them that was
  /// decoded (`null` for all), to save a frame while debugging. `null` before
  /// the first frame and on the web.
  (PixelBuffer, Rect?)? get lastFrame {
    final (CameraFrame, Rect?)? last = _lastFrame;
    final PixelBuffer? pixels = last?.$1.pixels;
    return pixels == null ? null : (pixels, last!.$2);
  }

  /// The physical camera that is open, where its lens is focused (`null`
  /// where the camera does not say) and the zoom automatic zoom is heading
  /// for (`null`: staying).
  ({CameraLens lens, LensFocus? focus, double? autoTarget}) get lensSample => (
    lens: _lens,
    focus: value.status.hasCamera ? _source?.lensFocus() : null,
    autoTarget: _autoTarget,
  );

  /// How often the camera stalled and was opened again.
  int get cameraRestarts => _cameraRestarts;

  /// How often the engine got stuck and was replaced.
  int get engineRestarts => _engineRestarts;
}

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
    this.source = CaptureSource.camera,
  }) : _cut = null,
       _positions = null,
       _encoded = null,
       _mirrored = false,
       assert(barcodes.length > 0, 'A capture has at least one barcode');

  const BarcodeCapture._({
    required this.barcodes,
    required this.imageSize,
    required this.time,
    required this.source,
    required List<BarcodePosition> positions,
    FrameCut? cut,
    Uint8List? encoded,
    bool mirrored = false,
  }) : _cut = cut,
       _positions = positions,
       _encoded = encoded,
       _mirrored = mirrored;

  /// The frame around the barcodes, kept for [snapshot].
  final FrameCut? _cut;

  /// The barcodes' positions in [_cut]'s frame (or in [_encoded]).
  final List<BarcodePosition>? _positions;

  /// The image file given to [ScannerController.readImage].
  final Uint8List? _encoded;

  /// Whether [_cut] is a mirror image of the scene.
  final bool _mirrored;

  /// The barcodes in the frame, at least one.
  final List<Barcode> barcodes;

  /// The first barcode: the one to use when you expect a single code.
  Barcode get barcode => barcodes.first;

  /// Size of the camera frame, in its display orientation. Barcode positions
  /// are in this coordinate space.
  final Size imageSize;

  /// When the frame was decoded.
  final DateTime time;

  /// Where the barcodes came from: a camera frame, or an image given to
  /// [ScannerController.readImage]. Positions of an image's barcodes are
  /// not on screen.
  final CaptureSource source;

  /// [barcode] (default [this.barcode]) cut out of the camera frame or the
  /// photo it was found in and straightened: a flat grayscale image with a
  /// little margin, its contrast stretched. Each call makes a new image,
  /// which the caller disposes.
  ///
  /// ```dart
  /// onDetect: (capture) async {
  ///   final ui.Image? image = await capture.snapshot();
  ///   history.add(capture.barcode, image);
  /// }
  /// ```
  ///
  /// `null` for captures not made by a [ScannerController], and for a
  /// barcode not in [barcodes].
  Future<ui.Image?> snapshot([Barcode? barcode]) async {
    final int index = barcode == null ? 0 : barcodes.indexOf(barcode);
    final List<BarcodePosition>? positions = _positions;
    if (index < 0 || positions == null) {
      return null;
    }
    FrameCut? cut = _cut;
    BarcodePosition position = positions[index];
    final Uint8List? encoded = _encoded;
    if (cut == null && encoded != null) {
      // The reader sees the file's pixels, the decoder here turns them.
      final int orientation = exifOrientation(encoded);
      final List<BarcodePosition> shown = <BarcodePosition>[
        for (final BarcodePosition p in positions)
          orientedPosition(p, imageSize, orientation),
      ];
      final (FrameCut, double)? decoded = await cutEncoded(
        encoded,
        orientedSize(imageSize, orientation),
        shown,
        linear: <bool>[for (final Barcode b in barcodes) b.format.isLinear],
      );
      if (decoded == null) {
        return null;
      }
      cut = decoded.$1;
      position = scalePosition(shown[index], decoded.$2);
    }
    if (cut == null) {
      return null;
    }
    final bool linear = barcodes[index].format.isLinear;
    List<Offset> corners = snapshotCorners(
      position,
      linear: linear,
      mirrored: _mirrored,
    );
    if (linear) {
      corners = fitBarHeight(
        cut,
        alignToBars(cut, corners, mirrored: _mirrored),
      );
    }
    final GrayImage? image = straighten(cut, corners);
    return image?.toImage();
  }
}

/// The longest side of a photo decoded to show on screen.
const int _photoSide = 2048;

/// For the scanner's templates. Not exported.
extension BarcodeCapturePhoto on BarcodeCapture {
  /// The photo given to [ScannerController.readImage], turned the way it
  /// shows, and the corners of each of [BarcodeCapture.barcodes] in its
  /// pixels. The caller disposes the image. `null` for a capture of the
  /// camera, or when the photo cannot be shown the way the reader saw it.
  Future<(ui.Image, List<List<Offset>>)?> decodePhoto() async {
    final Uint8List? encoded = _encoded;
    final List<BarcodePosition>? positions = _positions;
    if (encoded == null || positions == null) {
      return null;
    }
    final ui.Image image;
    try {
      final ui.Codec codec = await ui.instantiateImageCodecWithSize(
        await ui.ImmutableBuffer.fromUint8List(encoded),
        getTargetSize: (int width, int height) {
          final double scale = math.min(
            1,
            _photoSide / math.max(width, height),
          );
          return ui.TargetImageSize(
            width: (width * scale).round(),
            height: (height * scale).round(),
          );
        },
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      image = frame.image;
    } on Object {
      return null;
    }
    final int orientation = exifOrientation(encoded);
    final Size shown = orientedSize(imageSize, orientation);
    if ((image.width / image.height - shown.width / shown.height).abs() >
        0.02) {
      image.dispose();
      return null;
    }
    final double scale = image.width / shown.width;
    return (
      image,
      <List<Offset>>[
        for (final BarcodePosition p in positions)
          <Offset>[
            for (final Offset c in p.corners)
              orientedPoint(c, imageSize, orientation) * scale,
          ],
      ],
    );
  }
}

/// Where the barcodes of a [BarcodeCapture] came from.
enum CaptureSource {
  /// A camera frame.
  camera,

  /// An image given to [ScannerController.readImage].
  image,
}
