import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../l10n/scanner_localizations.dart';
import 'scanner_icons.dart';

/// Shape of the scanner's buttons and panels.
enum ScannerButtonShape {
  /// Round buttons, pill-shaped hints and actions. The default.
  circle,

  /// Squares with small rounded corners, for brands with sharper shapes.
  roundedSquare,
}

/// Shape of the scan window as drawn. The camera is decoded in the window's
/// rectangle whatever its shape.
enum ScannerWindowShape {
  /// A rectangle with corners of [ScannerTheme.windowRadius]. The default.
  rounded,

  /// A circle, or an ellipse in a window that is not square: the scrim is
  /// cut out round and the brackets are four arcs. For round codes, with a
  /// square window (`ScanWindow.centered(aspectRatio: 1)`).
  circle,

  /// The brackets alone, without the dimmed camera around the window.
  bracketsOnly,
}

/// What the scan window shows of the code found, under the result sheet:
/// its picture flies in from where the code is and stays in the window.
enum ScannerWindowPicture {
  /// The code drawn exactly where it can be, like `BarcodeThumbnail`: once
  /// the camera's cut-out has flown in, it turns into the modules the
  /// reader sampled (QR, Micro QR, rMQR, Data Matrix, Aztec) or into the
  /// code drawn again from its digits (EAN, UPC, ITF), sharp however
  /// blurred the frame. Other codes, such as Code 128 or PDF417, stay the
  /// cut-out: the sharpest of the frames read in the moment after the
  /// code, lightly sharpened. The default.
  exact,

  /// Always the camera's cut-out, as photographed.
  photo,

  /// Nothing: the camera stays in the window.
  none,
}

/// How a [ScanLine] moves.
enum ScanLineStyle {
  /// From the top of the window to the bottom, then again from the top.
  /// The default.
  sweep,

  /// Down and up again.
  bounce,
}

/// A line that runs across the scan window while the scanner searches, like
/// the laser of a till scanner:
///
/// ```dart
/// ScannerTheme(scanLine: ScanLine(color: Color(0xFFFF1A1A)))
/// ```
///
/// It shows inside the window only, follows its shape, and only while the
/// scanner searches: not on a code, while paused or under a result sheet,
/// on a hidden scanner, or with the platform's reduce motion setting. It is
/// drawn 30 times a second, with the brackets' breathing; it still costs
/// some energy, so check it with `make perf` on your devices.
@immutable
final class ScanLine {
  /// Creates a scan line.
  const ScanLine({
    this.color,
    this.thickness = 2,
    this.duration = const Duration(milliseconds: 1600),
    this.glow = true,
    this.style = ScanLineStyle.sweep,
    this.inset = 12,
  }) : assert(thickness > 0, 'thickness must be above 0'),
       assert(inset >= 0, 'inset cannot be negative'),
       _off = false;

  const ScanLine._off()
    : color = null,
      thickness = 0,
      duration = Duration.zero,
      glow = false,
      style = ScanLineStyle.sweep,
      inset = 0,
      _off = true;

  /// No scan line, also where the theme merged under has one, such as a
  /// `ScannerScope`'s: `ScannerTheme(scanLine: ScanLine.none)`.
  static const ScanLine none = ScanLine._off();

  /// The line's color. `null` is the theme's accent ([ScannerTheme.lockColor]).
  final Color? color;

  /// The line's thickness, in logical pixels. Default 2.
  final double thickness;

  /// How long one pass across the window takes. Default 1.6 s.
  final Duration duration;

  /// A soft light around the line, in its color. Default `true`.
  final bool glow;

  /// How the line moves: a [ScanLineStyle.sweep] (the default) or a
  /// [ScanLineStyle.bounce].
  final ScanLineStyle style;

  /// The margin between the line and the window's edges, in logical pixels.
  /// Default 12.
  final double inset;

  final bool _off;

  @override
  bool operator ==(Object other) =>
      other is ScanLine &&
      other._off == _off &&
      other.color == color &&
      other.thickness == thickness &&
      other.duration == duration &&
      other.glow == glow &&
      other.style == style &&
      other.inset == inset;

  @override
  int get hashCode =>
      Object.hash(_off, color, thickness, duration, glow, style, inset);

  @override
  String toString() => _off
      ? 'ScanLine.none'
      : 'ScanLine(color: $color, thickness: $thickness, duration: $duration, '
            'glow: $glow, style: ${style.name}, inset: $inset)';
}

