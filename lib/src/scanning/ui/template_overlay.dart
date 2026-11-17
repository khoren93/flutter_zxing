import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../content/barcode_content.dart';
import '../../errors.dart';
import '../scanner_controller.dart';
import 'controls.dart';
import 'glass.dart';
import 'pressable.dart';
import 'result_sheet.dart';
import 'scan_verdict.dart';
import 'scanner_icons.dart';
import 'scanner_strings.dart';
import 'scanner_template.dart';
import 'scanner_theme.dart';
import 'states.dart';
import 'thumbnail.dart';
import 'window_overlay.dart';

/// The overlay of a [ScannerTemplate], in every state of the camera: also
/// while it starts or after an error, so that the close button, the photo
/// button and a result read from a photo stay available. Keeps the current
/// result, the collected codes and the verdicts.
class TemplateOverlay extends StatefulWidget {
  /// Creates the overlay.
  const TemplateOverlay({
    super.key,
    required this.template,
    required this.layout,
    this.drawPlaceholder = true,
    this.drawError = true,
  });

  /// The template.
  final ScannerTemplate template;

  /// The scanner layout.
  final ScannerLayout layout;

  /// Draws [ScannerPlaceholder] while the camera starts.
  final bool drawPlaceholder;

  /// Draws [ScannerErrorView] when the camera failed.
  final bool drawError;

  @override
  State<TemplateOverlay> createState() => _TemplateOverlayState();
}

/// Whether [window] is the whole scanner: no window to show.
bool _isFull(Rect window, Size size) =>
    window.left <= 0.5 &&
    window.top <= 0.5 &&
    window.right >= size.width - 0.5 &&
    window.bottom >= size.height - 0.5;

String _keyOf(Barcode b) => '${b.format.index}|${b.text}';

