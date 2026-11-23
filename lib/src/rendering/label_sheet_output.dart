// Where a code and its caption go on a label, and the pages of a
// BarcodeLabelSheet as SVG and PDF: one geometry for both files and the
// preview widget. Not exported from the package.
import 'dart:convert' show latin1;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'label_sheet.dart';
import 'pdf_deflate.dart' if (dart.library.io) 'pdf_deflate_io.dart';

/// Space between a code and its caption, as a fraction of the caption size.
const double captionGap = 0.25;

/// Where the caption's baseline sits in its box, as a fraction of its
/// height: room for descenders under it.
const double captionBaseline = 0.78;

/// Width of a monospace character, as a fraction of the font size: exact
/// for Courier, about right for the monospace fonts SVG viewers pick.
const double monospaceAdvance = 0.6;

/// Points per millimetre.
const double pointsPerMm = 72 / 25.4;

/// Where the code and the caption of one label go, in millimetres.
@immutable
final class LabelPlacement {
  /// Creates a placement.
  const LabelPlacement({
    required this.code,
    required this.captionBox,
    required this.captionFontSize,
  });

  /// The code, quiet zone included, with the symbol's own proportions.
  final Rect code;

  /// The line of the caption, as wide as the label inside its padding;
  /// `null` when the sheet has no captions.
  final Rect? captionBox;

  /// The caption's font size: the sheet's, smaller for a caption that
  /// would not fit across.
  final double captionFontSize;

  /// The caption's baseline.
  double get baseline => captionBox!.top + captionBox!.height * captionBaseline;
}

/// The code of [layout] and [caption] on [label] (millimetres) of [sheet]:
/// the code as large as fits above the caption line, the two centered as
/// a group inside the padding.
LabelPlacement placeLabel(
  BarcodeLabelSheet sheet,
  Rect label,
  SymbolLayout layout,
  String? caption,
) {
  final double p = sheet.padding;
  final Rect inner = Rect.fromLTRB(
    label.left + p,
    label.top + p,
    label.right - p,
    label.bottom - p,
  );
  final double line = sheet.caption ? sheet.captionSize : 0;
  final double below = sheet.caption ? line * (1 + captionGap) : 0;
  final double scale = math.min(
    inner.width / layout.width,
    (inner.height - below) / layout.height,
  );
  final double w = layout.width * scale;
  final double h = layout.height * scale;
  final double top = inner.top + (inner.height - h - below) / 2;
  final Rect code = Rect.fromLTWH(
    inner.left + (inner.width - w) / 2,
    top,
    w,
    h,
  );
  if (!sheet.caption) {
    return LabelPlacement(code: code, captionBox: null, captionFontSize: 0);
  }
  final int chars = caption == null ? 0 : caption.runes.length;
  return LabelPlacement(
    code: code,
    captionBox: Rect.fromLTWH(
      inner.left,
      code.bottom + line * captionGap,
      inner.width,
      line,
    ),
    captionFontSize: chars == 0
        ? line
        : math.min(line, inner.width / (chars * monospaceAdvance)),
  );
}

/// Throws [ArgumentError] if the labels of [sheet] leave no room for a
/// code.
void checkRoom(BarcodeLabelSheet sheet) {
  final Rect label = sheet.labelRect(0);
  final double p = sheet.padding;
  final double below = sheet.caption ? sheet.captionSize * (1 + captionGap) : 0;
  if (label.width - 2 * p <= 0 || label.height - 2 * p - below <= 0) {
    throw ArgumentError(
      'The labels (${_n(label.width)} x ${_n(label.height)} mm) leave no '
      'room for a code inside the padding and caption',
    );
  }
}

