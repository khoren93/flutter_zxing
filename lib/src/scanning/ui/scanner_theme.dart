import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'scanner_strings.dart';

/// Shape of the scanner's buttons and panels.
enum ScannerButtonShape {
  /// Round buttons, pill-shaped hints and actions. The default.
  circle,

  /// Squares with small rounded corners, for brands with sharper shapes.
  roundedSquare,
}

/// Colors and shapes of the scanner widgets: the scan window, the buttons,
/// the glass panels and the result sheets.
///
/// Every field is optional. A field left `null` takes the value of the
/// template's theme (see `ScannerTemplate.theme`), then the default:
///
/// ```dart
/// BarcodeScanner(
///   template: ScannerTemplate.minimal(),
///   theme: ScannerTheme(
///     accent: Color(0xFFFF6A1A),
///     windowRadius: 6,
///     buttonShape: ScannerButtonShape.roundedSquare,
///   ),
/// )
/// ```
///
/// The text uses the app's font unless [fontFamily] is set. Read the
/// resolved theme in your own overlay or sheet with [ScannerTheme.of]; its
/// colors ([lockColor], [glassColor], [inkColor], ...) and text styles
/// ([titleStyle], [dataStyle], ...) follow the [accent] and [brightness].
@immutable
final class ScannerTheme with Diagnosticable {
  /// Creates a theme. `null` fields keep the value of the theme it is
  /// merged onto.
  const ScannerTheme({
    this.accent,
    this.brightness,
    this.windowRadius,
    this.buttonShape,
    this.blur,
    this.scrimBlur,
    this.fontFamily,
    this.monoFontFamily,
    this.warning,
    this.danger,
  });

  /// The accent of the default theme, a bright teal.
  static const Color defaultAccent = Color(0xFF2EE6B5);

  /// The color of a code the scanner has locked on: the window brackets,
  /// the outlines and the primary buttons. Text in this color is derived
  /// from it with enough contrast ([lockInkColor]). Default
  /// [defaultAccent].
  final Color? accent;

  /// Light or dark glass. `null` follows the platform's brightness.
  final Brightness? brightness;

  /// Corner radius of the scan window, in logical pixels. Default 24.
  final double? windowRadius;

  /// Shape of the buttons and panels. Default [ScannerButtonShape.circle].
  final ScannerButtonShape? buttonShape;

  /// Whether the glass panels blur the camera behind them. Default `true`;
  /// turn it off on slow devices: the panels then become more opaque.
  final bool? blur;

  /// Whether the dimmed camera around the scan window is also blurred.
  /// Default `true`. The blur is computed again for every camera frame:
  /// turn it off on slow phones (a 2020 Android phone does not manage it in
  /// a frame's time).
  final bool? scrimBlur;

  /// Font of the scanner's text. `null` uses the app's font.
  final String? fontFamily;

  /// Font of barcode data (payloads, codes, symbology identifiers). `null`
  /// uses a monospaced system font.
  final String? monoFontFamily;

  /// The color of a code that needs a look, such as a ticket already
  /// checked in (`ScanVerdict.warn`). Default [signalColor], amber.
  final Color? warning;

  /// The color of a code that is refused (`ScanVerdict.reject`) and of
  /// problems such as an expiry date that has passed. Default a bright
  /// red.
  final Color? danger;

  /// The theme of the nearest [ScannerScope], or the default theme; without
  /// a [brightness], the platform's (light where unknown).
  static ScannerTheme of(BuildContext context) {
    final ScannerTheme theme =
        context.dependOnInheritedWidgetOfExactType<ScannerScope>()?.theme ??
        const ScannerTheme();
    return theme.brightness != null
        ? theme
        : theme.copyWith(
            brightness:
                MediaQuery.maybePlatformBrightnessOf(context) ??
                Brightness.light,
          );
  }

  /// This theme with the non-null fields of [other] on top.
  ScannerTheme merge(ScannerTheme? other) {
    if (other == null) {
      return this;
    }
    return ScannerTheme(
      accent: other.accent ?? accent,
      brightness: other.brightness ?? brightness,
      windowRadius: other.windowRadius ?? windowRadius,
      buttonShape: other.buttonShape ?? buttonShape,
      blur: other.blur ?? blur,
      scrimBlur: other.scrimBlur ?? scrimBlur,
      fontFamily: other.fontFamily ?? fontFamily,
      monoFontFamily: other.monoFontFamily ?? monoFontFamily,
      warning: other.warning ?? warning,
      danger: other.danger ?? danger,
    );
  }

