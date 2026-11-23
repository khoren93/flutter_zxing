// Reads the PDF and SVG pages of a BarcodeLabelSheet back: checks the PDF's
// structure, and paints the codes of a page from its paths, to read them
// with BarcodeReader. Used by the label sheet tests.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// A PDF read back: the MediaBox, the content stream and the resources of
/// each page, and the dictionary of every object by number (a stream's
/// without its data).
typedef PdfPages = ({
  List<List<double>> mediaBoxes,
  List<String> contents,
  List<String> resources,
  Map<int, String> objects,
});

/// Checks [bytes] is a PDF with a correct cross-reference table and page
/// tree, every stream's length and every reference, and returns its pages.
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
  final Map<int, String> objects = <int, String>{};
  for (final MapEntry<int, int> o in offsets.entries) {
    final int body = s.indexOf('\n', o.value) + 1;
    final int end = s.indexOf('\nendobj\n', body);
    final int stream = s.indexOf('>>\nstream\n', body);
    if (stream >= 0 && stream < end) {
      final String dict = s.substring(body, stream + 2);
      final int length = int.parse(
        RegExp(r'/Length (\d+)').firstMatch(dict)![1]!,
      );
      final int data = stream + '>>\nstream\n'.length;
      expect(
        s.startsWith('\nendstream\nendobj\n', data + length),
        isTrue,
        reason: 'the length of stream ${o.key}',
      );
      objects[o.key] = dict;
    } else {
      objects[o.key] = s.substring(body, end);
    }
  }
  for (final String body in objects.values) {
    for (final Match r in RegExp(r'(\d+) 0 R').allMatches(body)) {
      expect(objects, contains(int.parse(r[1]!)), reason: 'reference $r');
    }
  }
  final List<List<double>> boxes = <List<double>>[];
  final List<String> contents = <String>[];
  final List<String> resources = <String>[];
  for (final int kid in kids) {
    final String page = s.substring(
      offsets[kid]!,
      s.indexOf('endobj', offsets[kid]!),
    );
    expect(page, contains('/Type/Page/Parent 2 0 R'));
    resources.add(
      RegExp(r'/Resources<<(.*)>> /Contents').firstMatch(page)![1]!,
    );
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
  return (
    mediaBoxes: boxes,
    contents: contents,
    resources: resources,
    objects: objects,
  );
}

/// Where a gradient paints, as the painters show it: dark, as every
/// gradient in the tests is.
const Color shadingInk = Color(0xFF1D3D7A);

/// Where a logo image goes, as the painters show it: a mid gray square,
/// harder to read around than the cleared modules.
const Color logoInk = Color(0xFF808080);

/// The codes of a PDF page's [content] painted at [px] pixels a
/// millimetre: its paths filled (nonzero `f`, even-odd `f*`) in their
/// `rg`/`g` colors, stroked (`S`, round caps with `1 J`) in their `RG`
/// color and `w` width, clips (`W n`, `W* n`), a shading or a shading
/// pattern (`sh`, `scn`, `SCN`) as [shadingInk], an image (`Do`) as a
/// [logoInk] square; text left out.
Future<PixelBuffer> paintPdfPage(String content, PaperSize paper, double px) {
  const double pointsPerMm = 72 / 25.4;
  return _paintWith(paper, px, (Canvas canvas) {
    final double k = px / pointsPerMm;
    canvas
      ..translate(0, paper.height * px)
      ..scale(k, -k);
    final List<double> args = <double>[];
    Path path = Path();
    PathFillType? clip;
    Color color = const Color(0xFF000000);
    Color stroke = const Color(0xFF000000);
    double width = 1;
    StrokeCap cap = StrokeCap.butt;
    final List<(Color, Color, double, StrokeCap)> states =
        <(Color, Color, double, StrokeCap)>[];
    Paint paint(Color c) => Paint()
      ..color = c
      ..isAntiAlias = false;
    double a(int i) => args[args.length - 6 + i];
    for (final String line in content.split('\n')) {
      if (line.startsWith('BT ')) {
        continue;
      }
      for (final String token in line.split(' ')) {
        if (token.isEmpty || token.startsWith('/')) {
          continue;
        }
        final double? number = double.tryParse(token);
        if (number != null) {
          args.add(number);
          continue;
        }
        switch (token) {
          case 'q':
            canvas.save();
            states.add((color, stroke, width, cap));
          case 'Q':
            canvas.restore();
            (color, stroke, width, cap) = states.removeLast();
          case 'cm':
            canvas.transform(
              Float64List.fromList(<double>[
                a(0), a(1), 0, 0, //
                a(2), a(3), 0, 0,
                0, 0, 1, 0,
                a(4), a(5), 0, 1,
              ]),
            );
          case 're':
            final int n = args.length;
            path.addRect(
              Rect.fromLTWH(args[n - 4], args[n - 3], args[n - 2], args[n - 1]),
            );
          case 'm':
            path.moveTo(args[args.length - 2], args.last);
          case 'l':
            path.lineTo(args[args.length - 2], args.last);
          case 'c':
            path.cubicTo(a(0), a(1), a(2), a(3), a(4), a(5));
          case 'h':
            path.close();
          case 'f' || 'f*':
            path.fillType = token == 'f'
                ? PathFillType.nonZero
                : PathFillType.evenOdd;
            canvas.drawPath(path, paint(color));
            path = Path();
          case 'W' || 'W*':
            clip = token == 'W' ? PathFillType.nonZero : PathFillType.evenOdd;
          case 'n':
            if (clip != null) {
              canvas.clipPath(path..fillType = clip, doAntiAlias: false);
            }
            clip = null;
            path = Path();
          case 'S':
            canvas.drawPath(
              path,
              paint(stroke)
                ..style = PaintingStyle.stroke
                ..strokeWidth = width
                ..strokeCap = cap,
            );
            path = Path();
          case 'w':
            width = args.last;
          case 'J':
            cap = StrokeCap.values[args.last.toInt()];
          case 'cs' || 'CS':
            break;
          case 'scn':
            color = shadingInk;
          case 'SCN':
            stroke = shadingInk;
          case 'RG':
            final int n = args.length;
            stroke = Color.from(
              alpha: 1,
              red: args[n - 3],
              green: args[n - 2],
              blue: args[n - 1],
            );
          case 'rg':
            final int n = args.length;
            color = Color.from(
              alpha: 1,
              red: args[n - 3],
              green: args[n - 2],
              blue: args[n - 1],
            );
          case 'g':
            color = Color.from(
              alpha: 1,
              red: args.last,
              green: args.last,
              blue: args.last,
            );
          case 'sh':
            canvas.drawPaint(paint(shadingInk));
          case 'Do':
            canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), paint(logoInk));
          default:
            fail('Unknown PDF operator $token');
        }
        args.clear();
      }
    }
  });
}