/// Changes to the scanner's text styles, each merged onto the built-in
/// style: set only what you change, such as a size or a weight, and the
/// rest stays, the font included.
///
/// ```dart
/// ScannerTheme(
///   textStyles: ScannerTextStyles(
///     title: TextStyle(fontWeight: FontWeight.w800),
///     hint: TextStyle(fontSize: 17),
///   ),
/// )
/// ```
///
/// The colors of the built-in styles follow the theme; a color set here
/// replaces it, except on buttons, whose text takes the button's color.
@immutable
final class ScannerTextStyles {
  /// Creates the changes.
  const ScannerTextStyles({
    this.title,
    this.display,
    this.overline,
    this.body,
    this.muted,
    this.hint,
    this.label,
    this.data,
    this.chip,
  });

  /// Sheet titles: a merchant, a network, a link's host
  /// ([ScannerTheme.titleStyle]).
  final TextStyle? title;

  /// Large numbers, such as an amount ([ScannerTheme.displayStyle]).
  final TextStyle? display;

  /// The small capitals above a title ([ScannerTheme.overlineStyle]).
  final TextStyle? overline;

  /// Body text of the sheets ([ScannerTheme.bodyStyle]); [muted] follows
  /// it.
  final TextStyle? body;

  /// Secondary body text, such as a verdict's message
  /// ([ScannerTheme.mutedStyle]).
  final TextStyle? muted;

  /// Hints and title pills over the camera ([ScannerTheme.hintStyle]).
  final TextStyle? hint;

  /// Buttons, such as the result sheet's actions
  /// ([ScannerTheme.labelStyle]).
  final TextStyle? label;

  /// Barcode data: payloads and codes ([ScannerTheme.dataStyle]); [chip]
  /// follows it.
  final TextStyle? data;

  /// Symbology chips ("QR Code", [ScannerTheme.chipStyle]).
  final TextStyle? chip;

