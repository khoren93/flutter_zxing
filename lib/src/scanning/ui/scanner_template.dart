import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../barcode/barcode_format.dart';
import '../../errors.dart';
import '../scan_window.dart';
import '../scanner_controller.dart';
import 'controls.dart';
import 'glass.dart';
import 'result_sheet.dart';
import 'scanner_icons.dart';
import 'scanner_strings.dart';
import 'scanner_theme.dart';
import 'states.dart';
import 'window_overlay.dart';

/// Builds the sheet shown for a scanned [barcode]; [scanAgain] hides it
/// and resumes scanning.
typedef ScannerResultBuilder =
    Widget Function(
      BuildContext context,
      Barcode barcode,
      VoidCallback scanAgain,
    );

/// Builds the buttons of the default result sheet for [barcode].
typedef ScannerActionsBuilder =
    List<ScannerAction> Function(
      BuildContext context,
      Barcode barcode,
      VoidCallback scanAgain,
    );

/// A ready-made scanner screen: which buttons it has, where the scan window
/// is, what happens when a code is found, and its default [theme].
///
/// ```dart
/// BarcodeScanner(template: ScannerTemplate.minimal())
/// BarcodeScanner(
///   template: ScannerTemplate.retail(onDone: (items) => save(items)),
///   theme: ScannerTheme(accent: Color(0xFFFF6A1A)),
/// )
/// ```
///
/// The named constructors are presets for common screens; every field can
/// be changed with [copyWith]. With one result at a time (all but
/// [ScannerTemplate.retail]) the brackets lock onto the code, scanning
/// pauses and a [BarcodeResultSheet] (or [resultBuilder]'s sheet) slides
/// up; with [collect], every code goes into a list with counts.
///
/// [scanWindow], [formats] and the detection the template needs apply to
/// the controller `BarcodeScanner` creates. A controller you pass keeps its
/// own settings.
@immutable
final class ScannerTemplate {
  /// Creates a template; prefer a preset and [copyWith].
  const ScannerTemplate({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(),
    this.formats,
    this.title,
    this.hint,
    this.hintIcon,
    this.closeButton = true,
    this.onClose,
    this.torchButton = true,
    this.photoButton = false,
    this.zoomButtons = false,
    this.switchCameraButton = false,
    this.collect = false,
    this.onDone,
    this.showResult = true,
    this.showResultIcon = false,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
  });

  /// The default screen: close and torch buttons, a hint under the window,
  /// a photo button, zoom presets and a camera switch; a result sheet with
  /// the parsed content.
  const ScannerTemplate.minimal({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(alignment: Alignment(0, -0.1)),
    this.formats,
    this.title,
    this.hint = 'Point the camera at a code',
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.torchButton = true,
    this.photoButton = true,
    this.zoomButtons = true,
    this.switchCameraButton = true,
    this.showResult = true,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
  }) : collect = false,
       onDone = null,
       showResultIcon = false;

