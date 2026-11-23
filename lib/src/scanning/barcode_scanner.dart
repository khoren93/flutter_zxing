part of 'scanner_controller.dart';

/// Builds what is drawn over the camera preview.
typedef ScannerOverlayBuilder =
    Widget Function(BuildContext context, ScannerLayout layout);

/// A camera preview that scans barcodes.
///
/// ```dart
/// BarcodeScanner(onDetect: (capture) => print(capture.barcode.text))
/// ```
///
/// Without a [controller] it creates one and disposes it with the widget;
/// pass your own to configure formats, the scan window or detection, and
/// to control the camera.
///
/// By default it dims the camera around the scan window, whose brackets
/// lock onto the code found, and outlines the codes. A [template] adds a
/// whole screen around it: buttons, hints and a result sheet:
///
/// ```dart
/// BarcodeScanner(
///   template: ScannerTemplate.minimal(),
///   theme: ScannerTheme(accent: Color(0xFFFF6A1A)),
/// )
/// ```
///
/// Replace the overlay with [overlayBuilder], or add your own buttons over
/// it with [foregroundBuilder]. Tap to focus and pinch to zoom are on.
///
/// While the scanner is not shown, such as under another page or in a tab
/// that is not selected ([TickerMode] off), it stops decoding, and after a
/// few seconds releases the camera; see [pauseWhenHidden].
class BarcodeScanner extends StatefulWidget {
  /// Creates a scanner.
  const BarcodeScanner({
    super.key,
    this.controller,
    this.onDetect,
    this.template,
    this.theme,
    this.strings,
    this.overlayBuilder,
    this.foregroundBuilder,
    this.errorBuilder,
    this.placeholderBuilder,
    this.onOpenSettings,
    this.fit = BoxFit.cover,
    this.tapToFocus = true,
    this.pinchToZoom = true,
    this.pauseWhenHidden = true,
  });

  /// The controller. `null` creates one with the [template]'s scan window,
  /// formats and detection, or with default settings.
  final ScannerController? controller;

  /// Called for every capture the controller reports.
  final ValueChanged<BarcodeCapture>? onDetect;

  /// A ready-made screen around the camera; see [ScannerTemplate].
  final ScannerTemplate? template;

  /// Colors and shapes, merged onto the [template]'s theme, which is
  /// merged onto the theme of a [ScannerScope] around the scanner.
  final ScannerTheme? theme;

  /// The texts; default those of a [ScannerScope] around the scanner, or
  /// English.
  final ScannerStrings? strings;

  /// Builds the overlay while the camera runs, instead of the [template]'s
  /// or the default [ScannerOverlay]. Return `const SizedBox.shrink()` for
  /// none.
  final ScannerOverlayBuilder? overlayBuilder;

  /// Builds a layer of your own over the overlay (the [template]'s too),
  /// in every state of the camera ([ScannerLayout.state]), with the
  /// scanner's theme: buttons of your own beside the template's.
  ///
  /// ```dart
  /// BarcodeScanner(
  ///   template: ScannerTemplate.minimal(),
  ///   foregroundBuilder: (context, layout) => Positioned(
  ///     left: 16,
  ///     top: layout.scanWindow.bottom + 72,
  ///     child: ScannerButton(icon: ScannerIcons.binary, label: 'Help', onPressed: help),
  ///   ),
  /// )
  /// ```
  ///
  /// It is laid out in a [Stack] that fills the scanner; leave the rest of
  /// it free of taps, so they reach the overlay and the camera.
  final ScannerOverlayBuilder? foregroundBuilder;

  /// Opens the app's settings, where the user allows the camera: the
  /// default error view (and the [template]'s) then offers "Open Settings"
  /// when camera access is off, instead of "Try again". Opening the
  /// settings needs a plugin such as `app_settings`; default
  /// [ScannerTemplate.onOpenSettings].
  final VoidCallback? onOpenSettings;

  /// Shown instead of the preview when the camera cannot be used. Default
  /// [ScannerErrorView].
  final Widget Function(BuildContext context, ScannerException error)?
  errorBuilder;

  /// Shown while the camera is starting or stopped. Default
  /// [ScannerPlaceholder].
  final WidgetBuilder? placeholderBuilder;

  /// How the preview fills the widget. With [BoxFit.cover] (the default)
  /// the edges of the camera image may be cut off; the scan window and
  /// barcode outlines always match what is visible.
  final BoxFit fit;

