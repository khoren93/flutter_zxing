# Colours and texts

Every scanner reads a `ScannerTheme` for its colours and shapes and a
`ScannerStrings` for its texts. Set them on one scanner, or once for the
whole app.

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
| `blur` | on, off when the device is too slow | Whether the glass blurs the camera behind it. Left unset, the scanner stops blurring for good when more than one frame in ten takes over 16 ms; `true` blurs always, `false` never |
| `scrimBlur` | on, off when the device is too slow | Whether the dimmed camera around the window is blurred too; it is computed again for every frame. Unset, `true` and `false` work as for `blur` |
| `fontFamily` | the app's | Font of the scanner's text |
| `monoFontFamily` | a monospaced system font | Font of barcode data |
| `warning` | amber | A code that needs a look (`ScanVerdict.warn`) |
| `danger` | a bright red | A refused code (`ScanVerdict.reject`) and problems such as an expired date |

## The whole app

A `ScannerScope` gives every scanner below it, `scanBarcode` and
`ScanFieldButton` included, a theme and texts. Put it in your app's
`builder` to follow its colours and language:

```dart
MaterialApp(
  builder: (context, child) => ScannerScope(
    theme: ScannerTheme(
      accent: Theme.of(context).colorScheme.primary,
      brightness: Theme.of(context).brightness,
    ),
    strings: const ScannerStrings(close: 'Scanner schließen', scanAgain: 'Weiter'),
    child: child!,
  ),
)
```

A template's theme applies over the scope's, and the scanner's own `theme`
and `strings` over both.

## Texts and languages

`ScannerStrings` holds every text of the scanner in English: buttons, hints,
errors, the result sheet and the template titles. Translate the ones your
app shows; the rest stay English.

```dart
const ScannerStrings german = ScannerStrings(
  close: 'Schließen',
  torchOn: 'Licht an',
  torchOff: 'Licht aus',
  scanAgain: 'Weiter scannen',
  copy: 'Kopieren',
  hintQrCode: 'Auf einen QR-Code richten',
);

final ScannerStrings mine = german.copyWith(close: 'Zurück');
```

The hints and titles of the templates are strings too (`hintQrCode`,
`hintBarcode`, `hintTicket`, `titlePayment`, `titleTicket`…), so a template
speaks the app's language without changing the template.
