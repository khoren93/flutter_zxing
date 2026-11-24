import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../barcode/barcode_format.dart';
import '../errors.dart';
import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_style.dart';
import 'barcode_view.dart';
import 'label_sheet_output.dart';
import 'logo_symbol.dart';
import 'symbol_shapes.dart';

/// A sheet of paper, in millimetres.
///
/// ```dart
/// const PaperSize a6 = PaperSize(105, 148);
/// final PaperSize wide = PaperSize.a4.landscape; // 297 x 210 mm
/// ```
@immutable
final class PaperSize {
  /// A sheet [width] x [height] millimetres.
  const PaperSize(this.width, this.height)
    : assert(width > 0 && height > 0, 'The paper must have a size');

  /// ISO A3: 297 x 420 mm.
  static const PaperSize a3 = PaperSize(297, 420);

  /// ISO A4: 210 x 297 mm.
  static const PaperSize a4 = PaperSize(210, 297);

  /// ISO A5: 148 x 210 mm.
  static const PaperSize a5 = PaperSize(148, 210);

  /// US Letter: 8.5 x 11 inches.
  static const PaperSize letter = PaperSize(215.9, 279.4);

  /// US Legal: 8.5 x 14 inches.
  static const PaperSize legal = PaperSize(215.9, 355.6);

  /// Width in millimetres.
  final double width;

  /// Height in millimetres.
  final double height;

  /// The same paper turned on its side: the longer side across.
  PaperSize get landscape => width >= height ? this : PaperSize(height, width);

  @override
  bool operator ==(Object other) =>
      other is PaperSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'PaperSize($width x $height mm)';
}

/// The order in which a [BarcodeLabelSheet] fills its pages with labels.
///
/// On a sheet of 3 columns and 4 rows, 24 items take two pages:
///
/// | Order | Page 1 | Page 2 |
/// |---|---|---|
/// | [rows] | 1–12, row by row | 13–24 |
/// | [columns] | 1–12, column by column | 13–24 |
/// | [columnStrips] | column 1: 1–4, column 2: 9–12, column 3: 17–20 | column 1: 5–8, column 2: 13–16, column 3: 21–24 |
/// | [rowStrips] | row 1: 1–3, row 2: 7–9, … | row 1: 4–6, row 2: 10–12, … |
enum LabelOrder {
  /// Row by row: the next item is to the right, then the next row starts
  /// at the left; then the next page. The default.
  rows,

  /// Column by column: the next item is below, then the next column
  /// starts at the top; then the next page. For a single sheet cut into
  /// column strips or labels stacked in order.
  columns,

  /// For a stack of sheets cut into columns: down the first column of
  /// page 1, then the same column of page 2 and every page after it, then
  /// the second column, from page 1 again. Each cut strip, stacked in page
  /// order, keeps its items in order.
  ///
  /// The item at column `c`, row `r` of page `p` is
  /// `c * rows * pages + p * rows + r`, with `pages` the
  /// [BarcodeLabelSheet.pageCount] of all the items. The files and the
  /// preview need the number of items first: an [Iterable] that is not a
  /// [List] is read into one, all its items in memory at once.
  columnStrips,

  /// For a stack of sheets cut into rows: along the first row of page 1,
  /// then the same row of page 2 and every page after it, then the second
  /// row. As [columnStrips], with rows for columns.
  rowStrips;

  /// Whether a page fills down its columns first.
  bool get _down => this == columns || this == columnStrips;

  /// Whether a column or row runs through all the pages.
  bool get _strips => this == columnStrips || this == rowStrips;
}

