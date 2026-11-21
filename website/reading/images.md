# Read an image

`BarcodeReader` reads image files (PNG, JPEG, GIF, BMP, WebP and anything
else Flutter decodes) and raw pixel buffers, on every platform, without a
camera. Reading runs on a background isolate, or in a Web Worker on the web.

```dart
Future<void> readPhoto(Uint8List bytes) async {
  const reader = BarcodeReader();
  final Barcode? first = await reader.read(bytes); // stops at the first code
  final List<Barcode> all = await reader.readAll(bytes); // every code
  print('${first?.text}, ${all.length} codes in the image');
}
```

"Not found" is `null` or an empty list. Exceptions are for errors only, all
subclasses of the sealed `ZxingException`:

- `ImageDecodeException`: the bytes are not an image Flutter decodes, or the
  image is over 128 megapixels or 65535 pixels a side. Such an image is
  refused before it is decoded: a small file can declare an image of
  gigabytes.
- `EngineException`: the engine failed.

Transparent pixels count as white, so a code on a transparent background
reads. `readAll(bytes, maxBarcodes: 5)` stops after five codes.

## A photo the user picks

`image_picker` comes with the package:

```dart
import 'package:image_picker/image_picker.dart';

Future<Barcode?> pickAndRead() async {
  final XFile? file = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (file == null) return null;
  return const BarcodeReader().read(await file.readAsBytes());
}
```

In a scanner, the photo button of the templates does this for you, and
`ScannerController.readImage` reads a photo like a camera frame: see
[The controller](../scanning/controller#photos-and-frames).

## Raw pixels

`readPixels` and `readAllPixels` read frames from anywhere else: video, a
network stream, another camera plugin, a rendered widget.

```dart
Future<Barcode?> readFrame(Uint8List yPlane, int width, int height, int stride) {
  const reader = BarcodeReader(options: ReaderOptions.camera());
  return reader.readPixels(
    PixelBuffer(yPlane, width: width, height: height, rowStride: stride),
  );
}
```

| `PixelBuffer` | What it is |
|---|---|
| `bytes`, `width`, `height` | The pixels; not copied until they go to the engine |
| `layout` | `PixelLayout.luminance` (one byte, the Y plane of YUV; the default), `rgb`, `rgba` or `bgra` |
| `rowStride` | Bytes per row, when rows are padded |
| `crop` | Only search this region, in pixels; positions stay relative to the whole buffer |

A `dart:ui` image, such as a widget rendered with a `RepaintBoundary`:

```dart
Future<List<Barcode>> readUiImage(ui.Image image) async {
  final ByteData? rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return const BarcodeReader().readAllPixels(
    PixelBuffer(
      rgba!.buffer.asUint8List(),
      width: image.width,
      height: image.height,
      layout: PixelLayout.rgba,
    ),
  );
}
```

## What a barcode holds

| `Barcode` | What it is |
|---|---|
| `text` | The payload as text: UTF-8, or the character set the code declares. GS1 codes read as `(01)09501101530003(17)250101`. |
| `bytes` | The raw payload bytes |
| `format` | The symbology, as specific as known, such as `BarcodeFormat.ean13` |
| `content` | What the text means: a link, Wi-Fi, a payment… See [What is in a code](../content/overview). |
| `contentType` | `text`, `binary`, `mixed`, `gs1`, `iso15434` or `unknownEci` |
| `position` | The four corners in pixels of the image, with `bounds` and `center` |
| `rotation` | Clockwise rotation in degrees, from -180 to 180 |
| `isMirrored`, `isInverted` | Found mirrored, or light on dark |
| `ecLevel`, `version` | Error correction and symbol version in the format's own terms, such as `M` and `4` for a QR code |
| `symbologyIdentifier` | The ISO/IEC 15424 identifier, such as `]Q1` |
| `sequence` | The part of a structured append message, below |
| `symbol` | The grid of modules a matrix code was read from |

For binary content the `text` is for display: characters that cannot be
shown are escaped (`<NUL>`, `<U+80>`). Use `bytes` for the data itself.

The position of a code in a JPEG photo is in the pixels as the file stores
them: the EXIF orientation is not applied.

## One message in several codes

A structured append message is split across several codes, such as QR,
Data Matrix, Aztec or PDF417; each part has a `sequence`. `merge` joins them, in any
order, once every part is there:

```dart
Future<void> readMessage(Uint8List bytes) async {
  const reader = BarcodeReader();
  final Barcode? message = await reader.merge(await reader.readAll(bytes));
  print(message?.text ?? 'Some parts are missing');
}
```

The parts can come from one image or from several camera frames. A
character set one part declares carries over to the next.