/// The codes of an SVG page painted at [px] pixels a millimetre, from its
/// nested `<svg>`s: their background `<rect>`, their `<path>`s in their
/// fill (a gradient as [shadingInk]) and fill rule, a `<use>` of the logo
/// as a [logoInk] square; text left out.
Future<PixelBuffer> paintSvgPage(String svg, PaperSize paper, double px) {
  final RegExp element = RegExp(
    r'<svg x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)" '
    r'viewBox="0 0 (\d+) (\d+)"[^>]*>(.*?)</svg>',
  );
  final RegExp shape = RegExp(r'<(rect|path|use) ([^>]*)/>');
  String? attribute(String attributes, String name) =>
      RegExp('(?:^| )$name="([^"]*)"').firstMatch(attributes)?[1];
  return _paintWith(paper, px, (Canvas canvas) {
    canvas.scale(px);
    for (final Match e in element.allMatches(svg)) {
      final List<double> v = <double>[
        for (int i = 1; i <= 6; i++) double.parse(e[i]!),
      ];
      // preserveAspectRatio's default: fit, centered.
      final double s = math.min(v[2] / v[4], v[3] / v[5]);
      canvas
        ..save()
        ..translate(v[0] + (v[2] - v[4] * s) / 2, v[1] + (v[3] - v[5] * s) / 2)
        ..scale(s);
      for (final Match m in shape.allMatches(e[7]!)) {
        final String at = m[2]!;
        double n(String name) => double.parse(attribute(at, name) ?? '0');
        switch (m[1]) {
          case 'rect':
            canvas.drawRect(
              Rect.fromLTWH(0, 0, n('width'), n('height')),
              _ink(attribute(at, 'fill')!),
            );
          case 'use':
            canvas.drawRect(
              Rect.fromLTWH(n('x'), n('y'), n('width'), n('height')),
              _ink('#808080'),
            );
          case 'path':
            final Path path = _svgPath(attribute(at, 'd')!)
              ..fillType = attribute(at, 'fill-rule') == 'evenodd'
                  ? PathFillType.evenOdd
                  : PathFillType.nonZero;
            canvas.drawPath(path, _ink(attribute(at, 'fill')!));
        }
      }
      canvas.restore();
    }
  });
}

/// A paint of an SVG fill: `#rgb`, `#rrggbb`, or a gradient as
/// [shadingInk].
Paint _ink(String fill) {
  Color color = shadingInk;
  if (fill.startsWith('#')) {
    String hex = fill.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((String c) => '$c$c').join();
    }
    color = Color(0xFF000000 | int.parse(hex, radix: 16));
  }
  return Paint()
    ..color = color
    ..isAntiAlias = false;
}

/// SVG path data as a [Path]: the commands the package writes (M, H, V,
/// h, v, A, z).
Path _svgPath(String d) {
  final Path path = Path();
  final List<String> tokens = <String>[
    for (final Match m in RegExp(r'[MHVhvAzL]|-?\d*\.?\d+').allMatches(d))
      m[0]!,
  ];
  double x = 0;
  double y = 0;
  double startX = 0;
  double startY = 0;
  int i = 0;
  double next() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    final String c = tokens[i++];
    switch (c) {
      case 'M':
        x = startX = next();
        y = startY = next();
        path.moveTo(x, y);
      case 'L':
        x = next();
        y = next();
        path.lineTo(x, y);
      case 'H':
        x = next();
        path.lineTo(x, y);
      case 'V':
        y = next();
        path.lineTo(x, y);
      case 'h':
        x += next();
        path.lineTo(x, y);
      case 'v':
        y += next();
        path.lineTo(x, y);
      case 'A':
        final double rx = next();
        final double ry = next();
        final double rotation = next();
        final bool large = next() != 0;
        final bool sweep = next() != 0;
        x = next();
        y = next();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: large,
          clockwise: sweep,
        );
      case 'z':
        path.close();
        x = startX;
        y = startY;
      default:
        fail('Unknown path command $c in $d');
    }
  }
  return path;
}

Future<PixelBuffer> _paintWith(
  PaperSize paper,
  double px,
  void Function(Canvas canvas) draw,
) async {
  final int w = (paper.width * px).ceil();
  final int h = (paper.height * px).ceil();
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawColor(const Color(0xFFFFFFFF), BlendMode.src);
  draw(canvas);
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