  /// Focus where the user taps.
  final bool tapToFocus;

  /// Zoom with a pinch gesture.
  final bool pinchToZoom;

  /// While the scanner is not shown ([TickerMode] off: under another
  /// page, in a tab that is not selected), pause decoding, and release the
  /// camera after a few seconds; when it shows again, go on as before.
  /// Nothing is reported to `onDetect` meanwhile. `false` keeps the camera
  /// as it is.
  final bool pauseWhenHidden;

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

/// How long a hidden scanner keeps the camera, so that a quick look at
/// another tab does not open it again.
const Duration _releaseHidden = Duration(seconds: 3);

class _BarcodeScannerState extends State<BarcodeScanner> {
  ScannerController? _own;
  StreamSubscription<BarcodeCapture>? _detections;
  double _zoomAtPinchStart = 1;
  final BackdropKey _backdrop = BackdropKey();

  /// [BarcodeScanner.pauseWhenHidden]: whether tickers are on here, and
  /// whether the scanner is treated as hidden.
  bool _shown = true;
  bool _hidden = false;
  bool _firstDependencies = true;

  /// What hiding did, to undo when the scanner shows again: paused the
  /// camera, stopped it (and whether it was paused before).
  bool _pausedByHiding = false;
  bool _stoppedByHiding = false;
  bool _pausedBeforeStop = false;
  Timer? _release;

  /// Whether the blur the theme leaves to the scanner (a `null`
  /// [ScannerTheme.blur] or [ScannerTheme.scrimBlur]) is off for good: the
  /// device did not draw the frames in time with it.
  bool _blurTooSlow = false;
  bool _watchingFrames = false;
  int _framesSeen = 0;

  /// How long each judged frame took to build or to draw, whichever is
  /// longer.
  final List<Duration> _frameTimes = <Duration>[];

  /// Frames not judged after the watch starts: shaders compile, the camera
  /// opens.
  static const int _warmupFrames = 15;

  /// Frames judged, about three seconds. The blur goes at once when
  /// [_lateFrames] of them take longer than [_frameBudget], and after them
  /// when one in ten takes longer than [_frameRoom]: a device without that
  /// room misses frames now and then, which a device that keeps up never
  /// does.
  static const int _judgedFrames = 90;
  static const int _lateFrames = 5;
  static const Duration _frameBudget = Duration(microseconds: 16667);
  static const Duration _frameRoom = Duration(milliseconds: 8);

