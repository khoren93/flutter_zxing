// The flutter_zxing design system's tokens, as the demo app uses them on
// screens without a camera (create, history, results).
//
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// The demo's colors for one brightness.
@immutable
final class Fz extends ThemeExtension<Fz> {
  const Fz._({
    required this.surface,
    required this.raised,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.lockSoft,
    required this.lockInk,
    required this.made,
    required this.madeInk,
    required this.focus,
  });

  /// Light screens.
  static const Fz light = Fz._(
    surface: Color(0xFFF4F6F9),
    raised: Color(0xFFFFFFFF),
    line: Color(0xFFDFE4EB),
    ink: Color(0xFF0E1218),
    inkMuted: Color(0xFF4B5563),
    lockSoft: Color(0x2E2EE6B5),
    lockInk: Color(0xFF00735D),
    made: Color(0x1F2563EB),
    madeInk: Color(0xFF1D4ED8),
    focus: Color(0xFF2563EB),
  );

  /// Dark screens.
  static const Fz dark = Fz._(
    surface: Color(0xFF0B0E13),
    raised: Color(0xFF161A21),
    line: Color(0xFF283039),
    ink: Color(0xFFEEF1F5),
    inkMuted: Color(0xFFA7B0BD),
    lockSoft: Color(0x382EE6B5),
    lockInk: Color(0xFF4FF0C4),
    made: Color(0x297CB2FF),
    madeInk: Color(0xFF9CC3FF),
    focus: Color(0xFF7CB2FF),
  );

  /// The accent: a code is read.
  static const Color lock = Color(0xFF2EE6B5);

  /// Text on [lock].
  static const Color onLock = Color(0xFF03261D);

  final Color surface;
  final Color raised;
  final Color line;
  final Color ink;
  final Color inkMuted;
  final Color lockSoft;
  final Color lockInk;

  /// The "Created" tag.
  final Color made;
  final Color madeInk;
  final Color focus;

  /// The colors of [context]'s theme.
  static Fz of(BuildContext context) =>
      Theme.of(context).extension<Fz>() ?? light;

  @override
  Fz copyWith() => this;

  @override
  Fz lerp(Fz? other, double t) => t < 0.5 ? this : (other ?? this);
}

/// The demo's theme for [brightness].
ThemeData demoTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final Fz fz = dark ? Fz.dark : Fz.light;
  final ColorScheme scheme =
      ColorScheme.fromSeed(seedColor: Fz.lock, brightness: brightness).copyWith(
        primary: fz.ink,
        onPrimary: fz.raised,
        surface: fz.surface,
        onSurface: fz.ink,
        onSurfaceVariant: fz.inkMuted,
        outline: fz.line,
        outlineVariant: fz.line,
        surfaceContainerLowest: fz.raised,
        surfaceContainerLow: fz.raised,
        surfaceContainer: fz.raised,
        surfaceContainerHigh: fz.raised,
        surfaceContainerHighest: fz.raised,
      );
  final ThemeData base = ThemeData(
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: fz.surface,
    extensions: <ThemeExtension<dynamic>>[fz],
  );
  final TextTheme text = base.textTheme.apply(
    bodyColor: fz.ink,
    displayColor: fz.ink,
  );
  final RoundedRectangleBorder field = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 30,
        height: 36 / 30,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fz.raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: fz.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: fz.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: fz.focus, width: 2),
      ),
      labelStyle: TextStyle(color: fz.inkMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: fz.ink,
        foregroundColor: fz.raised,
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: fz.ink,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: fz.line),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: fz.lockInk,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: fz.ink,
        minimumSize: const Size(44, 44),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: fz.raised,
        foregroundColor: fz.ink,
        selectedBackgroundColor: fz.ink,
        selectedForegroundColor: fz.raised,
        side: BorderSide(color: fz.line),
        shape: field,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: fz.raised,
      selectedColor: fz.ink,
      side: BorderSide(color: fz.line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: fz.ink,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      secondaryLabelStyle: TextStyle(
        color: fz.raised,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      showCheckmark: false,
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (Set<WidgetState> s) =>
            s.contains(WidgetState.selected) ? Fz.lock : fz.line,
      ),
      thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(
        Colors.transparent,
      ),
    ),
    dividerTheme: DividerThemeData(color: fz.line, space: 1, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: fz.ink,
      contentTextStyle: TextStyle(color: fz.raised),
      shape: const StadiumBorder(),
    ),
  );
}

/// A card: raised surface, hairline border, large radius.
class FzCard extends StatelessWidget {
  const FzCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fz.raised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: fz.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A small uppercase section label.
class FzLabel extends StatelessWidget {
  const FzLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
      color: Fz.of(context).inkMuted,
    ),
  );
}

/// The mint "Reads · checked" pill, or a warning when a code does not read;
/// with [text], the same pill for another check.
class ReadCheck extends StatelessWidget {
  const ReadCheck({
    super.key,
    required this.reads,
    this.long = false,
    this.invalid = false,
    this.text,
  });

  /// `null` while checking.
  final bool? reads;
  final bool long;

  /// The data cannot be encoded at all: no code to read.
  final bool invalid;

  /// Says something else in the same pill: "All 1,000 fit · QR Code".
  final String? text;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final bool? ok = reads;
    final Color bg = ok == false ? const Color(0x33FFB21E) : fz.lockSoft;
    final Color fg = ok == false
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFFFC857)
              : const Color(0xFF8A5A00))
        : fz.lockInk;
    final String text =
        this.text ??
        switch (ok) {
          null => 'Checking…',
          true =>
            long ? 'Reads · checked with flutter_zxing' : 'Reads · checked',
          false when invalid => 'Invalid data',
          false => 'Does not read: raise the contrast',
        };
    return Semantics(
      liveRegion: true,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              ok == false ? Icons.warning_amber_rounded : Icons.check_rounded,
              size: 15,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
