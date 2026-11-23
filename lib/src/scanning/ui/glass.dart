import 'dart:ui' show ClipOp, ImageFilter;

import 'package:flutter/widgets.dart';

import 'pressable.dart';
import 'scanner_icons.dart';
import 'scanner_theme.dart';

/// A translucent panel over the camera: it blurs what is behind it (unless
/// [ScannerTheme.blur] is off), has a light top edge and a soft shadow.
///
/// Its color is the theme's [ScannerTheme.glassColor], or
/// [ScannerTheme.sheetColor] when [strong]; an opaque one, such as a brand
/// color in [ScannerTheme.glass], is drawn without the blur.
///
/// The scanner's buttons, hints and sheets are built from it; use it for
/// your own panels so they match.
class ScannerGlass extends StatelessWidget {
  /// Creates a glass panel.
  const ScannerGlass({
    super.key,
    this.shape,
    this.strong = false,
    this.color,
    this.padding,
    required this.child,
  });

  /// The outline; default [ScannerTheme.pillBorder].
  final ShapeBorder? shape;

  /// More opaque glass, for panels with text on them such as sheets: the
  /// theme's [ScannerTheme.sheetColor].
  final bool strong;

  /// An opaque color instead of glass, e.g. for a button that is on.
  final Color? color;

  /// Space around [child].
  final EdgeInsetsGeometry? padding;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ShapeBorder shape = this.shape ?? theme.pillBorder;
    final TextDirection? direction = Directionality.maybeOf(context);
    final Color fill = color ?? (strong ? theme.sheetColor : theme.glassColor);
    Widget body = CustomPaint(
      foregroundPainter: color == null
          ? _EdgePainter(shape, theme.glassEdgeColor, direction)
          : null,
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: shape, color: fill),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
    // Nothing shows through an opaque color: no blur to pay for.
    final ImageFilter? filter = color == null && fill.a < 1
        ? theme.glassFilter
        : null;
    if (filter != null) {
      body = ClipPath(
        clipper: ShapeBorderClipper(shape: shape, textDirection: direction),
        child: BackdropFilter.grouped(filter: filter, child: body),
      );
    }
    return CustomPaint(
      painter: _ShadowPainter(shape, theme.shadowColor, direction),
      child: body,
    );
  }
}