  /// These changes with [other]'s on top, style by style: a size here and
  /// a weight in [other] give both.
  ScannerTextStyles merge(ScannerTextStyles? other) {
    if (other == null) {
      return this;
    }
    TextStyle? both(TextStyle? a, TextStyle? b) => a?.merge(b) ?? b;
    return ScannerTextStyles(
      title: both(title, other.title),
      display: both(display, other.display),
      overline: both(overline, other.overline),
      body: both(body, other.body),
      muted: both(muted, other.muted),
      hint: both(hint, other.hint),
      label: both(label, other.label),
      data: both(data, other.data),
      chip: both(chip, other.chip),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScannerTextStyles &&
      other.title == title &&
      other.display == display &&
      other.overline == overline &&
      other.body == body &&
      other.muted == muted &&
      other.hint == hint &&
      other.label == label &&
      other.data == data &&
      other.chip == chip;

  @override
  int get hashCode => Object.hash(
    title,
    display,
    overline,
    body,
    muted,
    hint,
    label,
    data,
    chip,
  );
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
/// ([titleStyle], [dataStyle], ...) follow the [accent] and [brightness],
/// and [icons] gives every icon of the built-in widgets.
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
    this.window,
    this.scrim,
    this.bracketWidth,
    this.bracketLength,
    this.windowShape,
    this.breathing,
    this.scanLine,
    this.windowPicture,
    this.glass,
    this.sheet,
    this.sheetRadius,
    this.outline,
    this.outlineWidth,
    this.textStyles = const ScannerTextStyles(),
    this.icons = const ScannerIconSet(),
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

  /// Whether the glass panels blur the camera behind them; without blur
  /// they are more opaque. Left `null`, the scanner blurs, and stops for
  /// good when, in its first three seconds, the device has no room for it
  /// (one frame in ten over 8 ms, or five over 16 ms), as on a 2020
  /// Android phone. `true` blurs always, `false` never.
  final bool? blur;

  /// Whether the dimmed camera around the scan window is also blurred. The
  /// blur is computed again for every camera frame. Left `null`, the
  /// scanner blurs, and stops for good when the device does not draw its
  /// frames in time, like [blur]. `true` blurs always, `false` never.
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

  /// The color of the scan window's brackets while the scanner searches;
  /// on a code they take the [accent]. Default white ([windowColor]).
  final Color? window;

  /// The dimmed camera around the scan window, such as
  /// `Color(0xB3000000)` for a darker one or a tint of your brand.
  /// Default a translucent black that depends on the [brightness]
  /// ([scrimColor]).
  final Color? scrim;

  /// Line width of the window's brackets, in logical pixels. Default 5.
  final double? bracketWidth;

  /// Length of each bracket's straight arm, in logical pixels, after the
  /// rounded corner. `null` makes it 22 % of the window's shorter side,
  /// from 12 to 44. On a code smaller than the brackets, the arms meet.
  final double? bracketLength;

  /// Shape of the scan window: [ScannerWindowShape.rounded] (the default),
  /// a [ScannerWindowShape.circle], or [ScannerWindowShape.bracketsOnly]
  /// without the scrim. The scrim's cut-out, the brackets and the
  /// [scanLine] follow it; the camera is decoded in the window's rectangle
  /// whatever its shape.
  final ScannerWindowShape? windowShape;

  /// Whether the window's brackets breathe while the scanner searches.
  /// `false` keeps them still. Default `true`; off with the platform's
  /// reduce motion setting.
  final bool? breathing;

  /// A line that runs across the window while the scanner searches, like a
  /// laser. Default none; [ScanLine.none] turns off one of the theme
  /// merged under.
  final ScanLine? scanLine;

  /// What the window shows of the code found: drawn exactly where it can
  /// be ([ScannerWindowPicture.exact], the default), always the camera's
  /// cut-out ([ScannerWindowPicture.photo]), or nothing
  /// ([ScannerWindowPicture.none]).
  final ScannerWindowPicture? windowPicture;

  /// The background of the buttons, hints and title pills over the camera,
  /// such as your brand's color. An opaque color is drawn without the blur
  /// behind it, which saves its cost; a translucent one keeps the blur
  /// unless [blur] is off. Default a light or dark glass ([glassColor]).
  final Color? glass;

  /// The background of the result sheets and cards, such as
  /// `Color(0xFFFFFFFF)` for a plain white one. An opaque color is drawn
  /// without the blur behind it, as for [glass]. Default a more opaque
  /// glass ([sheetColor]).
  final Color? sheet;

  /// The corner radius of the result sheets and cards, in logical pixels.
  /// `null` gives 32 at the top and 24 at the bottom, or 20 with
  /// [ScannerButtonShape.roundedSquare] buttons ([sheetBorder]).
  final double? sheetRadius;

  /// The outlines of the codes in view, as in [ScannerMode.pick] or a
  /// scanner without a window. Default the [accent] ([outlineColor]).
  final Color? outline;

  /// Line width of the outlines of the codes in view, in logical pixels.
  /// Default 3; 2 on a photo.
  final double? outlineWidth;

  /// Changes to the text styles, merged onto the built-in ones, such as a
  /// larger hint or a bolder title. The [fontFamily] applies under them.
  final ScannerTextStyles textStyles;

  /// Icons of the built-in buttons and sheets, such as your icon font's:
  ///
  /// ```dart
  /// ScannerTheme(
  ///   icons: ScannerIconSet(
  ///     torchOn: ScannerIconData.fromIconData(Icons.flash_on),
  ///     torchOff: ScannerIconData.fromIconData(Icons.flash_off),
  ///   ),
  /// )
  /// ```
  ///
  /// Merged icon by icon: an icon a set leaves out keeps the one of the
  /// theme it is merged onto, then the built-in one.
  final ScannerIconSet icons;

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
      window: other.window ?? window,
      scrim: other.scrim ?? scrim,
      bracketWidth: other.bracketWidth ?? bracketWidth,
      bracketLength: other.bracketLength ?? bracketLength,
      windowShape: other.windowShape ?? windowShape,
      breathing: other.breathing ?? breathing,
      scanLine: other.scanLine ?? scanLine,
      windowPicture: other.windowPicture ?? windowPicture,
      glass: other.glass ?? glass,
      sheet: other.sheet ?? sheet,
      sheetRadius: other.sheetRadius ?? sheetRadius,
      outline: other.outline ?? outline,
      outlineWidth: other.outlineWidth ?? outlineWidth,
      textStyles: textStyles.merge(other.textStyles),
      icons: icons.merge(other.icons),
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
    Color? window,
    Color? scrim,
    double? bracketWidth,
    double? bracketLength,
    ScannerWindowShape? windowShape,
    bool? breathing,
    ScanLine? scanLine,
    ScannerWindowPicture? windowPicture,
    Color? glass,
    Color? sheet,
    double? sheetRadius,
    Color? outline,
    double? outlineWidth,
    ScannerTextStyles? textStyles,
    ScannerIconSet? icons,
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
    window: window ?? this.window,
    scrim: scrim ?? this.scrim,
    bracketWidth: bracketWidth ?? this.bracketWidth,
    bracketLength: bracketLength ?? this.bracketLength,
    windowShape: windowShape ?? this.windowShape,
    breathing: breathing ?? this.breathing,
    scanLine: scanLine ?? this.scanLine,
    windowPicture: windowPicture ?? this.windowPicture,
    glass: glass ?? this.glass,
    sheet: sheet ?? this.sheet,
    sheetRadius: sheetRadius ?? this.sheetRadius,
    outline: outline ?? this.outline,
    outlineWidth: outlineWidth ?? this.outlineWidth,
    textStyles: textStyles ?? this.textStyles,
    icons: icons ?? this.icons,
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

  /// Line width of the window's brackets.
  double get resolvedBracketWidth => bracketWidth ?? 5;

  /// The scan window's shape.
  ScannerWindowShape get resolvedWindowShape =>
      windowShape ?? ScannerWindowShape.rounded;

  /// Whether the brackets breathe while searching (before reduce motion).
  bool get resolvedBreathing => breathing ?? true;

  /// The scan line, or `null` for none ([ScanLine.none] included).
  ScanLine? get resolvedScanLine =>
      scanLine == null || scanLine!._off ? null : scanLine;

  /// What the window shows of the code found.
  ScannerWindowPicture get resolvedWindowPicture =>
      windowPicture ?? ScannerWindowPicture.exact;

  /// Line width of the outlines of the codes in view.
  double get resolvedOutlineWidth => outlineWidth ?? 3;

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

  /// The scan window's brackets while searching ([window]).
  Color get windowColor => window ?? const Color(0xFFFFFFFF);

  /// The dimmed camera outside the scan window ([scrim]).
  Color get scrimColor =>
      scrim ?? (isDark ? const Color(0x94000000) : const Color(0x8006090D));

  /// Buttons, hints and title pills ([glass]).
  Color get glassColor =>
      glass ??
      (resolvedBlur
          ? (isDark ? const Color(0x9412151B) : const Color(0xADFFFFFF))
          : (isDark ? const Color(0xD912151B) : const Color(0xE6FFFFFF)));

  /// Sheets and cards: the more opaque glass that text sits on ([sheet]).
  Color get sheetColor =>
      sheet ??
      (resolvedBlur
          ? (isDark ? const Color(0xCC101318) : const Color(0xDBFFFFFF))
          : (isDark ? const Color(0xF2101318) : const Color(0xF7FFFFFF)));

  /// The outlines of the codes in view ([outline]).
  Color get outlineColor => outline ?? lockColor;

  /// The faint fill inside the outlines of the codes in view.
  Color get outlineFillColor => outline == null
      ? lockSoftColor
      : outline!.withValues(alpha: isDark ? 0.22 : 0.18);

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

  /// Shape of the scan window as drawn: a rounded rectangle, or an oval for
  /// [ScannerWindowShape.circle]. Its `getOuterPath` gives the window's
  /// outline, for a window of your own.
  ShapeBorder get windowBorder => switch (resolvedWindowShape) {
    ScannerWindowShape.circle => const OvalBorder(),
    _ => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(resolvedWindowRadius)),
    ),
  };

