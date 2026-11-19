// The camera on the web: getUserMedia into a <video> element shown through a
// platform view. Each frame is grabbed with createImageBitmap, cropped to the
// scan window by the browser (off the Dart heap), and transferred to the
// engine's worker. A second bitmap of the same frame stays here while it
// has codes, to cut them out.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math' as math;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../../barcode/barcode.dart';
import '../../engine/engine.dart';
import '../../engine/engine_protocol.dart';
import '../../engine/engine_web.dart';
import '../../errors.dart';
import '../../reading/pixel_buffer.dart';
import '../frame_geometry.dart';
import '../scanner_controller.dart';
import '../snapshot.dart';
import 'camera_source.dart';

/// The camera of this platform.
CameraSource createCameraSource() => WebCameraSource();

/// A camera through getUserMedia.
final class WebCameraSource implements CameraSource {
  /// Creates the source and its `<video>` element.
  WebCameraSource() {
    _video = web.document.createElement('video') as web.HTMLVideoElement
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    _video.style
      ..width = '100%'
      ..height = '100%'
      // The widget lays the element out at the video's own aspect ratio.
      ..objectFit = 'fill'
      ..pointerEvents = 'none';
    _viewType = 'flutter-zxing-camera-${_nextView++}';
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _video,
    );
    _video.addEventListener('resize', ((web.Event _) => _updatePreview()).toJS);
  }

  static int _nextView = 0;

  late final web.HTMLVideoElement _video;
  late final String _viewType;
  web.MediaStream? _stream;
  bool _front = false;
  Orientation _uiShape = Orientation.portrait;
  final ValueNotifier<FrameTransform?> _preview =
      ValueNotifier<FrameTransform?>(null);

  web.MediaStreamTrack? get _track =>
      _stream?.getVideoTracks().toDart.firstOrNull;

  @override
  ValueListenable<FrameTransform?> get previewTransform => _preview;

  @override
  Orientation get uiShape => _uiShape;

  // The browser turns the video with the device itself.
  @override
  set uiShape(Orientation value) => _uiShape = value;

  @override
  Future<CameraCapabilities> open(
    CameraFacing facing,
    CameraResolution resolution, {
    CameraLens lens = CameraLens.main,
  }) async {
    final (int width, int height) = switch (resolution) {
      CameraResolution.sd => (640, 480),
      CameraResolution.hd => (1280, 720),
      CameraResolution.fullHd => (1920, 1080),
    };
    if (!web.window.isSecureContext) {
      // Plain http (not localhost) has no camera access at all.
      throw const CameraUnsupportedException(
        'Cameras need a secure page: serve it over https or from localhost',
      );
    }
    final web.MediaDevices? devices = web.window.navigator.has('mediaDevices')
        ? web.window.navigator.mediaDevices
        : null;
    if (devices == null || !devices.has('getUserMedia')) {
      throw const CameraUnsupportedException(
        'This browser offers no camera access',
      );
    }
    final web.MediaStream stream;
    try {
      stream = await devices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: false.toJS,
              video: <String, Object>{
                'facingMode': facing == CameraFacing.back
                    ? 'environment'
                    : 'user',
                'width': <String, int>{'ideal': width},
                'height': <String, int>{'ideal': height},
              }.jsify()!,
            ),
          )
          .toDart;
    } on Object catch (e) {
      throw cameraError(_errorName(e), '$e');
    }
    _stream = stream;
    _front = facing == CameraFacing.front;
    _video.style.transform = _front ? 'scaleX(-1)' : '';
    _video.srcObject = stream;
    try {
      await _video.play().toDart;
    } on Object catch (e) {
      await close();
      throw cameraError(_errorName(e), '$e');
    }
    while (_video.videoWidth == 0 && _stream != null) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    _updatePreview();
    return _capabilities(hasOtherFacing: await _severalCameras(devices));
  }

  /// Whether the browser lists more than one camera. Browsers do not say
  /// which side a camera is on before it is opened; once access is granted
  /// they list every camera.
  static Future<bool> _severalCameras(web.MediaDevices devices) async {
    try {
      final List<web.MediaDeviceInfo> all =
          (await devices.enumerateDevices().toDart).toDart;
      return all
              .where((web.MediaDeviceInfo d) => d.kind == 'videoinput')
              .length >
          1;
    } on Object {
      return false;
    }
  }

  /// The DOMException name of a camera failure (NotAllowedError,
  /// NotFoundError, NotReadableError...): what a DOMException prints,
  /// "name: message", in both dart2js and dart2wasm.
  static String _errorName(Object error) {
    final String text = '$error';
    return RegExp(r'([A-Za-z]+Error)').firstMatch(text)?.group(1) ?? text;
  }

  CameraCapabilities _capabilities({required bool hasOtherFacing}) {
    final web.MediaStreamTrack? track = _track;
    if (track == null || !track.has('getCapabilities')) {
      return CameraCapabilities(hasOtherFacing: hasOtherFacing);
    }
    final JSObject caps = track.getCapabilities();
    double minZoom = 1;
    double maxZoom = 1;
    final JSAny? zoom = caps.getProperty('zoom'.toJS);
    if (zoom != null && zoom.isA<JSObject>()) {
      final JSAny? min = (zoom as JSObject).getProperty('min'.toJS);
      final JSAny? max = zoom.getProperty('max'.toJS);
      if (min != null && min.isA<JSNumber>()) {
        minZoom = (min as JSNumber).toDartDouble;
      }
      if (max != null && max.isA<JSNumber>()) {
        maxZoom = (max as JSNumber).toDartDouble;
      }
    }
    return CameraCapabilities(
      hasTorch: caps.has('torch'),
      minZoom: minZoom,
      maxZoom: maxZoom < minZoom ? minZoom : maxZoom,
      hasOtherFacing: hasOtherFacing,
    );
  }

  void _updatePreview() {
    _preview.value = _stream == null || _video.videoWidth == 0
        ? null
        : FrameTransform(
            Size(_video.videoWidth.toDouble(), _video.videoHeight.toDouble()),
            mirrored: _front,
          );
  }

  @override
  Future<void> close() async {
    _held?._release();
    _held = null;
    for (final web.MediaStreamTrack track
        in _stream?.getTracks().toDart ?? const <web.MediaStreamTrack>[]) {
      track.stop();
    }
    _stream = null;
    _video.srcObject = null;
    _preview.value = null;
  }

  /// Resolves on the next frame the video presents:
  /// requestVideoFrameCallback where the browser has it (never the same
  /// frame twice), animation frames otherwise.
  Future<void> _nextVideoFrame() {
    final Completer<void> presented = Completer<void>();
    if (_video.has('requestVideoFrameCallback')) {
      _video.callMethod(
        'requestVideoFrameCallback'.toJS,
        ((JSAny? _, JSAny? _) => presented.complete()).toJS,
      );
    } else {
      web.window.requestAnimationFrame(
        ((JSNumber _) => presented.complete()).toJS,
      );
    }
    return presented.future;
  }

  @override
  Future<CameraFrame?> nextFrame() async {
    if (_stream == null) {
      return null;
    }
    await _nextVideoFrame();
    final int arrivalMicros = cameraClock.elapsedMicroseconds;
    final FrameTransform? transform = _preview.value;
    if (_stream == null || transform == null) {
      return null;
    }
    // The previous frame's codes were cut out, if they were reported.
    _held?._release();
    _held = null;
    return _WebFrame(this, transform, arrivalMicros);
  }

  /// The last frame that kept a bitmap for cut-outs.
  _WebFrame? _held;

  /// Where frames are drawn to read their pixels, made on the first cut.
  web.CanvasRenderingContext2D? _canvas;

  web.CanvasRenderingContext2D get _cutCanvas => _canvas ??=
      (web.document.createElement('canvas') as web.HTMLCanvasElement)
              .getContext(
                '2d',
                <String, Object>{'willReadFrequently': true}.jsify(),
              )!
          as web.CanvasRenderingContext2D;

  @override
  Widget buildPreview() => HtmlElementView(viewType: _viewType);

  Future<void> _constrain(String name, JSAny value) async {
    final web.MediaStreamTrack? track = _track;
    if (track == null) {
      return;
    }
    final JSObject constraint = JSObject()..setProperty(name.toJS, value);
    await track
        .applyConstraints(
          web.MediaTrackConstraints()
            ..setProperty('advanced'.toJS, <JSObject>[constraint].toJS),
        )
        .toDart;
  }

  @override
  Future<void> setTorch(bool on) async {
    try {
      await _constrain('torch', on.toJS);
    } on Object catch (e) {
      throw cameraError(_errorName(e), '$e');
    }
  }

  @override
  Future<void> setZoom(double zoom) async {
    try {
      await _constrain('zoom', zoom.toJS);
    } on Object {
      // The camera rejected the value: keep the current zoom.
    }
  }

  // Browsers barely support points of interest; the camera keeps focusing
  // continuously on its own.
  @override
  Future<void> setFocusPoint(Offset point) async {}

  // Browsers do not report the focus.
  @override
  LensFocus? lensFocus() => null;
}

