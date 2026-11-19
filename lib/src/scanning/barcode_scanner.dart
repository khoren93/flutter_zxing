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
/// Replace the overlay with [overlayBuilder]. Tap to focus and pinch to
/// zoom are on.
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
    this.errorBuilder,
    this.placeholderBuilder,
    this.fit = BoxFit.cover,
    this.tapToFocus = true,
    this.pinchToZoom = true,
  });

  /// The controller. `null` creates one with the [template]'s scan window,
  /// formats and detection, or with default settings.
  final ScannerController? controller;

  /// Called for every capture the controller reports.
  final ValueChanged<BarcodeCapture>? onDetect;

  /// A ready-made screen around the camera; see [ScannerTemplate].
  final ScannerTemplate? template;

  /// Colors and shapes, merged onto the [template]'s theme.
  final ScannerTheme? theme;

  /// The texts; English by default.
  final ScannerStrings? strings;

  /// Builds the overlay while the camera runs, instead of the [template]'s
  /// or the default [ScannerOverlay]. Return `const SizedBox.shrink()` for
  /// none.
  final ScannerOverlayBuilder? overlayBuilder;

  /// Shown instead of the preview when the camera cannot be used. Default
  /// [ScannerErrorView].
  final Widget Function(BuildContext context, ScannerException error)?
  errorBuilder;

  /// Shown while the camera is starting. Default [ScannerPlaceholder].
  final WidgetBuilder? placeholderBuilder;

  /// How the preview fills the widget. With [BoxFit.cover] (the default)
  /// the edges of the camera image may be cut off; the scan window and
  /// barcode outlines always match what is visible.
  final BoxFit fit;

  /// Focus where the user taps.
  final bool tapToFocus;

  /// Zoom with a pinch gesture.
  final bool pinchToZoom;

  @override
  State<BarcodeScanner> createState() => _BarcodeScannerState();
}

class _BarcodeScannerState extends State<BarcodeScanner> {
  ScannerController? _own;
  StreamSubscription<BarcodeCapture>? _detections;
  double _zoomAtPinchStart = 1;
  final BackdropKey _backdrop = BackdropKey();

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
      _disconnect(old!);
      if (oldWidget.controller == null) {
        _own?.dispose();
        _own = null;
      }
      _connect();
    } else if (_own case final ScannerController own
        when widget.template != oldWidget.template) {
      final ScannerTemplate? template = widget.template;
      own
        ..formats = template?.formats
        ..scanWindow = template?.scanWindow ?? const ScanWindow.centered()
        ..detection = template?.detection ?? DetectionMode.distinct
        ..maxBarcodes = template == null ? 1 : template.maxBarcodes
        ..initialZoom = template?.initialZoom;
    }
  }

  @override
  void dispose() {
    _disconnect(_controller);
    _own?.dispose();
    super.dispose();
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
    return ScannerScope.resolve(
      context,
      theme: (template?.theme ?? const ScannerTheme()).merge(widget.theme),
      strings: widget.strings ?? const ScannerStrings(),
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
                ));
    } else {
      base =
          widget.placeholderBuilder?.call(context) ??
          (templateOverlay
              ? const SizedBox.expand()
              : ScannerPlaceholder(scanWindow: controller.scanWindow));
    }

    Widget? overlay;
    if (templateOverlay || ready) {
      overlay = ValueListenableBuilder<_Visible?>(
        valueListenable: controller._visible,
        builder: (BuildContext context, _Visible? visible, Widget? _) {
          final ScannerLayout layout = ready
              ? _layoutOf(controller, state, size, fit!, preview, visible)
              : ScannerLayout(
                  size: size,
                  scanWindow: controller.scanWindow.resolve(size),
                  barcodes: const <VisibleBarcode>[],
                  state: state,
                  controller: controller,
                );
          if (templateOverlay) {
            return TemplateOverlay(
              template: template,
              layout: layout,
              drawPlaceholder: widget.placeholderBuilder == null,
              drawError: widget.errorBuilder == null,
            );
          }
          return widget.overlayBuilder?.call(context, layout) ??
              ScannerOverlay(layout);
        },
      );
    }

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
/// closes. [formats] and [scanWindow] replace the template's; [hint] is
/// shown under the scan window, e.g. "Point the camera at a QR code" (pass
/// your own localized text, or an empty string for none). A [check] that
/// refuses a code keeps the scanner open with the verdict's text.
/// [presentation] opens it as a page or as a sheet.
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
  final ScannerTemplate page = ScannerTemplate(
    theme: base.theme,
    scanWindow: scanWindow ?? base.scanWindow,
    formats: formats ?? base.formats,
    title: base.title,
    hint: hint == null ? base.hint : (hint.isEmpty ? null : hint),
    hintIcon: base.hintIcon,
    closeButton: base.closeButton,
    onClose: base.onClose,
    torchButton: base.torchButton,
    photoButton: base.photoButton,
    zoomButtons: base.zoomButtons,
    switchCameraButton: base.switchCameraButton,
    check: check ?? base.check,
    showResult: false,
    closeOnResult: true,
    initialZoom: base.initialZoom,
    facing: facing ?? base.facing,
    haptics: base.haptics,
    sound: base.sound,
  );
  // The page has no Material: keep the caller's font.
  final TextStyle text = DefaultTextStyle.of(context).style;
  final Widget scanner = DefaultTextStyle(
    style: text,
    child: _ScanPage(
      template: page,
      theme: theme,
      strings: strings,
      sheet: presentation == ScannerPresentation.sheet,
    ),
  );
  return Navigator.of(context).push<Barcode>(switch (presentation) {
    ScannerPresentation.page => PageRouteBuilder<Barcode>(
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
    ScannerPresentation.sheet => PageRouteBuilder<Barcode>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: const Color(0x6B06090D),
      barrierLabel: (strings ?? const ScannerStrings()).close,
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

class _ScanPage extends StatefulWidget {
  const _ScanPage({
    required this.template,
    required this.theme,
    required this.strings,
    required this.sheet,
  });

  final ScannerTemplate template;
  final ScannerTheme? theme;
  final ScannerStrings? strings;
  final bool sheet;

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  late final ScannerController _controller = ScannerController.fromTemplate(
    widget.template,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The template's overlay closes the page with the code accepted.
    final Widget scanner = BarcodeScanner(
      controller: _controller,
      template: widget.template,
      theme: widget.theme,
      strings: widget.strings,
    );
    if (!widget.sheet) {
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