/// Pages of labels to print: a code with its text on each label, in a
/// fixed grid of [columns] x [rows] on [paper].
///
/// Give it the data, one item a label, and get the pages as a PDF or as
/// SVG documents in millimetres, which print at their real size. The codes
/// are vectors, black on white unless you give a [style]. Items are
/// encoded page by page, so a list of 10 000 never holds all its codes at
/// once.
///
/// ```dart
/// const sheet = BarcodeLabelSheet(
///   paper: PaperSize.a4,
///   columns: 3,
///   rows: 8,
///   writer: BarcodeWriter(BarcodeFormat.code128),
/// );
/// final Uint8List pdf = await sheet.pdf(['SKU-0001', 'SKU-0002', 'SKU-0003']);
/// ```
///
/// Measure your label paper: [margin] is the blank edge of the sheet,
/// [columnGap] and [rowGap] the space between labels, [padding] the blank
/// edge inside each label. Show a page on screen with
/// [BarcodeLabelSheetView].
///
/// Draw the codes with a [BarcodeStyle], as `BarcodeView` does:
///
/// ```dart
/// final sheet = BarcodeLabelSheet(
///   columns: 3,
///   rows: 8,
///   style: BarcodeStyle.soft.copyWith(
///     logo: () => const BarcodeLogo(AssetImage('assets/logo.png')),
///   ),
/// );
/// ```
@immutable
final class BarcodeLabelSheet {
  /// Creates a sheet layout. All lengths are in millimetres.
  const BarcodeLabelSheet({
    required this.columns,
    required this.rows,
    this.paper = PaperSize.a4,
    this.margin = const EdgeInsets.all(10),
    this.columnGap = 0,
    this.rowGap = 0,
    this.padding = 2,
    this.caption = true,
    this.captionSize = 3,
    this.codeSize,
    this.writer = const BarcodeWriter(BarcodeFormat.qrCode),
    this.style = BarcodeStyle.classic,
    this.order = LabelOrder.rows,
  }) : assert(columns > 0 && rows > 0, 'A sheet needs a column and a row'),
       assert(columnGap >= 0 && rowGap >= 0, 'Gaps cannot be negative'),
       assert(padding >= 0, 'The padding cannot be negative'),
       assert(captionSize > 0, 'The caption needs a size'),
       assert(codeSize == null || codeSize > 0, 'A code needs a size');

  /// The size of a page.
  final PaperSize paper;

  /// Labels across a page.
  final int columns;

  /// Labels down a page.
  final int rows;

  /// The blank edge of the page around the labels, in millimetres.
  final EdgeInsets margin;

  /// Space between two labels side by side, in millimetres.
  final double columnGap;

  /// Space between two labels one above the other, in millimetres.
  final double rowGap;

  /// The blank edge inside a label, around the code and its caption, in
  /// millimetres.
  final double padding;

  /// Whether a line of text goes under each code: the item itself, or
  /// what `captionText` gives for it. Turn it off for EAN-13, UPC-A and
  /// the other retail codes, which print their digits under the bars.
  final bool caption;

  /// The height of the caption's line, in millimetres (3 mm is about
  /// 8.5 pt). A caption too long for the label gets smaller to fit.
  final double captionSize;

  /// The longer side of each code, its quiet zone included, in
  /// millimetres: a 20 mm QR code on a larger label, centred with its
  /// caption. `null` makes each code as large as its label allows; a size
  /// larger than that is cut down to it.
  final double? codeSize;

  /// Encodes the items: the format, error correction and the rest. A QR
  /// code by default.
  final BarcodeWriter writer;

  /// How the codes are drawn: on the preview, in the SVG and in the PDF
  /// alike. Black squares by default ([BarcodeStyle.classic]).
  ///
  /// The code part of the style applies: [BarcodeStyle.color],
  /// [BarcodeStyle.gradient], [BarcodeStyle.moduleShape],
  /// [BarcodeStyle.finderShape], [BarcodeStyle.quietZone] and
  /// [BarcodeStyle.logo]. Under a logo each item is encoded with the error
  /// correction the logo needs, as `BarcodeView` and [BarcodeStyle.encode]
  /// do. The label is white paper: a [BarcodeStyle.backgroundColor] other
  /// than white fills the code's box, its quiet zone included. The style's
  /// [BarcodeStyle.title], [BarcodeStyle.caption] and [BarcodeStyle.card]
  /// are not drawn: the sheet has its own [caption].
  ///
  /// The PDF draws the module shapes as vector paths, a [LinearGradient] or
  /// [RadialGradient] as a PDF shading and the logo as one image the whole
  /// file shares. PDF colors are opaque, and a gradient's
  /// [TileMode.repeated] and [TileMode.mirror] extend its end colors. A
  /// [SweepGradient] cannot be drawn in the files: [pdf] and [svgPages]
  /// throw an [UnsupportedError] for it.
  final BarcodeStyle style;

