/// FFI integration tests
///
/// Ensure each FFI call actually works on each supported platform
/// (android, macos, ios, linux, windows) end-to-end.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart'
    show expect, group, isNot, isNotNull, isTrue, lessThan, setUpAll, test;
import 'package:flutter_zxing/flutter_zxing.dart'
    show
        Code,
        CodeSource,
        Codes,
        DecodeParams,
        EccLevel,
        Encode,
        EncodeParams,
        Format,
        ImageFormat,
        pngFromBytes,
        zx;

void main() async {
  setUpAll(() => zx.setLogEnabled(false));

  test('Zxing.setLogEnabled', () => zx.setLogEnabled(false));

  test('Zxing.version', () {
    assert(zx.version().isNotEmpty);
  });

  test('Zxing.encodeBarcode -> readBarcode(s)', () {
    const contents = "This is a QR code";

    // Encode a QR code image

    final encodeParams = EncodeParams(
      format: Format.qrCode,
      width: 100,
      height: 100,
      margin: 0,
      eccLevel: EccLevel.low,
    );

    final enc = zx.encodeBarcode(contents: contents, params: encodeParams);

    assert(enc.isValid);
    expect(enc.format, encodeParams.format);
    expect(enc.text, contents);
    assert(enc.data != null);
    assert(enc.length! > 0);
    expect(enc.width, encodeParams.width);
    expect(enc.height, encodeParams.height);

    final dataU8 = enc.data!;
    expect(dataU8.length, encodeParams.width * encodeParams.height);

    // Decode the image (no multiscan)

    final decodeParams = DecodeParams(
      imageFormat: ImageFormat.lum,
      format: encodeParams.format,
      width: encodeParams.width,
      height: encodeParams.height,
      isMultiScan: false,
    );
    final code1 = zx.readBarcode(dataU8, decodeParams);

    assert(code1.isValid);
    expect(code1.error, null);
    expect(code1.text, contents);
    expect(code1.format, encodeParams.format);
    expect(code1.isInverted, false);
    expect(code1.isMirrored, false);
    expect(code1.source, CodeSource.byteStream);

    // Decode the image (multiscan)

    final decodeParams2 = DecodeParams(
      imageFormat: ImageFormat.lum,
      format: encodeParams.format,
      width: encodeParams.width,
      height: encodeParams.height,
      isMultiScan: true,
    );
    final results = zx.readBarcodes(dataU8, decodeParams2);

    expect(results.error, null);
    expect(results.codes.length, 1);

    final code2 = results.codes.first;
    expect(code2.isValid, code1.isValid);
    expect(code2.error, code1.error);
    expect(code2.text, code1.text);
    expect(code2.rawBytes, code1.rawBytes);
    expect(code2.format, code1.format);
    expect(code2.isInverted, code1.isInverted);
    expect(code2.isMirrored, code1.isMirrored);
    expect(code2.source, CodeSource.byteStream);
  });

  test('Zxing.readBarcode(s) (bad image)', () {
    // Build an empty, white image
    const width = 100;
    const height = 100;
    final whiteImage = Uint32List(width * height);
    whiteImage.fillRange(0, whiteImage.length, 0xffffffff);

    // Decode the image (no multiscan)
    final decodeParams = DecodeParams(
      imageFormat: ImageFormat.rgbx,
      format: Format.qrCode,
      width: width,
      height: height,
      isMultiScan: false,
    );
    final dataU8 = whiteImage.buffer.asUint8List();
    final code1 = zx.readBarcode(dataU8, decodeParams);

    assert(!code1.isValid);
    expect(code1.error, "");
    expect(code1.text, null);
    expect(code1.format, Format.none);
    expect(code1.isInverted, false);
    expect(code1.isMirrored, false);

    // Decode the image (multiscan)
    final decodeParams2 = DecodeParams(
      imageFormat: ImageFormat.rgbx,
      format: Format.qrCode,
      width: width,
      height: height,
      isMultiScan: true,
    );
    final results = zx.readBarcodes(dataU8, decodeParams2);
    expect(results.error, null);
    expect(results.codes, []);
  });

  group('encode reports the bitmap it actually produced', () {
    /// zxing enlarges a symbol that does not fit the requested box. The
    /// reported width/height must describe the buffer, otherwise rendering it
    /// reads the wrong number of bytes per row and produces a scrambled,
    /// unscannable image.
    void expectSelfConsistent(Encode enc) {
      expect(enc.isValid, isTrue);
      expect(enc.width, isNotNull);
      expect(enc.height, isNotNull);
      expect(enc.length, enc.width! * enc.height!);
      expect(enc.data!.length, enc.width! * enc.height!);
      // Must not throw: the buffer is big enough for the reported size.
      pngFromBytes(enc.data!, enc.width!, enc.height!);
    }

    test('when a Code128 symbol is wider than the requested box', () {
      final enc = zx.encodeBarcode(
        contents: 'A' * 80,
        params: EncodeParams(
          format: Format.code128,
          width: 240,
          height: 120,
          margin: 0,
        ),
      );
      expectSelfConsistent(enc);
      // The symbol does not fit 240px, so the encoder grew it.
      expect(enc.width! > 240, isTrue);
      expect(enc.height, 120);

      // The oversized bitmap is a real barcode and still decodes.
      final code = zx.readBarcode(
        enc.data!,
        DecodeParams(
          imageFormat: ImageFormat.lum,
          format: Format.code128,
          width: enc.width!,
          height: enc.height!,
        ),
      );
      expect(code.isValid, isTrue);
      expect(code.text, 'A' * 80);
    });

    test('when a PDF417 symbol is shorter than the requested box', () {
      final enc = zx.encodeBarcode(
        contents: 'This is a PDF417',
        params: EncodeParams(
          format: Format.pdf417,
          width: 360,
          height: 120,
          margin: 0,
        ),
      );
      expectSelfConsistent(enc);
      expect(enc.height! < 120, isTrue);
    });

    test('when the symbol fits exactly', () {
      final enc = zx.encodeBarcode(
        contents: 'This is a QR code',
        params: EncodeParams(format: Format.qrCode, width: 100, height: 100),
      );
      expectSelfConsistent(enc);
      expect(enc.width, 100);
      expect(enc.height, 100);
    });
  });

  test('encodeBarcode reports an error instead of crashing', () {
    final enc = zx.encodeBarcode(
      contents: '',
      params: EncodeParams(format: Format.qrCode, width: 100, height: 100),
    );
    expect(enc.isValid, false);
    expect(enc.error, isNotNull);
  });

  test('readBarcode rejects a buffer smaller than width * height', () {
    // Without the bounds check on the native side this reads far past the end
    // of the buffer instead of reporting a problem.
    final code = zx.readBarcode(
      Uint8List(16),
      DecodeParams(
        imageFormat: ImageFormat.lum,
        format: Format.qrCode,
        width: 1000,
        height: 1000,
      ),
    );
    expect(code.isValid, false);
    expect(code.error, isNotNull);
    expect(code.error, isNot(''));
  });

  test('cropped positions are reported in full-image coordinates', () {
    // Put a QR code in a 200x200 image, then decode only its bottom-right
    // quadrant. The reported position must point at the code's real place in
    // the full image, not at an offset inside the crop.
    const size = 100;
    final enc = zx.encodeBarcode(
      contents: 'crop me',
      params: EncodeParams(format: Format.qrCode, width: size, height: size),
    );
    expect(enc.isValid, isTrue);

    const canvas = 200;
    final image = Uint8List(canvas * canvas)
      ..fillRange(0, canvas * canvas, 255);
    for (var y = 0; y < enc.height!; y++) {
      for (var x = 0; x < enc.width!; x++) {
        image[(y + 100) * canvas + (x + 100)] = enc.data![y * enc.width! + x];
      }
    }

    final code = zx.readBarcode(
      image,
      DecodeParams(
        imageFormat: ImageFormat.lum,
        format: Format.qrCode,
        width: canvas,
        height: canvas,
        cropLeft: 100,
        cropTop: 100,
        cropWidth: 100,
        cropHeight: 100,
      ),
    );

    expect(code.isValid, isTrue);
    expect(code.text, 'crop me');
    final pos = code.position!;
    expect(pos.imageWidth, canvas);
    expect(pos.imageHeight, canvas);
    // Inside the bottom-right quadrant, not near the origin.
    expect(pos.topLeftX >= 100, isTrue);
    expect(pos.topLeftY >= 100, isTrue);
    expect(pos.bottomRightX <= canvas, isTrue);
  });

  test('readBarcodes returns no codes when every candidate is invalid', () {
    // A noisy image can make zxing report results that all fail validation.
    // The native side must release its result array in that case rather than
    // handing Dart a buffer it will not free.
    final noise = Uint8List(200 * 200);
    for (var i = 0; i < noise.length; i++) {
      noise[i] = (i * 2654435761) % 256;
    }
    for (var i = 0; i < 50; i++) {
      final Codes codes = zx.readBarcodes(
        noise,
        DecodeParams(
          imageFormat: ImageFormat.lum,
          format: Format.any,
          width: 200,
          height: 200,
        ),
      );
      for (final Code code in codes.codes) {
        expect(code.isValid, isTrue);
      }
    }
  });

  test('the debug image is single-channel whatever the input format', () {
    // With logging on, the native side attaches the image it scanned so callers
    // can render it. It must be one byte per pixel (what `pngFromBytes`
    // expects) even when the input was multi-byte RGB.
    zx.setLogEnabled(true);
    try {
      final enc = zx.encodeBarcode(
        contents: 'debug image',
        params: EncodeParams(format: Format.qrCode, width: 90, height: 90),
      );

      // Expand the 1-byte-per-pixel bitmap into RGB.
      final rgb = Uint8List(enc.width! * enc.height! * 3);
      for (var i = 0; i < enc.length!; i++) {
        rgb[i * 3] = rgb[i * 3 + 1] = rgb[i * 3 + 2] = enc.data![i];
      }

      final code = zx.readBarcode(
        rgb,
        DecodeParams(
          imageFormat: ImageFormat.rgb,
          format: Format.qrCode,
          width: enc.width!,
          height: enc.height!,
        ),
      );

      expect(code.isValid, isTrue);
      expect(code.text, 'debug image');
      expect(code.imageWidth, enc.width);
      expect(code.imageHeight, enc.height);
      expect(code.imageBytes!.length, enc.width! * enc.height!);
      // Round-trips through the grayscale PNG encoder without throwing.
      pngFromBytes(code.imageBytes!, code.imageWidth!, code.imageHeight!);
      // The luminance of a black/white bitmap is the bitmap itself.
      expect(code.imageBytes, enc.data);
    } finally {
      zx.setLogEnabled(false);
    }
  });

  test('decoding duration is measured', () {
    final enc = zx.encodeBarcode(
      contents: 'timing',
      params: EncodeParams(format: Format.qrCode, width: 100, height: 100),
    );
    final code = zx.readBarcode(
      enc.data!,
      DecodeParams(
        imageFormat: ImageFormat.lum,
        format: Format.qrCode,
        width: enc.width!,
        height: enc.height!,
      ),
    );
    expect(code.isValid, isTrue);
    expect(code.duration >= 0, isTrue);
    expect(code.duration, lessThan(60000));
  });
}
