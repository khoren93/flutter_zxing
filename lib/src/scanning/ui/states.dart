import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../errors.dart';
import '../l10n/scanner_localizations.dart';
import '../scan_window.dart';
import 'glass.dart';
import 'result_sheet.dart';
import 'scanner_theme.dart';
import 'window_overlay.dart';

/// The dark backdrop shown where the camera picture will be.
class _Void extends StatelessWidget {
  const _Void();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment(-0.2, -1),
        end: Alignment(0.2, 1),
        colors: <Color>[Color(0xFF252A31), Color(0xFF171A1F)],
      ),
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.24),
          radius: 0.8,
          colors: <Color>[Color(0x47788CA0), Color(0x00788CA0)],
        ),
      ),
      child: SizedBox.expand(),
    ),
  );
}

/// Shown where the camera picture will be: while the camera starts, the
/// scan window, its brackets breathing, a spinner and "Starting the
/// camera…", so the layout does not jump when the picture arrives. While
/// the camera is stopped ([starting] `false`), the scan window alone.
class ScannerPlaceholder extends StatefulWidget {
  /// Creates the placeholder for [scanWindow].
  const ScannerPlaceholder({
    super.key,
    this.scanWindow = const ScanWindow.centered(),
    this.starting = true,
  });

  /// The scan window to draw.
  final ScanWindow scanWindow;

  /// Whether the camera is starting; `false` for a camera that is stopped,
  /// such as after `ScannerController.stop`.
  final bool starting;

  @override
  State<ScannerPlaceholder> createState() => _ScannerPlaceholderState();
}

class _ScannerPlaceholderState extends State<ScannerPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
  }

  @override
  void didUpdateWidget(ScannerPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animate();
  }

  void _animate() {
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still || !widget.starting) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      unawaited(_clock.repeat());
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        final Rect window = widget.scanWindow.resolve(size);
        final double radius = theme.resolvedWindowRadius;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _Void(),
            WindowScrim(window: window, radius: radius),
            CustomPaint(
              size: size,
              painter: BracketsPainter(
                repaint: _clock,
                rect: () => window,
                lock: () => 0,
                scale: () => 1,
                opacity: () =>
                    1 - 0.45 * math.sin(_clock.value * math.pi).abs(),
                radius: radius,
                color: theme.windowColor,
                lockColor: theme.lockColor,
                strokeWidth: theme.resolvedBracketWidth,
                armLength: theme.bracketLength,
                version: window,
              ),
            ),
            if (widget.starting) ...<Widget>[
              CustomPaint(
                size: size,
                painter: _SpinnerPainter(
                  _clock,
                  window.center,
                  theme.windowColor,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: math.min(window.bottom + 24, size.height - 64),
                child: Center(
                  child: ScannerHint(texts.starting, liveRegion: true),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.clock, this.center, this.color) : super(repaint: clock);

  final Animation<double> clock;
  final Offset center;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // One turn every 1.2 s: two turns per breath of the brackets.
    final double turn = (clock.value * 2) % 1;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 18),
      turn * 2 * math.pi - math.pi / 2,
      2 * math.pi / 3,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter old) =>
      old.center != center || old.color != color;
}

/// Shown when the camera cannot be used: a card with what happened and the
/// ways forward.
///
/// Without camera permission it offers [onOpenSettings] (opening the app's
/// settings needs a plugin such as `app_settings`; the button is hidden
/// without it), otherwise "Try again" ([onRetry]). [onPickImage] adds
/// "Choose a photo".
class ScannerErrorView extends StatelessWidget {
  /// Creates the view for [error].
  const ScannerErrorView(
    this.error, {
    super.key,
    this.onRetry,
    this.onOpenSettings,
    this.onPickImage,
  });

  /// What went wrong.
  final ScannerException error;

  /// Opens the camera again.
  final VoidCallback? onRetry;

  /// Opens the app's settings, for a denied permission.
  final VoidCallback? onOpenSettings;

  /// Reads a photo instead.
  final VoidCallback? onPickImage;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
    final bool permission = error is CameraPermissionException;
    final String title = permission
        ? texts.permissionTitle
        : texts.unavailableTitle;
    final String message = <String>[
      switch (error) {
        CameraPermissionException() => texts.permissionMessage,
        CameraInUseException() => texts.inUseMessage,
        CameraUnsupportedException() => texts.unsupportedMessage,
        _ => texts.unavailableMessage,
      },
      if (onPickImage != null) texts.photoFallback,
    ].join(' ');
    final VoidCallback? primaryAction = permission && onOpenSettings != null
        ? onOpenSettings
        : onRetry;
    final String primaryLabel = permission && onOpenSettings != null
        ? texts.openSettings
        : texts.tryAgain;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _Void(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Semantics(
                  container: true,
                  label: title,
                  child: ScannerGlass(
                    strong: true,
                    shape:
                        theme.resolvedButtonShape == ScannerButtonShape.circle
                        ? const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(28)),
                          )
                        : theme.sheetBorder,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: ScannerBadge(
                            icon: permission
                                ? theme.icons.cameraOff
                                : theme.icons.cameraError,
                            size: 64,
                            tone: permission
                                ? ScannerTone.accent
                                : ScannerTone.warning,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.titleStyle.copyWith(
                            fontSize: 24,
                            height: 30 / 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: theme.mutedStyle,
                        ),
                        if (primaryAction != null) ...<Widget>[
                          const SizedBox(height: 16),
                          ScannerActionButton(
                            label: primaryLabel,
                            primary: true,
                            onPressed: primaryAction,
                          ),
                        ],
                        if (onPickImage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          ScannerActionButton(
                            label: texts.choosePhoto,
                            primary: primaryAction == null,
                            onPressed: onPickImage,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
