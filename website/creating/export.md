# PNG, SVG and images

## Black on white

`BarcodeWriter` exports a code as a PNG, an SVG or a grayscale image, black
on white:

```dart
Future<void> save(Directory dir) async {
  const writer = BarcodeWriter(BarcodeFormat.qrCode);
  final Uint8List png = await writer.toPng('https://pub.dev', size: 512);
  final String svg = await writer.toSvg('https://pub.dev');
  await File('${dir.path}/qr.png').writeAsBytes(png);
  await File('${dir.path}/qr.svg').writeAsString(svg);
}
```

`size` is the longer side in pixels; `moduleSize` sets the pixels per module
instead (4 by default for SVG). Give one of them, not both. `quietZone:
false` leaves the blank margin out. An SVG is one path, crisp at any size:
its `viewBox` is in modules, its `width` and `height` in pixels.

## With a style

`BarcodeStyle` exports PNG and SVG with the same look as on screen: colours,
shapes, logo, title, caption and card. Around a card, the PNG is
transparent. In an SVG the text is `<text>` with the font named; the
program that shows the file picks the closest font it has.

```dart
Future<void> share() async {
  const writer = BarcodeWriter(BarcodeFormat.qrCode);
  const style = BarcodeStyle.lagoon;
  final Uint8List png = await style.encodePng(writer, 'https://pub.dev', size: 1024);
  final String svg = await style.encodeSvg(writer, 'https://pub.dev');
  print('${png.length} bytes of PNG, ${svg.length} characters of SVG');
}
```

To draw one code several times, encode it once with `style.encode` and draw
the symbol with `style.toPng` and `style.toSvg`. The export loads the
logo's image itself, sharp enough for the size asked.

## In an SVG of your own

`toSvgElement` gives a code as an element of a larger SVG, such as a page
of labels to print: a nested `<svg>` at `x`, `y` that fits `width` by
`height`, in the units of the page around it. A page in millimetres prints
at its real size.

```dart
Future<String> labelPage(List<String> items) async {
  const writer = BarcodeWriter(BarcodeFormat.qrCode);
  final page = StringBuffer(
    '<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" '
    'viewBox="0 0 210 297"><rect width="100%" height="100%" fill="#fff"/>',
  );
  for (final (i, item) in items.take(32).indexed) {
    final BarcodeSymbol symbol = await writer.encode(item);
    // 4 columns of 30 mm codes, 50 mm apart.
    page.write(symbol.toSvgElement(
      x: 10 + (i % 4) * 50,
      y: 10 + (i ~/ 4) * 35,
      width: 30,
    ));
  }
  page.write('</svg>');
  return page.toString();
}
```

The Use cases page has a whole [sheet of labels](../use-cases#a-sheet-of-labels).

## The modules themselves

`encode` gives the symbol: its size in modules and whether each module is
dark, to draw it yourself or hand it to a printer.

```dart
Future<void> modules() async {
  final BarcodeSymbol symbol = await const BarcodeWriter(BarcodeFormat.dataMatrix)
      .encodeBytes(Uint8List.fromList([0x00, 0x01, 0xFE, 0xFF]));
  for (int y = 0; y < symbol.height; y++) {
    print(List.generate(symbol.width, (x) => symbol.isDark(x, y) ? '█' : ' ').join());
  }
}
```

`BarcodeSymbol` also has its `format`, `quietZone` in modules, the `text`
under a linear barcode and the `errorCorrection` it was made with, and
renders itself with `toPng`, `toSvg` and `toImage`.

## Any kind of content

`writer.encodeContent` encodes a parsed or built content: text kinds as
text, `Gs1Content` in GS1 mode and `BinaryContent` as bytes. See
[Building content](../content/building#encoding-any-kind).