/// A number with at most three decimals, without trailing zeros.
String _n(double v) {
  final int i = (v * 1000).round();
  if (i % 1000 == 0) {
    return (i ~/ 1000).toString();
  }
  String s = (i / 1000).toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// [v] rounded to three decimals.
double _r(double v) => (v * 1000).roundToDouble() / 1000;

/// One page of [sheet] as an SVG document in millimetres: [symbols] in
/// label order, [captions] under them (`null`: none).
String svgPage(
  BarcodeLabelSheet sheet,
  List<BarcodeSymbol> symbols,
  List<String?> captions,
) {
  final PaperSize paper = sheet.paper;
  final StringBuffer svg = StringBuffer()
    ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
    ..write('width="${_n(paper.width)}mm" height="${_n(paper.height)}mm" ')
    ..write('viewBox="0 0 ${_n(paper.width)} ${_n(paper.height)}">')
    ..write('<rect width="100%" height="100%" fill="#fff"/>');
  for (int i = 0; i < symbols.length; i++) {
    final BarcodeSymbol symbol = symbols[i];
    final String? caption = captions[i];
    final LabelPlacement at = placeLabel(
      sheet,
      sheet.labelRect(i),
      SymbolLayout(symbol),
      caption,
    );
    svg.write(
      symbol.toSvgElement(
        x: _r(at.code.left),
        y: _r(at.code.top),
        width: _r(at.code.width),
        height: _r(at.code.height),
      ),
    );
    final Rect? box = at.captionBox;
    if (box != null && caption != null && caption.isNotEmpty) {
      svg
        ..write('<text x="${_n(box.center.dx)}" y="${_n(at.baseline)}" ')
        ..write('font-family="monospace" ')
        ..write('font-size="${_n(at.captionFontSize)}" ')
        ..write('text-anchor="middle" fill="#000">')
        ..write(xmlEscape(caption))
        ..write('</text>');
    }
  }
  svg.write('</svg>');
  return svg.toString();
}

/// The content stream of one page of [sheet] as a PDF draws it: in
/// millimetres with y down, black rectangles for the modules, Courier for
/// the text.
String pdfPageContent(
  BarcodeLabelSheet sheet,
  List<BarcodeSymbol> symbols,
  List<String?> captions,
) {
  final StringBuffer out = StringBuffer()
    ..write('q\n')
    ..write('${pointsPerMm.toStringAsFixed(7)} 0 0 ')
    ..write('-${pointsPerMm.toStringAsFixed(7)} 0 ')
    ..write('${_n(sheet.paper.height * pointsPerMm)} cm\n')
    ..write('0 g\n');
  for (int i = 0; i < symbols.length; i++) {
    final SymbolLayout layout = SymbolLayout(symbols[i]);
    final String? caption = captions[i];
    final LabelPlacement at = placeLabel(
      sheet,
      sheet.labelRect(i),
      layout,
      caption,
    );
    // The code in module units.
    final double m = at.code.width / layout.width;
    out.write(
      'q ${m.toStringAsFixed(6)} 0 0 ${m.toStringAsFixed(6)} '
      '${_n(at.code.left)} ${_n(at.code.top)} cm\n',
    );
    for (final ModuleRect r in layout.rects) {
      out.write('${r.x} ${r.y} ${r.width} ${r.height} re\n');
    }
    out.write('f\n');
    for (final TextRun t in layout.textRuns) {
      final double size = t.fittedSize(layout.width);
      _pdfText(out, t.text, t.x, t.top + t.fontSize, size);
    }
    out.write('Q\n');
    if (at.captionBox != null && caption != null && caption.isNotEmpty) {
      _pdfText(
        out,
        caption,
        at.captionBox!.center.dx,
        at.baseline,
        at.captionFontSize,
      );
    }
  }
  out.write('Q\n');
  return out.toString();
}

/// [text] in Courier at [size], centered on [x], its baseline at [y], in
/// a space with y down.
void _pdfText(StringBuffer out, String text, double x, double y, double size) {
  final double width = text.runes.length * monospaceAdvance * size;
  out
    ..write('BT /F1 ${_n(size)} Tf 1 0 0 -1 ')
    ..write('${_n(x - width / 2)} ${_n(y)} Tm ')
    ..write(pdfString(text))
    ..write(' Tj ET\n');
}

/// [text] as a PDF string in WinAnsiEncoding, ASCII only: Latin-1
/// characters as octal escapes, any other character as `?`.
String pdfString(String text) {
  final StringBuffer s = StringBuffer('(');
  for (final int r in text.runes) {
    if (r == 0x28 || r == 0x29 || r == 0x5C) {
      s
        ..write(r'\')
        ..writeCharCode(r);
    } else if (r >= 0x20 && r < 0x7F) {
      s.writeCharCode(r);
    } else if (r >= 0xA0 && r <= 0xFF) {
      s.write('\\${r.toRadixString(8)}');
    } else {
      s.write('?');
    }
  }
  s.write(')');
  return s.toString();
}

/// Writes a PDF of pages that draw with the built-in Courier font: the
/// pages as they come, then the page tree and the cross-reference table.
final class PdfWriter {
  /// Starts a document.
  PdfWriter() {
    _write('%PDF-1.4\n');
    // A comment of high bytes: tells tools the file is binary.
    _bytes.add(const <int>[0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    _object(1, '<</Type/Catalog/Pages 2 0 R>>');
    _object(
      3,
      '<</Type/Font/Subtype/Type1/BaseFont/Courier'
      '/Encoding/WinAnsiEncoding>>',
    );
  }

  final BytesBuilder _bytes = BytesBuilder(copy: false);

  /// The byte offset of each object, by number.
  final Map<int, int> _offsets = <int, int>{};
  final List<int> _pages = <int>[];
  int _next = 4;

  void _write(String s) => _bytes.add(latin1.encode(s));

  void _object(int number, String body) {
    _offsets[number] = _bytes.length;
    _write('$number 0 obj\n$body\nendobj\n');
  }

  /// Adds a page [width] x [height] millimetres drawn by [content].
  void addPage(double width, double height, String content) {
    final int page = _next++;
    final int stream = _next++;
    _pages.add(page);
    final String box =
        '0 0 ${_n(width * pointsPerMm)} '
        '${_n(height * pointsPerMm)}';
    _object(
      page,
      '<</Type/Page/Parent 2 0 R/MediaBox[$box]'
      ' /Resources<</Font<</F1 3 0 R>>>> /Contents $stream 0 R>>',
    );
    final Uint8List raw = latin1.encode(content);
    final Uint8List? packed = deflate(raw);
    final Uint8List data = packed ?? raw;
    _offsets[stream] = _bytes.length;
    _write(
      '$stream 0 obj\n<</Length ${data.length}'
      '${packed == null ? '' : '/Filter/FlateDecode'}>>\nstream\n',
    );
    _bytes.add(data);
    _write('\nendstream\nendobj\n');
  }

  /// The finished document.
  Uint8List close() {
    _object(
      2,
      '<</Type/Pages/Kids[${_pages.map((int p) => '$p 0 R').join(' ')}]'
      '/Count ${_pages.length}>>',
    );
    final int xref = _bytes.length;
    final StringBuffer table = StringBuffer('xref\n0 $_next\n')
      ..write('0000000000 65535 f \n');
    for (int i = 1; i < _next; i++) {
      table.write('${_offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    table
      ..write('trailer\n<</Size $_next/Root 1 0 R>>\n')
      ..write('startxref\n$xref\n%%EOF\n');
    _write(table.toString());
    return _bytes.takeBytes();
  }
}