  /// A copy with the given fields replaced.
  ScannerTheme copyWith({
    Color? accent,
    Brightness? brightness,
    double? windowRadius,
    ScannerButtonShape? buttonShape,
    bool? blur,
    bool? scrimBlur,
    String? fontFamily,
    String? monoFontFamily,
    Color? warning,
    Color? danger,
  }) => ScannerTheme(
    accent: accent ?? this.accent,
    brightness: brightness ?? this.brightness,
    windowRadius: windowRadius ?? this.windowRadius,
    buttonShape: buttonShape ?? this.buttonShape,
    blur: blur ?? this.blur,
    scrimBlur: scrimBlur ?? this.scrimBlur,
    fontFamily: fontFamily ?? this.fontFamily,
    monoFontFamily: monoFontFamily ?? this.monoFontFamily,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );

  // ---------------------------------------------------------------------------
  // Resolved values.

  /// Whether the glass is dark.
  bool get isDark => brightness == Brightness.dark;

  /// The scan window's corner radius.
  double get resolvedWindowRadius => windowRadius ?? 24;

  /// The buttons' and panels' shape.
  ScannerButtonShape get resolvedButtonShape =>
      buttonShape ?? ScannerButtonShape.circle;

  /// Whether glass blurs what is behind it.
  bool get resolvedBlur => blur ?? true;

  /// Whether the dimmed camera around the scan window is blurred.
  bool get resolvedScrimBlur => scrimBlur ?? true;

  _Palette get _palette => _palettes[this] ??= _Palette(this);
  static final Expando<_Palette> _palettes = Expando<_Palette>();

  /// The accent: brackets and outlines of a locked code, primary buttons.
  Color get lockColor => accent ?? defaultAccent;

  /// The accent, faint: the fill of outlines, chips and badges.
  Color get lockSoftColor => _palette.lockSoft;

  /// Text and icons in the accent's hue on glass and on [lockSoftColor],
  /// with a contrast of at least 4.5:1.
  Color get lockInkColor => _palette.lockInk;

  /// Text and icons on [lockColor].
  Color get onLockColor => _palette.onLock;

  /// The scan window's brackets while searching.
  Color get windowColor => const Color(0xFFFFFFFF);

  /// The dimmed camera outside the scan window.
  Color get scrimColor =>
      isDark ? const Color(0x94000000) : const Color(0x8006090D);

  /// Buttons, hints and title pills.
  Color get glassColor => resolvedBlur
      ? (isDark ? const Color(0x9412151B) : const Color(0xADFFFFFF))
      : (isDark ? const Color(0xD912151B) : const Color(0xE6FFFFFF));

  /// Sheets and cards: glass that text sits on.
  Color get glassStrongColor => resolvedBlur
      ? (isDark ? const Color(0xCC101318) : const Color(0xDBFFFFFF))
      : (isDark ? const Color(0xF2101318) : const Color(0xF7FFFFFF));

  /// The light edge along the top of glass.
  Color get glassEdgeColor =>
      isDark ? const Color(0x29FFFFFF) : const Color(0xD9FFFFFF);

  /// The shadow under glass.
  Color get shadowColor =>
      isDark ? const Color(0x80000000) : const Color(0x38000000);

  /// Primary text.
  Color get inkColor =>
      isDark ? const Color(0xFFEEF1F5) : const Color(0xFF0E1218);

  /// Secondary text.
  Color get inkMutedColor =>
      isDark ? const Color(0xFFA7B0BD) : const Color(0xFF4B5563);

  /// Outlines of secondary buttons and separators.
  Color get lineColor =>
      isDark ? const Color(0xFF283039) : const Color(0xFFDFE4EB);

  /// A control that is on, such as the torch.
  Color get signalColor => const Color(0xFFFFB21E);

  /// Text and icons on [signalColor].
  Color get onSignalColor => const Color(0xFF2A1D00);

  /// Text in the signal's hue, such as a warning.
  Color get signalInkColor =>
      isDark ? const Color(0xFFFFC857) : const Color(0xFF8A5A00);

  /// A code that needs a look ([warning]).
  Color get warningColor => warning ?? signalColor;

  /// Text and icons on [warningColor].
  Color get onWarningColor =>
      warning == null ? onSignalColor : _onColor(warningColor);

  /// A refused code and problems ([danger]).
  Color get dangerColor => danger ?? const Color(0xFFFF4D42);