  void _watchFrames(bool watch) {
    if (watch == _watchingFrames) {
      return;
    }
    _watchingFrames = watch;
    if (watch) {
      _framesSeen = 0;
      _frameTimes.clear();
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    } else {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
  }

  void _onTimings(List<ui.FrameTiming> timings) {
    for (final ui.FrameTiming t in timings) {
      if (++_framesSeen <= _warmupFrames) {
        continue;
      }
      _frameTimes.add(
        t.rasterDuration > t.buildDuration ? t.rasterDuration : t.buildDuration,
      );
      final int late = _frameTimes
          .where((Duration d) => d > _frameBudget)
          .length;
      if (late >= _lateFrames) {
        _blurDecided(drop: true, why: '$late of ${_frameTimes.length} late');
        return;
      }
      if (_frameTimes.length >= _judgedFrames) {
        final List<Duration> sorted = List<Duration>.of(_frameTimes)..sort();
        final Duration p90 = sorted[(sorted.length * 0.9).floor()];
        _blurDecided(
          drop: p90 > _frameRoom,
          why: 'one in ten took ${p90.inMicroseconds / 1000} ms or more',
        );
        return;
      }
    }
  }

  /// Stops watching the frames; [drop]: the blur goes for good.
  void _blurDecided({required bool drop, required String why}) {
    _watchFrames(false);
    _decided = true;
    if (!drop) {
      return;
    }
    debugPrint(
      'flutter_zxing: the frames have no room for blur ($why); the '
      'scanner stops blurring (set ScannerTheme.blur and scrimBlur to '
      'choose)',
    );
    if (mounted) {
      setState(() => _blurTooSlow = true);
    }
  }

  /// Whether the blur was judged: it is not watched again.
  bool _decided = false;

  ScannerController get _controller =>
      widget.controller ?? (_own ??= _create(widget.template));

  static ScannerController _create(ScannerTemplate? template) =>
      template == null
      ? ScannerController()
      : ScannerController.fromTemplate(template);

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(BarcodeScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ScannerController? old = oldWidget.controller ?? _own;
    if (widget.controller != oldWidget.controller) {
      if (_pausedByHiding) {
        unawaited(old!.resume());
      }
      _disconnect(old!);
      if (oldWidget.controller == null) {
        _own?.dispose();
        _own = null;
      }
      _pausedByHiding = false;
      _stoppedByHiding = false;
      _connect();
      if (_hidden) {
        // The new controller hides as well.
        _hidden = false;
        _setHidden(true, now: true);
      }
    } else if (_own case final ScannerController own
        when widget.template != oldWidget.template) {
      final ScannerTemplate? template = widget.template;
      own
        ..formats = template?.formats
        ..scanWindow = template?.scanWindow ?? const ScanWindow.centered()
        ..detection = template?.detection ?? DetectionMode.distinct
        ..maxBarcodes = template == null ? 1 : template.maxBarcodes
        ..initialZoom = template?.initialZoom;
      // Only when the template's side changes: the user's choice of camera
      // stays through rebuilds that make the template anew.
      final CameraFacing? facing = template?.facing;
      if (facing != oldWidget.template?.facing) {
        unawaited(own.switchCamera(facing ?? CameraFacing.back));
      }
    }
    if (widget.pauseWhenHidden != oldWidget.pauseWhenHidden) {
      _setHidden(widget.pauseWhenHidden && !_shown);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shown = TickerMode.valuesOf(context).enabled;
    final bool first = _firstDependencies;
    _firstDependencies = false;
    _setHidden(widget.pauseWhenHidden && !_shown, now: first);
  }

  @override
  void dispose() {
    _watchFrames(false);
    _release?.cancel();
    if (_pausedByHiding) {
      unawaited(_controller.resume());
    }
    _disconnect(_controller);
    _own?.dispose();
    super.dispose();
  }

  /// Pauses the camera when the scanner hides and releases it a little
  /// later ([now]: at once, for a scanner hidden from the start); undoes
  /// that when it shows again.
  void _setHidden(bool hidden, {bool now = false}) {
    if (hidden == _hidden) {
      return;
    }
    _hidden = hidden;
    final ScannerController controller = _controller;
    if (hidden) {
      final ScannerStatus status = controller.value.status;
      if (status == ScannerStatus.running ||
          (status == ScannerStatus.starting && !controller._pauseWhenStarted)) {
        _pausedByHiding = true;
        unawaited(controller.pause());
      }
      _release?.cancel();
      _release = now ? null : Timer(_releaseHidden, _releaseCamera);
      if (now) {
        _releaseCamera();
      }
      return;
    }
    _release?.cancel();
    _release = null;
    final ScannerStatus status = controller.value.status;
    if (_stoppedByHiding) {
      final bool paused = _pausedBeforeStop && !_pausedByHiding;
      _stoppedByHiding = false;
      _pausedByHiding = false;
      if (status == ScannerStatus.idle || status == ScannerStatus.error) {
        unawaited(controller.start());
        if (paused) {
          unawaited(controller.pause());
        }
      }
    } else if (_pausedByHiding) {
      _pausedByHiding = false;
      if (status == ScannerStatus.error) {
        // The camera failed meanwhile, such as taken by another page.
        unawaited(controller.start());
      } else {
        unawaited(controller.resume());
      }
    }
  }

  void _releaseCamera() {
    _release = null;
    if (!mounted || !_hidden) {
      return;
    }
    final ScannerController controller = _controller;
    final ScannerStatus status = controller.value.status;
    if (status.hasCamera || status == ScannerStatus.starting) {
      _stoppedByHiding = true;
      _pausedBeforeStop =
          status == ScannerStatus.paused || controller._pauseWhenStarted;
      unawaited(controller.stop());
    } else if (controller._statusBeforeHide case final ScannerStatus before) {
      // The app went to the background first, and the controller stopped
      // the camera itself: it opens again when this scanner shows, not when
      // the app returns.
      controller._statusBeforeHide = null;
      _stoppedByHiding = true;
      _pausedBeforeStop = before == ScannerStatus.paused;
    }
  }

  void _connect() {
    final ScannerController controller = _controller;
    _detections = controller.barcodes.listen(
      (BarcodeCapture capture) => widget.onDetect?.call(capture),
    );
    controller._attach();
  }

  void _disconnect(ScannerController controller) {
    unawaited(_detections?.cancel());
    _detections = null;
    controller._detach();
  }

  @override
  Widget build(BuildContext context) {
    final ScannerController controller = _controller;
    final Orientation shape = MediaQuery.orientationOf(context);
    final ScannerTemplate? template = widget.template;
    // A scope around the scanner gives the app's theme and texts; the
    // template's theme and the scanner's own go on top.
    final ScannerScope? around = context
        .dependOnInheritedWidgetOfExactType<ScannerScope>();
    ScannerTheme theme = (around?.theme ?? const ScannerTheme())
        .merge(template?.theme)
        .merge(widget.theme);
    // Blur left to the scanner goes when the device cannot draw it in time.
    final bool autoBlur = theme.blur == null || theme.scrimBlur == null;
    if (_blurTooSlow) {
      theme = theme.copyWith(
        blur: theme.blur ?? false,
        scrimBlur: theme.scrimBlur ?? false,
      );
    }
    _watchFrames(autoBlur && !_decided && _shown);
    return resolvedScannerScope(
      context,
      theme: theme,
      strings: widget.strings ?? around?.strings ?? const ScannerStrings(),
      child: BackdropGroup(
        backdropKey: _backdrop,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = constraints.biggest;
            controller._layout(size, widget.fit);
            // Telling the camera about the UI's shape can turn the preview,
            // which rebuilds this widget: not while it is being built.
            if (controller._source?.uiShape != shape) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => controller._source?.uiShape = shape,
              );
            }
            return ValueListenableBuilder<ScannerState>(
              valueListenable: controller,
              builder: (BuildContext context, ScannerState state, Widget? _) =>
                  _buildState(context, controller, state, size),
            );
          },
        ),
      ),
    );
  }

  Widget _buildState(
    BuildContext context,
    ScannerController controller,
    ScannerState state,
    Size size,
  ) {
    final ScannerTemplate? template = widget.template;
    final bool templateOverlay =
        template != null && widget.overlayBuilder == null;
    final ScannerException? error = state.error;
    final bool failed = state.status == ScannerStatus.error && error != null;
    final CameraSource? source = controller._source;
    final FrameTransform? preview = source?.previewTransform.value;
    final bool ready =
        !failed && source != null && preview != null && state.status.hasCamera;
    final PreviewFit? fit = ready
        ? PreviewFit(preview.displaySize, size, widget.fit)
        : null;

    final Widget base;
    if (ready) {
      // Rebuilt on every change of the transform, not only of its size: a
      // turn that keeps the shape (frames turned by the camera after the UI
      // turned) still changes how the preview is turned.
      base = ValueListenableBuilder<FrameTransform?>(
        valueListenable: source.previewTransform,
        builder: (BuildContext context, FrameTransform? transform, Widget? _) =>
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.fromSize(
                size: (transform ?? preview).displaySize,
                child: source.buildPreview(),
              ),
            ),
      );
    } else if (failed) {
      base =
          widget.errorBuilder?.call(context, error) ??
          (templateOverlay
              ? const SizedBox.expand()
              : ScannerErrorView(
                  error,
                  onRetry: () => unawaited(controller.start()),
                  onOpenSettings:
                      widget.onOpenSettings ?? template?.onOpenSettings,
                ));
    } else {
      base =
          widget.placeholderBuilder?.call(context) ??
          (templateOverlay
              ? const SizedBox.expand()
              : ScannerPlaceholder(
                  scanWindow: controller.scanWindow,
                  // Stopped, not starting: no "Starting the camera".
                  starting: state.status != ScannerStatus.idle,
                ));
    }

    ScannerLayout layoutOf(_Visible? visible) => ready
        ? _layoutOf(controller, state, size, fit!, preview, visible)
        : ScannerLayout(
            size: size,
            scanWindow: controller.scanWindow.resolve(size),
            barcodes: const <VisibleBarcode>[],
            state: state,
            controller: controller,
          );

    Widget? overlay;
    if (templateOverlay || ready) {
      overlay = ValueListenableBuilder<_Visible?>(
        valueListenable: controller._visible,
        builder: (BuildContext context, _Visible? visible, Widget? _) {
          final ScannerLayout layout = layoutOf(visible);
          if (templateOverlay) {
            return TemplateOverlay(
              template: template,
              layout: layout,
              drawPlaceholder: widget.placeholderBuilder == null,
              drawError: widget.errorBuilder == null,
              onOpenSettings: widget.onOpenSettings ?? template.onOpenSettings,
            );
          }
          return widget.overlayBuilder?.call(context, layout) ??
              ScannerOverlay(layout);
        },
      );
    }
    final ScannerOverlayBuilder? foreground = widget.foregroundBuilder;

    final bool focus = ready && widget.tapToFocus;
    final bool zoom = ready && widget.pinchToZoom;
    // Gestures go to the preview only: the overlay's buttons, pills and
    // sheets take their own taps, and the camera gets the rest.
    final Widget camera = !focus && !zoom
        ? base
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: focus
                ? (TapUpDetails details) {
                    final Offset p = fit!.toFrame(details.localPosition);
                    unawaited(
                      controller.setFocusPoint(
                        Offset(
                          p.dx / preview.displaySize.width,
                          p.dy / preview.displaySize.height,
                        ),
                      ),
                    );
                  }
                : null,
            onScaleStart: zoom
                ? (ScaleStartDetails _) => _zoomAtPinchStart = state.zoom
                : null,
            onScaleUpdate: zoom
                ? (ScaleUpdateDetails details) {
                    if (details.pointerCount > 1) {
                      unawaited(
                        controller.setZoom(_zoomAtPinchStart * details.scale),
                      );
                    }
                  }
                : null,
            child: base,
          );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<String>(
            ready
                ? 'preview'
                : failed
                ? 'error'
                : 'placeholder',
          ),
          child: camera,
        ),
        if (overlay != null)
          KeyedSubtree(key: const ValueKey<String>('overlay'), child: overlay),
        if (foreground != null)
          KeyedSubtree(
            key: const ValueKey<String>('foreground'),
            child: ValueListenableBuilder<_Visible?>(
              valueListenable: controller._visible,
              builder: (BuildContext context, _Visible? visible, Widget? _) =>
                  Stack(
                    fit: StackFit.expand,
                    children: <Widget>[foreground(context, layoutOf(visible))],
                  ),
            ),
          ),
      ],
    );
  }

  /// The overlay's view of the controller: everything in widget pixels.
  static ScannerLayout _layoutOf(
    ScannerController controller,
    ScannerState state,
    Size size,
    PreviewFit fit,
    FrameTransform preview,
    _Visible? visible,
  ) {
    final List<VisibleBarcode> barcodes = <VisibleBarcode>[];
    if (visible != null) {
      // Frames may come in another size than the preview: scale first.
      final double sx = preview.displaySize.width / visible.frameSize.width;
      final double sy = preview.displaySize.height / visible.frameSize.height;
      for (final _Seen seen in visible.barcodes) {
        barcodes.add(
          VisibleBarcode(seen.barcode, <Offset>[
            for (final Offset c in seen.corners)
              fit.toView(Offset(c.dx * sx, c.dy * sy)),
          ], id: seen.id),
        );
      }
    }
    return ScannerLayout(
      previewRect: Rect.fromPoints(
        fit.toView(Offset.zero),
        fit.toView(preview.displaySize.bottomRight(Offset.zero)),
      ),
      size: size,
      scanWindow: controller.scanWindow.resolve(size),
      barcodes: barcodes,
      state: state,
      controller: controller,
    );
  }
}