  /// Paying with a QR code: a title pill, the window high up and a sheet
  /// for the payment below it. Build the sheet with [resultBuilder].
  const ScannerTemplate.payment({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.6,
      alignment: Alignment(0, -0.5),
    ),
    this.formats = const <BarcodeFormat>{BarcodeFormat.qrCode},
    this.title = 'Pay with QR',
    this.hint,
    this.hintIcon,
    this.closeButton = true,
    this.onClose,
    this.torchButton = false,
    this.photoButton = false,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
  }) : zoomButtons = false,
       switchCameraButton = false,
       collect = false,
       onDone = null,
       showResult = true,
       showResultIcon = false;

  /// Retail and warehouse: dark glass, a wide window for product and
  /// shipping barcodes, the torch, and a list of everything scanned with
  /// counts; [onDone] receives the list.
  const ScannerTemplate.retail({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.88,
      aspectRatio: 3,
      alignment: Alignment(0, -0.6),
    ),
    this.formats = const <BarcodeFormat>{
      ...BarcodeFormat.retail,
      ...BarcodeFormat.industrial,
    },
    this.title,
    this.closeButton = true,
    this.onClose,
    this.torchButton = true,
    this.onDone,
    this.haptics = true,
  }) : hint = null,
       hintIcon = null,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       collect = true,
       showResult = true,
       showResultIcon = false,
       resultBuilder = null,
       actionsBuilder = null;

  /// Tickets and documents: a wide window for boarding passes, tickets and
  /// IDs (PDF417, Aztec, QR, Data Matrix), a title pill and a sheet for the
  /// fields. Build the sheet with [resultBuilder].
  const ScannerTemplate.ticket({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.87,
      aspectRatio: 2.2,
      alignment: Alignment(0, -0.35),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    },
    this.title = 'Scan your ticket',
    this.closeButton = true,
    this.onClose,
    this.torchButton = true,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
  }) : hint = null,
       hintIcon = null,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       collect = false,
       onDone = null,
       showResult = true,
       showResultIcon = false;

  /// Everyday QR codes: links, Wi‑Fi networks, contacts, events. Dark
  /// glass and a sheet with an icon of the content's kind; add buttons such
  /// as "Open" or "Connect" with [actionsBuilder].
  const ScannerTemplate.content({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.62,
      alignment: Alignment(0, -0.62),
    ),
    this.formats = const <BarcodeFormat>{BarcodeFormat.qrCode},
    this.title,
    this.hint = 'Point at a QR code',
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.torchButton = true,
    this.photoButton = true,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
  }) : zoomButtons = false,
       switchCameraButton = false,
       collect = false,
       onDone = null,
       showResult = true,
       showResultIcon = true;

  /// The template's theme; `BarcodeScanner.theme` is merged on top.
  final ScannerTheme theme;

  /// The scan window of the scanner's own controller.
  final ScanWindow scanWindow;

  /// Formats of the scanner's own controller; `null` reads all.
  final Set<BarcodeFormat>? formats;

  /// A title pill at the top, e.g. "Pay with QR".
  final String? title;

  /// A hint under the window while searching.
  final String? hint;

  /// An icon before [hint].
  final ScannerIconData? hintIcon;

  /// A close button at the top left, shown when [onClose] is set or the
  /// scanner's route can be popped.
  final bool closeButton;

  /// Called by the close button; default `Navigator.maybePop`.
  final VoidCallback? onClose;

  /// A torch button at the top right, when the camera has a torch.
  final bool torchButton;

  /// A button that reads a code from a photo, at the bottom left.
  final bool photoButton;

  /// Zoom presets at the bottom.
  final bool zoomButtons;

  /// A camera switch at the bottom right.
  final bool switchCameraButton;

  /// Collect every code in a [BarcodeListSheet] instead of showing one
  /// result at a time.
  final bool collect;

  /// Called by the list's "Done" button with the collected codes.
  final ValueChanged<List<CollectedBarcode>>? onDone;

  /// With one result at a time: pause and show a result sheet. Without it,
  /// the brackets lock onto the code and the app handles `onDetect`.
  final bool showResult;

  /// An icon of the content's kind on the default result sheet.
  final bool showResultIcon;

  /// Builds the result sheet; default [BarcodeResultSheet].
  final ScannerResultBuilder? resultBuilder;

  /// The buttons of the default result sheet; default copy and "Scan
  /// again".
  final ScannerActionsBuilder? actionsBuilder;

  /// A haptic tap when a code is found.
  final bool haptics;

  /// How the scanner's own controller reports codes for this template.
  DetectionMode get detection =>
      collect ? DetectionMode.distinct : DetectionMode.once;

  /// How many codes the scanner's own controller looks for in a frame.
  int? get maxBarcodes => collect ? null : 1;

  /// A copy with the given fields replaced.
  ScannerTemplate copyWith({
    ScannerTheme? theme,
    ScanWindow? scanWindow,
    Set<BarcodeFormat>? formats,
    String? title,
    String? hint,
    ScannerIconData? hintIcon,
    bool? closeButton,
    VoidCallback? onClose,
    bool? torchButton,
    bool? photoButton,
    bool? zoomButtons,
    bool? switchCameraButton,
    bool? collect,
    ValueChanged<List<CollectedBarcode>>? onDone,
    bool? showResult,
    bool? showResultIcon,
    ScannerResultBuilder? resultBuilder,
    ScannerActionsBuilder? actionsBuilder,
    bool? haptics,
  }) => ScannerTemplate(
    theme: theme ?? this.theme,
    scanWindow: scanWindow ?? this.scanWindow,
    formats: formats ?? this.formats,
    title: title ?? this.title,
    hint: hint ?? this.hint,
    hintIcon: hintIcon ?? this.hintIcon,
    closeButton: closeButton ?? this.closeButton,
    onClose: onClose ?? this.onClose,
    torchButton: torchButton ?? this.torchButton,
    photoButton: photoButton ?? this.photoButton,
    zoomButtons: zoomButtons ?? this.zoomButtons,
    switchCameraButton: switchCameraButton ?? this.switchCameraButton,
    collect: collect ?? this.collect,
    onDone: onDone ?? this.onDone,
    showResult: showResult ?? this.showResult,
    showResultIcon: showResultIcon ?? this.showResultIcon,
    resultBuilder: resultBuilder ?? this.resultBuilder,
    actionsBuilder: actionsBuilder ?? this.actionsBuilder,
    haptics: haptics ?? this.haptics,
  );
}

