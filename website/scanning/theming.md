# Colours and texts

Every scanner reads a `ScannerTheme` for its colours and shapes and
`ScannerLocalizations` for its texts, in the app's language. Set them on
one scanner, or once for the whole app.

## The theme

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    accent: Color(0xFFFF6A1A),
    windowRadius: 6,
    buttonShape: ScannerButtonShape.roundedSquare,
  ),
  onDetect: (capture) => print(capture.barcode.content),
)
```

Every field is optional: what you leave out comes from the template's
theme, then from a [`ScannerScope`](#the-whole-app), then from the
defaults.

| Field | Default | What it does |
|---|---|---|
| `accent` | `ScannerTheme.defaultAccent`, a bright teal | The colour of a locked code: the brackets, the outlines and the main buttons. Text in this colour gets enough contrast by itself. |
| `brightness` | the platform's | Light or dark glass |
| `windowRadius` | 24 | Corner radius of the scan window |
| `buttonShape` | `ScannerButtonShape.circle` | Round buttons, or `roundedSquare` for brands with sharper shapes |
| `blur` | on, off when the device is too slow | Whether the glass blurs the camera behind it. Left unset, the scanner stops blurring for good when, in its first three seconds, the device has no room for it (one frame in ten over 8 ms, or five over 16 ms); `true` blurs always, `false` never |
| `scrimBlur` | on, off when the device is too slow | Whether the dimmed camera around the window is blurred too; it is computed again for every frame. Unset, `true` and `false` work as for `blur` |
| `fontFamily` | the app's | Font of the scanner's text |
| `monoFontFamily` | a monospaced system font | Font of barcode data |
| `warning` | amber | A code that needs a look (`ScanVerdict.warn`) |
| `danger` | a bright red | A refused code (`ScanVerdict.reject`) and problems such as an expired date |

## The whole app

A `ScannerScope` gives every scanner below it, `scanBarcode` and
`ScanFieldButton` included, a theme and texts. Put it in your app's
`builder` to follow its colours:

```dart
MaterialApp(
  builder: (context, child) => ScannerScope(
    theme: ScannerTheme(
      accent: Theme.of(context).colorScheme.primary,
      brightness: Theme.of(context).brightness,
    ),
    child: child!,
  ),
)
```

A template's theme applies over the scope's, and the scanner's own `theme`
and `texts` over both.

## Texts and languages

The scanner's texts, from its buttons, hints and errors to the result sheet
and the template titles, come in English, Russian, German, Spanish, French
and Chinese (simplified). They follow the app's
locale with no setup: a Russian app shows «Фонарик», «Сканировать снова»;
a language the package does not have yet falls back to English. Counts
("3 codes", «3 кода»), dates and Wi‑Fi security follow the language.

The app's locale is the one its `MaterialApp` or `WidgetsApp` resolved, so
the app lists the languages it supports, as any localized app does, with
the delegates of Flutter's own widgets (`flutter_localizations`). The
scanner needs nothing more:

<!-- snippet: skip -->
```dart
MaterialApp(
  supportedLocales: const [Locale('en'), Locale('de'), Locale('ru')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: const HomePage(),
)
```

`ScannerLocalizations.of(context)` gives the texts anywhere, such as in
your own result sheet:

```dart
Widget security(BuildContext context, WifiContent wifi) =>
    Text(ScannerLocalizations.of(context).wifiSecurityOf(wifi.security));
```

`ScannerLocalizations.delegate` and `ScannerLocalizations.supportedLocales`
are there for apps that list every delegate by hand; adding them changes
nothing in the texts.

### Change a text

Subclass the built-in translation, override the texts to change and give
it to a `ScannerScope`, or to one scanner as `texts:`. The other texts stay
as they were.

```dart
class MyTexts extends ScannerLocalizationsEn {
  @override
  String get scanAgain => 'Next ticket';

  @override
  String get titleTicket => 'Scan your boarding pass';
}

Widget app(Widget home) => MaterialApp(
  builder: (context, child) => ScannerScope(texts: MyTexts(), child: child!),
  home: home,
);
```

The hints and titles of the templates are texts too (`hintQrCode`,
`hintBarcode`, `hintTicket`, `titlePayment`, `titleTicket`…), so a template
speaks the app's language without changing the template.

### Another language

Subclass `ScannerLocalizationsEn` with your language's code, override every
text, and choose it by the app's locale; `null` keeps the built-in
translations for the other languages:

```dart
class GermanTexts extends ScannerLocalizationsEn {
  GermanTexts() : super('de');

  @override
  String get close => 'Scanner schließen';

  @override
  String get scanAgain => 'Weiter scannen';

  @override
  String itemCount(int count) => count == 1 ? '1 Code' : '$count Codes';

  // Dates: "14. Nov 2026"; monthShort gives the month names.
  @override
  String dayMonthYear(int day, String month, int year) => '$day. $month $year';

  // ... every other text
}

Widget scope(BuildContext context, Widget child) => ScannerScope(
  texts: switch (Localizations.localeOf(context).languageCode) {
    'de' => GermanTexts(),
    _ => null,
  },
  child: child,
);
```

Better still, add it to the package: the texts are ARB files in
[`lib/l10n`](https://github.com/khoren93/flutter_zxing/tree/4.0/lib/l10n).
Copy `scanner_en.arb` to `scanner_<language>.arb`, translate it (the
`@` entries tell what each text is for) and open a pull request; `make l10n`
generates the code.
