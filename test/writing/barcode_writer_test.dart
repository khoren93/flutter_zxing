import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/writing/symbol_layout.dart';

/// A symbol from rows of '#' (dark) and '.' (light).
BarcodeSymbol _symbol(
  List<String> rows, {
  int quietZone = 0,
  String? text,
  BarcodeFormat format = BarcodeFormat.qrCode,
}) => BarcodeSymbol(
  format: format,
  width: rows.first.length,
  height: rows.length,
  modules: Uint8List.fromList(<int>[
    for (final String row in rows)
      for (final int c in row.codeUnits)
        if (c == 0x23) 1 else 0,
  ]),
  quietZone: quietZone,
  text: text,
);

void main() {
  group('creator options', () {
    test('map error correction per symbology', () {
      expect(
        const BarcodeWriter(
          BarcodeFormat.qrCode,
          errorCorrection: ErrorCorrection.high,
        ).creatorOptions,
        'ecLevel=H',
      );
      expect(
        const BarcodeWriter(
          BarcodeFormat.qrCodeModel2,
          errorCorrection: ErrorCorrection.low,
        ).creatorOptions,
        'ecLevel=L',
      );
      expect(
        const BarcodeWriter(
          BarcodeFormat.aztec,
          errorCorrection: ErrorCorrection.quartile,
        ).creatorOptions,
        'ecLevel=36%',
      );
      expect(
        const BarcodeWriter(
          BarcodeFormat.pdf417,
          errorCorrection: ErrorCorrection.medium,
        ).creatorOptions,
        'ecLevel=3',
      );
      // Fixed error correction: nothing to pass.
      expect(
        const BarcodeWriter(
          BarcodeFormat.dataMatrix,
          errorCorrection: ErrorCorrection.high,
        ).creatorOptions,
        '',
      );
    });

    test('combine version, GS1 and raw options, raw last', () {
      expect(
        const BarcodeWriter(
          BarcodeFormat.dataMatrix,
          version: 12,
          gs1: true,
          options: ' readerInit ',
        ).creatorOptions,
        'version=12,gs1,readerInit',
      );
    });
  });

  group('SymbolLayout', () {
    test('merges identical rows into one rectangle per bar', () {
      final SymbolLayout layout = SymbolLayout(
        _symbol(<String>['#.##', '#.##', '#.##'], quietZone: 2),
      );
      expect(layout.width, 8);
      expect(layout.height, 7);
      expect(layout.rects, const <ModuleRect>[
        ModuleRect(2, 2, 1, 3),
        ModuleRect(4, 2, 2, 3),
      ]);
    });

    test('splits runs that change from row to row', () {
      final SymbolLayout layout = SymbolLayout(
        _symbol(<String>['##.', '###', '.##']),
      );
      expect(layout.rects, const <ModuleRect>[
        ModuleRect(0, 0, 2, 1),
        ModuleRect(0, 1, 3, 1),
        ModuleRect(1, 2, 2, 1),
      ]);
    });

    test('makes room for text under the bars', () {
      final SymbolLayout layout = SymbolLayout(
        _symbol(<String>['#.#'], quietZone: 1, text: '42'),
      );
      expect(layout.text, '42');
      expect(layout.textTop, 1 + 1 + SymbolLayout.textGap);
      expect(
        layout.height,
        1 + 2 + SymbolLayout.textGap + SymbolLayout.textFontSize + 1,
      );
    });

    test('fits a size with whole-pixel modules', () {
      final SymbolLayout layout = SymbolLayout(
        _symbol(<String>['#.#', '.#.', '#.#'], quietZone: 1),
      );
      expect(layout.moduleSizeFor(100), 20);
      expect(layout.moduleSizeFor(3), 1);
    });
  });

  group('toSvg', () {
    test('is one path of the dark modules on white', () async {
      final String svg = _symbol(<String>['#.#'], quietZone: 1).toSvg();
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg" '));
      expect(svg, contains('viewBox="0 0 5 3"'));
      expect(svg, contains('<path d="M1 1h1v1h-1zM3 1h1v1h-1z" fill="#000"/>'));
      expect(svg, isNot(contains('<text')));
      expect(svg, endsWith('</svg>'));
    });

    test('adds the text, escaped', () async {
      final String svg = _symbol(<String>['#'], text: 'a<b&c').toSvg();
      expect(svg, contains('>a&lt;b&amp;c</text>'));
    });
  });

  group('toSvg with a style', () {
    // A 21 × 21 QR-sized symbol: finder patterns in three corners.
    final BarcodeSymbol qr = _symbol(<String>[
      for (int y = 0; y < 21; y++)
        String.fromCharCodes(<int>[
          for (int x = 0; x < 21; x++)
            if ((x + y).isEven) 0x23 else 0x2E,
        ]),
    ], quietZone: 1);

    test('colors, with opacity, in the short form where possible', () async {
      final String svg = await const BarcodeStyle(
        color: Color(0x801B4DFF),
      ).toSvg(qr);
      expect(svg, contains('fill="#1b4dff" fill-opacity="0.502"'));
      expect(svg, contains('<rect width="100%" height="100%" fill="#fff"/>'));
      expect(svg, contains('shape-rendering="crispEdges"'));
    });

    test('a transparent background is left out', () async {
      final String svg = await const BarcodeStyle(
        backgroundColor: Color(0x00000000),
      ).toSvg(qr);
      expect(svg, isNot(contains('<rect')));
    });

    test('rounded and circle shapes are arcs, finders even-odd', () async {
      final String rounded = await const BarcodeStyle(
        moduleShape: ModuleShape.rounded,
        finderShape: FinderShape.circle,
      ).toSvg(qr);
      expect(rounded, isNot(contains('crispEdges')));
      expect(rounded, contains('A0.5 0.5 0 0 1'));
      expect(rounded, contains('fill-rule="evenodd"'));
      // The three finders: three rings and three cores, six circles of
      // radius 3.5, 2.5 and 1.5 each drawn as two arcs.
      expect(RegExp('A3.5 3.5 ').allMatches(rounded).length, 6);
      final String dots = await const BarcodeStyle(
        moduleShape: ModuleShape.circle,
      ).toSvg(qr);
      expect(dots, contains('A0.45 0.45 0 1 1'));
    });

    test('linear and radial gradients span the symbol', () async {
      final String linear = await const BarcodeStyle(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF0B3D91), Color(0xFF00735D)],
          tileMode: TileMode.mirror,
        ),
      ).toSvg(qr);
      expect(
        linear,
        contains(
          <String>[
            '<linearGradient id="ink" gradientUnits="userSpaceOnUse" ',
            'x1="1" y1="11.5" x2="22" y2="11.5" spreadMethod="reflect">',
            '<stop offset="0" stop-color="#0b3d91"/>',
            '<stop offset="1" stop-color="#00735d"/></linearGradient>',
          ].join(),
        ),
      );
      expect(linear, contains('fill="url(#ink)"'));
      final String radial = await const BarcodeStyle(
        gradient: RadialGradient(
          colors: <Color>[Color(0xFF000000), Color(0xFF333333)],
          stops: <double>[0.2, 1],
        ),
      ).toSvg(qr);
      expect(radial, contains('cx="11.5" cy="11.5" r="10.5"'));
      expect(radial, contains('<stop offset="0.2" stop-color="#000"/>'));
    });

    test('a sweep gradient cannot be written', () async {
      await expectLater(
        const BarcodeStyle(
          gradient: SweepGradient(
            colors: <Color>[Color(0xFF000000), Color(0xFF333333)],
          ),
        ).toSvg(qr),
        throwsUnsupportedError,
      );
    });

    test('quietZone: false drops the margin', () async {
      final String svg = await const BarcodeStyle(quietZone: false).toSvg(qr);
      expect(svg, contains('viewBox="0 0 21 21"'));
    });

    test('the text takes the color', () async {
      final String svg = await const BarcodeStyle(
        color: Color(0xFF123456),
      ).toSvg(_symbol(<String>['#'], text: '1'));
      expect(svg, contains('text-anchor="middle" fill="#123456">1</text>'));
    });
  });

  group('toImage', () {
    final BarcodeSymbol symbol = _symbol(<String>['#.', '.#'], quietZone: 1);

    test('draws modules of the requested size', () async {
      final BarcodeImage image = await symbol.toImage(moduleSize: 3);
      expect(image.width, 12);
      expect(image.height, 12);
      int at(int x, int y) => image.pixels[y * image.width + x];
      expect(at(0, 0), 255); // quiet zone
      expect(at(3, 3), 0); // first dark module
      expect(at(5, 5), 0);
      expect(at(6, 3), 255); // light module
      expect(at(6, 6), 0);
    });

    test('defaults to 4 pixels per module and fits a size', () async {
      expect((await symbol.toImage()).width, 16);
      expect((await symbol.toImage(size: 41)).width, 40);
    });

    test('rejects both sizes, or a size below 1', () async {
      await expectLater(
        symbol.toImage(size: 10, moduleSize: 2),
        throwsArgumentError,
      );
      await expectLater(symbol.toImage(moduleSize: 0), throwsArgumentError);
    });

    test('draws the text under the bars', () async {
      final BarcodeImage image = await _symbol(<String>[
        '#.#.#.#.#.',
      ], text: '0123').toImage(moduleSize: 2);
      final SymbolLayout layout = SymbolLayout(
        _symbol(<String>['#.#.#.#.#.'], text: '0123'),
      );
      final int top = layout.textTop * 2;
      final Iterable<int> textBox = image.pixels.skip(top * image.width);
      expect(textBox.any((int v) => v < 128), isTrue);
    });
  });

  group('BarcodeImage', () {
    test('converts to a ui.Image and to PNG', () async {
      final BarcodeImage image = await _symbol(<String>[
        '#.',
        '.#',
      ]).toImage(moduleSize: 2);
      final Uint8List png = await image.toPng();
      expect(png.sublist(0, 8), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
      final ui.Image decoded = await image.toUiImage();
      expect(decoded.width, 4);
      decoded.dispose();
    });
  });
}