  /// The order the items fill the pages in: row by row (the default),
  /// column by column ([LabelOrder.columns]: the next item is below), or
  /// a column through all the pages before the next
  /// ([LabelOrder.columnStrips], for a stack of sheets cut into columns;
  /// [LabelOrder.rowStrips] for rows). The files and the preview follow
  /// it; [itemAt] and [slotOf] map an item to its label.
  final LabelOrder order;

  /// Labels on one page.
  int get labelsPerPage => columns * rows;

  /// Pages that [items] labels take.
  int pageCount(int items) => (items / labelsPerPage).ceil();

  /// The size of a label, in millimetres.
  Size get labelSize => Size(
    (paper.width - margin.horizontal - (columns - 1) * columnGap) / columns,
    (paper.height - margin.vertical - (rows - 1) * rowGap) / rows,
  );

  /// Where label [slot] is on its page, in millimetres from the top left
  /// corner. Slots count the labels of a page in [order]'s direction: row
  /// by row, left to right, for [LabelOrder.rows] and
  /// [LabelOrder.rowStrips]; column by column, top to bottom, for
  /// [LabelOrder.columns] and [LabelOrder.columnStrips].
  ///
  /// With [LabelOrder.rows] and [LabelOrder.columns] the slot of item `i`
  /// is `i` itself: item `labelsPerPage` starts the next page at the same
  /// place as item 0. With the strip orders an item's page and slot depend
  /// on the number of items: see [slotOf].
  ///
  /// Throws [ArgumentError] if [slot] is negative or the margins and gaps
  /// leave no room for the labels.
  Rect labelRect(int slot) {
    if (slot < 0) {
      throw ArgumentError.value(slot, 'slot', 'cannot be negative');
    }
    final Size size = labelSize;
    if (size.width <= 0 || size.height <= 0) {
      throw ArgumentError(
        'The margins and gaps leave no room for $columns x $rows labels '
        'on $paper',
      );
    }
    final int i = slot % labelsPerPage;
    final (int column, int row) = order._down
        ? (i ~/ rows, i % rows)
        : (i % columns, i ~/ columns);
    return Rect.fromLTWH(
      margin.left + column * (size.width + columnGap),
      margin.top + row * (size.height + rowGap),
      size.width,
      size.height,
    );
  }

  /// The index of the item on label [slot] (see [labelRect]) of [page],
  /// both from 0, when the sheet holds [total] items; `null` for a blank
  /// label: past the last item, or on a page past the last.
  ///
  /// ```dart
  /// const sheet = BarcodeLabelSheet(
  ///   columns: 3,
  ///   rows: 4,
  ///   order: LabelOrder.columnStrips,
  /// );
  /// sheet.itemAt(1, 0, 24); // 4: the fifth item tops column 1 of page 2
  /// sheet.itemAt(0, 4, 24); // 8: column 2 of page 1 starts with the ninth
  /// ```
  ///
  /// Throws [ArgumentError] if [slot] is not on a page or [page] or
  /// [total] is negative.
  int? itemAt(int page, int slot, int total) {
    if (slot < 0 || slot >= labelsPerPage) {
      throw RangeError.range(slot, 0, labelsPerPage - 1, 'slot');
    }
    if (page < 0) {
      throw ArgumentError.value(page, 'page', 'cannot be negative');
    }
    if (total < 0) {
      throw ArgumentError.value(total, 'total', 'cannot be negative');
    }
    final int pages = pageCount(total);
    if (page >= pages) {
      return null;
    }
    final int index;
    if (order._strips) {
      // A strip is a column (or a row) through every page.
      final int along = order._down ? rows : columns;
      final int strip = slot ~/ along;
      index = strip * along * pages + page * along + slot % along;
    } else {
      index = page * labelsPerPage + slot;
    }
    return index < total ? index : null;
  }