/// What an overlay needs to know, already in the coordinates of the
/// `BarcodeScanner` widget.
@immutable
final class ScannerLayout {
  /// Creates a layout.
  const ScannerLayout({
    required this.size,
    required this.scanWindow,
    required this.barcodes,
    required this.state,
    required this.controller,
    this.previewRect,
  });

  /// Size of the scanner widget.
  final Size size;

  /// Where the whole camera preview lies in the widget; it may reach past
  /// the widget's edges. `null` until the preview shows.
  final Rect? previewRect;

  /// The scan window.
  final Rect scanWindow;

  /// The barcodes in view, in the order they came into view. A barcode
  /// stays a moment after the camera last read it, so that frames that
  /// miss it do not make it flicker.
  final List<VisibleBarcode> barcodes;

  /// Camera state (torch, zoom, status).
  final ScannerState state;

  /// The controller, for buttons in the overlay.
  final ScannerController controller;
}

/// A barcode in view, positioned in the scanner widget.
@immutable
final class VisibleBarcode {
  /// Creates a visible barcode.
  const VisibleBarcode(this.barcode, this.corners, {this.id = 0});

  /// The barcode.
  final Barcode barcode;

  /// Stays the same while the barcode stays in view, and differs between
  /// barcodes in view, even two with the same content: a key for a widget
  /// that follows it.
  final int id;