/// The overlay of a [ScannerTemplate], in every state of the camera: also
/// while it starts or after an error, so that the close button, the photo
/// button and a result read from a photo stay available. Keeps the current
/// result and the collected codes.
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

  /// Counts locks, so that a cut-out arriving after "Scan again" is dropped.
  int _lock = 0;
  ScannerController? _controller;
  Barcode? _result;
  Timer? _showResult;
  final List<CollectedBarcode> _items = <CollectedBarcode>[];
  String? _notice;
  Timer? _hideNotice;

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
  }

  @override
  void dispose() {
    unawaited(_captures?.cancel());
    _showResult?.cancel();
    _hideNotice?.cancel();
    _flight.dispose();
    _cutOut?.dispose();
    super.dispose();
  }

  void _listen() {
    final ScannerController controller = widget.layout.controller;
    if (controller == _controller) {
      return;
    }
    unawaited(_captures?.cancel());
    _controller = controller;
    _captures = controller.barcodes.listen(_onCapture);
  }

  void _onCapture(BarcodeCapture capture) {
    if (_template.collect) {
      if (_template.haptics) {
        unawaited(HapticFeedback.selectionClick());
      }
      setState(() {
        for (final Barcode barcode in capture.barcodes) {
          final int index = _items.indexWhere(
            (CollectedBarcode item) =>
                item.barcode.format == barcode.format &&
                item.barcode.text == barcode.text,
          );
          final int count = index < 0 ? 1 : _items[index].count + 1;
          if (index >= 0) {
            _items.removeAt(index);
          }
          _items.insert(0, CollectedBarcode(barcode, count));
        }
      });
      return;
    }
    if (_result != null || _showResult != null || _settled) {
      return;
    }
    if (_template.haptics) {
      unawaited(HapticFeedback.mediumImpact());
    }
    unawaited(_takeIn(capture, ++_lock));
    if (!_template.showResult) {
      return;
    }
    unawaited(widget.layout.controller.pause());
    // Let the code settle in the window before the sheet rises.
    final Duration delay = capture.source == CaptureSource.image
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 380);
    _showResult = Timer(delay, () {
      _showResult = null;
      if (mounted) {
        setState(() => _result = capture.barcode);
      }
    });
  }

  /// Cuts the code of [capture] out of its frame and flies it from where
  /// it shows into the scan window. Nothing flies where there is no
  /// cut-out (the web, for now).
  Future<void> _takeIn(BarcodeCapture capture, int lock) async {
    final ui.Image? image = await capture.snapshot();
    // The layout shows the code from the frame after the capture.
    await WidgetsBinding.instance.endOfFrame;
    if (image == null || !mounted || lock != _lock) {
      image?.dispose();
      return;
    }
    final Barcode barcode = capture.barcode;
    List<Offset>? from;
    if (capture.source == CaptureSource.camera) {
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
    _lock++;
    setState(() {
      _result = null;
      _settled = false;
    });
    unawaited(widget.layout.controller.resume());
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
      _hideNotice?.cancel();
      setState(() => _notice = ScannerStrings.of(context).noCodeInPhoto);
      _hideNotice = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _notice = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScannerTemplate template = _template;
    final ScannerLayout layout = widget.layout;
    final ScannerController controller = layout.controller;
    final ScannerStatus status = layout.state.status;
    final bool camera =
        status == ScannerStatus.running || status == ScannerStatus.paused;
    final EdgeInsets safe = MediaQuery.viewPaddingOf(context);
    final Size size = layout.size;
    final bool landscape = size.width > size.height;
    final Widget? sheet = _sheet(context);
    final bool searching = camera && _result == null && layout.barcodes.isEmpty;
    final bool showClose =
        template.closeButton &&
        (template.onClose != null || (ModalRoute.of(context)?.canPop ?? false));
    const Duration fade = Duration(milliseconds: 200);
    final String? hint = _notice ?? template.hint;

    final ScannerException? error = layout.state.error;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (camera)
          ScannerOverlay(
            layout,
            lockOn: !template.collect,
            settled: _settled && _cutOut != null,
          )
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
        // The hint under the window.
        if (camera && hint != null && !template.collect)
          Positioned(
            left: 16,
            right: 16,
            top: math.min(layout.scanWindow.bottom + 16, size.height - 64),
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: searching || _notice != null ? 1 : 0,
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
                if (template.title case final String title)
                  Align(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 60),
                      child: ScannerHint(title),
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
        // The bottom bar, hidden under a sheet.
        if (camera &&
            (template.photoButton ||
                template.zoomButtons ||
                template.switchCameraButton) &&
            !template.collect)
          Positioned(
            left: safe.left + 40,
            right: safe.right + 40,
            bottom: math.max(safe.bottom, 12) + 24,
            child: IgnorePointer(
              ignoring: sheet != null,
              child: AnimatedOpacity(
                opacity: sheet == null ? 1 : 0,
                duration: fade,
                child: SizedBox(
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
          left: landscape ? null : safe.left + 12,
          right: safe.right + 12,
          // Below the top bar: a tall sheet scrolls instead of covering
          // the close and torch buttons.
          top: safe.top + 72,
          bottom: math.max(safe.bottom, 12),
          width: landscape ? math.min(420, size.width * 0.46) : null,
          child: Align(
            alignment: landscape
                ? Alignment.bottomRight
                : Alignment.bottomCenter,
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
                        key: ValueKey<Object?>(_result ?? template.collect),
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

  Widget? _sheet(BuildContext context) {
    final ScannerTemplate template = _template;
    if (template.collect) {
      final ValueChanged<List<CollectedBarcode>>? onDone = template.onDone;
      return BarcodeListSheet(
        items: _items,
        onDone: onDone == null
            ? null
            : () => onDone(List<CollectedBarcode>.unmodifiable(_items)),
      );
    }
    final Barcode? result = _result;
    if (result == null) {
      return null;
    }
    return template.resultBuilder?.call(context, result, _scanAgain) ??
        BarcodeResultSheet(
          result,
          actions: template.actionsBuilder?.call(context, result, _scanAgain),
          onScanAgain: _scanAgain,
          showIcon: template.showResultIcon,
        );
  }
}

/// The cut-out of the code found on its way from where the code shows into
/// the scan window, and the dark plate that covers the camera there.
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
        // The camera in the window fades under a plate; the brackets'
        // inner half stays clear of it.
        Positioned.fromRect(
          rect: window.deflate(3),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF06090D).withValues(alpha: 0.62 * t),
              borderRadius: BorderRadius.circular(math.max(0, radius - 3)),
            ),
          ),
        ),
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
