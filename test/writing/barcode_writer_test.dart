import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/writing/creator_options.dart';
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
        writerCreatorOptions(
          const BarcodeWriter(
            BarcodeFormat.qrCode,
            errorCorrection: ErrorCorrection.high,
          ),
        ),
        'ecLevel=H',
      );
      expect(
        writerCreatorOptions(
          const BarcodeWriter(
            BarcodeFormat.qrCodeModel2,
            errorCorrection: ErrorCorrection.low,
          ),
        ),
        'ecLevel=L',
      );
      expect(
        writerCreatorOptions(
          const BarcodeWriter(
            BarcodeFormat.aztec,
            errorCorrection: ErrorCorrection.quartile,
          ),
        ),
        'ecLevel=36%',
      );
      expect(
        writerCreatorOptions(
          const BarcodeWriter(
            BarcodeFormat.pdf417,
            errorCorrection: ErrorCorrection.medium,
          ),
        ),
        'ecLevel=3',
      );
      // Fixed error correction: nothing to pass.
      expect(
        writerCreatorOptions(
          const BarcodeWriter(
            BarcodeFormat.dataMatrix,
            errorCorrection: ErrorCorrection.high,
          ),
        ),
        '',
      );
    });

    test('combine version, GS1 and raw options, raw first to win', () {
      expect(
        writerCreatorOptions(
          const BarcodeWriter(
            BarcodeFormat.dataMatrix,
            version: 12,
            gs1: true,
            zxingOptions: ' readerInit ',
          ),
        ),
        'readerInit,version=12,gs1',
      );
    });
  });

  group('writer checks', () {
    void ok(BarcodeWriter writer) => checkWriter(writer);
    Matcher fails(String message) => throwsA(
      isA<ArgumentError>().having(
        (ArgumentError e) => e.message,
        'message',
        contains(message),
      ),
    );

    test('version within the range of the format', () {
      for (final (BarcodeFormat format, int min, int max)
          in <(BarcodeFormat, int, int)>[
            (BarcodeFormat.qrCode, 1, 40),
            (BarcodeFormat.qrCodeModel2, 1, 40),
            (BarcodeFormat.microQrCode, 1, 4),
            (BarcodeFormat.rmqrCode, 1, 38),
            (BarcodeFormat.dataMatrix, 1, 48),
            (BarcodeFormat.aztec, 1, 36),
            (BarcodeFormat.pdf417, 1, 30),
            (BarcodeFormat.compactPdf417, 1, 30),
            (BarcodeFormat.microPdf417, 1, 4),
          ]) {
        ok(BarcodeWriter(format, version: min));
        ok(BarcodeWriter(format, version: max));
        for (final int bad in <int>[min - 1, max + 1, -1]) {
          expect(
            () => checkWriter(BarcodeWriter(format, version: bad)),
            throwsA(
              isA<RangeError>()
                  .having((RangeError e) => e.start, 'start', min)
                  .having((RangeError e) => e.end, 'end', max),
            ),
            reason: '${format.name} $bad',
          );
        }
      }
    });

    test('version on a format without versions', () {
      for (final BarcodeFormat format in BarcodeFormat.writable) {
        if (versionRange(format) == null) {
          expect(
            () => checkWriter(BarcodeWriter(format, version: 1)),
            fails('BarcodeFormat.${format.name} has no versions'),
          );
        }
      }
      expect(versionRange(BarcodeFormat.ean13), isNull);
      expect(versionRange(BarcodeFormat.aztecRune), isNull);
    });

    test('zxingOptions take the keys zxing-cpp knows', () {
      ok(
        const BarcodeWriter(
          BarcodeFormat.qrCode,
          zxingOptions:
              'ecLevel=H, eci=UTF-8, gs1, readerInit=true, data_mask: 3, '
              'version=5',
        ),
      );
      ok(
        const BarcodeWriter(
          BarcodeFormat.dataMatrix,
          zxingOptions: '{"forceSquare": true}',
        ),
      );
      ok(
        const BarcodeWriter(
          BarcodeFormat.pdf417,
          zxingOptions: 'columns=4,rows=10,ecLevel=5',
        ),
      );
      ok(
        const BarcodeWriter(
          BarcodeFormat.aztec,
          zxingOptions: 'EcLevel=23%, extraEscapeMode',
        ),
      );
      ok(const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: ' , '));
      for (final String options in <String>[
        'eci=26',
        'eci=0',
        'eci=shift_jis',
        'eci=ISO 8859 5',
        'ecLevel=50%',
        'ecLevel=2',
        'dataMask=7',
      ]) {
        ok(BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: options));
      }
      ok(
        const BarcodeWriter(
          BarcodeFormat.microQrCode,
          zxingOptions: 'ecLevel=Q, dataMask=3',
        ),
      );
    });

    test('zxingOptions zxing-cpp cannot parse are rejected', () {
      // zxing-cpp parses these in getters that cannot throw: they would end
      // the process.
      for (final (BarcodeFormat format, String options, String message)
          in <(BarcodeFormat, String, String)>[
            (BarcodeFormat.qrCode, 'version=+5', 'version takes a whole'),
            (BarcodeFormat.pdf417, 'columns=0x4', 'columns takes a whole'),
            (BarcodeFormat.pdf417, 'rows=3000000000', 'rows takes a whole'),
            (BarcodeFormat.qrCode, 'dataMask=12345678', 'dataMask is 0 to 7'),
            (BarcodeFormat.pdf417, 'columns=0', 'columns is at least 1'),
            (BarcodeFormat.qrCode, r'eci=\', 'eci is an ECI number'),
            (BarcodeFormat.qrCode, r'eci=\q', 'eci is an ECI number'),
            (BarcodeFormat.qrCode, 'eci=1234567', 'eci is an ECI number'),
            // Ignored by zxing-cpp before.
            (BarcodeFormat.qrCode, 'eci=UTF8x', 'eci is an ECI number'),
            (BarcodeFormat.pdf417, 'ecLevel=23%', 'percentages are for'),
            // A BarcodeWriteException from zxing-cpp before.
            (BarcodeFormat.aztec, 'ecLevel=L', 'L, M, Q and H are for'),
          ]) {
        expect(
          () => checkWriter(BarcodeWriter(format, zxingOptions: options)),
          fails(message),
          reason: options,
        );
      }
    });

    test('the eci names are the ones zxing-cpp knows', () {
      final String source = File(
        'third_party/zxing-cpp/core/src/CharacterSet.cpp',
      ).readAsStringSync();
      final List<String> names = RegExp(
        r'\{"([^"]+)",\s*CharacterSet::',
      ).allMatches(source).map((RegExpMatch m) => m[1]!).toList();
      expect(names, hasLength(greaterThan(30)));
      for (final String name in names) {
        expect(isCharsetName(name), isTrue, reason: name);
      }
      expect(isCharsetName('UTF-7'), isFalse);
    });

    test('zxingOptions reject unknown keys and wrong values', () {
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'nonsense=1'),
        ),
        fails('Unknown option "nonsense"'),
      );
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'ecLevel=Z'),
        ),
        fails('ecLevel is'),
      );
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'ecLevel'),
        ),
        fails('ecLevel is'),
      );
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.pdf417, zxingOptions: 'rows=ten'),
        ),
        fails('rows takes a whole number'),
      );
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'gs1=yes'),
        ),
        fails('gs1 is true or false'),
      );
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'eci='),
        ),
        fails('eci takes a value'),
      );
      expect(
        () => checkWriter(
          const BarcodeWriter(BarcodeFormat.qrCode, zxingOptions: 'version=99'),
        ),
        throwsRangeError,
      );
    });

    test('encode checks before it starts the engine', () async {
      await expectLater(
        const BarcodeWriter(BarcodeFormat.qrCode, version: 0).encode('x'),
        throwsRangeError,
      );
      await expectLater(
        const BarcodeWriter(
          BarcodeFormat.qrCode,
          zxingOptions: 'nonsense=1',
        ).encodeBytes(Uint8List(1)),
        throwsArgumentError,
      );
      await expectLater(
        const BarcodeWriter(BarcodeFormat.itf14).encode('x'),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message,
            'message',
            'BarcodeFormat.itf14 cannot be written',
          ),
        ),
      );
    });
  });

  group('toString and equality', () {
    test('BarcodeWriter shows the format and what differs', () {
      expect(
        const BarcodeWriter(BarcodeFormat.qrCode).toString(),
        'BarcodeWriter(qrCode)',
      );
      expect(
        const BarcodeWriter(
          BarcodeFormat.dataMatrix,
          errorCorrection: ErrorCorrection.high,
          version: 12,
          gs1: true,
          showText: true,
          zxingOptions: 'forceSquare',
        ).toString(),
        'BarcodeWriter(dataMatrix, errorCorrection: high, version: 12, '
        'gs1: true, showText: true, '
        "zxingOptions: 'forceSquare')",
      );
    });

    test('BarcodeSymbol and BarcodeImage show their size', () {
      expect(
        _symbol(<String>['#.', '.#']).toString(),
        'BarcodeSymbol(qrCode, 2 x 2)',
      );
      expect(
        _symbol(
          <String>['#.#'],
          quietZone: 9,
          text: '123',
          format: BarcodeFormat.ean8,
        ).toString(),
        'BarcodeSymbol(ean8, 3 x 1, quietZone: 9, text: "123")',
      );
      expect(
        BarcodeImage(width: 4, height: 2, pixels: Uint8List(8)).toString(),
        'BarcodeImage(4 x 2)',
      );
    });

    test('BarcodeSymbols are equal when they draw the same', () {
      final BarcodeSymbol a = _symbol(<String>['#.', '.#'], quietZone: 1);
      expect(a, _symbol(<String>['#.', '.#'], quietZone: 1));
      expect(a.hashCode, _symbol(<String>['#.', '.#'], quietZone: 1).hashCode);
      // Any non-zero byte is dark.
      final BarcodeSymbol other = BarcodeSymbol(
        format: BarcodeFormat.qrCode,
        width: 2,
        height: 2,
        modules: Uint8List.fromList(<int>[255, 0, 0, 7]),
        quietZone: 1,
      );
      expect(a, other);
      expect(a.hashCode, other.hashCode);
      expect(a, isNot(_symbol(<String>['#.', '##'], quietZone: 1)));
      expect(a, isNot(_symbol(<String>['#.', '.#'])));
      expect(a, isNot(_symbol(<String>['#.', '.#'], quietZone: 1, text: 'x')));
      expect(
        a,
        isNot(
          _symbol(
            <String>['#.', '.#'],
            quietZone: 1,
            format: BarcodeFormat.dataMatrix,
          ),
        ),
      );
      expect(_symbol(<String>['#.#.']), isNot(_symbol(<String>['#.', '#.'])));
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
      expect(layout.textRuns.single.text, '42');
      expect(layout.textRuns.single.top, 1 + 1 + SymbolLayout.textGap);
      expect(
        layout.height,
        1 + 2 + SymbolLayout.textGap + SymbolLayout.textFontSize + 1,
      );
    });

    test('a size: whole-pixel modules, the longer side exactly', () {
      expect(exportSize(5, 5, 100, null), (
        moduleSize: 20,
        width: 100,
        height: 100,
      ));
      expect(exportSize(5, 5, 104, null), (
        moduleSize: 20,
        width: 104,
        height: 104,
      ));
      expect(exportSize(5, 5, 5, null), (moduleSize: 1, width: 5, height: 5));
      // A linear code: the shorter side in proportion.
      expect(exportSize(100, 30, 250, null), (
        moduleSize: 2,
        width: 250,
        height: 75,
      ));
      expect(exportSize(5, 5, null, null), (
        moduleSize: 4,
        width: 20,
        height: 20,
      ));
      expect(exportSize(5, 3, null, 3), (moduleSize: 3, width: 15, height: 9));
    });

    test('a size smaller than the code, or both, is an error', () {
      expect(() => exportSize(5, 5, 4, null), throwsArgumentError);
      expect(() => exportSize(5, 5, 10, 2), throwsArgumentError);
      expect(() => exportSize(5, 5, 0, null), throwsArgumentError);
      expect(() => exportSize(5, 5, null, 0), throwsArgumentError);
    });
  });

  group('toSvg', () {
    test('is one path of the dark modules on white', () async {
      final String svg = _symbol(<String>['#.#'], quietZone: 1).toSvg();
      expect(svg, startsWith('<svg xmlns="http://www.w3.org/2000/svg" '));
      expect(svg, contains('viewBox="0 0 5 3"'));
      expect(svg, contains('width="20" height="12"'));
      expect(svg, contains('<path d="M1 1h1v1h-1zM3 1h1v1h-1z" fill="#000"/>'));
      expect(svg, isNot(contains('<text')));
      expect(svg, endsWith('</svg>'));
    });

    test('is sized in pixels: per module, or across the longer side', () {
      final BarcodeSymbol symbol = _symbol(<String>['#.#'], quietZone: 1);
      expect(symbol.toSvg(moduleSize: 10), contains('width="50" height="30"'));
      expect(symbol.toSvg(size: 100), contains('width="100" height="60"'));
      expect(symbol.toSvg(size: 100), contains('viewBox="0 0 5 3"'));
      expect(
        symbol.toSvg(quietZone: false),
        contains('viewBox="0 0 3 1" width="12" height="4"'),
      );
      expect(() => symbol.toSvg(size: 4), throwsArgumentError);
      expect(() => symbol.toSvg(size: 10, moduleSize: 2), throwsArgumentError);
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
      expect(svg, contains('<rect width="23" height="23" fill="#fff"/>'));
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
      final String id = RegExp(
        r'<linearGradient id="(ink-[0-9a-f]{8})"',
      ).firstMatch(linear)!.group(1)!;
      expect(
        linear,
        contains(
          <String>[
            '<linearGradient id="$id" gradientUnits="userSpaceOnUse" ',
            'x1="1" y1="11.5" x2="22" y2="11.5" spreadMethod="reflect">',
            '<stop offset="0" stop-color="#0b3d91"/>',
            '<stop offset="1" stop-color="#00735d"/></linearGradient>',
          ].join(),
        ),
      );
      expect(linear, contains('fill="url(#$id)"'));
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
      // Exactly the size: whole-pixel modules, the rest white margin.
      final BarcodeImage sized = await symbol.toImage(size: 41);
      expect((sized.width, sized.height), (41, 41));
      expect(sized.pixels.first, 255);
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
      final int top = layout.textRuns.single.top.toInt() * 2;
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
