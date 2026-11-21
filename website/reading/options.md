# Reader options

`ReaderOptions` sets how hard the engine looks for codes. The defaults suit
photos and files: every search strategy is on. `ReaderOptions.camera()`,
the default of the scanner, leaves out light-on-dark codes, so each camera
frame takes less work.

```dart
const photos = BarcodeReader(); // ReaderOptions()
const frames = BarcodeReader(options: ReaderOptions.camera());
const pure = BarcodeReader(
  formats: {BarcodeFormat.qrCode},
  options: ReaderOptions(isPure: true),
);
```

| Option | Default | What it does |
|---|---|---|
| `tryHarder` | `true` | Spend more time to find codes in difficult images |
| `tryRotate` | `true` | Also look for codes turned by 90°, 180° and 270° |
| `tryInvert` | `true`, `false` in `camera()` | Also look for light-on-dark codes |
| `tryDownscale` | `true` | Also search a smaller copy of large images; finds big, blurry codes |
| `isPure` | `false` | The image is exactly one clean, unrotated, tightly cropped code |
| `returnErrors` | `false` | Also return codes that were found but could not be decoded, with their `error` |
| `validateOptionalChecksum` | `false` | Check the optional checksums of Code 39 and ITF, and drop codes that fail |
| `binarizer` | `Binarizer.localAverage` | How the image turns black and white, below |
| `minLineCount` | 2 | For linear codes, how many scan lines must agree; more means fewer false reads on noisy images |
| `eanAddOn` | `EanAddOn.ignore` | The EAN-2/EAN-5 add-on next to some EAN and UPC codes, below |
| `characterSet` | none | The character set of codes that declare none, below |

`copyWith` changes some fields of a set:

```dart
final ReaderOptions dark = const ReaderOptions.camera().copyWith(tryInvert: true);
```

## Binarizer

| `Binarizer` | For |
|---|---|
| `localAverage` | A threshold from the neighbourhood of each pixel; best for uneven light. The default. |
| `globalHistogram` | One threshold from the histogram; fast, for even light |
| `fixedThreshold` | A fixed threshold at mid grey |
| `boolCast` | Any non-zero pixel is light; for images that are black and white already |

## EAN and UPC add-ons

Books carry the price and magazines the issue in a small EAN-5 or EAN-2
code next to the main one.

| `EanAddOn` | What happens |
|---|---|
| `ignore` | Read the main code only, whether or not there is an add-on. The default. |
| `read` | Append the add-on to the text when there is one |
| `require` | Report EAN and UPC codes only together with an add-on |

## Character sets

A code can declare its character set with an ECI. For one that does not,
the engine guesses the set from the bytes, which can go wrong for short
texts: old labels in Windows-1251 or Shift_JIS then read as garbled text.
Name the set the codes of your app use:

```dart
const reader = BarcodeReader(
  options: ReaderOptions(characterSet: CharacterSet.cp1251),
);
```

`CharacterSet` has 32 sets, from ISO-8859 and the Windows code pages to
Shift_JIS, Big5, GB18030, EUC-KR and UTF-16. It applies only to codes that
declare no character set.

## Formats

The formats are a separate setting of the reader and of the controller, not
an option: see [Formats](../formats#choosing-formats).
