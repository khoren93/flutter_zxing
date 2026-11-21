part of 'scanner_controller.dart';

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

  /// Frames the camera delivered while the frame before this one was
  /// decoded, replaced by newer ones before they could be: the frames the
  /// decoder could not keep up with. Frames sent while the scanner was
  /// paused, or by the camera before it opened again, are not counted.
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
