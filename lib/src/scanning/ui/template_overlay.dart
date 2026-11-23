import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../content/barcode_content.dart';
import '../../errors.dart';
import '../l10n/scanner_localizations.dart';
import '../l10n/scanner_localizations_lookup.dart';
import '../scanner_controller.dart';
import '../snapshot.dart';
import 'barcode_label.dart';
import 'controls.dart';
import 'glass.dart';
import 'pressable.dart';
import 'result_sheet.dart';
import 'scan_verdict.dart';
import 'scanner_icons.dart';
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
    this.onOpenSettings,
  });

  /// The template.
  final ScannerTemplate template;

  /// The scanner layout.
  final ScannerLayout layout;

  /// Draws [ScannerPlaceholder] while the camera starts.
  final bool drawPlaceholder;

  /// Draws [ScannerErrorView] when the camera failed.
  final bool drawError;

  /// Opens the app's settings from the error view.
  final VoidCallback? onOpenSettings;

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

/// How long the scanner reads on after a code pictured by its cut-out, for
/// a sharper frame of it: until shortly before the result sheet rises.
const Duration _lookFor = Duration(milliseconds: 300);

/// How much sharper ([sharpness]) a later frame's cut-out must be to
/// replace the one shown: not for noise.
const double _sharperBy = 1.15;

/// The cross-fade to a sharper or exact picture of the code in the window.
const Duration _pictureFade = Duration(milliseconds: 150);