  /// Its corners in widget coordinates (top-left, top-right, bottom-right,
  /// bottom-left of the symbol).
  final List<Offset> corners;

  /// The smallest rectangle containing [corners].
  Rect get bounds => BarcodePosition(
    topLeft: corners[0],
    topRight: corners[1],
    bottomRight: corners[2],
    bottomLeft: corners[3],
  ).bounds;
}

/// How [scanBarcode] shows its scanner.
enum ScannerPresentation {
  /// A full-screen page.
  page,

  /// A sheet over the lower part of the screen; the page under it, such as
  /// the form being filled in, stays in view. A tap above it closes it.
  sheet,
}

/// Opens a scanner and returns the first barcode found (and accepted by
/// [check]), or `null` if the user closes it.
///
/// ```dart
/// final Barcode? barcode = await scanBarcode(context, formats: {BarcodeFormat.qrCode});
/// ```
///
/// The screen is [template] (default [ScannerTemplate.minimal]) without
/// its result sheet: the brackets lock onto the code and the screen
/// closes. Everything else of the template stays; one that collects codes
/// or keeps scanning takes one code here. [formats], [scanWindow],
/// [facing], [hint] and [check] replace the template's; [hint] is shown
/// under the scan window, e.g. "Point the camera at a QR code" (pass your
/// own localized text, or an empty string for none). A [check] that
/// refuses a code keeps the scanner open with the verdict's text.
/// [presentation] opens it as a page or as a sheet.
///
/// The theme and texts of a [ScannerScope] around [context] apply, under
/// the template's theme, [theme] and [strings].
Future<Barcode?> scanBarcode(
  BuildContext context, {
  Set<BarcodeFormat>? formats,
  ScanWindow? scanWindow,
  CameraFacing? facing,
  String? hint,
  ScannerCheck? check,
  ScannerPresentation presentation = ScannerPresentation.page,
  ScannerTemplate? template,
  ScannerTheme? theme,
  ScannerStrings? strings,
}) {
  final ScannerTemplate base = template ?? const ScannerTemplate.minimal();
  final ScannerTemplate page = base.copyWith(
    scanWindow: scanWindow,
    formats: formats == null ? null : () => formats,
    hint: hint == null ? null : () => hint,
    facing: facing == null ? null : () => facing,
    check: check == null ? null : () => check,
    // One code and the screen closes: a template that collects codes or
    // keeps scanning takes one at a time here.
    mode: switch (base.mode) {
      ScannerMode.collect || ScannerMode.continuous => ScannerMode.single,
      final ScannerMode mode => mode,
    },
    showResult: false,
    closeOnResult: true,
    // It counts the codes of a scanner that keeps scanning.
    counter: false,
  );
  return _pushScanner<Barcode>(
    context,
    template: page,
    presentation: presentation,
    theme: theme,
    strings: strings,
  );
}

