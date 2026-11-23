# Colours and texts

Every scanner reads a `ScannerTheme` for its colours and shapes and
`ScannerLocalizations` for its texts, in the app's language. Set them on
one scanner, or once for the whole app.

The [Your brand’s look](../use-cases#your-brand-s-look) use case puts most
of this page together in one file: colours, buttons, the scan window, texts
and a widget of your own.

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
| `window` | white | The brackets of the scan window while the scanner searches; on a code they take the `accent` |
| `scrim` | a translucent black, darker on dark glass | The dimmed camera around the window |
| `bracketWidth` | 5 | Line width of the brackets |
| `bracketLength` | 22 % of the window's shorter side, 12 to 44 | Length of each bracket's straight arm |
| `windowShape` | `ScannerWindowShape.rounded` | The window drawn with rounded corners, as a `circle`, or as the brackets alone (`bracketsOnly`) ([The window's shape](#the-window-s-shape)) |
| `breathing` | `true` | Whether the brackets breathe while the scanner searches ([Motion](#motion)) |
| `scanLine` | none | A line that runs across the window while the scanner searches, like a laser ([Motion](#motion)) |
| `windowPicture` | `ScannerWindowPicture.exact` | What the window shows of the code found: drawn exactly where it can be, the camera's picture (`photo`) or nothing (`none`) ([The code in the window](#the-code-in-the-window)) |
| `glass` | a light or dark glass | The background of the buttons, hints and title pills ([Glass and sheets](#glass-and-sheets)) |
| `sheet` | a more opaque glass | The background of the result sheets and cards |
| `sheetRadius` | 32 at the top and 24 at the bottom; 20 with `roundedSquare` | Corner radius of the result sheets and cards |
| `outline`, `outlineWidth` | the `accent`, 3 | The outlines of the codes in view, as when picking one of several |
| `textStyles` | the built-in styles | Changes to the text styles, such as a bolder title ([Text styles](#text-styles)) |
| `icons` | the built-in line icons | The icons of the buttons and sheets ([Icons](#icons)) |

## The window and the scrim

The brackets of the scan window are white while the scanner searches and
take the accent once they lock onto a code. Give them your colour, a
thinner line and shorter arms, and dim the camera around the window more,
or in your brand's tint:

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    window: Color(0xFFFF8CC6),
    scrim: Color(0xC21A0B2E),
    bracketWidth: 3,
    bracketLength: 24,
  ),
)
```

`ScannerTheme.of(context).windowColor` and `.scrimColor` give the colours
in use, for a window of your own drawn in an `overlayBuilder`.

### The window's shape

`windowShape` draws the window as a `circle`, for round codes, or as its
brackets alone, with no dimming around it (`bracketsOnly`). The scrim's
cut-out, the brackets and the scan line follow the shape; a circle's
brackets are four arcs, which turn into corners on the code they lock onto.

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(
    scanWindow: ScanWindow.centered(width: 0.6),
  ),
  theme: const ScannerTheme(windowShape: ScannerWindowShape.circle),
)
```

The shape is only drawn: the camera is decoded in the window's rectangle,
the `scanWindow`, whatever its shape. A square window
(`ScanWindow.centered(aspectRatio: 1)`, the default) makes a circle; a wider
one, an ellipse. `ScannerTheme.of(context).windowBorder` gives the shape in
use, for a window of your own.

### Motion

While the scanner searches, the brackets breathe slowly. `breathing: false`
keeps them still. `scanLine` adds a line that runs across the window, like
the laser of a till scanner:

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(
    scanWindow: ScanWindow.centered(width: 0.9, aspectRatio: 3),
  ),
  theme: const ScannerTheme(
    breathing: false,
    scanLine: ScanLine(
      color: Color(0xFFFF1A1A), // the accent by default
      thickness: 2,
      duration: Duration(milliseconds: 1600), // one pass
      style: ScanLineStyle.sweep, // or bounce: down and up
      inset: 12, // the margin inside the window
      glow: true, // a soft light around the line
    ),
  ),
)
```

The line runs inside the window only, in its shape, and only while the
scanner searches: it hides on a code, while the scanner is paused or under a
result sheet or a verdict, while another screen covers the scanner, and with
the system's reduce motion setting, which also stops the breathing.
`ScanLine.none` turns off a line set in a `ScannerScope` for one scanner.

::: tip Energy
The line and the breathing are drawn 30 times a second, on the same frames,
and nothing is drawn for them while the scanner does not search. The line
still costs some energy over a still window: measure your screen on your
devices, such as with Xcode's energy gauge or Android Studio's profiler, or
with `make perf` in the package's repository for its own templates
([Load and battery](../more/accuracy-and-speed#load-and-battery)).
:::

### The code in the window

The code found flies from where it is into the window and stays there under
the result sheet. By default it is drawn exactly once it lands, sharp
however fast the camera moved: a QR code, Data Matrix or Aztec code from
the modules the reader sampled, an EAN, UPC or ITF from its digits. The
other codes, such as Code 128 or PDF417, can be drawn in more than one way
and show the camera's picture: the sharpest of the frames read in the
moment after the code (the result does not wait for it), lightly
sharpened. The result sheet's thumbnail is pictured the same way
(`BarcodeThumbnail`).

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    windowPicture: ScannerWindowPicture.photo, // or exact, none
  ),
)
```

`photo` always shows the camera's picture, as it was cut out of the frame;
`none` leaves the camera in the window. `capture.snapshot()` gives the
camera's picture as cut out, not sharpened.

## Glass and sheets

The buttons, hints and title pills are glass: translucent and blurred over
the camera. `glass` gives them your colour, `sheet` the result sheets and
cards, and `sheetRadius` the sheets' corners:

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    brightness: Brightness.light,
    glass: Color(0xFFEAF0FF),
    sheet: Color(0xFFFFFFFF),
    sheetRadius: 16,
  ),
)
```

An opaque colour is drawn without the blur behind it, which is not seen
through it anyway and so costs nothing; a translucent one, such as
`Color(0xB30B3D91)`, keeps the blur unless `blur` is `false`. Every sheet of
the scanner is a `ScannerSheet` and takes both, as do your own. Text keeps
the theme's ink colours, dark on light glass: choose a `brightness` that
reads on your colour. `.glassColor` and `.sheetColor` give the colours in
use.

The codes in view are outlined in the accent, as when picking one of
several: `outline` and `outlineWidth` change it.

## Text styles

`fontFamily` sets the font of every text. `textStyles` changes single
styles: each is merged onto the built-in one, so set only what changes,
such as a size or a weight, and the rest stays, the font included.

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    fontFamily: 'Inter',
    textStyles: ScannerTextStyles(
      title: TextStyle(fontWeight: FontWeight.w800),
      hint: TextStyle(fontSize: 17),
      label: TextStyle(letterSpacing: 0.5),
    ),
  ),
)
```

| Style | Where |
|---|---|
| `title` | The titles of the sheets: a merchant, a network, a link's host |
| `display` | Large numbers, such as an amount |
| `overline` | The small capitals above a title ("LINK") |
| `body` | The text of the sheets; `muted` follows it |
| `muted` | Secondary text, such as a verdict's message |
| `hint` | The hint and title pills over the camera |
| `label` | Buttons |
| `data` | Barcode data; `chip` follows it |
| `chip` | The symbology chips ("QR Code") |

A colour set in a style replaces the theme's, except on buttons, whose
text takes the button's colour. `ScannerTheme.of(context).titleStyle` and
the other styles give the result, for a sheet of your own.

## Icons

The scanner draws its own line icons, so it needs no icon font. Give it
yours in an `icons` set, from any icon font: Material's, Cupertino's or one
your app bundles. Each icon you set replaces a built-in one; the others
stay.

```dart
BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    icons: ScannerIconSet(
      close: ScannerIconData.fromIconData(Icons.arrow_back),
      torchOn: ScannerIconData.fromIconData(Icons.flashlight_on),
      torchOff: ScannerIconData.fromIconData(Icons.flashlight_off),
      photo: ScannerIconData.fromIconData(Icons.photo_library_outlined),
      switchCamera: ScannerIconData.fromIconData(Icons.cameraswitch_outlined),
    ),
  ),
)
```

An icon of a font is drawn in the same 24-point box and colour as the
built-in ones. The set has every icon of the built-in widgets:

| Icon | Where |
|---|---|
| `close` | The close button, a sheet's close, and back from a photo to the camera |
| `torchOn`, `torchOff` | The torch button, on and off |
| `photo` | The photo button |
| `switchCamera` | The camera switch |
| `copy`, `copied` | The copy button of a result sheet, before and after copying |
| `show`, `hide` | Showing and hiding a secret, such as a Wi‑Fi password |
| `accept`, `warn`, `reject` | A check's verdict on a code |
| `card` | The badge of a loyalty card's number |
| `counter` | Before the counter of codes let in |
| `cameraOff`, `cameraError` | The error card, without camera access or when the camera failed |
| `scan` | The button of a `ScanFieldButton` |

Sets merge icon by icon: a set in a `ScannerScope` for the whole app, and
another for one scanner with a few icons of its own. Anywhere else a
scanner widget takes an icon, `ScannerButton`, `ScannerIcon`, a template's
`hintIcon` or `ScannerAction`, it takes one of a font too:

```dart
ScannerButton(
  icon: const ScannerIconData.fromIconData(Icons.help_outline),
  label: 'Help',
  onPressed: () {},
)
```

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

Subclass a built-in translation (`ScannerLocalizationsEn`, `…De`, `…Es`,
`…Fr`, `…Ru` or `…Zh`), override the texts to change and give it to a
`ScannerScope`, or to one scanner as `texts:`. The other texts stay as they
were.

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

Texts given this way are used in every language. For an app in several
languages, choose them by the app's locale, as in
[Another language](#another-language), and return `null` where the
built-in translation is right.

The hints and titles of the templates are texts too (`hintQrCode`,
`hintBarcode`, `hintTicket`, `titlePayment`, `titleTicket`…), so a template
speaks the app's language without changing the template.

### Another language

For a language the package does not have yet, subclass
`ScannerLocalizationsEn` with your language's code, override every text,
and choose it by the app's locale; `null` keeps the built-in translations
for the other languages:

```dart
class ItalianTexts extends ScannerLocalizationsEn {
  ItalianTexts() : super('it');

  @override
  String get close => 'Chiudi lo scanner';

  @override
  String get scanAgain => 'Scansiona di nuovo';

  @override
  String itemCount(int count) => count == 1 ? '1 codice' : '$count codici';

  // Dates: "14 nov 2026"; monthShort gives the month names.
  @override
  String dayMonthYear(int day, String month, int year) => '$day $month $year';

  // ... every other text
}

Widget scope(BuildContext context, Widget child) => ScannerScope(
  texts: switch (Localizations.localeOf(context).languageCode) {
    'it' => ItalianTexts(),
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
