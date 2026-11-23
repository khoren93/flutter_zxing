// BarcodeLabelSheet without the engine: the grid, where a code and its
// caption go on a label, and the SVG and PDF of a page drawn from symbols
// made here. label_sheet_native_test.dart encodes real items.
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/rendering/label_sheet_output.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

import 'label_sheet_files.dart';

/// A square symbol [n] modules across, a checkerboard.
BarcodeSymbol _square(int n, {int quietZone = 4}) => BarcodeSymbol(
  format: BarcodeFormat.qrCode,
  width: n,
  height: n,
  modules: Uint8List.fromList(<int>[
    for (int y = 0; y < n; y++)
      for (int x = 0; x < n; x++) (x + y) % 2 ^ 1,
  ]),
  quietZone: quietZone,
);

void main() {
  group('PaperSize', () {
    test('ISO and US sizes in millimetres', () {
      expect((PaperSize.a4.width, PaperSize.a4.height), (210, 297));
      expect((PaperSize.a5.width, PaperSize.a5.height), (148, 210));
      expect((PaperSize.a3.width, PaperSize.a3.height), (297, 420));
      expect(PaperSize.letter.width, closeTo(8.5 * 25.4, 1e-9));
      expect(PaperSize.legal.height, closeTo(14 * 25.4, 1e-9));
    });

    test('landscape puts the longer side across, once', () {
      expect(PaperSize.a4.landscape, const PaperSize(297, 210));
      expect(PaperSize.a4.landscape.landscape, PaperSize.a4.landscape);
    });
  });

  group('the grid', () {
    const BarcodeLabelSheet sheet = BarcodeLabelSheet(columns: 3, rows: 8);

    test('labels per page and pages', () {
      expect(sheet.labelsPerPage, 24);
      expect(sheet.pageCount(0), 0);
      expect(sheet.pageCount(1), 1);
      expect(sheet.pageCount(24), 1);
      expect(sheet.pageCount(25), 2);
      expect(sheet.pageCount(10000), 417);
    });

    test('labels fill the page inside the margins, row by row', () {
      expect(sheet.labelSize.width, closeTo(190 / 3, 1e-9));
      expect(sheet.labelSize.height, closeTo(277 / 8, 1e-9));
      expect(sheet.labelRect(0).topLeft, const Offset(10, 10));
      final Rect fourth = sheet.labelRect(4); // second row, second column
      expect(fourth.left, closeTo(10 + 190 / 3, 1e-9));
      expect(fourth.top, closeTo(10 + 277 / 8, 1e-9));
      final Rect last = sheet.labelRect(23);
      expect(last.right, closeTo(200, 1e-9));
      expect(last.bottom, closeTo(287, 1e-9));
      // The next page starts at the same place.
      expect(sheet.labelRect(24), sheet.labelRect(0));
      expect(sheet.labelRect(47), last);
    });

    test('uneven margins and gaps', () {
      const BarcodeLabelSheet labels = BarcodeLabelSheet(
        paper: PaperSize.letter,
        columns: 2,
        rows: 5,
        margin: EdgeInsets.fromLTRB(5, 12, 7, 10),
        columnGap: 4,
        rowGap: 2,
      );
      final Size size = labels.labelSize;
      expect(size.width, closeTo((215.9 - 12 - 4) / 2, 1e-9));
      expect(size.height, closeTo((279.4 - 22 - 8) / 5, 1e-9));
      expect(labels.labelRect(1).left, closeTo(5 + size.width + 4, 1e-9));
      expect(labels.labelRect(2).top, closeTo(12 + size.height + 2, 1e-9));
      expect(labels.labelRect(9).right, closeTo(215.9 - 7, 1e-9));
      expect(labels.labelRect(9).bottom, closeTo(279.4 - 10, 1e-9));
    });

    test('landscape paper: more room across', () {
      final BarcodeLabelSheet wide = sheet.copyWith(
        paper: PaperSize.a4.landscape,
      );
      expect(wide.labelSize.width, closeTo(277 / 3, 1e-9));
      expect(wide.labelRect(23).bottom, closeTo(200, 1e-9));
    });

    test('no room is an error', () {
      const BarcodeLabelSheet crowded = BarcodeLabelSheet(
        columns: 50,
        rows: 2,
        columnGap: 5,
      );
      expect(() => crowded.labelRect(0), throwsArgumentError);
      expect(() => sheet.labelRect(-1), throwsArgumentError);
      expect(() => checkRoom(sheet.copyWith(padding: 20)), throwsArgumentError);
      checkRoom(sheet);
    });

    test('equality and copyWith', () {
      expect(sheet.copyWith(), sheet);
      expect(sheet.copyWith().hashCode, sheet.hashCode);
      expect(sheet.copyWith(rows: 7), isNot(sheet));
      expect(
        sheet.copyWith(writer: const BarcodeWriter(BarcodeFormat.code128)),
        isNot(sheet),
      );
      expect(sheet.style, BarcodeStyle.classic);
      final BarcodeLabelSheet soft = sheet.copyWith(style: BarcodeStyle.soft);
      expect(soft, isNot(sheet));
      expect(soft.style, BarcodeStyle.soft);
      expect(soft.copyWith(), soft);
      expect(soft.copyWith().hashCode, soft.hashCode);
      expect(sheet.toString(), isNot(contains('styled')));
      expect(soft.toString(), contains('styled'));
    });
  });

  group('fill order', () {
    const BarcodeLabelSheet byRows = BarcodeLabelSheet(columns: 3, rows: 4);
    final BarcodeLabelSheet byColumns = byRows.copyWith(
      order: LabelOrder.columns,
    );

    test('rows: the next item is to the right; columns: below', () {
      expect(byRows.order, LabelOrder.rows);
      final Rect first = byRows.labelRect(0);
      expect(byColumns.labelRect(0), first);
      expect(byRows.labelRect(1).top, first.top);
      expect(byRows.labelRect(1).left, greaterThan(first.left));
      expect(byColumns.labelRect(1).left, first.left);
      expect(byColumns.labelRect(1).top, greaterThan(first.top));
      // Item 4 starts the second column, item 3 the second row.
      expect(byColumns.labelRect(4).top, first.top);
      expect(byColumns.labelRect(4).left, byRows.labelRect(1).left);
      expect(byRows.labelRect(3).left, first.left);
      // The last label of a page is bottom right in both; the next page
      // starts top left.
      expect(byColumns.labelRect(11), byRows.labelRect(11));
      expect(byRows.labelRect(11).right, closeTo(200, 1e-9));
      expect(byRows.labelRect(11).bottom, closeTo(287, 1e-9));
      expect(byColumns.labelRect(12), first);
    });

    test('equality, copyWith and toString', () {
      expect(byColumns, isNot(byRows));
      expect(byColumns.copyWith(), byColumns);
      expect(byColumns.copyWith().hashCode, byColumns.hashCode);
      expect(byColumns.copyWith(order: LabelOrder.rows), byRows);
      expect(byColumns.toString(), contains('by columns'));
      expect(byRows.toString(), isNot(contains('columns')));
    });

    test('the SVG and the PDF put item 1 under item 0', () {
      final List<BarcodeSymbol> symbols = <BarcodeSymbol>[
        _square(21),
        _square(21),
      ];
      final String svg = svgPage(byColumns, symbols, <String?>['A', 'B']);
      final List<(double, double)> at = <(double, double)>[
        for (final Match m in RegExp(
          r'<svg x="([\d.]+)" y="([\d.]+)"',
        ).allMatches(svg))
          (double.parse(m[1]!), double.parse(m[2]!)),
      ];
      expect(at, hasLength(2));
      expect(at[1].$1, at[0].$1);
      expect(at[1].$2, greaterThan(at[0].$2));
      final String pdf = pdfPageContent(byColumns, symbols, <String?>[
        'A',
        'B',
      ]);
      final List<(double, double)> codes = <(double, double)>[
        for (final Match m in RegExp(
          r'^q [\d.]+ 0 0 [\d.]+ ([\d.]+) ([\d.]+) cm$',
          multiLine: true,
        ).allMatches(pdf))
          (double.parse(m[1]!), double.parse(m[2]!)),
      ];
      expect(codes, hasLength(2));
      expect(codes[1].$1, codes[0].$1);
      expect(codes[1].$2, greaterThan(codes[0].$2));
    });
  });

  group('a label', () {
    const BarcodeLabelSheet sheet = BarcodeLabelSheet(columns: 3, rows: 8);
    final SymbolLayout layout = SymbolLayout(_square(21));

    test('the code and caption fit inside the padding, centered', () {
      final Rect label = sheet.labelRect(0);
      final LabelPlacement at = placeLabel(sheet, label, layout, 'SKU-0001');
      final Rect inner = label.deflate(sheet.padding);
      final Rect caption = at.captionBox!;
      // Square, centered across, as tall as the room above the caption.
      expect(at.code.width, closeTo(at.code.height, 1e-9));
      expect(at.code.center.dx, closeTo(label.center.dx, 1e-9));
      expect(
        at.code.height,
        closeTo(inner.height - sheet.captionSize * (1 + captionGap), 1e-9),
      );
      expect(at.code.top, closeTo(inner.top, 1e-9));
      expect(caption.top, greaterThan(at.code.bottom));
      expect(caption.bottom, closeTo(inner.bottom, 1e-9));
      expect(caption.width, closeTo(inner.width, 1e-9));
      expect(at.captionFontSize, sheet.captionSize);
    });

    test('a long caption gets smaller to fit', () {
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(0),
        layout,
        'X' * 100,
      );
      expect(at.captionFontSize, lessThan(sheet.captionSize));
      expect(
        100 * monospaceAdvance * at.captionFontSize,
        closeTo(at.captionBox!.width, 1e-9),
      );
    });

    test('codeSize makes the code smaller, centred with its caption', () {
      final BarcodeLabelSheet small = sheet.copyWith(codeSize: () => 12);
      final Rect label = small.labelRect(0);
      final LabelPlacement at = placeLabel(small, label, layout, 'SKU-0001');
      expect(at.code.width, closeTo(12, 1e-9));
      expect(at.code.height, closeTo(12, 1e-9));
      expect(at.code.center.dx, closeTo(label.center.dx, 1e-9));
      // The code and its caption together are centred down the label.
      final double block = at.captionBox!.bottom - at.code.top;
      expect(
        at.code.top - label.top,
        closeTo(label.bottom - (at.code.top + block), 1e-9),
      );
      // Larger than the label allows: cut down to it.
      final LabelPlacement big = placeLabel(
        sheet.copyWith(codeSize: () => 500),
        label,
        layout,
        'SKU-0001',
      );
      final LabelPlacement full = placeLabel(sheet, label, layout, 'SKU-0001');
      expect(big.code, full.code);
    });

    test('without a caption the code takes the whole label', () {
      final BarcodeLabelSheet bare = sheet.copyWith(caption: false);
      final Rect label = bare.labelRect(0);
      final LabelPlacement at = placeLabel(bare, label, layout, null);
      expect(at.captionBox, isNull);
      expect(at.code.height, closeTo(label.height - 2 * bare.padding, 1e-9));
      expect(at.code.center.dy, closeTo(label.center.dy, 1e-9));
    });
  });

  group('SVG page', () {
    const BarcodeLabelSheet sheet = BarcodeLabelSheet(columns: 2, rows: 3);

    test('in millimetres, a code and a caption a label', () {
      final String svg = svgPage(
        sheet,
        <BarcodeSymbol>[_square(21), _square(25), _square(21)],
        <String?>['A-1', 'B-2', 'C-3'],
      );
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg" '));
      expect(svg, contains(' width="210mm" height="297mm" '));
      expect(svg, contains(' viewBox="0 0 210 297">'));
      expect(svg, contains('<rect width="100%" height="100%" fill="#fff"/>'));
      expect(svg, endsWith('</svg>'));
      expect(RegExp('<svg x=').allMatches(svg), hasLength(3));
      expect(RegExp('<text ').allMatches(svg), hasLength(3));
      expect(svg, contains('>B-2</text>'));
      expect(svg, contains('text-anchor="middle"'));
      // The first code's element at its placement.
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(0),
        SymbolLayout(_square(21)),
        'A-1',
      );
      final Match first = RegExp(
        r'<svg x="([\d.]+)" y="([\d.]+)" width="([\d.]+)"',
      ).firstMatch(svg)!;
      expect(double.parse(first[1]!), closeTo(at.code.left, 1e-3));
      expect(double.parse(first[2]!), closeTo(at.code.top, 1e-3));
      expect(double.parse(first[3]!), closeTo(at.code.width, 1e-3));
    });

    test('captions are escaped', () {
      final String svg = svgPage(
        sheet,
        <BarcodeSymbol>[_square(21)],
        <String?>['<a & "b">\u0001'],
      );
      expect(svg, contains('>&lt;a &amp; &quot;b&quot;&gt;</text>'));
      expect(svg, isNot(contains('<a ')));
    });

    test('no caption, no text', () {
      final String svg = svgPage(
        sheet.copyWith(caption: false),
        <BarcodeSymbol>[_square(21)],
        <String?>[null],
      );
      expect(svg, isNot(contains('<text')));
    });

    test('Letter is in millimetres too', () {
      final String svg = svgPage(
        sheet.copyWith(paper: PaperSize.letter),
        const <BarcodeSymbol>[],
        const <String?>[],
      );
      expect(svg, contains('width="215.9mm" height="279.4mm"'));
      expect(svg, contains('viewBox="0 0 215.9 279.4"'));
    });
  });

  group('PDF', () {
    const BarcodeLabelSheet sheet = BarcodeLabelSheet(columns: 2, rows: 3);

    Uint8List twoPages(BarcodeLabelSheet sheet) {
      final PdfWriter pdf = PdfWriter();
      for (int p = 0; p < 2; p++) {
        pdf.addPage(
          sheet.paper.width,
          sheet.paper.height,
          pdfPageContent(
            sheet,
            <BarcodeSymbol>[_square(21), _square(25)],
            <String?>['(page $p)', 'é 日'],
          ),
        );
      }
      return pdf.close();
    }

    test('header, pages, MediaBox in points, xref offsets', () {
      final PdfPages pages = readPdf(twoPages(sheet));
      expect(pages.contents, hasLength(2));
      for (final List<double> box in pages.mediaBoxes) {
        expect(box[0], 0);
        expect(box[1], 0);
        expect(box[2], closeTo(595.276, 1e-3));
        expect(box[3], closeTo(841.89, 1e-3));
      }
      final PdfPages letter = readPdf(
        twoPages(sheet.copyWith(paper: PaperSize.letter)),
      );
      expect(letter.mediaBoxes.first, <double>[0, 0, 612, 792]);
    });

    test('codes as rectangles, captions in Courier', () {
      final String page = readPdf(twoPages(sheet)).contents.first;
      expect(page, startsWith('q\n2.8346457 0 0 -2.8346457 0 841.89 cm\n'));
      expect(
        RegExp(
          r'^q [\d.]+ 0 0 [\d.]+ [\d.]+ [\d.]+ cm$',
          multiLine: true,
        ).allMatches(page),
        hasLength(2),
      );
      expect(page, contains(' re\n'));
      expect(page, contains(r'(\(page 0\)) Tj'));
      // Latin-1 as octal, anything else as ?.
      expect(page, contains(r'(\351 ?) Tj'));
    });

    test('PDF strings escape what needs it', () {
      expect(pdfString(r'a(b)c\d'), r'(a\(b\)c\\d)');
      expect(pdfString('ÿ€\n'), r'(\377??)');
    });

    test('the painted page puts the codes where the placement says', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final String content = readPdf(twoPages(sheet)).contents.first;
      final PixelBuffer pixels = await paintPdfPage(content, sheet.paper, 2);
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(0),
        SymbolLayout(_square(21)),
        '',
      );
      // The checkerboard's first dark module: just inside the quiet zone.
      final double m = at.code.width / 29;
      final int x = ((at.code.left + 4.5 * m) * 2).round();
      final int y = ((at.code.top + 4.5 * m) * 2).round();
      expect(pixels.bytes[(y * pixels.width + x) * 4], 0);
      final int qx = ((at.code.left + 1 * m) * 2).round();
      expect(pixels.bytes[(y * pixels.width + qx) * 4], 255);
    });
  });

  group('styled codes', () {
    const BarcodeLabelSheet sheet = BarcodeLabelSheet(columns: 2, rows: 3);
    final List<BarcodeSymbol> symbols = <BarcodeSymbol>[
      _square(21),
      _square(25),
      _square(21),
    ];
    const List<String?> captions = <String?>['A-1', 'B-2', 'C-3'];

    /// The page of [style] as a PDF of two pages, read back.
    PdfPages pdfOf(BarcodeStyle style, {SheetLogo? logo}) {
      final BarcodeLabelSheet styled = sheet.copyWith(style: style);
      final PdfWriter pdf = PdfWriter();
      final PdfStyleResources shared = PdfStyleResources(pdf, logo);
      for (int p = 0; p < 2; p++) {
        final PdfPageResources resources = PdfPageResources(shared);
        final String content = pdfPageContent(
          styled,
          symbols,
          captions,
          resources: resources,
        );
        pdf.addPage(
          sheet.paper.width,
          sheet.paper.height,
          content,
          resources: resources.entries,
        );
      }
      return readPdf(pdf.close());
    }

    Iterable<String> objectsWith(PdfPages pages, String text) =>
        pages.objects.values.where((String o) => o.contains(text));

    test('classic: the same plain elements and rectangles as before', () {
      final String svg = svgPage(sheet, symbols, captions);
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(0),
        SymbolLayout(symbols[0]),
        'A-1',
      );
      double r(double v) => (v * 1000).roundToDouble() / 1000;
      expect(
        svg,
        contains(
          symbols[0].toSvgElement(
            x: r(at.code.left),
            y: r(at.code.top),
            width: r(at.code.width),
            height: r(at.code.height),
          ),
        ),
      );
      expect(svg, isNot(contains('<defs>')));
      final PdfPages pdf = pdfOf(BarcodeStyle.classic);
      expect(pdf.resources.first, '/Font<</F1 3 0 R>>');
      expect(pdf.contents.first, isNot(contains(' rg\n')));
      expect(pdf.contents.first, isNot(contains(' c\n')));
      expect(pdf.contents.first, contains('\n4 4 1 1 re\n'));
    });

    test('SVG: shapes and colors of the style, shared gradients', () {
      final String soft = svgPage(
        sheet.copyWith(style: BarcodeStyle.soft),
        symbols,
        captions,
      );
      expect(RegExp('<svg x=').allMatches(soft), hasLength(3));
      expect(soft, contains(' fill-rule="evenodd"'));
      expect(soft, contains('A0.5 0.5 0 0 1 '));
      expect(soft, isNot(contains('crispEdges')));

      final String dots = svgPage(
        sheet.copyWith(style: BarcodeStyle.dots),
        symbols,
        captions,
      );
      expect(dots, contains('fill="#0b3d91"'));
      expect(dots, contains('A0.45 0.45 0 1 1 '));

      final String lagoon = svgPage(
        sheet.copyWith(style: BarcodeStyle.lagoon),
        symbols,
        captions,
      );
      // One gradient per size of code: the two 21-module codes share one.
      final List<String> ids = <String>[
        for (final Match m in RegExp(
          '<linearGradient id="([^"]+)"',
        ).allMatches(lagoon))
          m[1]!,
      ];
      expect(ids, hasLength(2));
      expect(lagoon.indexOf('<defs>'), lessThan(lagoon.indexOf('<svg x=')));
      expect(
        RegExp('fill="url\\(#${ids[0]}\\)"').allMatches(lagoon),
        isNotEmpty,
      );
      expect(lagoon, contains('stop-color="#00735d"'));
    });

    test('SVG: a dark background fills the code box, white is the paper', () {
      final String night = svgPage(
        sheet.copyWith(style: BarcodeStyle.night),
        symbols,
        captions,
      );
      expect(night, contains('<rect width="29" height="29" fill="#0e1218"/>'));
      expect(night, contains('<rect width="33" height="33" fill="#0e1218"/>'));
      final String soft = svgPage(
        sheet.copyWith(style: BarcodeStyle.soft),
        symbols,
        captions,
      );
      expect(RegExp('<rect ').allMatches(soft), hasLength(1)); // the page
    });

    test("the style's title, caption and card are not drawn", () {
      final BarcodeLabelSheet framed = sheet.copyWith(
        style: BarcodeStyle.soft.copyWith(
          title: () => const BarcodeCaption('TITLE'),
          caption: () => const BarcodeCaption('CAPTION'),
          card: () => const BarcodeCard(color: Color(0xFFFF0000)),
        ),
      );
      final String svg = svgPage(framed, symbols, captions);
      expect(svg, isNot(contains('TITLE')));
      expect(svg, isNot(contains('CAPTION')));
      expect(svg, isNot(contains('#f00')));
      expect(
        svg,
        svgPage(sheet.copyWith(style: BarcodeStyle.soft), symbols, captions),
      );
    });

    test('without the quiet zone the code fills its box', () {
      final BarcodeLabelSheet bare = sheet.copyWith(
        style: BarcodeStyle.dots.copyWith(quietZone: false),
      );
      final String svg = svgPage(bare, symbols, captions);
      expect(svg, contains('viewBox="0 0 21 21"'));
      expect(svg, contains('viewBox="0 0 25 25"'));
      final String classic = svgPage(
        sheet.copyWith(style: const BarcodeStyle(quietZone: false)),
        symbols,
        captions,
      );
      expect(classic, contains('viewBox="0 0 21 21" shape-rendering'));
    });

    test('SVG: the logo once a page, used by every code', () {
      const SheetLogo logo = SheetLogo(width: 2, height: 2, png: 'AAAA');
      final String svg = svgPage(
        sheet.copyWith(
          style: BarcodeStyle.soft.copyWith(
            logo: () => BarcodeLogo(MemoryImage(Uint8List(0))),
          ),
        ),
        symbols,
        captions,
        logo: logo,
      );
      expect(svg, contains('xmlns:xlink="http://www.w3.org/1999/xlink"'));
      expect(RegExp('<symbol id="zx-logo"').allMatches(svg), hasLength(1));
      expect(RegExp('base64,AAAA').allMatches(svg), hasLength(1));
      expect(
        RegExp('<use xlink:href="#zx-logo" ').allMatches(svg),
        hasLength(3),
      );
    });

    test('PDF: module shapes as Bézier paths, colors as rg', () {
      final String soft = pdfOf(BarcodeStyle.soft).contents.first;
      expect(soft, contains(' c\n'));
      expect(soft, contains('\nf\n'));
      expect(soft, contains('\nf*\n'));
      expect(soft, contains('0 0 0 rg\n'));
      final String dots = pdfOf(BarcodeStyle.dots).contents.first;
      expect(dots, contains('0.043 0.239 0.569 rg\n'));
      // A dot a dark module: a zero-length line stroked with round caps.
      expect(dots, contains('0.043 0.239 0.569 RG\n0.9 w 1 J\n'));
      expect(
        RegExp(
          r'^([\d.]+ [\d.]+) m \1 l$',
          multiLine: true,
        ).allMatches(dots).length,
        greaterThan(3 * 100),
      );
      expect(dots, contains('\nS\n'));
      // The round eyes stay curves.
      expect(dots, contains(' c\n'));
      final String night = pdfOf(BarcodeStyle.night).contents.first;
      expect(night, contains('0.055 0.071 0.094 rg\n0 0 29 29 re f\n'));
    });

    test('PDF: a gradient is one shading the pages share, as patterns', () {
      final PdfPages lagoon = pdfOf(BarcodeStyle.lagoon);
      final List<String> shadings = objectsWith(
        lagoon,
        '/ShadingType 2',
      ).toList();
      expect(shadings, hasLength(1));
      expect(shadings.single, contains('/Coords[0 0 1 1]'));
      expect(shadings.single, contains('/FunctionType 2'));
      expect(shadings.single, contains('/C0[0 0.451 0.365]'));
      expect(shadings.single, contains('/Extend[true true]'));
      final int n = lagoon.objects.entries
          .firstWhere(
            (MapEntry<int, String> e) => e.value.contains('/ShadingType'),
          )
          .key;
      // A pattern a place on the page: the shading placed there, the same
      // on both pages.
      final List<String> patterns = objectsWith(
        lagoon,
        '/PatternType 2/Shading $n 0 R/Matrix[',
      ).toList();
      expect(patterns, hasLength(3));
      // The first label's pattern puts the shading's unit square on its
      // symbol: (0, 0) at the top left module, (1, 1) at the bottom right,
      // in points with y up.
      final List<double> mx = <double>[
        for (final String v in RegExp(
          r'/Matrix\[([^\]]*)\]',
        ).firstMatch(patterns.first)![1]!.split(' '))
          double.parse(v),
      ];
      final LabelPlacement at = placeLabel(
        sheet,
        sheet.labelRect(0),
        SymbolLayout(symbols[0]),
        'A-1',
      );
      final double m = at.code.width / 29;
      Offset point(double x, double y) =>
          Offset(mx[0] * x + mx[2] * y + mx[4], mx[1] * x + mx[3] * y + mx[5]);
      Offset expected(double modules) => Offset(
        (at.code.left + modules * m) * pointsPerMm,
        (297 - (at.code.top + modules * m)) * pointsPerMm,
      );
      for (final (double unit, double modules) in <(double, double)>[
        (0, 4),
        (1, 25),
      ]) {
        expect(point(unit, unit).dx, closeTo(expected(modules).dx, 0.01));
        expect(point(unit, unit).dy, closeTo(expected(modules).dy, 0.01));
      }
      expect(lagoon.resources[0], lagoon.resources[1]);
      expect(lagoon.contents[0], lagoon.contents[1]);
      final String content = lagoon.contents.first;
      expect(lagoon.resources.first, startsWith('/Font<<'));
      expect(lagoon.resources.first, contains('/Pattern<</P'));
      expect(
        RegExp(r'/Pattern cs /P\d+ scn').allMatches(content),
        hasLength(3),
      );
      expect(content, contains('\nf*\n'));
    });

    test('PDF: a radial gradient of three colors stitches functions', () {
      final PdfPages pages = pdfOf(
        const BarcodeStyle(
          gradient: RadialGradient(
            colors: <Color>[
              Color(0xFF000000),
              Color(0xFF203040),
              Color(0xFF000080),
            ],
            stops: <double>[0.2, 0.5, 1],
          ),
        ),
      );
      final String shading = objectsWith(pages, '/ShadingType 3').single;
      expect(shading, contains('/Coords[0.5 0.5 0 0.5 0.5 0.5]'));
      expect(shading, contains('/FunctionType 3'));
      expect(shading, contains('/Bounds[0.2 0.5]'));
      expect(shading, contains('/Encode[0 1 0 1 0 1]'));
    });

    test('PDF: the logo image is in the file once, with its alpha', () {
      final SheetLogo logo = SheetLogo(
        width: 2,
        height: 1,
        rgb: Uint8List.fromList(<int>[255, 0, 0, 0, 0, 255]),
        alpha: Uint8List.fromList(<int>[255, 0]),
      );
      final PdfPages pages = pdfOf(
        BarcodeStyle.soft.copyWith(
          logo: () => BarcodeLogo(MemoryImage(Uint8List(0))),
        ),
        logo: logo,
      );
      final List<int> images = <int>[
        for (final MapEntry<int, String> e in pages.objects.entries)
          if (e.value.contains('/Subtype/Image/')) e.key,
      ];
      expect(images, hasLength(2)); // the RGB image and its soft mask
      final String rgb = pages.objects.values.singleWhere(
        (String o) => o.contains('/DeviceRGB') && o.contains('/Image'),
      );
      expect(rgb, contains('/Width 2/Height 1/BitsPerComponent 8'));
      final int mask = int.parse(
        RegExp(r'/SMask (\d+) 0 R').firstMatch(rgb)![1]!,
      );
      expect(pages.objects[mask], contains('/ColorSpace/DeviceGray'));
      final int image = images.firstWhere((int i) => i != mask);
      for (int p = 0; p < 2; p++) {
        expect(pages.resources[p], contains('/XObject<</Logo $image 0 R>>'));
        expect(RegExp('/Logo Do').allMatches(pages.contents[p]), hasLength(3));
      }
    });

    test('PDF: an opaque logo has no soft mask', () {
      final SheetLogo logo = SheetLogo(
        width: 1,
        height: 1,
        rgb: Uint8List.fromList(<int>[1, 2, 3]),
      );
      final PdfPages pages = pdfOf(
        BarcodeStyle.classic.copyWith(
          logo: () => BarcodeLogo(MemoryImage(Uint8List(0))),
        ),
        logo: logo,
      );
      expect(objectsWith(pages, '/Subtype/Image'), hasLength(1));
      expect(objectsWith(pages, '/SMask'), isEmpty);
    });

    test('PDF: a gradient or a logo needs the resources', () {
      expect(
        () => pdfPageContent(
          sheet.copyWith(style: BarcodeStyle.lagoon),
          symbols,
          captions,
        ),
        throwsArgumentError,
      );
    });

    test(
      'the painted styled pages put dark modules where the code is',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final BarcodeLabelSheet styled = sheet.copyWith(
          style: BarcodeStyle.lagoon,
        );
        final LabelPlacement at = placeLabel(
          styled,
          styled.labelRect(0),
          SymbolLayout(_square(21)),
          '',
        );
        final double m = at.code.width / 29;
        for (final PixelBuffer pixels in <PixelBuffer>[
          await paintPdfPage(
            pdfOf(styled.style).contents.first,
            sheet.paper,
            4,
          ),
          await paintSvgPage(
            svgPage(styled, symbols, captions),
            sheet.paper,
            4,
          ),
        ]) {
          int at4(double x, double y) =>
              pixels.bytes[((y * 4).round() * pixels.width + (x * 4).round()) *
                  4];
          // The finder's left edge (its corners are rounded), then the
          // quiet zone.
          expect(
            at4(at.code.left + 4.5 * m, at.code.top + 7.5 * m),
            lessThan(100),
          );
          expect(at4(at.code.left + 1 * m, at.code.top + 7.5 * m), 255);
        }
      },
    );

    test('the PDF and the SVG draw the same shapes', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final BarcodeStyle style in <BarcodeStyle>[
        BarcodeStyle.soft,
        BarcodeStyle.dots,
        BarcodeStyle.lagoon,
        BarcodeStyle.night,
        const BarcodeStyle(finderShape: FinderShape.circle),
      ]) {
        final BarcodeLabelSheet styled = sheet.copyWith(style: style);
        final PixelBuffer pdf = await paintPdfPage(
          pdfOf(style).contents.first,
          sheet.paper,
          6,
        );
        final PixelBuffer svg = await paintSvgPage(
          svgPage(styled, symbols, captions),
          sheet.paper,
          6,
        );
        int dark = 0;
        int differ = 0;
        for (int i = 0; i < pdf.bytes.length; i += 4) {
          dark += pdf.bytes[i] < 128 ? 1 : 0;
          differ += (pdf.bytes[i] - svg.bytes[i]).abs() > 100 ? 1 : 0;
        }
        expect(dark, greaterThan(10000));
        // Only edge pixels, rasterized a little differently.
        expect(differ, lessThan(dark / 50), reason: '$style');
      }
    });

    test('a sweep gradient cannot be drawn in the files', () async {
      final BarcodeLabelSheet sweep = sheet.copyWith(
        style: const BarcodeStyle(
          gradient: SweepGradient(
            colors: <Color>[Color(0xFF000000), Color(0xFF000080)],
          ),
        ),
      );
      await expectLater(sweep.pdf(<String>['A']), throwsUnsupportedError);
      await expectLater(
        sweep.svgPages(<String>['A']).toList(),
        throwsUnsupportedError,
      );
    });
  });
}