/// Opens [template] as a screen of its own, with its result sheet, and
/// returns what the sheet passes to `ScannerResult.finish`, or `null` if
/// the user closes it. For a code that needs more than [scanBarcode]
/// gives, such as the customer a loyalty card belongs to:
///
/// ```dart
/// final Customer? customer = await openScanner<Customer>(
///   context,
///   template: ScannerTemplate.loyalty(
///     check: (barcode) async {
///       final Customer? c = await customers.find(barcode.text);
///       if (c == null) return const ScanVerdict.reject(title: 'Unknown card');
///       return ScanVerdict.accept(title: c.name, data: c);
///     },
///     actionsBuilder: (context, result) => [
///       ScannerAction(
///         label: 'Attach to the sale',
///         primary: true,
///         onPressed: () => result.finish(result.verdict?.data),
///       ),
///       ScannerAction.scanAgain(result.scanAgain),
///     ],
///   ),
/// );
/// ```
///
/// The theme and texts of a [ScannerScope] around [context] apply, under
/// the template's theme, [theme] and [strings]. [presentation] opens it as
/// a page or as a sheet.
Future<T?> openScanner<T>(
  BuildContext context, {
  ScannerTemplate template = const ScannerTemplate.minimal(),
  ScannerPresentation presentation = ScannerPresentation.page,
  ScannerTheme? theme,
  ScannerStrings? strings,
}) => _pushScanner<T>(
  context,
  template: template,
  presentation: presentation,
  theme: theme,
  strings: strings,
);