  /// The page and the slot (see [labelRect]) of item [index] of [total],
  /// all from 0: the reverse of [itemAt].
  ///
  /// Throws [RangeError] unless `0 <= index < total`.
  ({int page, int slot}) slotOf(int index, int total) {
    RangeError.checkValidIndex(index, null, 'index', total);
    if (!order._strips) {
      return (page: index ~/ labelsPerPage, slot: index % labelsPerPage);
    }
    final int pages = pageCount(total);
    final int along = order._down ? rows : columns;
    final int strip = index ~/ (along * pages);
    final int inStrip = index % (along * pages);
    return (page: inStrip ~/ along, slot: strip * along + inStrip % along);
  }

  /// The pages as SVG documents, one a page, in millimetres: an A4 page is
  /// `width="210mm" height="297mm"` with a `viewBox` of `0 0 210 297`.
  /// Each page is made when the stream asks for it.
  ///
  /// [captionText] gives the text under the code of an item (the item
  /// itself by default); see [caption]. SVG holds any text; the program
  /// that shows the file picks a monospace font.
  ///
  /// ```dart
  /// int n = 0;
  /// await for (final String page in sheet.svgPages(items)) {
  ///   await File('labels-${++n}.svg').writeAsString(page);
  /// }
  /// ```
  ///
  /// The [style]'s logo is embedded as a PNG, once a page.
  ///
  /// No items give no pages. Throws [BarcodeWriteException] naming the
  /// item and its index if an item cannot be encoded (such as a character
  /// Code 128 cannot hold): no page is skipped silently. Throws
  /// [ArgumentError] if the labels leave no room for a code or the
  /// style's logo cannot be loaded, and [UnsupportedError] for a
  /// [SweepGradient]; both before the first page.
  Stream<String> svgPages(
    Iterable<String> items, {
    String Function(String item)? captionText,
  }) async* {
    _check();
    final SheetLogo? logo = await loadSheetLogo(this, png: true);
    await for (final _Page page in _pages(items, captionText)) {
      yield svgPage(
        this,
        page.symbols,
        page.captions,
        slots: page.slots,
        logo: logo,
      );
    }
  }

  /// Throws if the labels leave no room or the style cannot be drawn.
  void _check() {
    checkRoom(this);
    if (style.gradient is SweepGradient) {
      throw UnsupportedError(
        'A label sheet cannot draw a SweepGradient: use a LinearGradient '
        'or a RadialGradient',
      );
    }
  }

  /// The pages as one PDF document: vector shapes for the modules (see
  /// [style]), the built-in Courier font for the text, each page the size
  /// of [paper]. Print it at 100 % (actual size).
  ///
  /// [captionText] gives the text under the code of an item (the item
  /// itself by default); see [caption]. The PDF shows Latin-1 text
  /// (English and Western European letters); any other character is
  /// printed as `?`: use [svgPages] for other scripts.
  ///
  /// [onProgress] is called after each page with the labels done and the
  /// number of [items]; with it, [items] is counted first. The strip
  /// orders count them in any case (see [LabelOrder.columnStrips]).
  ///
  /// ```dart
  /// final Uint8List bytes = await sheet.pdf(
  ///   items,
  ///   onProgress: (done, total) => print('$done of $total'),
  /// );
  /// ```
  ///
  /// Throws [BarcodeWriteException] naming the item and its index if an
  /// item cannot be encoded, [ArgumentError] if [items] is empty, the
  /// labels leave no room for a code or the style's logo cannot be
  /// loaded, and [UnsupportedError] for a [SweepGradient].
  Future<Uint8List> pdf(
    Iterable<String> items, {
    String Function(String item)? captionText,
    void Function(int done, int total)? onProgress,
  }) async {
    _check();
    final int total = onProgress == null ? 0 : items.length;
    final PdfWriter pdf = PdfWriter();
    final PdfStyleResources shared = PdfStyleResources(
      pdf,
      await loadSheetLogo(this, png: false),
    );
    int done = 0;
    await for (final _Page page in _pages(items, captionText)) {
      final PdfPageResources resources = PdfPageResources(shared);
      final String content = pdfPageContent(
        this,
        page.symbols,
        page.captions,
        slots: page.slots,
        resources: resources,
      );
      pdf.addPage(
        paper.width,
        paper.height,
        content,
        resources: resources.entries,
      );
      done += page.symbols.length;
      onProgress?.call(done, total);
    }
    if (done == 0) {
      throw ArgumentError.value(items, 'items', 'is empty');
    }
    return pdf.close();
  }

