// Reads the PDF and SVG pages of a BarcodeLabelSheet back: checks the PDF's
// structure, and paints the codes of a page from its rectangles, to read
// them with BarcodeReader. Used by the label sheet tests.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// A PDF read back: the MediaBox and the content stream of each page.
typedef PdfPages = ({List<List<double>> mediaBoxes, List<String> contents});

/// Checks [bytes] is a PDF with a correct cross-reference table and page
/// tree, and returns its pages.
PdfPages readPdf(Uint8List bytes) {
  // Latin-1: one character a byte, so string offsets are byte offsets.
  final String s = latin1.decode(bytes);
  expect(s.startsWith('%PDF-1.4\n'), isTrue, reason: 'header');
  final Match start = RegExp(r'startxref\n(\d+)\n%%EOF\n$').firstMatch(s)!;
  final int xref = int.parse(start[1]!);
  final Match head = RegExp(r'xref\n0 (\d+)\n').matchAsPrefix(s, xref)!;
  final int size = int.parse(head[1]!);
  int at = head.end;
  final Map<int, int> offsets = <int, int>{};
  for (int i = 0; i < size; i++) {
    final String entry = s.substring(at, at + 20);
    expect(entry, matches(RegExp(r'^\d{10} \d{5} [nf] \n$')));
    if (i == 0) {
      expect(entry, '0000000000 65535 f \n');
    } else {
      final int offset = int.parse(entry.substring(0, 10));
      expect(s.startsWith('$i 0 obj\n', offset), isTrue, reason: 'object $i');
      offsets[i] = offset;
    }
    at += 20;
  }
  expect(s.startsWith('trailer\n<</Size $size/Root 1 0 R>>', at), isTrue);
  expect(
    s.startsWith('1 0 obj\n<</Type/Catalog/Pages 2 0 R>>', offsets[1]!),
    isTrue,
  );
  final Match tree = RegExp(
    r'/Type/Pages/Kids\[([^\]]*)\]/Count (\d+)',
  ).matchAsPrefix(s, offsets[2]! + '2 0 obj\n<<'.length)!;
  final List<int> kids = <int>[
    for (final Match m in RegExp(r'(\d+) 0 R').allMatches(tree[1]!))
      int.parse(m[1]!),
  ];
  expect(kids, hasLength(int.parse(tree[2]!)));
  final List<List<double>> boxes = <List<double>>[];
  final List<String> contents = <String>[];
  for (final int kid in kids) {
    final String page = s.substring(
      offsets[kid]!,
      s.indexOf('endobj', offsets[kid]!),
    );
    expect(page, contains('/Type/Page/Parent 2 0 R'));
    final Match box = RegExp(r'/MediaBox\[([^\]]*)\]').firstMatch(page)!;
    boxes.add(<double>[
      for (final String n in box[1]!.split(' ')) double.parse(n),
    ]);
    final int stream = int.parse(
      RegExp(r'/Contents (\d+) 0 R').firstMatch(page)![1]!,
    );
    final Match dict = RegExp(
      r'\d+ 0 obj\n<</Length (\d+)(/Filter/FlateDecode)?>>\nstream\n',
    ).matchAsPrefix(s, offsets[stream]!)!;
    final int length = int.parse(dict[1]!);
    expect(s.startsWith('\nendstream\nendobj\n', dict.end + length), isTrue);
    final Uint8List data = bytes.sublist(dict.end, dict.end + length);
    contents.add(
      latin1.decode(dict[2] == null ? data : ZLibCodec().decode(data)),
    );
  }
  return (mediaBoxes: boxes, contents: contents);
}

/// The codes of a PDF page's [content] painted black on white at [px]
/// pixels a millimetre, from its module rectangles (text left out).
Future<PixelBuffer> paintPdfPage(String content, PaperSize paper, double px) {
  final RegExp code = RegExp(r'^q ([\d.]+) 0 0 ([\d.]+) ([\d.]+) ([\d.]+) cm$');
  final RegExp rect = RegExp(r'^(\d+) (\d+) (\d+) (\d+) re$');
  final List<Rect> rects = <Rect>[];
  double s = 0;
  Offset origin = Offset.zero;
  for (final String line in content.split('\n')) {
    final Match? c = code.firstMatch(line);
    if (c != null) {
      s = double.parse(c[1]!);
      origin = Offset(double.parse(c[3]!), double.parse(c[4]!));
      continue;
    }
    final Match? r = rect.firstMatch(line);
    if (r != null) {
      final List<double> v = <double>[
        for (int i = 1; i <= 4; i++) double.parse(r[i]!),
      ];
      rects.add(
        Rect.fromLTWH(
          origin.dx + v[0] * s,
          origin.dy + v[1] * s,
          v[2] * s,
          v[3] * s,
        ),
      );
    }
  }
  return _paint(rects, paper, px);
}

/// The codes of an SVG page painted black on white at [px] pixels a
/// millimetre, from the paths of its nested `<svg>`s (text left out).
Future<PixelBuffer> paintSvgPage(String svg, PaperSize paper, double px) {
  final RegExp element = RegExp(
    r'<svg x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)" '
    r'viewBox="0 0 (\d+) (\d+)"[^>]*><path d="([^"]*)"',
  );
  final RegExp move = RegExp(r'M(\d+) (\d+)h(\d+)v(\d+)h-\d+z');
  final List<Rect> rects = <Rect>[];
  for (final Match e in element.allMatches(svg)) {
    final List<double> v = <double>[
      for (int i = 1; i <= 6; i++) double.parse(e[i]!),
    ];
    // preserveAspectRatio's default: fit, centered.
    final double s = math.min(v[2] / v[4], v[3] / v[5]);
    final Offset origin = Offset(
      v[0] + (v[2] - v[4] * s) / 2,
      v[1] + (v[3] - v[5] * s) / 2,
    );
    for (final Match m in move.allMatches(e[7]!)) {
      rects.add(
        Rect.fromLTWH(
          origin.dx + int.parse(m[1]!) * s,
          origin.dy + int.parse(m[2]!) * s,
          int.parse(m[3]!) * s,
          int.parse(m[4]!) * s,
        ),
      );
    }
  }
  return _paint(rects, paper, px);
}

Future<PixelBuffer> _paint(List<Rect> rects, PaperSize paper, double px) async {
  final int w = (paper.width * px).ceil();
  final int h = (paper.height * px).ceil();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  final Paint black = Paint()
    ..color = const Color(0xFF000000)
    ..isAntiAlias = false;
  for (final Rect r in rects) {
    canvas.drawRect(
      Rect.fromLTRB(r.left * px, r.top * px, r.right * px, r.bottom * px),
      black,
    );
  }
  final ui.Picture picture = recorder.endRecording();
  final ui.Image image = await picture.toImage(w, h);
  picture.dispose();
  final ByteData rgba = (await image.toByteData())!;
  image.dispose();
  return PixelBuffer(
    rgba.buffer.asUint8List(),
    width: w,
    height: h,
    layout: PixelLayout.rgba,
  );
}
