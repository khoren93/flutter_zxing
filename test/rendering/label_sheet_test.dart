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
}