  /// [items] encoded a page at a time.
  Stream<_Page> _pages(
    Iterable<String> items,
    String Function(String item)? captionText,
  ) async* {
    final BarcodeWriter writer = writerUnderLogo(this.writer, style.logo);
    if (order._strips) {
      // Random access: a List as it is, anything else read into one.
      final List<String> all = items is List<String> ? items : items.toList();
      final int pages = pageCount(all.length);
      for (int p = 0; p < pages; p++) {
        final List<int> slots = <int>[];
        final List<int> indices = <int>[];
        for (int slot = 0; slot < labelsPerPage; slot++) {
          final int? i = itemAt(p, slot, all.length);
          if (i != null) {
            slots.add(slot);
            indices.add(i);
          }
        }
        if (indices.isEmpty) {
          continue;
        }
        final List<BarcodeSymbol> symbols = await Future.wait(
          <Future<BarcodeSymbol>>[
            for (final int i in indices) _encode(writer, i, all[i]),
          ],
        );
        yield _Page(symbols, <String?>[
          for (final int i in indices)
            if (caption) captionText?.call(all[i]) ?? all[i] else null,
        ], slots);
      }
      return;
    }
    final Iterator<String> it = items.iterator;
    int index = 0;
    while (true) {
      final List<String> data = <String>[];
      while (data.length < labelsPerPage && it.moveNext()) {
        data.add(it.current);
      }
      if (data.isEmpty) {
        return;
      }
      final int first = index;
      final List<BarcodeSymbol> symbols = await Future.wait(
        <Future<BarcodeSymbol>>[
          for (int i = 0; i < data.length; i++)
            _encode(writer, first + i, data[i]),
        ],
      );
      index += data.length;
      yield _Page(symbols, <String?>[
        for (final String item in data)
          if (caption) captionText?.call(item) ?? item else null,
      ]);
    }
  }

  /// [item] at [index] encoded with [writer] (see [encodeFor]), or a
  /// [BarcodeWriteException] that names it.
  Future<BarcodeSymbol> _encode(
    BarcodeWriter writer,
    int index,
    String item,
  ) async {
    try {
      return await encodeFor(writer, style, item);
    } on BarcodeWriteException catch (e) {
      final String shown = item.length > 60
          ? '${item.substring(0, 57)}...'
          : item;
      throw BarcodeWriteException(
        'Item $index ("$shown") cannot be encoded: ${e.message}',
      );
    }
  }

  /// Creates a copy with the given fields replaced.
  ///
  /// [codeSize], which may be `null`, takes a function: `copyWith(codeSize:
  /// () => null)` clears it.
  BarcodeLabelSheet copyWith({
    PaperSize? paper,
    int? columns,
    int? rows,
    EdgeInsets? margin,
    double? columnGap,
    double? rowGap,
    double? padding,
    bool? caption,
    double? captionSize,
    ValueGetter<double?>? codeSize,
    BarcodeWriter? writer,
    BarcodeStyle? style,
    LabelOrder? order,
  }) => BarcodeLabelSheet(
    paper: paper ?? this.paper,
    columns: columns ?? this.columns,
    rows: rows ?? this.rows,
    margin: margin ?? this.margin,
    columnGap: columnGap ?? this.columnGap,
    rowGap: rowGap ?? this.rowGap,
    padding: padding ?? this.padding,
    caption: caption ?? this.caption,
    captionSize: captionSize ?? this.captionSize,
    codeSize: codeSize == null ? this.codeSize : codeSize(),
    writer: writer ?? this.writer,
    style: style ?? this.style,
    order: order ?? this.order,
  );