class _TemplateOverlayState extends State<TemplateOverlay>
    with SingleTickerProviderStateMixin {
  StreamSubscription<BarcodeCapture>? _captures;

  /// The code found, cut out of the frame, flying into the window.
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  ui.Image? _cutOut;
  List<Offset>? _cutFrom;
  bool _cutLinear = false;
  bool _settled = false;

  /// The cut-out shown in the result sheet: a handle of its own, as the
  /// window's fades away with "Scan again" while the sheet is still leaving.
  ui.Image? _resultCutOut;

  /// Counts locks, so that a cut-out arriving after "Scan again" is dropped.
  int _lock = 0;
  ScannerController? _controller;
  Barcode? _result;
  Timer? _showResult;
  final List<CollectedBarcode> _items = <CollectedBarcode>[];
  String? _notice;
  Timer? _hideNotice;

  /// A check is running: codes found meanwhile are skipped.
  bool _checking = false;

  /// The verdict shown in [ScannerMode.continuous], for [_verdictOf].
  ScanVerdict? _verdict;
  Barcode? _verdictOf;
  Timer? _hideVerdict;

  /// Accepted codes, for the counter.
  int _accepted = 0;

  /// The window flashes in a verdict's color.
  ScanStatus? _flash;
  Timer? _flashEnd;

  /// The latest capture of each code in view, for [ScannerMode.pick]: a
  /// picked code flies from its own frame.
  final Map<String, BarcodeCapture> _pickable = <String, BarcodeCapture>{};

  /// Scans again after [ScannerTemplate.resumeAfter], or closes the screen.
  Timer? _after;

  /// Whether [ScannerTemplate.initialZoom] was set since the camera
  /// started.
  bool _zoomSet = false;

  ScannerTemplate get _template => widget.template;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(TemplateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
    _setInitialZoom();
  }

  @override
  void dispose() {
    unawaited(_captures?.cancel());
    _showResult?.cancel();
    _hideNotice?.cancel();
    _hideVerdict?.cancel();
    _flashEnd?.cancel();
    _after?.cancel();
    _flight.dispose();
    _cutOut?.dispose();
    _resultCutOut?.dispose();
    for (final CollectedBarcode item in _items) {
      item.cutOut?.dispose();
    }
    super.dispose();
  }

  void _listen() {
    final ScannerController controller = widget.layout.controller;
    if (controller == _controller) {
      return;
    }
    unawaited(_captures?.cancel());
    _controller = controller;
    _zoomSet = false;
    _captures = controller.barcodes.listen(_onCapture);
    _setInitialZoom();
  }

  /// Zooms to [ScannerTemplate.initialZoom] once the camera runs, again
  /// after every start.
  void _setInitialZoom() {
    final ScannerStatus status = widget.layout.state.status;
    if (status != ScannerStatus.running && status != ScannerStatus.paused) {
      _zoomSet = false;
      return;
    }
    final double? zoom = _template.initialZoom;
    if (_zoomSet || zoom == null) {
      return;
    }
    _zoomSet = true;
    unawaited(widget.layout.controller.setZoom(zoom));
  }

  void _onCapture(BarcodeCapture capture) {
    switch (_template.mode) {
      case ScannerMode.collect:
        _collect(capture);
      case ScannerMode.pick:
        if (capture.source == CaptureSource.image) {
          unawaited(_single(capture, capture.barcode));
          return;
        }
        for (final Barcode barcode in capture.barcodes) {
          _pickable[_keyOf(barcode)] = capture;
        }
        // Keep the latest few dozen.
        while (_pickable.length > 32) {
          _pickable.remove(_pickable.keys.first);
        }
      case ScannerMode.continuous:
        unawaited(_continuous(capture));
      case ScannerMode.single:
        unawaited(_single(capture, capture.barcode));
    }
  }

  void _collect(BarcodeCapture capture) {
    if (_template.haptics) {
      unawaited(HapticFeedback.selectionClick());
    }
    if (_template.sound) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    setState(() {
      for (final Barcode barcode in capture.barcodes) {
        final int index = _items.indexWhere(
          (CollectedBarcode item) =>
              item.barcode.format == barcode.format &&
              item.barcode.text == barcode.text,
        );
        final CollectedBarcode? before = index >= 0 ? _items[index] : null;
        if (index >= 0) {
          _items.removeAt(index);
        }
        _items.insert(
          0,
          CollectedBarcode(
            barcode,
            (before?.count ?? 0) + 1,
            cutOut: before?.cutOut,
          ),
        );
        if (before?.cutOut == null && BarcodeThumbnail.needsCutOut(barcode)) {
          unawaited(_cutOutFor(capture, barcode));
        }
      }
    });
  }

  /// Runs the template's check on [barcode]; `null` when it failed or the
  /// overlay is gone.
  Future<ScanVerdict?> _judge(Barcode barcode) async {
    final ScannerCheck? check = _template.check;
    if (check == null) {
      return const ScanVerdict.accept();
    }
    _checking = true;
    try {
      return await check(barcode) ?? const ScanVerdict.accept();
    } on Object catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter_zxing',
          context: ErrorDescription('while checking a scanned code'),
        ),
      );
      return null;
    } finally {
      _checking = false;
    }
  }

  /// One code at a time: [barcode] of [capture], from where it shows
  /// ([from]) or as reported.
  Future<void> _single(
    BarcodeCapture capture,
    Barcode barcode, {
    List<Offset>? from,
  }) async {
    if (_result != null || _showResult != null || _settled || _checking) {
      return;
    }
    if (_template.check != null) {
      final ScanVerdict? verdict = await _judge(barcode);
      if (!mounted || verdict == null) {
        return;
      }
      if (verdict.status == ScanStatus.rejected) {
        _feedback(ScanStatus.rejected);
        _flashFor(ScanStatus.rejected);
        _showNotice(
          <String>[
            verdict.title ?? ScannerStrings.of(context).rejected,
            ?verdict.message,
          ].join(' · '),
        );
        if (capture.source == CaptureSource.image ||
            _template.detection == DetectionMode.once) {
          // A photo or a paused camera: scan on.
          unawaited(widget.layout.controller.resume());
        }
        return;
      }
      if (_settled || _result != null) {
        return;
      }
    }
    _feedback(ScanStatus.accepted);
    final ScannerController controller = widget.layout.controller;
    unawaited(_takeIn(capture, barcode, ++_lock, from: from));
    if (_template.closeOnResult) {
      unawaited(controller.pause());
      // Let the code fly into the window before the screen closes.
      _after = Timer(const Duration(milliseconds: 450), () {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
          unawaited(Navigator.maybeOf(context)?.maybePop(barcode));
        }
      });
      return;
    }
    if (!_template.showResult) {
      if (_template.detection != DetectionMode.once) {
        unawaited(controller.pause());
      }
      return;
    }
    unawaited(controller.pause());
    // Let the code settle in the window before the sheet rises.
    final Duration delay = capture.source == CaptureSource.image
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 380);
    _showResult = Timer(delay, () {
      _showResult = null;
      if (mounted) {
        setState(() => _result = barcode);
        if (_template.resumeAfter case final Duration after) {
          _after = Timer(after, _scanAgain);
        }
      }
    });
  }

  /// Scanning goes on: a verdict for each code.
  Future<void> _continuous(BarcodeCapture capture) async {
    if (_checking) {
      return;
    }
    final Barcode barcode = capture.barcode;
    final ScanVerdict? verdict = await _judge(barcode);
    if (!mounted || verdict == null) {
      return;
    }
    _feedback(verdict.status);
    _hideVerdict?.cancel();
    final Duration shown = _template.resumeAfter ?? const Duration(seconds: 2);
    setState(() {
      _verdict = verdict;
      _verdictOf = barcode;
      _flash = verdict.status;
      if (verdict.status == ScanStatus.accepted) {
        _accepted++;
      }
    });
    _flashEnd?.cancel();
    _hideVerdict = Timer(shown, () {
      if (mounted) {
        setState(() {
          _verdict = null;
          _verdictOf = null;
          _flash = null;
        });
      }
    });
  }

  void _feedback(ScanStatus status) {
    if (_template.haptics) {
      unawaited(switch (status) {
        ScanStatus.accepted => HapticFeedback.mediumImpact(),
        ScanStatus.warning => HapticFeedback.heavyImpact(),
        ScanStatus.rejected => HapticFeedback.vibrate(),
      });
    }
    if (_template.sound) {
      unawaited(
        SystemSound.play(
          status == ScanStatus.accepted
              ? SystemSoundType.click
              : SystemSoundType.alert,
        ),
      );
    }
  }

  /// The window flashes in [status]'s color for a moment.
  void _flashFor(ScanStatus status) {
    _flashEnd?.cancel();
    setState(() => _flash = status);
    _flashEnd = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _flash = null);
      }
    });
  }

  void _showNotice(String text) {
    _hideNotice?.cancel();
    setState(() => _notice = text);
    _hideNotice = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _notice = null);
      }
    });
  }

  /// Keeps the cut-out of a collected [barcode] for its row.
  Future<void> _cutOutFor(BarcodeCapture capture, Barcode barcode) async {
    final ui.Image? image = await capture.snapshot(barcode);
    if (image == null) {
      return;
    }
    if (!mounted) {
      image.dispose();
      return;
    }
    final int index = _items.indexWhere(
      (CollectedBarcode item) =>
          item.barcode.format == barcode.format &&
          item.barcode.text == barcode.text,
    );
    if (index < 0 || _items[index].cutOut != null) {
      image.dispose();
      return;
    }
    final CollectedBarcode item = _items[index];
    setState(() {
      _items[index] = CollectedBarcode(item.barcode, item.count, cutOut: image);
    });
  }

  /// Cuts [barcode] out of the frame of [capture] and flies it from where
  /// it shows into the scan window. Nothing flies where there is no
  /// cut-out.
  Future<void> _takeIn(
    BarcodeCapture capture,
    Barcode barcode,
    int lock, {
    List<Offset>? from,
  }) async {
    final ui.Image? image = await capture.snapshot(barcode);
    // The layout shows the code from the frame after the capture.
    await WidgetsBinding.instance.endOfFrame;
    if (image == null || !mounted || lock != _lock) {
      image?.dispose();
      return;
    }
    if (from == null && capture.source == CaptureSource.camera) {
      for (final VisibleBarcode v in widget.layout.barcodes) {
        if (v.barcode.format == barcode.format &&
            v.barcode.text == barcode.text) {
          from = v.corners;
          break;
        }
      }
    }
    setState(() {
      _cutOut?.dispose();
      _cutOut = image;
      _resultCutOut?.dispose();
      _resultCutOut = image.clone();
      _cutFrom = from;
      _cutLinear = barcode.format.isLinear;
      _settled = true;
    });
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _flight.value = 1;
    } else {
      unawaited(_flight.forward(from: 0));
    }
  }

  void _scanAgain() {
    _showResult?.cancel();
    _showResult = null;
    _after?.cancel();
    _after = null;
    _lock++;
    setState(() {
      _result = null;
      _settled = false;
    });
    unawaited(widget.layout.controller.resume());
  }

  /// [ScannerMode.pick]: the user tapped [code].
  void _pick(VisibleBarcode code) {
    final BarcodeCapture capture =
        _pickable[_keyOf(code.barcode)] ??
        BarcodeCapture(
          barcodes: <Barcode>[code.barcode],
          imageSize: widget.layout.size,
          time: DateTime.now(),
        );
    unawaited(_single(capture, code.barcode, from: code.corners));
  }

  Future<void> _pickPhoto() async {
    final (bool picked, BarcodeCapture? capture) = await pickAndReadImage(
      widget.layout.controller,
    );
    if (picked && mounted) {
      _photoRead(capture);
    }
  }

  void _photoRead(BarcodeCapture? capture) {
    if (capture == null && mounted) {
      _showNotice(ScannerStrings.of(context).noCodeInPhoto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = widget.layout.size;
    // In landscape the sheet takes the right half: the window moves to the
    // middle of the left half while it is up (always, for a list or a
    // large hint).
    final bool aside =
        size.width > size.height &&
        (_template.mode == ScannerMode.collect ||
            _template.largeHint ||
            _result != null ||
            _verdict != null);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: aside ? 1 : 0),
      duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      builder: (BuildContext context, double t, Widget? _) =>
          _build(context, t),
    );
  }

  /// The window in the middle of the left half of a landscape view, level
  /// with the sheet in the right half; made smaller if it does not fit.
  static Rect _windowAside(Rect window, Size size, EdgeInsets safe) {
    final Rect half = Rect.fromLTRB(
      safe.left,
      safe.top + 72,
      size.width / 2,
      size.height - math.max(safe.bottom, 12),
    );
    final double scale = math.min(
      1,
      math.min(
        (half.width - 32) / window.width,
        (half.height - 16) / window.height,
      ),
    );
    return Rect.fromCenter(
      center: half.center,
      width: window.width * math.max(scale, 0.3),
      height: window.height * math.max(scale, 0.3),
    );
  }

  /// Where a code settles without a window ([ScanWindow.full]): a square
  /// a little above the middle.
  static Rect _resultWindow(Size size) {
    final double side = math.min(size.width, size.height) * 0.62;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: side,
      height: side,
    );
  }

  Color? _flashColor(ScannerTheme theme) => switch (_flash) {
    ScanStatus.accepted => theme.lockColor,
    ScanStatus.warning => theme.warningColor,
    ScanStatus.rejected => theme.dangerColor,
    null => null,
  };

  Widget _build(BuildContext context, double aside) {
    final ScannerTemplate template = _template;
    final ScannerLayout full = widget.layout;
    final ScannerController controller = full.controller;
    final ScannerStatus status = full.state.status;
    final bool camera =
        status == ScannerStatus.running || status == ScannerStatus.paused;
    final EdgeInsets safe = MediaQuery.viewPaddingOf(context);
    final Size size = full.size;
    final bool landscape = size.width > size.height;
    final bool noWindow = _isFull(full.scanWindow, size);
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    // The window as drawn: the scan window, or on its way beside the sheet;
    // without a window, where the code settles.
    Rect window = full.scanWindow;
    if (noWindow && _settled) {
      window = _resultWindow(size);
    }
    if (aside > 0) {
      window = Rect.lerp(window, _windowAside(window, size, safe), aside)!;
    }
    final ScannerLayout layout = window == full.scanWindow
        ? full
        : ScannerLayout(
            size: size,
            scanWindow: window,
            barcodes: full.barcodes,
            state: full.state,
            controller: controller,
          );
    final Widget? sheet = _sheet(context, camera);
    final bool searching =
        camera &&
        _result == null &&
        _verdict == null &&
        layout.barcodes.isEmpty;
    final bool pick = template.mode == ScannerMode.pick && camera && !_settled;
    final bool showClose =
        template.closeButton &&
        (template.onClose != null || (ModalRoute.of(context)?.canPop ?? false));
    const Duration fade = Duration(milliseconds: 200);
    final String? hint = _notice ?? (template.largeHint ? null : template.hint);
    final bool bottomBar =
        template.photoButton ||
        template.zoomButtons ||
        template.switchCameraButton;
    final Color? flash = _flashColor(theme);
    final String? title = template.largeHint
        ? null
        : template.counter
        ? strings.checkedIn(_accepted)
        : pick && layout.barcodes.isNotEmpty
        ? strings.codesInView(layout.barcodes.length)
        : template.title;

    final ScannerException? error = layout.state.error;
    // The hint: under the window, or above the bottom bar without one.
    final double hintTop = noWindow
        ? size.height -
              math.max(safe.bottom, 12) -
              24 -
              40 -
              (bottomBar && !landscape ? 72 : 0)
        : math.min(layout.scanWindow.bottom + 16, size.height - 64);
    Widget overlay = ScannerOverlay(
      layout,
      lockOn: template.mode != ScannerMode.collect && !pick,
      settled: _settled && _cutOut != null,
    );
    if (flash != null) {
      overlay = ScannerScope(
        theme: theme.copyWith(accent: flash),
        strings: strings,
        child: overlay,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // The camera in the window fades under a dark plate as the cut-out
        // flies in: the whole window, under the brackets.
        if (camera && _cutOut != null)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _settled ? 1 : 0,
              duration: fade,
              child: AnimatedBuilder(
                animation: _flight,
                builder: (BuildContext context, Widget? _) => _WindowPlate(
                  window: layout.scanWindow,
                  radius: theme.resolvedWindowRadius,
                  opacity: Curves.easeInOutCubicEmphasized.transform(
                    _flight.value,
                  ),
                ),
              ),
            ),
          ),
        if (camera)
          overlay
        else if (status == ScannerStatus.error && error != null) ...<Widget>[
          if (widget.drawError)
            ScannerErrorView(
              error,
              onRetry: () => unawaited(controller.start()),
              onPickImage: template.photoButton
                  ? () => unawaited(_pickPhoto())
                  : null,
            ),
        ] else if (widget.drawPlaceholder)
          ScannerPlaceholder(scanWindow: controller.scanWindow),
        // The window tinted in a verdict's color.
        if (camera && !noWindow)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: flash == null ? 0 : 1,
              duration: fade,
              child: _WindowPlate(
                window: layout.scanWindow,
                radius: theme.resolvedWindowRadius,
                opacity: 1,
                color: (flash ?? theme.lockColor).withValues(alpha: 0.28),
              ),
            ),
          ),
        if (camera && _cutOut != null)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _settled ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              onEnd: () {
                if (!_settled && mounted) {
                  setState(() {
                    _cutOut?.dispose();
                    _cutOut = null;
                  });
                }
              },
              child: AnimatedBuilder(
                animation: _flight,
                builder: (BuildContext context, Widget? _) => _CutOutFlight(
                  image: _cutOut!,
                  from: _cutFrom,
                  linear: _cutLinear,
                  window: layout.scanWindow,
                  progress: _flight.value,
                ),
              ),
            ),
          ),
        // A label on every code in view, to pick one.
        if (pick)
          for (final (int i, VisibleBarcode code) in layout.barcodes.indexed)
            _PickLabel(
              key: ValueKey<String>(_keyOf(code.barcode)),
              number: i + 1,
              code: code,
              size: size,
              onPressed: () => _pick(code),
            ),
        // The hint under the window.
        if (camera && hint != null && template.mode != ScannerMode.collect)
          Positioned(
            left: 16,
            right: 16,
            top: hintTop,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: searching || _notice != null || pick ? 1 : 0,
                duration: fade,
                child: Center(
                  child: ScannerHint(
                    hint,
                    icon: _notice == null ? template.hintIcon : null,
                    liveRegion: _notice != null,
                  ),
                ),
              ),
            ),
          ),
        // A notice without the camera, such as a photo without a code.
        if (!camera && _notice != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: math.max(safe.bottom, 12) + 24,
            child: Center(child: ScannerHint(_notice!, liveRegion: true)),
          ),
        // A tap on the camera around a result scans again.
        if (_result != null && template.resultBuilder == null)
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _scanAgain,
              ),
            ),
          ),
        // The top bar.
        Positioned(
          left: safe.left + 20,
          right: safe.right + 20,
          top: safe.top + 12,
          child: SizedBox(
            height: 48,
            child: Stack(
              children: <Widget>[
                if (showClose)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ScannerCloseButton(onPressed: template.onClose),
                  ),
                if (title != null)
                  Align(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: ScannerHint(
                        title,
                        icon: template.counter ? ScannerIcons.person : null,
                        liveRegion: template.counter,
                      ),
                    ),
                  ),
                if (camera && template.torchButton)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TorchButton(controller),
                  ),
              ],
            ),
          ),
        ),
        // The bottom bar, hidden under a sheet; a column at the right in
        // landscape, where a row would run into the window and the hint.
        if (camera && bottomBar && template.mode != ScannerMode.collect)
          Positioned(
            left: landscape ? null : safe.left + 40,
            right: landscape ? safe.right + 20 : safe.right + 40,
            top: landscape ? safe.top + 72 : null,
            bottom: math.max(safe.bottom, 12) + (landscape ? 12 : 24),
            child: IgnorePointer(
              ignoring: sheet != null,
              child: AnimatedOpacity(
                opacity: sheet == null ? 1 : 0,
                duration: fade,
                child: landscape
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (template.photoButton)
                            PickImageButton(controller, onResult: _photoRead),
                          if (template.zoomButtons) ...<Widget>[
                            // Gaps give way on a low screen.
                            const Flexible(child: SizedBox(height: 16)),
                            ZoomButtons(controller, direction: Axis.vertical),
                          ],
                          if (template.switchCameraButton) ...<Widget>[
                            // Gaps give way on a low screen.
                            const Flexible(child: SizedBox(height: 16)),
                            SwitchCameraButton(controller),
                          ],
                        ],
                      )
                    : SizedBox(
                        height: 48,
                        child: Stack(
                          children: <Widget>[
                            if (template.photoButton)
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: PickImageButton(
                                  controller,
                                  onResult: _photoRead,
                                ),
                              ),
                            if (template.zoomButtons)
                              Align(child: ZoomButtons(controller)),
                            if (template.switchCameraButton)
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: SwitchCameraButton(controller),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        // The sheet: at the bottom, or at the side in landscape.
        Positioned(
          // In landscape: the middle of the right half.
          left: landscape ? size.width / 2 + 12 : safe.left + 12,
          right: safe.right + 12,
          // Below the top bar: a tall sheet scrolls instead of covering
          // the close and torch buttons.
          top: safe.top + 72,
          bottom: math.max(safe.bottom, 12),
          child: Align(
            alignment: landscape ? Alignment.center : Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder:
                    (Widget child, Animation<double> animation) =>
                        FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: landscape
                                  ? const Offset(0.15, 0)
                                  : const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                child: sheet == null
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        key: ValueKey<Object?>(
                          _verdict ?? _result ?? template.mode,
                        ),
                        reverse: true,
                        child: sheet,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _sheet(BuildContext context, bool camera) {
    final ScannerTemplate template = _template;
    if (template.mode == ScannerMode.collect) {
      final ValueChanged<List<CollectedBarcode>>? onDone = template.onDone;
      return BarcodeListSheet(
        items: _items,
        onDone: onDone == null
            ? null
            : () => onDone(List<CollectedBarcode>.unmodifiable(_items)),
      );
    }
    if ((_verdict, _verdictOf) case (
      final ScanVerdict verdict,
      final Barcode barcode,
    )) {
      return _VerdictSheet(
        verdict: verdict,
        barcode: barcode,
        duration: template.resumeAfter ?? const Duration(seconds: 2),
      );
    }
    final Barcode? result = _result;
    if (result == null) {
      return template.largeHint && camera
          ? _HintPanel(title: template.title, hint: _notice ?? template.hint)
          : null;
    }
    return template.resultBuilder?.call(context, result, _scanAgain) ??
        BarcodeResultSheet(
          result,
          actions: template.actionsBuilder?.call(context, result, _scanAgain),
          onScanAgain: _scanAgain,
          showIcon: template.showResultIcon,
          asCard: template.resultAsCard,
          cutOut: _resultCutOut,
        );
  }
}

/// A plate over the scan window: dark once a code settled in it, or
/// tinted in a verdict's [color].
class _WindowPlate extends StatelessWidget {
  const _WindowPlate({
    required this.window,
    required this.radius,
    required this.opacity,
    this.color,
  });

  final Rect window;
  final double radius;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      Positioned.fromRect(
        rect: window,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                color ??
                const Color(0xFF06090D).withValues(alpha: 0.82 * opacity),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    ],
  );
}

/// The verdict on a code while scanning goes on: a badge in the status's
/// color, the title and message, and a bar running down until it hides.
class _VerdictSheet extends StatelessWidget {
  const _VerdictSheet({
    required this.verdict,
    required this.barcode,
    required this.duration,
  });

  final ScanVerdict verdict;
  final Barcode barcode;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    final (
      Color color,
      Color on,
      ScannerIconData icon,
      String over,
    ) = switch (verdict.status) {
      ScanStatus.accepted => (
        theme.lockColor,
        theme.onLockColor,
        ScannerIcons.check,
        strings.accepted,
      ),
      ScanStatus.warning => (
        theme.warningColor,
        theme.onWarningColor,
        ScannerIcons.alert,
        strings.needsAttention,
      ),
      ScanStatus.rejected => (
        theme.dangerColor,
        theme.onDangerColor,
        ScannerIcons.close,
        strings.rejected,
      ),
    };
    final String title = verdict.title ?? barcode.text;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      liveRegion: true,
      child: ScannerSheet(
        padding: const EdgeInsets.all(20),
        label: <String>[over, title, ?verdict.message].join(': '),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: color,
                    shape: theme.buttonBorder,
                  ),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Center(
                      child: ScannerIcon(icon, size: 30, color: on),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(over.toUpperCase(), style: theme.overlineStyle),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: theme.titleStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (verdict.message case final String message)
                        Text(
                          message,
                          style: theme.mutedStyle.copyWith(
                            fontSize: 15,
                            height: 20 / 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(2)),
              child: SizedBox(
                height: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1, end: 0),
                  duration: still ? Duration.zero : duration,
                  builder: (BuildContext context, double t, Widget? _) =>
                      CustomPaint(
                        painter: _TimerPainter(
                          t,
                          color,
                          theme.inkMutedColor.withValues(alpha: 0.22),
                        ),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerPainter extends CustomPainter {
  const _TimerPainter(this.left, this.color, this.track);

  final double left;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = track)
      ..drawRect(
        Offset.zero & Size(size.width * left, size.height),
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_TimerPainter old) =>
      old.left != left || old.color != color || old.track != track;
}

/// The [ScannerTemplate.largeHint] panel: the title and hint large.
class _HintPanel extends StatelessWidget {
  const _HintPanel({required this.title, required this.hint});

  final String? title;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return Semantics(
      liveRegion: true,
      child: ScannerSheet(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title case final String title)
              Text(title, style: theme.displayStyle.copyWith(fontSize: 36)),
            if (title != null && hint != null) const SizedBox(height: 12),
            if (hint case final String hint)
              Text(
                hint,
                style: theme.mutedStyle.copyWith(fontSize: 19, height: 28 / 19),
              ),
          ],
        ),
      ),
    );
  }
}

/// [ScannerMode.pick]: a label above a code in view; a tap picks the code.
class _PickLabel extends StatelessWidget {
  const _PickLabel({
    super.key,
    required this.number,
    required this.code,
    required this.size,
    required this.onPressed,
  });

  final int number;
  final VisibleBarcode code;
  final Size size;
  final VoidCallback onPressed;

  static String _labelOf(Barcode barcode) {
    final String text = switch (barcode.content) {
      UrlContent(:final Uri url) when url.host.isNotEmpty =>
        url.host.replaceFirst(RegExp(r'^www\.'), ''),
      WifiContent(:final String ssid) => ssid,
      ContactContent(:final String? name) when name != null => name,
      _ => barcode.text.trim().split('\n').first,
    };
    return text.length > 28 ? '${text.substring(0, 27)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    final Barcode barcode = code.barcode;
    final Rect bounds = code.bounds;
    final String label = _labelOf(barcode);
    const double height = 36;
    // Above the code, or below it at the top of the screen.
    final double top = bounds.top - height - 8 >= 64
        ? bounds.top - height - 8
        : math.min(bounds.bottom + 8, size.height - height - 8);
    return Positioned(
      left: 8,
      right: 8,
      top: top,
      height: height,
      child: CustomSingleChildLayout(
        delegate: _CenterOn(bounds.center.dx - 8),
        child: Semantics(
          button: true,
          label: '$number. ${strings.kindOf(barcode.content)}: $label',
          hint: strings.pickCode,
          child: Pressable(
            onPressed: onPressed,
            shape: theme.pillBorder,
            child: ScannerGlass(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: theme.lockColor,
                        shape: const CircleBorder(),
                      ),
                      child: SizedBox.square(
                        dimension: 24,
                        child: Center(
                          child: Text(
                            '$number',
                            style: theme.labelStyle.copyWith(
                              fontSize: 12,
                              height: 1,
                              color: theme.onLockColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ScannerIcon(
                      BarcodeResultSheet.iconOf(barcode.content),
                      size: 16,
                      color: theme.inkColor,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        style: theme.hintStyle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays out its child at its own width, centered on [x] and kept inside.
class _CenterOn extends SingleChildLayoutDelegate {
  const _CenterOn(this.x);

  final double x;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen().copyWith(
        maxWidth: math.min(constraints.maxWidth, 260),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (x - childSize.width / 2).clamp(
      0,
      math.max(0, size.width - childSize.width),
    ),
    0,
  );

  @override
  bool shouldRelayout(_CenterOn old) => old.x != x;
}

/// The cut-out of the code found on its way from where the code shows into
/// the scan window.
class _CutOutFlight extends StatelessWidget {
  const _CutOutFlight({
    required this.image,
    required this.from,
    required this.linear,
    required this.window,
    required this.progress,
  });

  final ui.Image image;

  /// The code's corners on screen when it was found; `null` for a photo,
  /// which grows in the middle of the window.
  final List<Offset>? from;
  final bool linear;
  final Rect window;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final double t = Curves.easeInOutCubicEmphasized.transform(progress);
    final double radius = theme.resolvedWindowRadius;
    final double aspect = image.width / image.height;
    // Where it settles: as large as the window allows, with a margin.
    final Rect inner = window.deflate(math.max(16, radius * 0.8));
    final Size fitted = applyBoxFit(
      BoxFit.contain,
      Size(aspect, 1),
      inner.size,
    ).destination;
    final Rect to = Alignment.center.inscribe(fitted, inner);
    // Where it starts: on the code, turned like it.
    Offset start = to.center;
    double startWidth = to.width * 0.6;
    double angle = 0;
    final List<Offset>? q = from;
    if (q != null && q.length == 4) {
      start = (q[0] + q[1] + q[2] + q[3]) / 4;
      final Offset across = ((q[1] - q[0]) + (q[2] - q[3])) / 2;
      startWidth = across.distance * (linear ? 1.12 : 1.18);
      angle = math.atan2(across.dy, across.dx);
    }
    final Offset center = Offset.lerp(start, to.center, t)!;
    // A little lift halfway.
    final double width =
        (startWidth + (to.width - startWidth) * t) *
        (1 + 0.05 * math.sin(math.pi * progress));
    final double height = width / aspect;
    final double corner = math.min(12, width * 0.08);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: center.dx - width / 2,
          top: center.dy - height / 2,
          width: width,
          height: height,
          child: Transform.rotate(
            angle: angle * (1 - t),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(corner),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x73000000),
                    blurRadius: 28,
                    offset: Offset(0, 8 + 8 * math.sin(math.pi * progress)),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(corner),
                child: RawImage(image: image, fit: BoxFit.fill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
