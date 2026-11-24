# Label sheets

`BarcodeLabelSheet` puts a list of data on pages to print: one code with
its text on each label, in a fixed grid of columns and rows. You get the
pages as one PDF or as SVG documents, in millimetres, so they print at
their real size. The codes are vectors, black on white unless you give
them a [style](#styled-codes).

```dart
Future<void> printLabels(List<String> skus, Directory dir) async {
  const sheet = BarcodeLabelSheet(
    paper: PaperSize.a4,
    columns: 3,
    rows: 8,
    writer: BarcodeWriter(BarcodeFormat.code128),
  );
  final Uint8List pdf = await sheet.pdf(skus);
  await File('${dir.path}/labels.pdf').writeAsBytes(pdf);
}
```

Print the file at 100 % (actual size), not "fit to page", or the codes
miss the labels.

## Paper

`PaperSize` is a sheet in millimetres. There are `PaperSize.a3`, `a4`,
`a5`, `letter` and `legal`; give any other size to the constructor, and
turn a sheet on its side with `landscape`:

```dart
const PaperSize a6 = PaperSize(105, 148);
final PaperSize wide = PaperSize.a4.landscape; // 297 x 210 mm
```

## Layout

Measure your label paper, or copy the numbers from its box. All lengths
are in millimetres.

| Setting | Default | What it is |
|---|---|---|
| `paper` | `PaperSize.a4` | The page |
| `columns`, `rows` | required | Labels across and down a page |
| `margin` | `EdgeInsets.all(10)` | The blank edge of the page; give each side its own with `EdgeInsets.fromLTRB` |
| `columnGap`, `rowGap` | `0` | Space between labels side by side, and one above the other |
| `padding` | `2` | The blank edge inside each label |
| `caption` | `true` | A line of text under each code |
| `captionSize` | `3` | The height of that line (3 mm is about 8.5 pt) |
| `codeSize` | `null` | The longer side of each code in millimetres, centred on its label with the caption; `null` as large as the label allows |
| `writer` | QR code | The format, error correction and the rest |
| `style` | `BarcodeStyle.classic` | How the codes are drawn: see [Styled codes](#styled-codes) |
| `order` | `LabelOrder.rows` | The order the items fill the pages in: see [Order](#order) |

In each label the code is as large as fits above the caption, keeping its
proportions, and the two are centered. A caption too long for its label
gets smaller.

The caption is the item itself; `captionText` gives other text, such as a
product name. Turn captions off for EAN-13, UPC-A and the other retail
codes: they print their digits under the bars themselves.

```dart
Future<Uint8List> shelfLabels(Map<String, String> products) {
  const sheet = BarcodeLabelSheet(
    paper: PaperSize.letter,
    columns: 3,
    rows: 10,
    margin: EdgeInsets.fromLTRB(4.8, 12.7, 4.8, 12.7),
    columnGap: 3.2,
  );
  return sheet.pdf(
    products.keys,
    captionText: (String sku) => products[sku]!,
  );
}
```

`labelsPerPage`, `pageCount(items)`, `labelSize` and `labelRect(slot)`
give the grid, for a preview of your own or to print something next to
the codes. `itemAt(page, slot, total)` names the item on a label, in any
order, and `slotOf(index, total)` finds where an item goes.

## Order

`order` says where the next item goes. With 3 columns, 4 rows and 24
items on two pages:

| `order` | Page 1 | Page 2 | For |
|---|---|---|---|
| `LabelOrder.rows` | 1–12, left to right, then the next row | 13–24 | The default |
| `LabelOrder.columns` | 1–12, top to bottom, then the next column | 13–24 | One sheet cut into column strips, or labels stacked in order |
| `LabelOrder.columnStrips` | column 1: 1–4, column 2: 9–12, column 3: 17–20 | column 1: 5–8, column 2: 13–16, column 3: 21–24 | A stack of sheets cut into columns |
| `LabelOrder.rowStrips` | row 1: 1–3, row 2: 7–9, … | row 1: 4–6, row 2: 10–12, … | A stack of sheets cut into rows |

With `columnStrips` a column runs on through every page before the next
column starts: print the stack, cut it into strips, and each strip, page
after page, holds its items in order. The item at column `c`, row `r` of
page `p` is `c × rows × pages + p × rows + r`. When the items do not fill
the last pages, the blank labels are at the ends of the columns.

The strip orders need the number of items first, and each item by its
place: give them a `List`, such as `SerialItems` or `BarcodeItems`. Any
other `Iterable` is read into a list, all its items in memory at once.

## Styled codes

`style` takes the [`BarcodeStyle`](./styles) of `BarcodeView`, and the
preview, the PDF and the SVG draw the codes with it:

```dart
Future<Uint8List> brandedLabels(List<String> urls) {
  final sheet = BarcodeLabelSheet(
    columns: 3,
    rows: 8,
    style: BarcodeStyle.dots.copyWith(
      logo: () => const BarcodeLogo(AssetImage('assets/logo.png')),
    ),
  );
  return sheet.pdf(urls);
}
```

The code part of the style applies: `color`, `gradient`, `moduleShape`,
`finderShape`, `quietZone` and `logo`. A label is white paper, so a
`backgroundColor` other than white fills the code's box, its quiet zone
included. The style's `title`, `caption` and `card` are not drawn: the
sheet has its own caption.

Under a logo each item is encoded with the error correction the logo
needs, as `BarcodeView` does. The logo is loaded once for the whole
sheet, sharp at 300 dpi, and is in the PDF once however many labels show
it (in an SVG, once a page). A logo that cannot load stops the sheet with
an `ArgumentError` before the first page.

In the PDF the module shapes are vector paths, a `LinearGradient` or
`RadialGradient` is a real PDF gradient across each code, and colors are
opaque. A gradient's `TileMode.repeated` and `mirror` extend its end
colors there. A `SweepGradient` cannot be drawn in the files: `pdf` and
`svgPages` throw an `UnsupportedError` for it.

Rounded modules and dots take more room than squares: 10 000 QR codes
make a PDF of about 17 MB with dots and 29 MB with rounded modules, in
7 to 10 seconds on a laptop (squares: under 3 MB in about 2.5 seconds).

## PDF or SVG

`pdf` gives one document with every page: rectangles for the modules and
the built-in Courier font for the text, so it needs no fonts and opens
everywhere. Its text is Latin-1 (English and Western European letters);
any other character is printed as `?`.

`svgPages` gives one SVG document a page, each in millimetres
(`width="210mm"` for A4). SVG holds text in any script; the program that
shows the file picks a monospace font.

```dart
Future<void> savePages(List<String> items, Directory dir) async {
  const sheet = BarcodeLabelSheet(columns: 4, rows: 10);
  int n = 0;
  await for (final String page in sheet.svgPages(items)) {
    await File('${dir.path}/labels-${++n}.svg').writeAsString(page);
  }
}
```

## Large batches

Both encode the items a page at a time, so a list of 10 000 never holds
all its codes at once. 10 000 QR codes make a PDF of about 1.2 MB in about
1.5 seconds on a laptop (compressed on Android, iOS and desktop; on the
web the PDF is not compressed and a few times larger). `onProgress` tells
you how far it is:

```dart
Future<Uint8List> withProgress(List<String> items) {
  const sheet = BarcodeLabelSheet(columns: 4, rows: 10);
  return sheet.pdf(
    items,
    onProgress: (int done, int total) => print('$done of $total labels'),
  );
}
```

An item the format cannot hold, such as letters in an EAN-13, stops the
whole sheet with a `BarcodeWriteException` that names the item and its
index: a sheet never prints with a label silently missing. Check your
data first with `BarcodeWriter.checkItems`, and make numbered items or
read them from a CSV file with the helpers in [Many codes](./batches).

## Preview

`BarcodeLabelSheetView` shows one page: white paper at the page's
proportions, as wide as it may be, with each code and caption where the
PDF puts them.

```dart
Widget preview(BarcodeLabelSheet sheet, List<String> items, int page) =>
    BarcodeLabelSheetView(sheet: sheet, items: items, page: page);
```

The Use cases page has the whole [sheet of labels](../use-cases#a-sheet-of-labels):
a QR or Code 128 switch, the preview with page buttons, and sharing the
PDF.