  /// Text and icons on [dangerColor].
  Color get onDangerColor =>
      danger == null ? const Color(0xFFFFFFFF) : _onColor(dangerColor);

  /// Text in the danger's hue on glass, such as "Expired".
  Color get dangerInkColor => danger != null
      ? _inkOf(dangerColor, isDark)
      : (isDark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E));

  /// The keyboard focus ring.
  Color get focusColor =>
      isDark ? const Color(0xFF7CB2FF) : const Color(0xFF2563EB);

  // ---------------------------------------------------------------------------
  // Shapes.

  /// Shape of a 48 dp button.
  ShapeBorder get buttonBorder => switch (resolvedButtonShape) {
    ScannerButtonShape.circle => const CircleBorder(),
    ScannerButtonShape.roundedSquare => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
  };

  /// Shape of hints, title pills, chips and action buttons.
  ShapeBorder get pillBorder => switch (resolvedButtonShape) {
    ScannerButtonShape.circle => const StadiumBorder(),
    ScannerButtonShape.roundedSquare => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
  };

  /// Shape of the result sheets and cards.
  ShapeBorder get sheetBorder => switch (resolvedButtonShape) {
    ScannerButtonShape.circle => const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(32),
        bottom: Radius.circular(24),
      ),
    ),
    ScannerButtonShape.roundedSquare => const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  };

  /// The blur behind glass, or `null` without [blur].
  ImageFilter? get glassFilter => resolvedBlur ? _glassFilter : null;

  static final ImageFilter _glassFilter = ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturate140),
    inner: ImageFilter.blur(sigmaX: 20, sigmaY: 20, tileMode: TileMode.clamp),
  );

  // ---------------------------------------------------------------------------
  // Text.

  TextStyle get _text => TextStyle(fontFamily: fontFamily, color: inkColor);

  /// Sheet titles: a merchant, a network, a link's host.
  TextStyle get titleStyle => _text.copyWith(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.22,
  );

  /// Large numbers, such as an amount.
  TextStyle get displayStyle => _text.copyWith(
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.68,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// The small capitals above a title ("LINK", "PAYMENT REQUEST").
  TextStyle get overlineStyle => _text.copyWith(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.48,
    color: inkMutedColor,
  );

  /// Body text.
  TextStyle get bodyStyle => _text.copyWith(fontSize: 16, height: 1.5);

  /// Secondary body text.
  TextStyle get mutedStyle => bodyStyle.copyWith(color: inkMutedColor);

  /// Hints and title pills.
  TextStyle get hintStyle => _text.copyWith(
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w500,
  );

  /// Buttons.
  TextStyle get labelStyle =>
      _text.copyWith(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600);

  /// Barcode data: payloads and codes.
  TextStyle get dataStyle => TextStyle(
    fontFamily: monoFontFamily ?? _monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
    color: inkColor,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Symbology chips ("QR Code").
  TextStyle get chipStyle => dataStyle.copyWith(
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.48,
    color: lockInkColor,
  );

  static const String _monoFamily = 'Menlo';
  static const List<String> _monoFallback = <String>[
    'SF Mono',
    'monospace',
    'Roboto Mono',
    'Consolas',
    'DejaVu Sans Mono',
    'Courier New',
  ];

  @override
  bool operator ==(Object other) =>
      other is ScannerTheme &&
      other.accent == accent &&
      other.brightness == brightness &&
      other.windowRadius == windowRadius &&
      other.buttonShape == buttonShape &&
      other.blur == blur &&
      other.scrimBlur == scrimBlur &&
      other.fontFamily == fontFamily &&
      other.monoFontFamily == monoFontFamily &&
      other.warning == warning &&
      other.danger == danger;

  @override
  int get hashCode => Object.hash(
    accent,
    brightness,
    windowRadius,
    buttonShape,
    blur,
    scrimBlur,
    fontFamily,
    monoFontFamily,
    warning,
    danger,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('accent', accent, defaultValue: null))
      ..add(EnumProperty<Brightness>('brightness', brightness))
      ..add(DoubleProperty('windowRadius', windowRadius, defaultValue: null))
      ..add(EnumProperty<ScannerButtonShape>('buttonShape', buttonShape))
      ..add(FlagProperty('blur', value: blur, ifFalse: 'no blur'))
      ..add(FlagProperty('scrimBlur', value: scrimBlur, ifTrue: 'scrim blur'))
      ..add(StringProperty('fontFamily', fontFamily, defaultValue: null))
      ..add(
        StringProperty('monoFontFamily', monoFontFamily, defaultValue: null),
      )
      ..add(ColorProperty('warning', warning, defaultValue: null))
      ..add(ColorProperty('danger', danger, defaultValue: null));
  }
}