/// Opens a scanner that accepts only content of the kind [T], such as an
/// `OtpContent` or a `WifiContent`, and returns it, or `null` if the user
/// closes the scanner. Other codes are refused with [reject] (by default
/// [ScannerStrings.rejected]) and the scanner stays open. The other
/// parameters are those of [scanBarcode].
///
/// ```dart
/// final OtpContent? otp = await scanContent<OtpContent>(
///   context,
///   hint: 'Scan the QR code your service shows',
///   reject: const ScanVerdict.reject(title: 'Not a 2FA code'),
/// );
/// ```
Future<T?> scanContent<T extends BarcodeContent>(
  BuildContext context, {
  Set<BarcodeFormat>? formats,
  ScanWindow? scanWindow,
  CameraFacing? facing,
  String? hint,
  ScanVerdict? reject,
  ScannerPresentation presentation = ScannerPresentation.page,
  ScannerTemplate? template,
  ScannerTheme? theme,
  ScannerStrings? strings,
}) async {
  final Barcode? barcode = await scanBarcode(
    context,
    formats: formats,
    scanWindow: scanWindow,
    facing: facing,
    hint: hint,
    check: acceptOnly<T>(reject: reject),
    presentation: presentation,
    template: template,
    theme: theme,
    strings: strings,
  );
  return switch (barcode?.content) {
    final T content => content,
    _ => null,
  };
}

/// A [ScannerCheck] that accepts only content of the kind [T] and refuses
/// the rest with [reject] (by default [ScannerStrings.rejected]).
///
/// ```dart
/// ScannerTemplate.content(check: acceptOnly<WifiContent>(
///   reject: const ScanVerdict.reject(title: 'Not a Wi‑Fi code'),
/// ))
/// ```
ScannerCheck acceptOnly<T extends BarcodeContent>({ScanVerdict? reject}) =>
    (Barcode barcode) =>
        barcode.content is T ? null : reject ?? const ScanVerdict.reject();

Future<T?> _pushScanner<T>(
  BuildContext context, {
  required ScannerTemplate template,
  required ScannerPresentation presentation,
  ScannerTheme? theme,
  ScannerStrings? strings,
}) {
  final ScannerTemplate page = template;
  // The route is built under the navigator: take the caller's scope along.
  final ScannerScope? around = context
      .getInheritedWidgetOfExactType<ScannerScope>();
  final ScannerStrings texts = strings ?? ScannerStrings.of(context);
  // The page has no Material: keep the caller's font.
  final TextStyle text = DefaultTextStyle.of(context).style;
  final Widget scanner = ScannerScope(
    theme: around?.theme ?? const ScannerTheme(),
    strings: texts,
    child: DefaultTextStyle(
      style: text,
      child: _ScanPage(
        template: page,
        theme: theme,
        sheet: presentation == ScannerPresentation.sheet,
      ),
    ),
  );
  return Navigator.of(context).push<T>(switch (presentation) {
    ScannerPresentation.page => PageRouteBuilder<T>(
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder:
          (BuildContext context, Animation<double> _, Animation<double> _) =>
              scanner,
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
    ),
    ScannerPresentation.sheet => PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0x6B06090D),
      barrierLabel: texts.close,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder:
          (BuildContext context, Animation<double> _, Animation<double> _) =>
              scanner,
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> _,
            Widget child,
          ) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          ),
    ),
  });
}

class _ScanPage extends StatelessWidget {
  const _ScanPage({
    required this.template,
    required this.theme,
    required this.sheet,
  });

  final ScannerTemplate template;
  final ScannerTheme? theme;
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    // The template's overlay closes the page with the code accepted.
    final Widget scanner = BarcodeScanner(template: template, theme: theme);
    if (!sheet) {
      return ColoredBox(color: const Color(0xFF000000), child: scanner);
    }
    final Size screen = MediaQuery.sizeOf(context);
    final double height = math.min(
      screen.height - MediaQuery.viewPaddingOf(context).top - 24,
      math.max(420, screen.height * 0.62),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: height),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: ColoredBox(
            color: const Color(0xFF000000),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // The sheet is below the status bar.
                MediaQuery.removeViewPadding(
                  context: context,
                  removeTop: true,
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: scanner,
                  ),
                ),
                // A handle: the sheet can be closed.
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 40,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0x8CFFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
