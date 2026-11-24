# Formats

flutter_zxing reads 32 formats and creates 30, with one `BarcodeFormat`
list for both, the same on every platform.

| Linear product | Linear industrial | Matrix |
|---|---|---|
| EAN-13, EAN-8 | Code 128 | QR Code |
| UPC-A, UPC-E | Code 39 (Standard, Extended) | Micro QR Code |
| EAN-2, EAN-5 add-ons ᴬ | Code 32, PZN | rMQR Code |
| ISBN ᶜ | Code 93 | Data Matrix |
| DataBar, DataBar Limited | Codabar | Aztec, Aztec Rune |
| DataBar Expanded | ITF, ITF-14 ᴿ | PDF417, MicroPDF417 |
| | Telepen | MaxiCode ᴿ |
| | DX Film Edge | |

ᴿ read only. ᴬ read with their EAN-13, EAN-8, UPC-A or UPC-E
(`ReaderOptions(eanAddOn:)`). ᶜ created only; an ISBN reads as EAN-13.

Micro QR, rMQR, DataBar Expanded and Limited, MaxiCode, MicroPDF417, DX Film
Edge and Telepen are formats that ML Kit does not read.

MaxiCode is read from clean images only (a code without background, not
skewed), not from the camera: a limit of zxing-cpp.

## Choosing formats

Every reader takes a set of formats; `null` reads all of them. Fewer formats
decode faster and never mistake one symbology for another.

```dart
const reader = BarcodeReader(formats: {BarcodeFormat.qrCode, BarcodeFormat.ean13});

final controller = ScannerController(formats: BarcodeFormat.retail);
```

| Set | Formats |
|---|---|
| `BarcodeFormat.linear` | Every linear format |
| `BarcodeFormat.matrix` | Every matrix format |
| `BarcodeFormat.retail` | EAN/UPC and DataBar |
| `BarcodeFormat.industrial` | Code 128, Code 39, ITF, Data Matrix, PDF417 |
| `BarcodeFormat.writable` | Every format that can be created, for a format picker |

A format that cannot be read in a reader's set, such as `isbn`, throws an
`ArgumentError`: `format.canRead` and `format.canWrite` say what each format
does.

## What each format holds

`format.input` describes the data a format takes, with an example, for a
form or a hint. It is `null` for formats that cannot be created.

```dart
final BarcodeInput? input = BarcodeFormat.ean13.input;
print(input?.description); // what the format holds, in a few words
print(input?.example); // 9501101530003
print(input?.digitsOnly); // true: show a numeric keyboard
```

Data a format cannot hold throws a `BarcodeWriteException` that says why,
such as `Invalid check digit '4', expecting '3'`.

## The engine

zxing-cpp 3.2.0. `zxingCppVersion` gives the version at run time.