class _TemplateOverlayState extends State<TemplateOverlay>
    with TickerProviderStateMixin {
  StreamSubscription<BarcodeCapture>? _captures;

  /// The code found, cut out of the frame, flying into the window.
  late final AnimationController _flight;
  ui.Image? _cutOut;
  List<Offset>? _cutFrom;
  bool _cutLinear = false;
  bool _settled = false;

  /// The width over the height of the card the code flies in on: its first
  /// cut-out's, kept when a sharper one replaces it.
  double _cutAspect = 1;

  /// How sharp [_cutOut] is ([sharpness]).
  double _cutSharpness = 0;

  /// The cut-out [_cutOut] replaced, under it while it fades in ([_swap]).
  ui.Image? _cutBefore;
  late final AnimationController _swap;

  /// The code found, drawn exactly over its cut-out once it landed
  /// ([_exact]); `null` where it is not ([ScannerWindowPicture]).
  Barcode? _exactOf;
  late final AnimationController _exact;

  /// The first cut-out of the code found is in the window (or there is
  /// none): later frames of it are compared with it.
  Future<void> _taken = Future<void>.value();

  /// A frame of the code found, read after it, waiting to be compared, and
  /// the lock it belongs to.
  (BarcodeCapture, int)? _nextLook;
  bool _looking = false;

  /// The cut-out shown in the result sheet: a handle of its own, as the
  /// window's fades away with "Scan again" while the sheet is still leaving.
  ui.Image? _resultCutOut;

  /// Counts locks, so that a cut-out arriving after "Scan again" is dropped.
  int _lock = 0;
  ScannerController? _controller;
  Barcode? _result;

  /// The capture [_result] came from.
  BarcodeCapture? _resultCapture;

  /// What the check said about [_result]; `null` without a check.
  ScanVerdict? _resultVerdict;
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

  /// Counts verdicts: each one is a sheet of its own, also when it equals
  /// the one before, so that its timer starts anew and screen readers
  /// announce it.
  int _verdicts = 0;

  /// Accepted codes, for the counter.
  int _accepted = 0;

  /// The window flashes in a verdict's color.
  ScanVerdictKind? _flash;
  Timer? _flashEnd;

  /// The latest capture of each code in view, for [ScannerMode.pick]: a
  /// picked code flies from its own frame.
  final Map<String, BarcodeCapture> _pickable = <String, BarcodeCapture>{};

  /// [ScannerMode.pick]: the number on the label of each code in view, by
  /// [VisibleBarcode.id], kept while the code stays in view.
  final Map<int, int> _numbers = <int, int>{};

  /// [ScannerMode.pick]: the codes whose label is below them.
  final Set<int> _labelsBelow = <int>{};

  /// [ScannerMode.pick]: the photo or the frozen camera frame whose codes
  /// are shown to pick from.
  _PickPhoto? _photo;

  /// [ScannerMode.pick]: the camera frame is being frozen.
  bool _freezing = false;

  /// Counts photos, so that one still decoding after "Scan again" is
  /// dropped.
  int _photoLoad = 0;

  /// Scans again after [ScannerTemplate.resumeAfter], or closes the screen.
  Timer? _after;

  /// Counts the results left, so that a check still running for one is
  /// dropped.
  int _run = 0;

  /// Without a sheet: a code was taken and the scanner waits paused for
  /// the app to resume it.
  bool _holding = false;

  /// A code is being judged or shown: the next one waits.
  bool get _busy =>
      _holding ||
      _result != null ||
      _showResult != null ||
      _after != null ||
      _settled ||
      _checking;

  ScannerTemplate get _template => widget.template;

  @override
  void initState() {
    super.initState();
    // Here, not on first use: a ticker cannot be made in dispose.
    _flight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _swap = AnimationController(vsync: this, duration: _pictureFade, value: 1);
    _exact = AnimationController(vsync: this, duration: _pictureFade);
    _listen();
  }

  @override
  void didUpdateWidget(TemplateOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
    if (_template.mode != ScannerMode.pick) {
      if (_photo != null) {
        // The camera waits under a photo: the new template scans on.
        _clearResult();
        final ScannerController controller = widget.layout.controller;
        unawaited(Future<void>.microtask(controller.resume));
      }
      _dropPhoto();
    }
  }

  @override
  void dispose() {
    unawaited(_captures?.cancel());
    _controller?.removeListener(_onState);
    _showResult?.cancel();
    _hideNotice?.cancel();
    _hideVerdict?.cancel();
    _flashEnd?.cancel();
    _after?.cancel();
    _controller?.endGlimpse();
    _flight.dispose();
    _swap.dispose();
    _exact.dispose();
    _cutOut?.dispose();
    _cutBefore?.dispose();
    _resultCutOut?.dispose();
    _photo?.image.dispose();
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
    _controller?.removeListener(_onState);
    _controller?.endGlimpse();
    _controller = controller;
    _captures = controller.barcodes.listen(_onCapture);
    controller.addListener(_onState);
  }

  /// Without a sheet the app resumes the scanner: the next code starts
  /// anew, also when the code taken is still flying in.
  void _onState() {
    if (_holding &&
        mounted &&
        _controller?.value.status == ScannerStatus.running) {
      setState(_clearResult);
    }
  }

  void _onCapture(BarcodeCapture capture) {
    switch (_template.mode) {
      case ScannerMode.collect:
        _collectLater(capture);
      case ScannerMode.pick:
        if (capture.source == CaptureSource.image) {
          unawaited(_openPhoto(capture));
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

  /// [ScannerMode.collect]: the captures wait for the check of the one
  /// before them, so that none is skipped.
  Future<void> _collecting = Future<void>.value();

  void _collectLater(BarcodeCapture capture) {
    _collecting = _collecting.then((_) => _collect(capture));
  }

  Future<void> _collect(BarcodeCapture capture) async {
    if (!mounted) {
      return;
    }
    List<Barcode> taken = capture.barcodes;
    final Map<Barcode, ScanVerdict> verdicts = <Barcode, ScanVerdict>{};
    bool told = false;
    if (_template.check != null) {
      taken = <Barcode>[];
      ScanVerdict? flagged;
      ScanVerdict? refused;
      for (final Barcode barcode in capture.barcodes) {
        final ScanVerdict? verdict = await _judge(barcode);
        if (!mounted) {
          return;
        }
        switch (verdict?.kind) {
          case null:
            break;
          case ScanVerdictKind.reject:
            refused = verdict;
          case ScanVerdictKind.warn:
            flagged = verdict;
            taken.add(barcode);
            verdicts[barcode] = verdict!;
          case ScanVerdictKind.accept:
            taken.add(barcode);
            verdicts[barcode] = verdict!;
        }
      }
      // A refused code is told first: it is not in the list.
      if (refused ?? flagged case final ScanVerdict verdict) {
        final ScannerLocalizations texts = ScannerLocalizations.of(context);
        told = true;
        _feedback(_feedbackOf(verdict.kind));
        _flashFor(verdict.kind);
        _showNotice(
          <String>[
            verdict.title ??
                (verdict.kind == ScanVerdictKind.reject
                    ? texts.rejected
                    : texts.needsAttention),
            ?verdict.message,
          ].join(' · '),
        );
      }
      if (taken.isEmpty) {
        return;
      }
    }
    if (!told) {
      _feedback(
        _template.check == null ? ScanFeedback.found : ScanFeedback.accepted,
        listed: true,
      );
    }
    setState(() {
      for (final Barcode barcode in taken) {
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
            verdict: verdicts[barcode] ?? before?.verdict,
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
    if (_busy) {
      return;
    }
    final ScannerController controller = widget.layout.controller;
    // Without a sheet the app resumes the scanner. It pauses now, before
    // the check, so that a resume of the app while the check runs counts;
    // with DetectionMode.once it paused by itself.
    final bool hold = !_template.showResult && !_template.closeOnResult;
    final bool pausedHere =
        hold &&
        controller.detection != DetectionMode.once &&
        controller.value.status == ScannerStatus.running;
    if (pausedHere) {
      unawaited(controller.pause());
    }
    ScanVerdict? warning;
    ScanVerdict? taken;
    if (_template.check != null) {
      final int run = _run;
      final ScanVerdict? verdict = await _judge(barcode);
      if (!mounted || run != _run) {
        return;
      }
      if (verdict == null) {
        _scanOn(capture, pausedHere: pausedHere);
        return;
      }
      if (verdict.kind == ScanVerdictKind.reject) {
        _feedback(ScanFeedback.rejected);
        _flashFor(ScanVerdictKind.reject);
        _showNotice(
          <String>[
            verdict.title ?? ScannerLocalizations.of(context).rejected,
            ?verdict.message,
          ].join(' · '),
        );
        _scanOn(capture, pausedHere: pausedHere);
        return;
      }
      if (_settled || _result != null) {
        return;
      }
      taken = verdict;
      if (verdict.kind == ScanVerdictKind.warn) {
        warning = verdict;
      }
    }
    if (_template.mode == ScannerMode.pick) {
      _template.onPick?.call(barcode, capture);
    }
    if (warning != null) {
      // Taken, with the verdict's text in the warning color.
      _feedback(ScanFeedback.warned);
      _flashFor(ScanVerdictKind.warn);
      _showNotice(
        <String>[
          warning.title ?? ScannerLocalizations.of(context).needsAttention,
          ?warning.message,
        ].join(' · '),
      );
    } else {
      _feedback(_feedbackOf(ScanVerdictKind.accept));
    }
    if (hold) {
      // The app resumed the scanner already: nothing to hold.
      if (controller.value.status != ScannerStatus.paused) {
        return;
      }
      _holding = true;
    }
    final int lock = ++_lock;
    unawaited(_taken = _takeIn(capture, barcode, lock, from: from));
    if (_template.closeOnResult) {
      unawaited(controller.pause());
      _lookForSharper(capture, barcode, lock);
      // Let the code fly into the window before the screen closes.
      _after = Timer(
        const Duration(milliseconds: 450),
        () => _closeWith(barcode),
      );
      return;
    }
    if (hold) {
      _lookForSharper(capture, barcode, lock);
      return;
    }
    unawaited(controller.pause());
    _lookForSharper(capture, barcode, lock);
    // Let the code settle in the window before the sheet rises.
    final Duration delay = capture.source == CaptureSource.image
        ? const Duration(milliseconds: 200)
        : const Duration(milliseconds: 380);
    _showResult = Timer(delay, () {
      _showResult = null;
      controller.endGlimpse();
      if (mounted) {
        setState(() {
          _result = barcode;
          _resultCapture = capture;
          _resultVerdict = taken;
        });
        if (_template.resumeAfter case final Duration after) {
          _after = Timer(after, _scanAgain);
        }
      }
    });
  }

  /// A code was not taken: a photo or a paused camera scans on.
  void _scanOn(BarcodeCapture capture, {bool pausedHere = false}) {
    if (_photo == null &&
        (pausedHere ||
            capture.source == CaptureSource.image ||
            widget.layout.controller.detection == DetectionMode.once)) {
      unawaited(widget.layout.controller.resume());
    }
  }

  /// `ScannerResult.finish`: the screen closes with [value].
  void _finish([Object? value]) {
    _after?.cancel();
    _closeWith(value);
  }

  /// Closes the screen with [value], once no other route lies over it.
  /// Where the screen does not close, such as the app's first screen or
  /// one that refuses to be popped, scanning goes on.
  void _closeWith(Object? value) {
    _after = null;
    if (!mounted) {
      return;
    }
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (route == null || route.isCurrent) {
      final NavigatorState? navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        _scanAgain();
        return;
      }
      unawaited(
        navigator.maybePop(value).then((bool _) {
          if (mounted && (route?.isCurrent ?? true)) {
            _scanAgain();
          }
        }),
      );
    } else if (route.isActive) {
      _after = Timer(
        const Duration(milliseconds: 200),
        () => _closeWith(value),
      );
    }
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
    _feedback(_feedbackOf(verdict.kind));
    _hideVerdict?.cancel();
    final Duration shown = _template.resumeAfter ?? const Duration(seconds: 2);
    setState(() {
      _verdict = verdict;
      _verdictOf = barcode;
      _verdicts++;
      _flash = verdict.kind;
      if (verdict.kind == ScanVerdictKind.accept) {
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

  /// A check's verdict as feedback; an accepted code without a check was
  /// only found.
  ScanFeedback _feedbackOf(ScanVerdictKind kind) => switch (kind) {
    ScanVerdictKind.accept when _template.check == null => ScanFeedback.found,
    ScanVerdictKind.accept => ScanFeedback.accepted,
    ScanVerdictKind.warn => ScanFeedback.warned,
    ScanVerdictKind.reject => ScanFeedback.rejected,
  };

  /// The template's own feedback, or the built-in haptic and sound; a code
  /// [listed] in a collection gets a lighter haptic.
  void _feedback(ScanFeedback kind, {bool listed = false}) {
    final ValueChanged<ScanFeedback>? own = _template.onFeedback;
    if (own != null) {
      own(kind);
      return;
    }
    final bool good =
        kind == ScanFeedback.found || kind == ScanFeedback.accepted;
    if (_template.haptics) {
      unawaited(switch (kind) {
        _ when good && listed => HapticFeedback.selectionClick(),
        ScanFeedback.found ||
        ScanFeedback.accepted => HapticFeedback.mediumImpact(),
        ScanFeedback.warned => HapticFeedback.heavyImpact(),
        ScanFeedback.rejected => HapticFeedback.vibrate(),
      });
    }
    if (_template.sound) {
      unawaited(
        SystemSound.play(good ? SystemSoundType.click : SystemSoundType.alert),
      );
    }
  }

  /// The window flashes in [kind]'s color for a moment.
  void _flashFor(ScanVerdictKind kind) {
    _flashEnd?.cancel();
    setState(() => _flash = kind);
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
    final ui.Image? image = (await _pictureOf(capture, barcode))?.$1;
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
      _items[index] = CollectedBarcode(
        item.barcode,
        item.count,
        cutOut: image,
        verdict: item.verdict,
      );
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
    final (ui.Image, double)? picture = await _pictureOf(capture, barcode);
    // The layout shows the code from the frame after the capture.
    await WidgetsBinding.instance.endOfFrame;
    if (picture == null || !mounted || lock != _lock) {
      picture?.$1.dispose();
      return;
    }
    final (ui.Image image, double score) = picture;
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
      _cutAspect = image.width / image.height;
      _cutSharpness = score;
      _cutBefore?.dispose();
      _cutBefore = null;
      _swap.value = 1;
      _exactOf =
          ScannerTheme.of(context).resolvedWindowPicture ==
                  ScannerWindowPicture.exact &&
              !BarcodeThumbnail.needsCutOut(barcode)
          ? barcode
          : null;
      _exact.value = 0;
      _settled = true;
    });
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _flight.value = 1;
      _exact.value = 1;
    } else {
      // Landed, the cut-out turns into the code drawn exactly.
      unawaited(
        _flight.forward(from: 0).then((_) {
          if (mounted && lock == _lock && _exactOf != null) {
            unawaited(_exact.forward(from: 0));
          }
        }),
      );
    }
  }

  /// [barcode] cut out of the frame of [capture], lightly sharpened, and
  /// how sharp it was before ([sharpness]).
  Future<(ui.Image, double)?> _pictureOf(
    BarcodeCapture capture,
    Barcode? barcode,
  ) async {
    final GrayImage? gray = await capture.straightened(barcode);
    if (gray == null) {
      return null;
    }
    return (await unsharpMask(gray).toImage(), sharpness(gray));
  }

  /// A code pictured by its cut-out, read from a camera frame that may be
  /// blurred by the motion that brought it into view: the scanner, paused,
  /// reads on for a moment ([_lookFor]), and a sharper cut-out from a later
  /// frame replaces the one in the window and the sheet. The result, its
  /// feedback and `onDetect` do not wait for it.
  void _lookForSharper(BarcodeCapture capture, Barcode barcode, int lock) {
    final ScannerController controller = widget.layout.controller;
    final bool shown =
        ScannerTheme.of(context).resolvedWindowPicture !=
            ScannerWindowPicture.none ||
        (_template.showResult && !_template.closeOnResult);
    if (!shown ||
        _template.mode != ScannerMode.single ||
        capture.source != CaptureSource.camera ||
        !BarcodeThumbnail.needsCutOut(barcode) ||
        controller.value.status != ScannerStatus.paused) {
      return;
    }
    controller.glimpse(barcode, _lookFor, (BarcodeCapture frame) {
      if (!mounted || lock != _lock) {
        return;
      }
      // Only the latest frame waits: the one before is skipped.
      _nextLook = (frame, lock);
      if (!_looking) {
        unawaited(_lookAtFrames());
      }
    });
  }

  /// Compares the frames read after the code with its cut-out shown, one
  /// at a time, and fades in a sharper one.
  Future<void> _lookAtFrames() async {
    _looking = true;
    try {
      while (mounted) {
        final (BarcodeCapture, int)? next = _nextLook;
        if (next == null) {
          return;
        }
        _nextLook = null;
        final (BarcodeCapture frame, int lock) = next;
        await _taken;
        if (!mounted || lock != _lock || _cutOut == null) {
          continue;
        }
        final (GrayImage, double)? picture = await frame.sharpenedApart();
        if (picture == null) {
          continue;
        }
        final (GrayImage sharpened, double score) = picture;
        if (score <= _cutSharpness * _sharperBy) {
          continue;
        }
        final ui.Image image = await sharpened.toImage();
        if (!mounted || lock != _lock || _cutOut == null) {
          image.dispose();
          continue;
        }
        _swapIn(image, score);
      }
    } finally {
      _looking = false;
    }
  }

  /// Fades [image], sharper ([score]), in over the cut-out in the window;
  /// in the result sheet too while it has not risen yet.
  void _swapIn(ui.Image image, double score) {
    final ui.Image? before = _cutOut;
    setState(() {
      _cutBefore?.dispose();
      _cutBefore = before;
      _cutOut = image;
      _cutSharpness = score;
      if (_result == null) {
        _resultCutOut?.dispose();
        _resultCutOut = image.clone();
      }
    });
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _dropCutBefore(before);
      _swap.value = 1;
      return;
    }
    unawaited(
      _swap.forward(from: 0).then((_) {
        if (mounted) {
          _dropCutBefore(before);
        }
      }),
    );
  }

  /// Lets go of the cut-out [before], once the one after it is in.
  void _dropCutBefore(ui.Image? before) {
    if (before != null && _cutBefore == before) {
      setState(() {
        before.dispose();
        _cutBefore = null;
      });
    }
  }

  /// Forgets the code found.
  void _clearResult() {
    _showResult?.cancel();
    _showResult = null;
    _controller?.endGlimpse();
    _nextLook = null;
    _after?.cancel();
    _after = null;
    _lock++;
    _run++;
    _result = null;
    _resultCapture = null;
    _resultVerdict = null;
    _settled = false;
    _holding = false;
  }

  /// Hides the result of the code found.
  void _hideResult() => setState(_clearResult);

  void _scanAgain() {
    _hideResult();
    setState(_dropPhoto);
    unawaited(widget.layout.controller.resume());
  }

  /// [ScannerMode.pick]: from a result back to the codes to pick from: the
  /// ones on the photo, or the ones in view of the camera.
  void _backToCodes() {
    _hideResult();
    if (_photo == null) {
      unawaited(widget.layout.controller.resume());
    }
  }

  /// [ScannerMode.pick]: [codes] by the number on their label. A code
  /// keeps its number and the side of its label while it stays in view, so
  /// that labels neither swap numbers nor jump as the camera moves.
  /// A label goes no higher than [minTop], clear of the top bar.
  List<VisibleBarcode> _labeled(
    List<VisibleBarcode> codes,
    Size size,
    double minTop,
  ) {
    final Set<int> ids = <int>{for (final VisibleBarcode c in codes) c.id};
    _numbers.removeWhere((int id, int _) => !ids.contains(id));
    _labelsBelow.removeWhere((int id) => !ids.contains(id));
    for (final VisibleBarcode code in codes) {
      if (!_numbers.containsKey(code.id)) {
        // The smallest number free.
        final Set<int> used = _numbers.values.toSet();
        int number = 1;
        while (used.contains(number)) {
          number++;
        }
        _numbers[code.id] = number;
      }
      final Rect bounds = code.bounds;
      const double room = _PickLabel.height + _PickLabel.gap;
      final bool fitsAbove = bounds.top - room >= minTop;
      final bool fitsBelow = bounds.bottom + room <= size.height - 8;
      if (!_labelsBelow.contains(code.id)) {
        if (!fitsAbove && fitsBelow) {
          _labelsBelow.add(code.id);
        }
      } else if (!fitsBelow ||
          // Back above only well clear of the top, not to and fro.
          bounds.top - room >= minTop + 32) {
        _labelsBelow.remove(code.id);
      }
    }
    return codes.toList()..sort(
      (VisibleBarcode a, VisibleBarcode b) =>
          _numbers[a.id]!.compareTo(_numbers[b.id]!),
    );
  }

  /// [ScannerMode.pick]: the user tapped [code] on the photo.
  void _pickOnPhoto(VisibleBarcode code) {
    final _PickPhoto? photo = _photo;
    if (photo != null) {
      final _PhotoCode picked = photo.codes[code.id];
      unawaited(_single(picked.capture, picked.barcode, from: code.corners));
    }
  }

  /// The capture [code] of the camera was reported in.
  BarcodeCapture _captureOf(VisibleBarcode code) =>
      _pickable[_keyOf(code.barcode)] ??
      BarcodeCapture(
        barcodes: <Barcode>[code.barcode],
        imageSize: widget.layout.size,
        time: DateTime.now(),
      );

  /// [code] as its capture reported it: it has moved since, and the capture
  /// finds its picture by the code it reported.
  Barcode _reportedOf(VisibleBarcode code) =>
      _captureOf(code).barcodes.firstWhere(
        (Barcode b) =>
            b.format == code.barcode.format && b.text == code.barcode.text,
        orElse: () => code.barcode,
      );

  /// [ScannerMode.pick]: the user tapped [code] in view of the camera.
  Future<void> _pick(VisibleBarcode code) async {
    if (_freezing || _busy) {
      return;
    }
    final BarcodeCapture capture = _captureOf(code);
    final Barcode barcode = _reportedOf(code);
    _freezing = true;
    await _freeze(widget.layout.barcodes);
    _freezing = false;
    if (mounted) {
      await _single(capture, barcode, from: code.corners);
    }
  }

  /// [ScannerMode.pick]: a photo was read. One code is the result; among
  /// several the user picks on the photo.
  Future<void> _openPhoto(BarcodeCapture capture) async {
    if (capture.barcodes.length < 2) {
      await _single(capture, capture.barcode);
      return;
    }
    if (_busy) {
      return;
    }
    final int load = ++_photoLoad;
    unawaited(widget.layout.controller.pause());
    final (ui.Image, List<List<Offset>>)? photo = await capture.decodePhoto();
    if (!mounted || load != _photoLoad) {
      photo?.$1.dispose();
      return;
    }
    if (photo == null) {
      // It cannot be shown: the code the reader found first.
      await _single(capture, capture.barcode);
      return;
    }
    setState(() {
      _dropPhoto();
      _photo = _PickPhoto(photo.$1, <_PhotoCode>[
        for (final (int i, Barcode barcode) in capture.barcodes.indexed)
          _PhotoCode(barcode, capture, photo.$2[i]),
      ]);
    });
  }

  /// [ScannerMode.pick]: stops the camera on the frame with [codes], so that
  /// they stay to pick from whatever the camera sees next. Where a frame
  /// cannot be kept, the camera goes on.
  Future<void> _freeze(List<VisibleBarcode> codes) async {
    final ScannerController controller = widget.layout.controller;
    final Rect? preview = widget.layout.previewRect;
    final Size size = widget.layout.size;
    unawaited(controller.pause());
    final ui.Image? image = preview == null
        ? null
        : await controller.lastFrameImage();
    if (!mounted) {
      image?.dispose();
      return;
    }
    if (image == null || preview == null) {
      await controller.resume();
      return;
    }
    final Map<int, int> numbers = <int, int>{
      for (final (int i, VisibleBarcode code) in codes.indexed)
        if (_numbers[code.id] case final int number) i: number,
    };
    final double sx = image.width / preview.width;
    final double sy = image.height / preview.height;
    setState(() {
      _dropPhoto();
      _numbers.addAll(numbers);
      _photo = _PickPhoto(
        image,
        <_PhotoCode>[
          for (final VisibleBarcode code in codes)
            _PhotoCode(_reportedOf(code), _captureOf(code), <Offset>[
              for (final Offset c in code.corners)
                Offset((c.dx - preview.left) * sx, (c.dy - preview.top) * sy),
            ]),
        ],
        frozenIn: preview,
        frozenAt: size,
      );
    });
  }

  /// Leaves the photo; the numbers of its codes go with it.
  void _dropPhoto() {
    _photoLoad++;
    _photo?.image.dispose();
    _photo = null;
    _numbers.clear();
    _labelsBelow.clear();
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
      _showNotice(ScannerLocalizations.of(context).noCodeInPhoto);
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

  /// Where [image] shows with [fit] in the middle of [area].
  static Rect _fit(ui.Image image, Rect area, BoxFit fit) {
    final Size source = Size(image.width.toDouble(), image.height.toDouble());
    final Size shown = switch (fit) {
      // Past the area's edges, unlike the destination of applyBoxFit.
      BoxFit.cover =>
        source *
            math.max(area.width / source.width, area.height / source.height),
      _ => applyBoxFit(fit, source, area.size).destination,
    };
    return Alignment.center.inscribe(shown, area);
  }

  Color? _flashColor(ScannerTheme theme) => switch (_flash) {
    ScanVerdictKind.accept => theme.lockColor,
    ScanVerdictKind.warn => theme.warningColor,
    ScanVerdictKind.reject => theme.dangerColor,
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
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
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
            previewRect: full.previewRect,
          );
    final Widget? sheet = _sheet(context, camera);
    final bool searching =
        camera &&
        _result == null &&
        _verdict == null &&
        layout.barcodes.isEmpty;
    final _PickPhoto? photo = _photo;
    // The codes of a photo are up to pick from.
    final bool choosing =
        photo != null && !_settled && _result == null && _showResult == null;
    final bool pick =
        template.mode == ScannerMode.pick &&
        camera &&
        !_settled &&
        photo == null;
    final bool showClose =
        template.closeButton &&
        photo == null &&
        (template.onClose != null || (ModalRoute.of(context)?.canPop ?? false));
    const Duration fade = Duration(milliseconds: 200);
    // The code found shows in the window, unless the theme says nothing.
    final bool pictured =
        theme.resolvedWindowPicture != ScannerWindowPicture.none;
    final String? hint =
        _notice ?? (template.largeHint ? null : template.resolveHint(texts));
    // The torch with the controls; a list, which shows no controls, keeps
    // it at the top.
    final bool torchInControls =
        template.torchButton &&
        template.torchPosition == ScannerTorchPosition.withControls &&
        template.mode != ScannerMode.collect;
    final bool controls =
        template.photoButton ||
        template.zoomButtons ||
        template.switchCameraButton ||
        torchInControls;
    final Color? flash = _flashColor(theme);
    // The counter counts codes let in one after another: continuous only.
    final bool counter =
        template.counter && template.mode == ScannerMode.continuous;
    final String? title = template.largeHint
        ? null
        : counter
        ? texts.checkedIn(_accepted)
        : pick && layout.barcodes.isNotEmpty
        ? texts.codesInView(layout.barcodes.length)
        : choosing
        ? texts.codesInView(photo.codes.length)
        : template.resolveTitle(texts);

    final ScannerException? error = layout.state.error;
    // Where the controls go: the layout's place where it has room, else
    // the adaptive one.
    final Rect scanWindow = full.scanWindow;
    final double topRow =
        template.controlsLayout == ScannerControlsLayout.topBar
        ? _topRow(context, theme, title, safe, size, counter: counter)
        : 0;
    final _ControlsPlace place = switch (template.controlsLayout) {
      ScannerControlsLayout.sideColumn
          when !landscape &&
              size.width - safe.right - 20 - (scanWindow.right + 12) >= 48 =>
        _ControlsPlace.side,
      ScannerControlsLayout.topBar
          when noWindow || topRow + 48 + 12 <= scanWindow.top =>
        _ControlsPlace.top,
      _ => landscape ? _ControlsPlace.side : _ControlsPlace.bottom,
    };
    // The hint: under the window, or above the bottom bar without one.
    final double hintTop = noWindow
        ? size.height -
              math.max(safe.bottom, 12) -
              24 -
              40 -
              (controls && place == _ControlsPlace.bottom ? 72 : 0)
        : math.min(layout.scanWindow.bottom + 16, size.height - 64);
    // The highest a pick label goes: below the top bar, and below the
    // controls there.
    final double labelTop = place == _ControlsPlace.top
        ? math.max(safe.top + _PickLabel.topBar, topRow + 48 + 8)
        : safe.top + _PickLabel.topBar;
    // The photo, with room above it for the label of a code at its top.
    final double photoTop = safe.top + 72 + _PickLabel.height + _PickLabel.gap;
    final Rect? photoRect = switch (photo) {
      null => null,
      // A frozen frame lies exactly where the preview was.
      _PickPhoto(:final Rect frozenIn, :final Size frozenAt)
          when frozenAt == size =>
        frozenIn,
      _PickPhoto(frozen: true, :final ui.Image image) => _fit(
        image,
        Offset.zero & size,
        BoxFit.cover,
      ),
      _PickPhoto(:final ui.Image image) => _fit(
        image,
        Rect.fromLTRB(
          safe.left + 8,
          photoTop,
          size.width - safe.right - 8,
          math.max(photoTop + 1, hintTop - 8),
        ),
        BoxFit.contain,
      ),
    };
    final List<VisibleBarcode> photoCodes = choosing
        ? _labeled(
            <VisibleBarcode>[
              for (final (int i, _PhotoCode code) in photo.codes.indexed)
                VisibleBarcode(code.barcode, <Offset>[
                  for (final Offset c in code.corners)
                    photoRect!.topLeft +
                        Offset(
                          c.dx * photoRect.width / photo.image.width,
                          c.dy * photoRect.height / photo.image.height,
                        ),
                ], id: i),
            ],
            size,
            labelTop,
          )
        : const <VisibleBarcode>[];
    Widget overlay = ScannerOverlay(
      layout,
      lockOn: template.mode != ScannerMode.collect && !pick,
      settled: _settled && _cutOut != null,
      searching: _verdict == null,
    );
    if (flash != null) {
      overlay = ScannerScope(
        theme: theme.copyWith(accent: flash),
        texts: texts,
        child: overlay,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // The camera in the window fades under a dark plate as the cut-out
        // flies in: the whole window, under the brackets.
        if (camera && _cutOut != null && pictured)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _settled ? 1 : 0,
              duration: fade,
              child: AnimatedBuilder(
                animation: _flight,
                builder: (BuildContext context, Widget? _) => _WindowPlate(
                  window: layout.scanWindow,
                  shape: theme.windowBorder,
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
              onOpenSettings: widget.onOpenSettings,
              onPickImage: template.photoButton
                  ? () => unawaited(_pickPhoto())
                  : null,
            ),
        ] else if (widget.drawPlaceholder)
          ScannerPlaceholder(
            scanWindow: controller.scanWindow,
            starting: status != ScannerStatus.idle,
          ),
        // The window tinted in a verdict's color.
        if (camera && !noWindow)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: flash == null ? 0 : 1,
              duration: fade,
              child: _WindowPlate(
                window: layout.scanWindow,
                shape: theme.windowBorder,
                opacity: 1,
                color: (flash ?? theme.lockColor).withValues(alpha: 0.28),
              ),
            ),
          ),
        // A photo with several codes or the frozen frame, over the paused
        // camera.
        if (photo != null)
          _PhotoView(
            image: photo.image,
            rect: photoRect!,
            codes: photoCodes,
            color: theme.outlineColor,
            width: theme.outlineWidth ?? 2,
            radius: photo.frozen ? 0 : 12,
          ),
        if (camera && _cutOut != null && pictured)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _settled ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              onEnd: () {
                if (!_settled && mounted) {
                  setState(() {
                    _cutOut?.dispose();
                    _cutOut = null;
                    _cutBefore?.dispose();
                    _cutBefore = null;
                  });
                }
              },
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  _flight,
                  _swap,
                  _exact,
                ]),
                builder: (BuildContext context, Widget? _) => _CutOutFlight(
                  image: _cutOut!,
                  before: _cutBefore,
                  swap: _swap.value,
                  aspect: _cutAspect,
                  exact: _exactOf,
                  exactness: _exact.value,
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
          for (final VisibleBarcode code in _labeled(
            layout.barcodes,
            size,
            labelTop,
          ))
            _PickLabel(
              key: ValueKey<int>(code.id),
              number: _numbers[code.id]!,
              code: code,
              below: _labelsBelow.contains(code.id),
              minTop: labelTop,
              onPressed: () => unawaited(_pick(code)),
            ),
        // On a photo a code is picked by its label or by the code itself,
        // as labels of codes side by side may overlap.
        for (final VisibleBarcode code in photoCodes)
          Positioned.fromRect(
            rect: code.bounds,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _pickOnPhoto(code),
              ),
            ),
          ),
        for (final VisibleBarcode code in photoCodes)
          _PickLabel(
            key: ValueKey<int>(code.id),
            number: _numbers[code.id]!,
            code: code,
            below: _labelsBelow.contains(code.id),
            minTop: labelTop,
            onPressed: () => _pickOnPhoto(code),
          ),
        // The hint under the window.
        if ((camera || choosing) &&
            hint != null &&
            (template.mode != ScannerMode.collect || _notice != null))
          Positioned(
            left: 16,
            right: 16,
            top: hintTop,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: searching || _notice != null || pick || choosing
                    ? 1
                    : 0,
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
        if (!camera && !choosing && _notice != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: math.max(safe.bottom, 12) + 24,
            child: Center(child: ScannerHint(_notice!, liveRegion: true)),
          ),
        // A tap around a result scans again, or goes back to the codes.
        if (_result != null)
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: template.mode == ScannerMode.pick
                    ? _backToCodes
                    : _scanAgain,
              ),
            ),
          ),
        // A way out for staff on a screen without buttons.
        if (template.hiddenExit)
          Positioned(
            left: 0,
            top: 0,
            width: safe.left + 88,
            height: safe.top + 88,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: <Type, GestureRecognizerFactory>{
                LongPressGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<
                      LongPressGestureRecognizer
                    >(
                      () => LongPressGestureRecognizer(
                        duration: const Duration(seconds: 2),
                      ),
                      (LongPressGestureRecognizer r) => r.onLongPress = () {
                        final VoidCallback? onClose = template.onClose;
                        if (onClose != null) {
                          onClose();
                        } else {
                          unawaited(Navigator.maybePop(context));
                        }
                      },
                    ),
              },
            ),
          ),
        // The top bar.
        Positioned(
          left: safe.left + 20,
          right: safe.right + 20,
          top: safe.top + 12,
          // At least the buttons' height: a title in large text grows it.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Stack(
              alignment: Alignment.center,
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
                        icon: counter ? theme.icons.counter : null,
                        liveRegion: counter,
                      ),
                    ),
                  ),
                if (camera &&
                    template.torchButton &&
                    !torchInControls &&
                    photo == null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TorchButton(controller),
                  ),
                if (photo != null && _result == null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: ScannerButton(
                      icon: theme.icons.close,
                      label: texts.backToCamera,
                      onPressed: _scanAgain,
                    ),
                  ),
              ],
            ),
          ),
        ),
        // The controls, hidden under a sheet: a row at the bottom or under
        // the top bar, or a column at the right (in landscape, where a row
        // would run into the window and the hint).
        if (camera &&
            controls &&
            photo == null &&
            template.mode != ScannerMode.collect)
          Positioned(
            left: switch (place) {
              _ControlsPlace.side => landscape ? null : scanWindow.right + 12,
              _ => safe.left + 40,
            },
            right: switch (place) {
              _ControlsPlace.side => safe.right + 20,
              _ => safe.right + 40,
            },
            top: switch (place) {
              _ControlsPlace.side => landscape ? safe.top + 72 : scanWindow.top,
              _ControlsPlace.top => topRow,
              _ControlsPlace.bottom => null,
            },
            bottom: switch (place) {
              _ControlsPlace.side when !landscape =>
                size.height - scanWindow.bottom,
              _ControlsPlace.top => null,
              _ => math.max(safe.bottom, 12) + (landscape ? 12 : 24),
            },
            child: IgnorePointer(
              ignoring: sheet != null,
              child: AnimatedOpacity(
                opacity: sheet == null ? 1 : 0,
                duration: fade,
                child: place == _ControlsPlace.side
                    ? _controlsColumn(template, full, torchInControls)
                    : _controlsRow(template, controller, torchInControls),
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
                        key: _verdict != null
                            ? ValueKey<int>(_verdicts)
                            : ValueKey<Object?>(_result ?? template.mode),
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

  /// The top of a row of controls under the top bar, which a title in
  /// large text makes taller; below the corner of [ScannerTemplate.hiddenExit].
  double _topRow(
    BuildContext context,
    ScannerTheme theme,
    String? title,
    EdgeInsets safe,
    Size size, {
    required bool counter,
  }) {
    double bar = 48;
    if (title != null) {
      // The title pill: 60 from each side of the bar, 16 inside it, and
      // the icon of a counter.
      final TextPainter painter =
          TextPainter(
            text: TextSpan(text: title, style: theme.hintStyle),
            textAlign: TextAlign.center,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(
            maxWidth: math.max(
              0,
              size.width - safe.horizontal - 40 - 120 - 32 - (counter ? 28 : 0),
            ),
          );
      bar = math.max(bar, painter.height + 20);
      painter.dispose();
    }
    final double below = safe.top + 12 + bar + 12;
    return _template.hiddenExit ? math.max(below, safe.top + 88 + 8) : below;
  }

  /// The controls in a row: the photo button at the start, the zoom in the
  /// middle, the camera switch and the torch at the end.
  Widget _controlsRow(
    ScannerTemplate template,
    ScannerController controller,
    bool torch,
  ) {
    final List<Widget> start = <Widget>[
      if (template.photoButton)
        PickImageButton(controller, onResult: _photoRead),
    ];
    final List<Widget> end = <Widget>[
      if (template.switchCameraButton) SwitchCameraButton(controller),
      if (torch) TorchButton(controller),
    ];
    // As much room at each side, so that the zoom stays in the middle.
    final int sides = math.max(start.length, end.length);
    final double side = sides * 48 + math.max(0, sides - 1) * 8;
    Widget slot(List<Widget> buttons, MainAxisAlignment alignment) => SizedBox(
      width: side,
      height: 48,
      child: Row(mainAxisAlignment: alignment, spacing: 8, children: buttons),
    );
    // The zoom in the middle, made smaller where it would run into the
    // buttons at the sides.
    return SizedBox(
      height: 48,
      child: Row(
        spacing: 8,
        children: <Widget>[
          if (sides > 0) slot(start, MainAxisAlignment.start),
          Expanded(
            child: template.zoomButtons
                ? Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ZoomButtons(controller),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (sides > 0) slot(end, MainAxisAlignment.end),
        ],
      ),
    );
  }

  /// The controls in a column, made smaller on a screen too low for it.
  Widget _controlsColumn(
    ScannerTemplate template,
    ScannerLayout layout,
    bool torch,
  ) {
    final ScannerController controller = layout.controller;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: <Widget>[
            if (template.photoButton)
              PickImageButton(controller, onResult: _photoRead),
            if (template.zoomButtons)
              ZoomButtons(controller, direction: Axis.vertical),
            // Hidden without a second camera or a torch: no gap.
            if (template.switchCameraButton && layout.state.canSwitchCamera)
              SwitchCameraButton(controller),
            if (torch && layout.state.torch != TorchState.unavailable)
              TorchButton(controller),
          ],
        ),
      ),
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
          ? _HintPanel(
              title: template.resolveTitle(ScannerLocalizations.of(context)),
              hint:
                  _notice ??
                  template.resolveHint(ScannerLocalizations.of(context)),
            )
          : null;
    }
    final bool pick = template.mode == ScannerMode.pick;
    final ScannerResult shown = ScannerResult(
      barcode: result,
      capture: _resultCapture!,
      cutOut: _resultCutOut,
      scanAgain: _scanAgain,
      finish: _finish,
      backToCodes: pick ? _backToCodes : null,
      verdict: _resultVerdict,
      defaultActions: defaultResultActions(
        result,
        ScannerLocalizations.of(context),
        onScanAgain: _scanAgain,
        header: template.resultHeader,
      ),
    );
    return template.resultBuilder?.call(context, shown) ??
        BarcodeResultSheet(
          result,
          actions: template.actionsBuilder?.call(context, shown),
          onScanAgain: _scanAgain,
          onClose: shown.backToCodes,
          header: template.resultHeader,
          cutOut: _resultCutOut,
          verdict: _resultVerdict,
        );
  }
}

/// Where the controls of a template are.
enum _ControlsPlace { bottom, side, top }

/// A plate over the scan window: dark once a code settled in it, or
/// tinted in a verdict's [color].
class _WindowPlate extends StatelessWidget {
  const _WindowPlate({
    required this.window,
    required this.shape,
    required this.opacity,
    this.color,
  });

  final Rect window;
  final ShapeBorder shape;
  final double opacity;
  final Color? color;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      Positioned.fromRect(
        rect: window,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color:
                color ??
                const Color(0xFF06090D).withValues(alpha: 0.82 * opacity),
            shape: shape,
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
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
    final (
      Color color,
      Color on,
      ScannerIconData icon,
      String over,
    ) = switch (verdict.kind) {
      ScanVerdictKind.accept => (
        theme.lockColor,
        theme.onLockColor,
        theme.icons.accept,
        texts.accepted,
      ),
      ScanVerdictKind.warn => (
        theme.warningColor,
        theme.onWarningColor,
        theme.icons.warn,
        texts.needsAttention,
      ),
      ScanVerdictKind.reject => (
        theme.dangerColor,
        theme.onDangerColor,
        theme.icons.reject,
        texts.rejected,
      ),
    };
    final String title = verdict.title ?? barcodeLabel(barcode);
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ScannerSheet(
      padding: const EdgeInsets.all(20),
      label: <String>[over, title, ?verdict.message].join(': '),
      liveRegion: true,
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
                  child: Center(child: ScannerIcon(icon, size: 30, color: on)),
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
    return ScannerSheet(
      padding: const EdgeInsets.all(32),
      liveRegion: true,
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
    );
  }
}

/// [ScannerMode.pick]: a photo with several codes, or the camera frame
/// frozen when a code was picked.
final class _PickPhoto {
  const _PickPhoto(this.image, this.codes, {this.frozenIn, this.frozenAt});

  final ui.Image image;
  final List<_PhotoCode> codes;

  /// A frozen frame: where the preview lay in a scanner of [frozenAt].
  final Rect? frozenIn;
  final Size? frozenAt;

  bool get frozen => frozenIn != null;
}

/// A code to pick on a [_PickPhoto].
final class _PhotoCode {
  const _PhotoCode(this.barcode, this.capture, this.corners);

  final Barcode barcode;
  final BarcodeCapture capture;

  /// In pixels of the image.
  final List<Offset> corners;
}

/// [ScannerMode.pick]: the photo on a dark plate, an outline on each of
/// [codes].
class _PhotoView extends StatelessWidget {
  const _PhotoView({
    required this.image,
    required this.rect,
    required this.codes,
    required this.color,
    required this.width,
    required this.radius,
  });

  final ui.Image image;

  /// Where the photo shows.
  final Rect rect;
  final List<VisibleBarcode> codes;
  final Color color;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) => AbsorbPointer(
    child: ColoredBox(
      color: const Color(0xFF06090D),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fromRect(
            rect: rect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: RawImage(image: image, fit: BoxFit.fill),
            ),
          ),
          CustomPaint(painter: _OutlinesPainter(codes, color, width)),
        ],
      ),
    ),
  );
}