  @override
  bool operator ==(Object other) =>
      other is BarcodeLabelSheet &&
      other.paper == paper &&
      other.columns == columns &&
      other.rows == rows &&
      other.margin == margin &&
      other.columnGap == columnGap &&
      other.rowGap == rowGap &&
      other.padding == padding &&
      other.caption == caption &&
      other.captionSize == captionSize &&
      other.codeSize == codeSize &&
      other.writer == writer &&
      other.style == style &&
      other.order == order;

  @override
  int get hashCode => Object.hash(
    paper,
    columns,
    rows,
    margin,
    columnGap,
    rowGap,
    padding,
    caption,
    captionSize,
    codeSize,
    writer,
    style,
    order,
  );

  @override
  String toString() =>
      'BarcodeLabelSheet(${columns}x$rows on $paper, ${writer.format.name}'
      '${order == LabelOrder.rows ? '' : ', by ${order.name}'}'
      '${style == BarcodeStyle.classic ? '' : ', styled'})';
}

/// The codes of one page, the captions under them and their slots
/// (`null`: the first ones, in order).
final class _Page {
  const _Page(this.symbols, this.captions, [this.slots]);
  final List<BarcodeSymbol> symbols;
  final List<String?> captions;
  final List<int>? slots;
}

/// Shows one page of a [BarcodeLabelSheet]: white paper at the page's
/// proportions, as wide as it may be, each code and caption where the PDF
/// and SVG put them.
///
/// ```dart
/// BarcodeLabelSheetView(sheet: sheet, items: items, page: 0)
/// ```
///
/// The codes are [BarcodeView]s drawn with the sheet's
/// [BarcodeLabelSheet.style]. An item that cannot be encoded leaves its
/// label without a code; [BarcodeLabelSheet.pdf] and
/// [BarcodeLabelSheet.svgPages] throw for it.
class BarcodeLabelSheetView extends StatefulWidget {
  /// Creates a view of [page] (from 0) of [items] on [sheet].
  const BarcodeLabelSheetView({
    super.key,
    required this.sheet,
    required this.items,
    this.page = 0,
    this.captionText,
  });

  /// The layout and the writer.
  final BarcodeLabelSheet sheet;

  /// All the items; the view shows those of [page], in the sheet's
  /// [BarcodeLabelSheet.order]. The strip orders need all of them at once
  /// (see [LabelOrder.columnStrips]): give those a [List].
  final Iterable<String> items;

  /// The page to show, from 0. A page past the items shows blank paper.
  final int page;

  /// The text under the code of an item, as for [BarcodeLabelSheet.pdf];
  /// the item itself by default.
  final String Function(String item)? captionText;

  @override
  State<BarcodeLabelSheetView> createState() => _BarcodeLabelSheetViewState();
}

class _BarcodeLabelSheetViewState extends State<BarcodeLabelSheetView> {
  /// The items of the page shown and the writer they were encoded with
  /// (the sheet's, as the style's logo needs it).
  List<String> _items = const <String>[];
  BarcodeWriter? _writer;

  /// The label of each item (see [BarcodeLabelSheet.labelRect]).
  List<int> _slots = const <int>[];
  BarcodeLogo? _logo;

