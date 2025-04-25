/// FFI integration tests
///
/// Ensure each FFI call actually works on each supported platform
/// (android, macos, ios, linux, windows) end-to-end.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show expect, test;
import 'package:flutter_zxing/flutter_zxing.dart'
    show DecodeParams, EccLevel, EncodeParams, Format, ImageFormat, zx;

void main() async {
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
}