class _OutlinesPainter extends CustomPainter {
  const _OutlinesPainter(this.codes, this.color, this.width);

  final List<VisibleBarcode> codes;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round;
    for (final VisibleBarcode code in codes) {
      canvas.drawPath(Path()..addPolygon(code.corners, true), paint);
    }
  }

  @override
  bool shouldRepaint(_OutlinesPainter old) =>
      old.codes != codes || old.color != color || old.width != width;
}

/// [ScannerMode.pick]: a label above a code in view; a tap picks the code.
class _PickLabel extends StatelessWidget {
  const _PickLabel({
    super.key,
    required this.number,
    required this.code,
    required this.below,
    required this.minTop,
    required this.onPressed,
  });

  /// The label's height, its gap to the code, and the room the top bar
  /// takes below the safe area.
  static const double height = 36;
  static const double gap = 8;
  static const double topBar = 64;

  /// The highest the label goes: clear of the top bar.
  final double minTop;

  final int number;
  final VisibleBarcode code;

  /// Below the code instead of above it.
  final bool below;
  final VoidCallback onPressed;

  static String _labelOf(Barcode barcode) {
    final String text = switch (barcode.content) {
      UrlContent(:final Uri url) when url.host.isNotEmpty =>
        url.host.replaceFirst(RegExp(r'^www\.'), ''),
      WifiContent(:final String ssid) => ssid,
      ContactContent(:final String? name) when name != null => name,
      _ => barcodeLabel(barcode).trim().split('\n').first,
    };
    // By characters: an emoji is never cut in half.
    final Characters chars = text.characters;
    return chars.length > 28 ? '${chars.take(27)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
    final Barcode barcode = code.barcode;
    final Rect bounds = code.bounds;
    final String label = _labelOf(barcode);
    final double top = below
        ? bounds.bottom + gap
        : math.max(bounds.top - height - gap, minTop);
    return Positioned(
      left: 8,
      right: 8,
      top: top,
      height: height,
      child: CustomSingleChildLayout(
        delegate: _CenterOn(bounds.center.dx - 8),
        child: Semantics(
          button: true,
          label: '$number. ${texts.kindOf(barcode.content)}: $label',
          hint: texts.pickCode,
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
/// the scan window; landed, it may turn into the code drawn [exact]ly, and
/// a sharper cut-out may fade in over it.
class _CutOutFlight extends StatelessWidget {
  const _CutOutFlight({
    required this.image,
    required this.before,
    required this.swap,
    required this.aspect,
    required this.exact,
    required this.exactness,
    required this.from,
    required this.linear,
    required this.window,
    required this.progress,
  });

  final ui.Image image;

  /// The cut-out [image] replaces, under it while [swap] runs to 1.
  final ui.Image? before;
  final double swap;

  /// The card's width over its height: the first cut-out's.
  final double aspect;

  /// The code drawn exactly over the cut-out, as [exactness] runs to 1;
  /// `null` for none.
  final Barcode? exact;
  final double exactness;

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
    // Where it settles: as large as the window allows, with a margin; in a
    // round window, inside its circle.
    final Rect inner = theme.resolvedWindowShape == ScannerWindowShape.circle
        ? Rect.fromCenter(
            center: window.center,
            width: window.width / math.sqrt2,
            height: window.height / math.sqrt2,
          ).deflate(8)
        : window.deflate(math.max(16, radius * 0.8));
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
    final ui.Image? under = swap < 1 ? before : null;
    final Barcode? drawn = exact;
    // The code drawn is built from the start, unseen: a code drawn again is
    // encoded first.
    final Widget picture = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (drawn == null || exactness < 1) ...<Widget>[
          if (under != null) RawImage(image: under, fit: BoxFit.fill),
          Opacity(
            opacity: under == null ? 1 : swap,
            child: RawImage(image: image, fit: BoxFit.fill),
          ),
        ],
        if (drawn != null)
          KeyedSubtree(
            key: const ValueKey<String>('exact'),
            child: Opacity(
              opacity: exactness,
              child: ColoredBox(
                color: const Color(0xFFFFFFFF),
                child: Padding(
                  // The cut-out's margin around the code: the quiet zone
                  // it was cut with (see snapshotCorners).
                  padding: EdgeInsets.all(
                    linear ? width * 0.054 : math.min(width, height) * 0.076,
                  ),
                  child: Center(
                    child: exactBarcodePicture(drawn, showText: true),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
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
                child: picture,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