/// The CSS `saturate(1.4)` matrix.
const List<double> _saturate140 = <double>[
  0.213 + 0.787 * 1.4, 0.715 - 0.715 * 1.4, 0.072 - 0.072 * 1.4, 0, 0, //
  0.213 - 0.213 * 1.4, 0.715 + 0.285 * 1.4, 0.072 - 0.072 * 1.4, 0, 0, //
  0.213 - 0.213 * 1.4, 0.715 - 0.715 * 1.4, 0.072 + 0.928 * 1.4, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Colors derived from the accent, computed once per theme.
final class _Palette {
  _Palette(ScannerTheme theme) {
    final Color accent = theme.lockColor;
    lockSoft = accent.withValues(alpha: theme.isDark ? 0.22 : 0.18);
    lockInk = _inkOf(accent, theme.isDark);
    onLock = _onColor(accent);
  }

  late final Color lockSoft;
  late final Color lockInk;
  late final Color onLock;
}

/// Text in [color]'s hue: darker on light glass, lighter on dark glass,
/// until it reads at 4.5:1.
Color _inkOf(Color color, bool dark) {
  final HSLColor hsl = HSLColor.fromColor(color);
  final Color background = dark
      ? const Color(0xFF101318)
      : const Color(0xFFF4F6F9);
  double lightness = dark
      ? (hsl.lightness + 0.08).clamp(0.0, 1.0)
      : hsl.lightness;
  Color ink = hsl.withLightness(lightness).toColor();
  while (_contrast(ink, background) < 4.5 &&
      (dark ? lightness < 1 : lightness > 0)) {
    lightness = (lightness + (dark ? 0.02 : -0.02)).clamp(0.0, 1.0);
    ink = hsl.withLightness(lightness).toColor();
  }
  return ink;
}

/// Text on [color]: a near-black of its hue when that reads better than
/// white, as on bright colors.
Color _onColor(Color color) {
  const Color white = Color(0xFFFFFFFF);
  final HSLColor hsl = HSLColor.fromColor(color);
  final Color deep = hsl
      .withLightness(0.08)
      .withSaturation(hsl.saturation * 0.9)
      .toColor();
  return _contrast(deep, color) >= _contrast(white, color) ? deep : white;
}

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Gives the scanner widgets below it a theme and texts.
///
/// Put one around the app or a screen to give every scanner below it the
/// app's theme and translated texts: `BarcodeScanner`, `scanBarcode` and
/// `ScanFieldButton` take them, under a template's theme and their own
/// `theme` and `strings`. `BarcodeScanner` inserts one with the result;
/// use it also to style scanner widgets elsewhere, such as a
/// [ScannerTheme]-styled button in your own screen.
class ScannerScope extends InheritedWidget {
  /// Creates a scope.
  const ScannerScope({
    super.key,
    this.theme = const ScannerTheme(),
    this.strings = const ScannerStrings(),
    required super.child,
  });

  /// The theme; a `null` brightness follows the platform's.
  final ScannerTheme theme;

  /// The texts.
  final ScannerStrings strings;

  /// The font of the surrounding text, unless it is the warning style a
  /// Material app gives text outside a `Material` (red monospace).
  static String? _ambientFamily(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(context).style;
    final String? label = style.debugLabel;
    if (label != null && label.contains('fallback style')) {
      return null;
    }
    return style.fontFamily;
  }

  @override
  bool updateShouldNotify(ScannerScope oldWidget) =>
      oldWidget.theme != theme || oldWidget.strings != strings;
}

/// A scope whose theme has its brightness resolved from the platform and
/// whose text uses the app's font, around [child].
Widget resolvedScannerScope(
  BuildContext context, {
  required ScannerTheme theme,
  required ScannerStrings strings,
  required Widget child,
}) {
  final ScannerTheme resolved = theme.brightness != null
      ? theme
      : theme.copyWith(
          brightness:
              MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light,
        );
  return ScannerScope(
    theme: resolved,
    strings: strings,
    child: DefaultTextStyle(
      style: TextStyle(
        inherit: false,
        fontFamily: resolved.fontFamily ?? ScannerScope._ambientFamily(context),
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: resolved.inkColor,
        decoration: TextDecoration.none,
      ),
      child: child,
    ),
  );
}