final class _WebFrame extends CameraFrame {
  _WebFrame(this._source, this.transform, this.arrivalMicros);

  final WebCameraSource _source;

  /// The decoded part of the frame, kept while it has codes.
  web.ImageBitmap? _kept;

  /// Where [_kept] is in the frame.
  Rect _keptArea = Rect.zero;

  @override
  final int arrivalMicros;

  // The video element shows the newest frame; skipped ones are not counted.
  @override
  int get dropped => 0;

  @override
  final FrameTransform transform;

  @override
  PixelBuffer? get pixels => null;

  @override
  bool get mirrored => false;

  @override
  FrameCut? cut(List<BarcodePosition> positions, {List<bool>? linear}) {
    final web.ImageBitmap? kept = _kept;
    if (kept == null) {
      return null;
    }
    final Rect? area = cutArea(positions, _keptArea, linear: linear);
    if (area == null) {
      return null;
    }
    final int width = area.width.toInt();
    final int height = area.height.toInt();
    final web.CanvasRenderingContext2D canvas = _source._cutCanvas;
    final web.HTMLCanvasElement element = canvas.canvas;
    if (element.width < width || element.height < height) {
      element
        ..width = math.max(element.width, width)
        ..height = math.max(element.height, height);
    }
    canvas.drawImage(
      kept,
      _keptArea.left - area.left,
      _keptArea.top - area.top,
    );
    final Uint8List rgba = Uint8List.view(
      canvas.getImageData(0, 0, width, height).data.toDart.buffer,
    );
    return grayCut(rgba, width * 4, 4, area, shift: area.topLeft);
  }