/// The shadow under glass, mostly outside its shape: the camera seen
/// through the glass is not darkened (like a CSS `box-shadow`).
///
/// Drawn as a blurred rounded rectangle, which Impeller draws analytically
/// in one pass; a blurred path costs an offscreen blur on every camera frame.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter(this.shape, this.color, this.direction);

  final ShapeBorder shape;
  final Color color;
  final TextDirection? direction;

  static const Offset _offset = Offset(0, 10);
  static const MaskFilter _blur = MaskFilter.blur(BlurStyle.normal, 15);

  RRect? _rrect(Rect rect) => switch (shape) {
    CircleBorder() => RRect.fromRectAndRadius(
      Rect.fromCircle(center: rect.center, radius: rect.shortestSide / 2),
      Radius.circular(rect.shortestSide / 2),
    ),
    StadiumBorder() => RRect.fromRectAndRadius(
      rect,
      Radius.circular(rect.shortestSide / 2),
    ),
    final RoundedRectangleBorder r =>
      r.borderRadius.resolve(direction).toRRect(rect),
    _ => null,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint = Paint()
      ..color = color
      ..maskFilter = _blur;
    final RRect? rrect = _rrect(rect);
    canvas
      ..save()
      // Keep the shadow out of the middle of the glass; a rectangle clip is
      // cheap, the rounded corners let a little of it through.
      ..clipRect(
        rrect == null
            ? rect
            : Rect.fromLTRB(
                rect.left + rrect.tlRadiusX * 0.3,
                rect.top + rrect.tlRadiusY * 0.3,
                rect.right - rrect.brRadiusX * 0.3,
                rect.bottom - rrect.brRadiusY * 0.3,
              ),
        clipOp: ClipOp.difference,
      );
    if (rrect != null) {
      canvas.drawRRect(rrect.shift(_offset), paint);
    } else {
      canvas.drawPath(
        shape.getOuterPath(rect, textDirection: direction).shift(_offset),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) =>
      old.shape != shape || old.color != color || old.direction != direction;
}

/// The one-pixel light edge along the top inside the glass.
class _EdgePainter extends CustomPainter {
  const _EdgePainter(this.shape, this.color, this.direction);

  final ShapeBorder shape;
  final Color color;
  final TextDirection? direction;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outline = shape.getOuterPath(
      Offset.zero & size,
      textDirection: direction,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outline,
        outline.shift(const Offset(0, 1)),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.shape != shape || old.color != color || old.direction != direction;
}

/// A 48 × 48 glass button with an icon, as on the scanner's corners.
///
/// [label] is read by screen readers.
class ScannerButton extends StatelessWidget {
  /// Creates a button.
  const ScannerButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.isToggle = false,
  });

  /// The icon.
  final ScannerIconData icon;

  /// What the button does, for screen readers.
  final String label;

  /// Called on tap; `null` disables the button.
  final VoidCallback? onPressed;

  /// Drawn in [ScannerTheme.signalColor], as a torch that is on.
  final bool selected;

  /// Whether the button turns something on and off; screen readers then
  /// announce [selected] as its state.
  final bool isToggle;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      toggled: isToggle ? selected : null,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        shape: theme.buttonBorder,
        child: ScannerGlass(
          shape: theme.buttonBorder,
          color: selected ? theme.signalColor : null,
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: ScannerIcon(
                icon,
                color: selected ? theme.onSignalColor : theme.inkColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass pill with an optional icon: hints ("Point at a QR code") and
/// titles ("Pay with QR").
class ScannerHint extends StatelessWidget {
  /// Creates a hint.
  const ScannerHint(this.text, {super.key, this.icon, this.liveRegion = false});

  /// The text.
  final String text;

  /// An icon before the text.
  final ScannerIconData? icon;

  /// Whether screen readers announce changes, for status texts.
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return Semantics(
      liveRegion: liveRegion,
      child: ScannerGlass(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  ScannerIcon(icon!, size: 20, color: theme.inkColor),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: theme.hintStyle,
                    textAlign: TextAlign.center,
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

/// A sheet of strong glass at the bottom of the scanner, for results: in
/// the theme's [ScannerTheme.sheetColor] and [ScannerTheme.sheetBorder]
/// ([ScannerTheme.sheet] and [ScannerTheme.sheetRadius]).
class ScannerSheet extends StatelessWidget {
  /// Creates a sheet.
  const ScannerSheet({
    super.key,
    this.padding = const EdgeInsets.all(24),
    this.label,
    this.liveRegion = false,
    required this.child,
  });

  /// Space around [child].
  final EdgeInsetsGeometry padding;

  /// What the sheet shows, for screen readers.
  final String? label;

  /// Screen readers announce [label] when the sheet appears or changes,
  /// as for a code found or a verdict.
  final bool liveRegion;

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: label,
      liveRegion: liveRegion,
      child: ScannerGlass(
        shape: theme.sheetBorder,
        strong: true,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// A full-width button of a result sheet: [primary] in the accent, or
/// outlined.
class ScannerActionButton extends StatelessWidget {
  /// Creates a button.
  const ScannerActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
    this.compact = false,
    this.semanticLabel,
  });

  /// The text; an empty string shows the [icon] alone.
  final String label;

  /// What screen readers say instead of [label], such as for a button
  /// with an icon alone.
  final String? semanticLabel;

  /// An icon before the text.
  final ScannerIconData? icon;

  /// Called on tap; `null` disables the button.
  final VoidCallback? onPressed;

  /// Filled with the accent.
  final bool primary;

  /// 44 high with its own width, instead of 52 and as wide as allowed.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ShapeBorder shape = theme.pillBorder;
    final Color ink = primary ? theme.onLockColor : theme.inkColor;
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      // The label is on the button's semantics node.
      children: <Widget>[
        if (icon != null) ScannerIcon(icon!, size: 20, color: ink),
        if (icon != null && label.isNotEmpty) const SizedBox(width: 8),
        if (label.isNotEmpty)
          Flexible(
            child: Text(
              label,
              style: theme.labelStyle.copyWith(color: ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? label,
      child: Pressable(
        onPressed: onPressed,
        shape: shape,
        child: Opacity(
          opacity: onPressed == null ? 0.5 : 1,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: primary ? theme.lockColor : null,
              shape: primary
                  ? shape
                  : _withSide(shape, BorderSide(color: theme.lineColor)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compact ? 44 : 52),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 16),
                child: Center(
                  widthFactor: 1,
                  child: ExcludeSemantics(child: content),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static ShapeBorder _withSide(ShapeBorder shape, BorderSide side) =>
      switch (shape) {
        final OutlinedBorder outlined => outlined.copyWith(side: side),
        _ => shape,
      };
}

/// The color of a [ScannerChip] or a `ScannerBadge`.
enum ScannerTone {
  /// The accent ([ScannerTheme.lockColor]). The default.
  accent,

  /// The signal color ([ScannerTheme.signalColor]), for things to look
  /// at.
  warning,

  /// The danger color ([ScannerTheme.dangerColor]), for problems such as
  /// "Expired".
  danger,
}

/// A chip with the symbology of a code ("QR Code", "GS1-128 · GS1").
class ScannerChip extends StatelessWidget {
  /// Creates a chip.
  const ScannerChip(this.text, {super.key, this.tone = ScannerTone.accent});

  /// The text.
  final String text;

  /// The color: the accent, or a warning or danger for things to look at
  /// and problems ("Expired").
  final ScannerTone tone;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final (Color fill, Color ink) = switch (tone) {
      ScannerTone.accent => (theme.lockSoftColor, theme.lockInkColor),
      ScannerTone.warning => (
        theme.signalColor.withValues(alpha: 0.2),
        theme.signalInkColor,
      ),
      ScannerTone.danger => (
        theme.dangerColor.withValues(alpha: 0.2),
        theme.dangerInkColor,
      ),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text,
          style: theme.chipStyle.copyWith(color: ink),
          maxLines: 1,
        ),
      ),
    );
  }
}
