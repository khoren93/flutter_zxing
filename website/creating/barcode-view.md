# Barcodes as widgets

`BarcodeView` draws a barcode as vectors, lined up with the screen's
pixels: sharp at any size. QR is the default format; a `BarcodeWriter` picks
another.

```dart
const BarcodeView('https://pub.dev', width: 200)

const BarcodeView(
  '4006381333931',
  writer: BarcodeWriter(BarcodeFormat.ean13), // digits under it by default
  width: 240,
)
```

<CodeGallery :items="[{ file: 'ean13.svg', label: 'BarcodeFormat.ean13', alt: 'An EAN-13 barcode with its digits under it' }, { file: 'datamatrix-gs1.png', label: 'dataMatrix, gs1: true', alt: 'A GS1 Data Matrix code' }, { file: 'pdf417.png', label: 'BarcodeFormat.pdf417', alt: 'A PDF417 code, as on a boarding pass' }]" />

The code is encoded in the background and cached. When the data changes,
the previous code stays on screen until the new one is ready, so it does
not flash.

## The writer

| `BarcodeWriter` | Default | What it does |
|---|---|---|
| `format` | | The symbology, one of `BarcodeFormat.writable` |
| `errorCorrection` | `medium` for QR, the format's own for others | `ErrorCorrection.low`, `medium`, `quartile` or `high`, for formats that have it |
| `version` | the smallest that fits | The symbol size, such as 1–40 for QR or 1–48 for Data Matrix |
| `gs1` | `false` | Encode GS1 data, written with the Application Identifiers in parentheses: `(01)09501101530003(17)250101` |
| `showText` | the format's custom | The digits under a linear barcode: on for EAN, UPC and ISBN |
| `zxingOptions` | none | zxing-cpp's own options, such as `'eci=UTF-8'`; a key here wins over the typed field it sets |

```dart
const BarcodeView(
  '(01)09501101530003(17)270101(10)AB12',
  writer: BarcodeWriter(BarcodeFormat.dataMatrix, gs1: true),
  width: 160,
)
```

The Create tab of the demo builds a code from what it holds, its format
and its style, reads the preview back to check that it scans, and exports
it as PNG or SVG:

<LiveDemo query="tab=create" label="The Create tab of the demo" />

## Errors

Data a format cannot hold, such as letters in an EAN-13 or a wrong check
digit, throws a `BarcodeWriteException` that says why: `Invalid check digit
'4', expecting '3'`. In a `BarcodeView` it shows `errorBuilder`, or an empty
box with the error reported to `FlutterError`:

```dart
BarcodeView(
  '12345',
  writer: const BarcodeWriter(BarcodeFormat.ean13),
  width: 240,
  errorBuilder: (context, error) => Text(error.message),
)
```

`format.input` describes what each format holds, with an example, for a
form: see [Formats](../formats#what-each-format-holds).

## A content

`BarcodeContentView` draws a [content](../content/overview), such as a
Wi‑Fi network or a payment, with what its standard requires: a Swiss
QR-bill gets error correction M and the Swiss cross, GS1 data is encoded
as GS1. A content with problems, such as a wrong IBAN, shows
`errorBuilder` with the reason instead of a code.

```dart
Widget guestWifi() => BarcodeContentView(
  const WifiContent(ssid: 'Guests', password: 'welcome-2026'),
  width: 200,
  errorBuilder: (context, error) => Text(error.message),
);
```

See [Payments](../content/payments#create-a-payment-code) and
[Building content](../content/building#encoding-any-kind).

## Binary data and read symbols

`BarcodeView.bytes` encodes bytes, for formats with a byte mode (QR, Data
Matrix, Aztec, PDF417). `BarcodeView.symbol` draws a symbol as it is, such
as the grid a scanned code was read from: nothing is encoded, so the code
shown is exactly the one read.

```dart
Widget binary(Uint8List data) => BarcodeView.bytes(data, width: 200);

Widget asRead(Barcode barcode) {
  final BarcodeSymbol? symbol = barcode.symbol;
  return symbol == null ? const SizedBox() : BarcodeView.symbol(symbol, width: 56);
}
```

## Accessibility

A `BarcodeView` is announced by its format's name, its title and caption,
and the digits under a linear barcode: never by the encoded data, which may
be a password or bank details. `semanticLabel` replaces the label.

## On paper

To print many codes at once, on A4, Letter or label paper, see
[Label sheets](./label-sheets).
