import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as imglib;

/// Pure-Dart tests: everything here runs on the host VM without loading the
/// native library. End-to-end coverage of the FFI calls lives in
/// `example/integration_test/ffi_test.dart`, which runs on a real device.
void main() {
  group('Format', () {
    test('barcode formats are distinct single bits', () {
      const List<int> formats = <int>[
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
      ];
      expect(formats.toSet().length, formats.length);
      for (final int format in formats) {
        expect(format & (format - 1), 0, reason: '$format is not a single bit');
      }
    });

    test('linear and matrix sets do not overlap and cover `any`', () {
      expect(Format.linearCodes & Format.matrixCodes, 0);
      expect(Format.linearCodes | Format.matrixCodes, Format.any);
    });

    test('every format has a name, ratio and demo text', () {
      for (final int format in CodeFormat.supportedEncodeFormats) {
        expect(format.name, isNot('Unknown'), reason: 'name for $format');
        expect(format.ratio, greaterThan(0), reason: 'ratio for $format');
        expect(format.demoText, isNotEmpty, reason: 'demoText for $format');
        expect(
          format.maxTextLength,
          greaterThan(0),
          reason: 'maxTextLength for $format',
        );
      }
    });

    test('demo text fits within the format maximum length', () {
      for (final int format in CodeFormat.supportedEncodeFormats) {
        expect(
          format.demoText.length,
          lessThanOrEqualTo(format.maxTextLength),
          reason: '${format.name} demo text is longer than it can encode',
        );
      }
    });

    test('unknown format degrades gracefully', () {
      const int bogus = 1 << 30;
      expect(bogus.name, 'Unknown');
      expect(bogus.ratio, 1.0);
      expect(bogus.demoText, '');
      expect(bogus.maxTextLength, 0);
      expect(bogus.isSupportedEccLevel, isFalse);
    });

    test('only QR advertises ECC level support', () {
      expect(Format.qrCode.isSupportedEccLevel, isTrue);
      expect(Format.code128.isSupportedEccLevel, isFalse);
    });
  });

  group('EccLevel', () {
    test('maps to the values zxing expects', () {
      expect(EccLevel.low.value, 2);
      expect(EccLevel.medium.value, 4);
      expect(EccLevel.quartile.value, 6);
      expect(EccLevel.high.value, 8);
    });
  });

  group('DecodeParams', () {
    test('copyWith replaces only the named fields', () {
      final DecodeParams params = DecodeParams(
        format: Format.qrCode,
        tryHarder: true,
        maxNumberOfSymbols: 3,
      );
      final DecodeParams copy = params.copyWith(width: 64, height: 32);

      expect(copy.width, 64);
      expect(copy.height, 32);
      expect(copy.format, Format.qrCode);
      expect(copy.tryHarder, isTrue);
      expect(copy.maxNumberOfSymbols, 3);
    });

    test('copyWith does not mutate the original', () {
      final DecodeParams params = DecodeParams();
      params.copyWith(width: 100, isMultiScan: true);

      expect(params.width, 0);
      expect(params.isMultiScan, isFalse);
    });

    test('copyWith can turn flags off', () {
      final DecodeParams params = DecodeParams(isMultiScan: true);
      expect(params.copyWith(isMultiScan: false).isMultiScan, isFalse);
    });
  });

  group('Codes', () {
    test('error reports the first failing code', () {
      final Codes codes = Codes(
        codes: <Code>[
          Code(text: 'ok', isValid: true),
          Code(error: 'first failure'),
          Code(error: 'second failure'),
        ],
      );
      expect(codes.error, 'first failure');
    });

    test('error is null when every code decoded', () {
      final Codes codes = Codes(codes: <Code>[Code(text: 'ok', isValid: true)]);
      expect(codes.error, isNull);
    });

    test('an empty result has no error', () {
      expect(Codes().error, isNull);
      expect(Codes().codes, isEmpty);
    });

    test('a scan that never ran carries its error without any codes', () {
      // A failure to read or download the image must not look like a hit:
      // callers treat a non-empty list as "codes were found".
      final Codes codes = Codes(error: 'Failed to decode image');
      expect(codes.error, 'Failed to decode image');
      expect(codes.codes, isEmpty);
    });

    test('an explicit error wins over a per-code error', () {
      final Codes codes = Codes(
        codes: <Code>[Code(error: 'per code')],
        error: 'whole scan',
      );
      expect(codes.error, 'whole scan');
    });
  });

  group('resizeToMaxSize', () {
    imglib.Image image(int w, int h) => imglib.Image(width: w, height: h);

    test('leaves an image that already fits untouched', () {
      final imglib.Image original = image(100, 50);
      expect(identical(resizeToMaxSize(original, 768), original), isTrue);
    });

    test('scales the longest side down to maxSize, keeping the ratio', () {
      final imglib.Image resized = resizeToMaxSize(image(2000, 1000), 500);
      expect(resized.width, 500);
      expect(resized.height, 250);
    });

    test('scales portrait images by their height', () {
      final imglib.Image resized = resizeToMaxSize(image(1000, 2000), 500);
      expect(resized.width, 250);
      expect(resized.height, 500);
    });

    test('never collapses an extreme aspect ratio to a zero-sized side', () {
      final imglib.Image resized = resizeToMaxSize(image(4000, 3), 100);
      expect(resized.width, 100);
      expect(resized.height, greaterThanOrEqualTo(1));
    });

    test('a null or non-positive maxSize disables resizing', () {
      final imglib.Image original = image(2000, 2000);
      expect(identical(resizeToMaxSize(original, null), original), isTrue);
      expect(identical(resizeToMaxSize(original, 0), original), isTrue);
      expect(identical(resizeToMaxSize(original, -10), original), isTrue);
    });
  });

  group('pngFromBytes', () {
    test('encodes a grayscale buffer into a decodable PNG', () {
      final Uint8List bytes = Uint8List.fromList(<int>[0, 255, 255, 0]);
      final imglib.Image? decoded = imglib.decodePng(pngFromBytes(bytes, 2, 2));

      expect(decoded, isNotNull);
      expect(decoded!.width, 2);
      expect(decoded.height, 2);
      expect(decoded.getPixel(0, 0).r, 0);
      expect(decoded.getPixel(1, 0).r, 255);
    });

    test('reads a view into a larger buffer from the right offset', () {
      final Uint8List backing = Uint8List.fromList(<int>[
        9, 9, // padding the view must skip over
        0, 255, 255, 0,
      ]);
      final Uint8List view = Uint8List.sublistView(backing, 2);
      final imglib.Image? decoded = imglib.decodePng(pngFromBytes(view, 2, 2));

      expect(decoded!.getPixel(0, 0).r, 0);
      expect(decoded.getPixel(1, 0).r, 255);
    });

    test('rejects a buffer that is too small instead of reading past it', () {
      expect(
        () => pngFromBytes(Uint8List(3), 2, 2),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects non-positive dimensions', () {
      expect(
        () => pngFromBytes(Uint8List(4), 0, 2),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => pngFromBytes(Uint8List(4), 2, -1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ScannerOverlayBorder', () {
    const Rect rect = Rect.fromLTWH(0, 0, 400, 800);

    test('a fractional cutOutSize is a share of the shorter side', () {
      const ScannerOverlayBorder border = ScannerOverlayBorder(cutOutSize: 0.5);
      final Rect cutOut = border.getInnerPath(rect).getBounds();

      expect(cutOut.width, closeTo(200, 0.01));
      expect(cutOut.height, closeTo(200, 0.01));
      expect(cutOut.center.dx, closeTo(200, 0.01));
      expect(cutOut.center.dy, closeTo(400, 0.01));
    });

    test('a cutOutSize above 1 is in pixels, clamped to the shorter side', () {
      expect(
        const ScannerOverlayBorder(
          cutOutSize: 320,
        ).getInnerPath(rect).getBounds().width,
        closeTo(320, 0.01),
      );
      expect(
        const ScannerOverlayBorder(
          cutOutSize: 5000,
        ).getInnerPath(rect).getBounds().width,
        closeTo(400, 0.01),
      );
    });

    test('offsets of +/-1 push the cut-out to the edges without leaving', () {
      const ScannerOverlayBorder right = ScannerOverlayBorder(
        cutOutSize: 0.5,
        horizontalOffset: 1,
      );
      final Rect cutOut = right.getInnerPath(rect).getBounds();

      expect(cutOut.right, closeTo(rect.right, 0.01));
      expect(cutOut.left, greaterThanOrEqualTo(rect.left - 0.01));

      const ScannerOverlayBorder top = ScannerOverlayBorder(
        cutOutSize: 0.5,
        verticalOffset: -1,
      );
      expect(top.getInnerPath(rect).getBounds().top, closeTo(rect.top, 0.01));
    });

    test('the outer path is the full rect minus the cut-out', () {
      const ScannerOverlayBorder border = ScannerOverlayBorder(cutOutSize: 0.5);
      final Path outer = border.getOuterPath(rect);

      expect(outer.contains(const Offset(5, 5)), isTrue);
      expect(outer.contains(rect.center), isFalse);
    });
  });

  group('codeHitRegions', () {
    Code codeAt(int left, int top, int right, int bottom) => Code(
      text: 'code',
      isValid: true,
      position: Position(
        100,
        100,
        left,
        top,
        right,
        top,
        left,
        bottom,
        right,
        bottom,
      ),
    );

    test('scales positions from image space into overlay space', () {
      final List<CodeHitRegion> regions = codeHitRegions(<Code>[
        codeAt(10, 20, 30, 40),
      ], const Size(200, 200));

      expect(regions, hasLength(1));
      expect(regions.first.rect, const Rect.fromLTRB(20, 40, 60, 80));
    });

    test('skips codes without usable geometry', () {
      final Code noPosition = Code(text: 'a', isValid: true);
      final Code zeroSizedImage = Code(
        text: 'b',
        isValid: true,
        position: Position(0, 0, 0, 0, 1, 0, 0, 1, 1, 1),
      );

      expect(
        codeHitRegions(<Code>[noPosition, zeroSizedImage], const Size(10, 10)),
        isEmpty,
      );
    });
  });
}