  void _release() {
    _kept?.close();
    _kept = null;
  }

  @override
  Future<EngineReadResult> read(
    BarcodeEngine engine,
    Rect? crop,
    EngineReadOptions options,
  ) async {
    final Size size = transform.frameSize;
    final Rect area = crop ?? Offset.zero & size;
    // Both bitmaps are taken now, of the frame the video shows: the
    // engine's goes to the worker, the other stays for cut-outs.
    JSPromise<web.ImageBitmap> grab() => web.window.createImageBitmap(
      _source._video,
      area.left.toInt().toJS,
      area.top.toInt(),
      area.width.toInt(),
      area.height.toInt(),
    );
    final Future<web.ImageBitmap> forEngine = grab().toDart;
    final Future<web.ImageBitmap?> forCut = grab().toDart.then(
      (web.ImageBitmap b) => b,
      onError: (Object _) => null,
    );
    final web.ImageBitmap bitmap;
    try {
      bitmap = await forEngine;
    } on Object {
      unawaited(forCut.then((web.ImageBitmap? b) => b?.close()));
      rethrow;
    }
    final EngineBackend backend = await engine.backend;
    final EngineReadResult result;
    try {
      result = (await (backend as WebBackend).readBitmap(
        bitmap,
        options,
      )).asPrinted(options);
    } on Object {
      unawaited(forCut.then((web.ImageBitmap? b) => b?.close()));
      rethrow;
    }
    final web.ImageBitmap? kept = await forCut;
    if (result.barcodes.isEmpty || kept == null) {
      kept?.close();
    } else {
      _source._held?._release();
      _source._held = this;
      _kept = kept;
      _keptArea = Rect.fromLTWH(
        area.left.truncateToDouble(),
        area.top.truncateToDouble(),
        kept.width.toDouble(),
        kept.height.toDouble(),
      );
    }
    return EngineReadResult(
      barcodes: <Barcode>[
        for (final Barcode b in result.barcodes)
          mapBarcodePosition(b, (Offset p) => p + area.topLeft),
      ],
      imageWidth: size.width.round(),
      imageHeight: size.height.round(),
      engineMicros: result.engineMicros,
    );
  }
}
