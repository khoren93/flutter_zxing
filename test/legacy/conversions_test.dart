// The mapping between the 3.x API and the 4.0 engine, without the engine.
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';
import 'package:flutter_zxing/src/legacy/conversions.dart';

/// Every 3.x format bit that reads something.
const List<int> _bits = <int>[
  Format.aztec,
  Format.codabar,
  Format.code39,
  Format.code93,
  Format.code128,
  Format.dataBar,
  Format.dataBarExpanded,
  Format.dataMatrix,
  Format.ean8,
  Format.ean13,
  Format.itf,
  Format.maxiCode,
  Format.pdf417,
  Format.qrCode,
  Format.upca,
  Format.upce,
  Format.microQRCode,
  Format.rmqrCode,
  Format.dxFilmEdge,
  Format.dataBarLimited,
  Format.telepen,
  Format.microPdf417,
];

/// A symbol from rows of '#' (dark) and '.' (light).
EngineSymbol _symbol(
  List<String> rows, {
  BarcodeFormat format = BarcodeFormat.qrCode,
  int quietZone = 0,
}) => EngineSymbol(
  format: format,
  width: rows.first.length,
  height: rows.length,
  modules: Uint8List.fromList(<int>[
    for (final String row in rows)
      for (final int c in row.codeUnits)
        if (c == 0x23) 1 else 0,
  ]),
  quietZoneLeft: quietZone,
  quietZoneTop: quietZone,
  quietZoneRight: quietZone,
  quietZoneBottom: quietZone,
);

/// The bitmap of [encode] as rows of '#' and '.'.
List<String> _rows(Encode encode) => <String>[
  for (int y = 0; y < encode.height!; y++)
    String.fromCharCodes(<int>[
      for (int x = 0; x < encode.width!; x++)
        if (encode.data![y * encode.width! + x] == 0) 0x23 else 0x2e,
    ]),
];