  /// Shape of the result sheets and cards.
  ShapeBorder get sheetBorder => switch (resolvedButtonShape) {
    _ when sheetRadius != null => RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(sheetRadius!)),
    ),
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
  TextStyle get titleStyle => _text
      .copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.22,
      )
      .merge(textStyles.title);

  /// Large numbers, such as an amount.
  TextStyle get displayStyle => _text
      .copyWith(
        fontSize: 34,
        height: 40 / 34,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.68,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      )
      .merge(textStyles.display);

  /// The small capitals above a title ("LINK", "PAYMENT REQUEST").
  TextStyle get overlineStyle => _text
      .copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.48,
        color: inkMutedColor,
      )
      .merge(textStyles.overline);

  /// Body text.
  TextStyle get bodyStyle =>
      _text.copyWith(fontSize: 16, height: 1.5).merge(textStyles.body);

  /// Secondary body text.
  TextStyle get mutedStyle =>
      bodyStyle.copyWith(color: inkMutedColor).merge(textStyles.muted);

  /// Hints and title pills.
  TextStyle get hintStyle => _text
      .copyWith(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w500)
      .merge(textStyles.hint);

  /// Buttons.
  TextStyle get labelStyle => _text
      .copyWith(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600)
      .merge(textStyles.label);

  /// Barcode data: payloads and codes.
  TextStyle get dataStyle => TextStyle(
    fontFamily: monoFontFamily ?? _monoFamily,
    fontFamilyFallback: _monoFallback,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w500,
    color: inkColor,
    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
  ).merge(textStyles.data);

  /// Symbology chips ("QR Code").
  TextStyle get chipStyle => dataStyle
      .copyWith(
        fontSize: 12,
        height: 16 / 12,
        letterSpacing: 0.48,
        color: lockInkColor,
      )
      .merge(textStyles.chip);

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
      other.danger == danger &&
      other.window == window &&
      other.scrim == scrim &&
      other.bracketWidth == bracketWidth &&
      other.bracketLength == bracketLength &&
      other.windowShape == windowShape &&
      other.breathing == breathing &&
      other.scanLine == scanLine &&
      other.windowPicture == windowPicture &&
      other.glass == glass &&
      other.sheet == sheet &&
      other.sheetRadius == sheetRadius &&
      other.outline == outline &&
      other.outlineWidth == outlineWidth &&
      other.textStyles == textStyles &&
      other.icons == icons;

  @override
  int get hashCode => Object.hashAll(<Object?>[
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
    window,
    scrim,
    bracketWidth,
    bracketLength,
    windowShape,
    breathing,
    scanLine,
    windowPicture,
    glass,
    sheet,
    sheetRadius,
    outline,
    outlineWidth,
    textStyles,
    icons,
  ]);

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
      ..add(ColorProperty('danger', danger, defaultValue: null))
      ..add(ColorProperty('window', window, defaultValue: null))
      ..add(ColorProperty('scrim', scrim, defaultValue: null))
      ..add(DoubleProperty('bracketWidth', bracketWidth, defaultValue: null))
      ..add(DoubleProperty('bracketLength', bracketLength, defaultValue: null))
      ..add(EnumProperty<ScannerWindowShape>('windowShape', windowShape))
      ..add(FlagProperty('breathing', value: breathing, ifFalse: 'still'))
      ..add(
        DiagnosticsProperty<ScanLine>('scanLine', scanLine, defaultValue: null),
      )
      ..add(EnumProperty<ScannerWindowPicture>('windowPicture', windowPicture))
      ..add(ColorProperty('glass', glass, defaultValue: null))
      ..add(ColorProperty('sheet', sheet, defaultValue: null))
      ..add(DoubleProperty('sheetRadius', sheetRadius, defaultValue: null))
      ..add(ColorProperty('outline', outline, defaultValue: null))
      ..add(DoubleProperty('outlineWidth', outlineWidth, defaultValue: null))
      ..add(
        DiagnosticsProperty<ScannerTextStyles>(
          'textStyles',
          textStyles,
          defaultValue: const ScannerTextStyles(),
        ),
      )
      ..add(
        DiagnosticsProperty<ScannerIconSet>(
          'icons',
          icons,
          defaultValue: const ScannerIconSet(),
        ),
      );
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
/// `theme` and `texts`. `BarcodeScanner` inserts one with the result;
/// use it also to style scanner widgets elsewhere, such as a
/// [ScannerTheme]-styled button in your own screen.
class ScannerScope extends InheritedWidget {
  /// Creates a scope.
  const ScannerScope({
    super.key,
    this.theme = const ScannerTheme(),
    this.texts,
    required super.child,
  });

  /// The theme; a `null` brightness follows the platform's.
  final ScannerTheme theme;

  /// The texts of the scanner widgets below, such as a subclass of a
  /// built-in translation with a few texts changed:
  ///
  /// ```dart
  /// class MyTexts extends ScannerLocalizationsEn {
  ///   @override
  ///   String get scanAgain => 'Next ticket';
  /// }
  ///
  /// ScannerScope(texts: MyTexts(), child: ...)
  /// ```
  ///
  /// `null` leaves them to [ScannerLocalizations.of]: those of an outer
  /// scope, of a registered `ScannerLocalizations.delegate`, or the built-in
  /// translation for the app's locale.
  final ScannerLocalizations? texts;

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
      oldWidget.theme != theme || oldWidget.texts != texts;
}

/// A scope whose theme has its brightness resolved from the platform and
/// whose text uses the app's font, around [child].
Widget resolvedScannerScope(
  BuildContext context, {
  required ScannerTheme theme,
  required ScannerLocalizations? texts,
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
    texts: texts,
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