  /// Their symbols, `null` for one that cannot be encoded or is not yet.
  List<BarcodeSymbol?> _symbols = const <BarcodeSymbol?>[];

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(BarcodeLabelSheetView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  /// Encodes the items of the page when they or the writer changed.
  void _update() {
    final BarcodeLabelSheet sheet = widget.sheet;
    final int n = sheet.labelsPerPage;
    final List<String> items;
    final List<int> slots;
    if (widget.page < 0) {
      items = const <String>[];
      slots = const <int>[];
    } else if (sheet.order._strips) {
      final Iterable<String> source = widget.items;
      final List<String> all = source is List<String>
          ? source
          : source.toList();
      items = <String>[];
      slots = <int>[];
      for (int slot = 0; slot < n; slot++) {
        final int? i = sheet.itemAt(widget.page, slot, all.length);
        if (i != null) {
          items.add(all[i]);
          slots.add(slot);
        }
      }
    } else {
      items = widget.items.skip(widget.page * n).take(n).toList();
      slots = <int>[for (int i = 0; i < items.length; i++) i];
    }
    final BarcodeLogo? logo = sheet.style.logo;
    final BarcodeWriter writer = writerUnderLogo(sheet.writer, logo);
    if (writer == _writer &&
        logo == _logo &&
        listEquals(items, _items) &&
        listEquals(slots, _slots)) {
      return;
    }
    _items = items;
    _slots = slots;
    _writer = writer;
    _logo = logo;
    _symbols = List<BarcodeSymbol?>.filled(items.length, null);
    for (int i = 0; i < items.length; i++) {
      unawaited(_encodeAt(i, items, writer, widget.sheet.style));
    }
  }

  Future<void> _encodeAt(
    int i,
    List<String> items,
    BarcodeWriter writer,
    BarcodeStyle style,
  ) async {
    BarcodeSymbol? symbol;
    try {
      symbol = await encodeFor(writer, style, items[i]);
    } on BarcodeWriteException {
      symbol = null;
    }
    // Still the same page?
    if (mounted && identical(items, _items) && writer == _writer) {
      setState(() => _symbols[i] = symbol);
    }
  }

  @override
  Widget build(BuildContext context) {
    final BarcodeLabelSheet sheet = widget.sheet;
    final PaperSize paper = sheet.paper;
    return AspectRatio(
      aspectRatio: paper.width / paper.height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double mm = box.maxWidth / paper.width;
          return ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Stack(
              children: <Widget>[
                for (int i = 0; i < _items.length; i++) ..._label(sheet, i, mm),
              ],
            ),
          );
        },
      ),
    );
  }

  /// The code and caption of label [i] at [mm] logical pixels a
  /// millimetre.
  List<Widget> _label(BarcodeLabelSheet sheet, int i, double mm) {
    final BarcodeSymbol? symbol = _symbols[i];
    final String? caption = sheet.caption
        ? (widget.captionText?.call(_items[i]) ?? _items[i])
        : null;
    if (symbol == null) {
      return const <Widget>[];
    }
    final BarcodeStyle style = codeStyleOf(sheet);
    final LabelPlacement at = placeLabel(
      sheet,
      sheet.labelRect(_slots[i]),
      SymbolLayout(styledSymbol(symbol, style)),
      caption,
    );
    final Rect? line = at.captionBox;
    return <Widget>[
      Positioned(
        left: at.code.left * mm,
        top: at.code.top * mm,
        width: at.code.width * mm,
        height: at.code.height * mm,
        child: BarcodeView.symbol(
          symbol,
          style: style,
          width: at.code.width * mm,
          height: at.code.height * mm,
        ),
      ),
      if (line != null && caption != null && caption.isNotEmpty)
        Positioned(
          left: line.left * mm,
          top: line.top * mm,
          width: line.width * mm,
          height: line.height * mm,
          child: Baseline(
            baseline: (at.baseline - line.top) * mm,
            baselineType: TextBaseline.alphabetic,
            // Baseline loosens the width: the text gets the whole line to
            // be centred in, as in the SVG and the PDF.
            child: SizedBox(
              width: line.width * mm,
              child: Text(
                caption,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: const Color(0xFF000000),
                  fontSize: at.captionFontSize * mm,
                  height: 1,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const <String>[
                    'Courier New',
                    'Courier',
                    'Menlo',
                  ],
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}