void main() {
  group('formats', () {
    test('no known bit means every format', () {
      expect(formatsOfMask(Format.none), isNull);
      expect(formatsOfMask(1 << 30), isNull);
    });

    test('Code 39 and DataBar mean the variants 3.x read', () {
      expect(formatsOfMask(Format.code39), <BarcodeFormat>{
        BarcodeFormat.code39Standard,
        BarcodeFormat.code39Extended,
      });
      expect(
        formatsOfMask(Format.dataBar),
        isNot(contains(BarcodeFormat.dataBarExpanded)),
      );
      expect(formatsOfMask(Format.any), isNot(contains(BarcodeFormat.code32)));
    });

    test('a mask combines its bits', () {
      expect(formatsOfMask(Format.qrCode | Format.ean13), <BarcodeFormat>{
        BarcodeFormat.qrCode,
        BarcodeFormat.ean13,
      });
    });

    test('what a bit reads is reported as that bit', () {
      for (final int bit in _bits) {
        for (final BarcodeFormat format in formatsOfMask(bit)!) {
          expect(formatBitOf(format), bit, reason: format.name);
        }
      }
    });

    test('every readable format has a bit, except the EAN add-ons', () {
      for (final BarcodeFormat format in BarcodeFormat.values) {
        final bool known =
            format.canRead &&
            format != BarcodeFormat.ean2 &&
            format != BarcodeFormat.ean5;
        expect(formatBitOf(format) != Format.none, known, reason: format.name);
      }
    });

    test('every format 3.x could create can still be created', () {
      for (final int bit in <int>[
        ...CodeFormat.supportedEncodeFormats,
        Format.pdf417,
      ]) {
        expect(writeFormatOf(bit)?.canWrite, isTrue, reason: bit.name);
      }
      expect(writeFormatOf(Format.dataBar), isNull);
      expect(writeFormatOf(Format.qrCode | Format.aztec), isNull);
    });

    test('error correction keeps its name', () {
      for (final EccLevel level in EccLevel.values) {
        expect(errorCorrectionOf(level).name, level.name);
      }
    });
  });

  group('pixelBufferOf', () {
    DecodeParams params(int imageFormat, {int width = 2, int height = 1}) =>
        DecodeParams(imageFormat: imageFormat, width: width, height: height);

    test('passes the layouts the engine reads through', () {
      final Uint8List bytes = Uint8List(8);
      for (final (int format, PixelLayout layout) in <(int, PixelLayout)>[
        (ImageFormat.lum, PixelLayout.luminance),
        (ImageFormat.rgb, PixelLayout.rgb),
        (ImageFormat.rgba, PixelLayout.rgba),
        (ImageFormat.bgra, PixelLayout.bgra),
      ]) {
        final PixelBuffer buffer = pixelBufferOf(bytes, params(format));
        expect(buffer.layout, layout);
        expect(identical(buffer.bytes, bytes), isTrue);
      }
    });

    test('converts the other layouts', () {
      PixelBuffer convert(int format, List<int> bytes) =>
          pixelBufferOf(Uint8List.fromList(bytes), params(format));

      final PixelBuffer lumA = convert(ImageFormat.lumA, <int>[1, 9, 2, 9]);
      expect(lumA.layout, PixelLayout.luminance);
      expect(lumA.bytes, <int>[1, 2]);

      final PixelBuffer bgr = convert(ImageFormat.bgr, <int>[3, 2, 1, 6, 5, 4]);
      expect(bgr.layout, PixelLayout.rgb);
      expect(bgr.bytes, <int>[1, 2, 3, 4, 5, 6]);

      final PixelBuffer argb = convert(ImageFormat.argb, <int>[
        9, 1, 2, 3, 8, 4, 5, 6, //
      ]);
      expect(argb.layout, PixelLayout.rgba);
      expect(argb.bytes, <int>[1, 2, 3, 9, 4, 5, 6, 8]);

      final PixelBuffer abgr = convert(ImageFormat.abgr, <int>[
        9, 3, 2, 1, 8, 6, 5, 4, //
      ]);
      expect(abgr.bytes, <int>[1, 2, 3, 9, 4, 5, 6, 8]);
    });

    test('skips row padding while converting', () {
      final PixelBuffer buffer = pixelBufferOf(
        Uint8List.fromList(<int>[1, 9, 0, 0, 2, 9, 0, 0]),
        params(ImageFormat.lumA, width: 1, height: 2),
        rowStride: 4,
      );
      expect(buffer.bytes, <int>[1, 2]);
      expect(buffer.rowStride, isNull);
    });

    test('rejects an unknown format or a short buffer', () {
      expect(
        () => pixelBufferOf(Uint8List(8), params(ImageFormat.none)),
        throwsArgumentError,
      );
      expect(
        () => pixelBufferOf(Uint8List(3), params(ImageFormat.bgr)),
        throwsArgumentError,
      );
    });

    test('takes the crop from the params', () {
      final PixelBuffer buffer = pixelBufferOf(
        Uint8List(100),
        DecodeParams(
          width: 10,
          height: 10,
          cropLeft: 1,
          cropTop: 2,
          cropWidth: 3,
          cropHeight: 4,
        ),
      );
      expect(buffer.crop, const Rect.fromLTWH(1, 2, 3, 4));
      expect(
        pixelBufferOf(Uint8List(100), DecodeParams(width: 10, height: 10)).crop,
        isNull,
      );
    });
  });

  test('the debug image is the luminance of the crop', () {
    final DebugImage image = DebugImage.of(
      PixelBuffer(
        Uint8List.fromList(<int>[
          0, 0, 0, 0, 255, 255, 255, 0, 0, 0, 0, 0, // row 0, stride 12
          0, 0, 0, 0, 10, 20, 30, 0, 0, 0, 0, 0, // row 1
        ]),
        width: 3,
        height: 2,
        layout: PixelLayout.bgra,
        rowStride: 12,
        crop: const Rect.fromLTWH(1, 0, 1, 2),
      ),
    );
    expect(image.width, 1);
    expect(image.height, 2);
    // zxing-cpp's RGBToLum of BGRA (10, 20, 30): r 30, g 20, b 10.
    expect(image.bytes, <int>[
      255,
      (306 * 30 + 601 * 20 + 117 * 10 + 512) >> 10,
    ]);
  });

  test('nothing found is an invalid code with an empty error', () {
    final Code code = codeOf(
      null,
      imageWidth: 4,
      imageHeight: 3,
      duration: 1,
      source: CodeSource.byteStream,
    );
    expect(code.isValid, isFalse);
    expect(code.error, '');
    expect(code.format, Format.none);
    expect(code.position?.imageWidth, 4);
  });

  group('encodeOf', () {
    test('scales a matrix symbol into the requested size, centred', () {
      final Encode encode = encodeOf(
        _symbol(<String>['#.', '.#']),
        EncodeParams(width: 7, height: 7),
        'x',
      );
      expect(encode.isValid, isTrue);
      expect(encode.format, Format.qrCode);
      expect(encode.text, 'x');
      expect(encode.length, 49);
      // Three pixels per module; the spare pixel goes right and bottom.
      expect(_rows(encode), <String>[
        '###....',
        '###....',
        '###....',
        '...###.',
        '...###.',
        '...###.',
        '.......',
      ]);
    });

    test('grows the bitmap when the symbol and margin do not fit', () {
      final Encode encode = encodeOf(
        _symbol(<String>['#.', '.#']),
        EncodeParams(width: 1, height: 1, margin: 1),
        'x',
      );
      expect(_rows(encode), <String>['....', '.#..', '..#.', '....']);
    });

    test('a negative margin is the quiet zone of the symbology', () {
      final Encode encode = encodeOf(
        _symbol(<String>['#'], quietZone: 2),
        EncodeParams(width: 0, height: 0, margin: -1),
        'x',
      );
      expect(encode.width, 5);
    });

    test('stretches linear bars over the requested height', () {
      final Encode encode = encodeOf(
        _symbol(<String>['#.#', '#..'], format: BarcodeFormat.code128),
        EncodeParams(format: Format.code128, width: 8, height: 2, margin: 2),
        'x',
      );
      // (3 + 2 margin) fits 8 once: one pixel per module, centred.
      expect(_rows(encode), <String>['..#.#...', '..#.#...']);

      final Encode wide = encodeOf(
        _symbol(<String>['#.#'], format: BarcodeFormat.code128),
        EncodeParams(format: Format.code128, width: 6, height: 1),
        'x',
      );
      expect(_rows(wide), <String>['##..##']);
    });
  });
}
