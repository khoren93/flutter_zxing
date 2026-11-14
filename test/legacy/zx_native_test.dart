// The 3.x API on the real engine, beyond the end-to-end checks of
// example/integration_test/ffi_test.dart: camera frames, every 3.x pixel
// format, image files stb does not read, other isolates.
@Tags(<String>['native'])
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as imglib;

/// A QR code of [text] as one byte per pixel, [size] x [size].
Encode _qr(String text, {int size = 120}) {
  final Encode encode = zx.encodeBarcode(
    contents: text,
    params: EncodeParams(width: size, height: size, margin: 10),
  );
  expect(encode.isValid, isTrue, reason: encode.error);
  return encode;
}

/// [encode] pasted at ([left], [top]) of a white [width] x [height] image
/// with [bytesPerPixel] bytes per pixel and [rowPadding] extra bytes per row.
Uint8List _canvas(
  Encode encode, {
  required int width,
  required int height,
  int left = 0,
  int top = 0,
  int bytesPerPixel = 1,
  int rowPadding = 0,
}) {
  final int stride = width * bytesPerPixel + rowPadding;
  final Uint8List out = Uint8List(stride * height)
    ..fillRange(0, stride * height, 255);
  for (int y = 0; y < encode.height!; y++) {
    for (int x = 0; x < encode.width!; x++) {
      final int v = encode.data![y * encode.width! + x];
      final int i = (top + y) * stride + (left + x) * bytesPerPixel;
      out.fillRange(i, i + bytesPerPixel, v);
    }
  }
  return out;
}

/// EAN and UPC, whose text zxing-cpp reports as EAN-13 digits.
const int _retail = Format.ean8 | Format.ean13 | Format.upca | Format.upce;

CameraImage _frame(
  Uint8List bytes, {
  required int width,
  required int height,
  required int bytesPerRow,
  ImageFormatGroup group = ImageFormatGroup.yuv420,
}) => CameraImage.fromPlatformInterface(
  CameraImageData(
    format: CameraImageFormat(group, raw: 0),
    planes: <CameraImagePlane>[
      CameraImagePlane(bytes: bytes, bytesPerRow: bytesPerRow),
    ],
    width: width,
    height: height,
  ),
);

void main() {
  group('camera frames', () {
    late Encode qr;
    late CameraImage yuv;

    setUpAll(() {
      qr = _qr('camera');
      // A padded luminance plane, the code in the bottom-right corner.
      yuv = _frame(
        _canvas(
          qr,
          width: 320,
          height: 240,
          left: 180,
          top: 100,
          rowPadding: 64,
        ),
        width: 320,
        height: 240,
        bytesPerRow: 320 + 64,
      );
    });

    test('need startCameraProcessing', () async {
      await expectLater(
        zx.processCameraImage(yuv, DecodeParams()),
        throwsStateError,
      );
    });

    test('are read in full-frame coordinates, cropped', () async {
      await zx.startCameraProcessing();
      try {
        final Code code = await zx.processCameraImage(
          yuv,
          DecodeParams(
            width: 320,
            height: 240,
            cropLeft: 160,
            cropTop: 80,
            cropWidth: 160,
            cropHeight: 160,
          ),
        );
        expect(code.isValid, isTrue, reason: code.error);
        expect(code.text, 'camera');
        expect(code.source, CodeSource.camera);
        expect(code.position!.imageWidth, 320);
        expect(code.position!.topLeftX, greaterThanOrEqualTo(180));

        // Outside the crop: nothing.
        final Code outside = await zx.processCameraImage(
          yuv,
          DecodeParams(cropWidth: 100, cropHeight: 100),
        );
        expect(outside.isValid, isFalse);

        final Codes codes = await zx.processCameraImageMulti(
          yuv,
          DecodeParams(),
        );
        expect(codes.codes.map((Code c) => c.text), <String>['camera']);
      } finally {
        zx.stopCameraProcessing();
      }
    });

    test('BGRA frames are read', () async {
      await zx.startCameraProcessing();
      try {
        final CameraImage bgra = _frame(
          _canvas(
            qr,
            width: 160,
            height: 160,
            bytesPerPixel: 4,
            rowPadding: 16,
          ),
          width: 160,
          height: 160,
          bytesPerRow: 160 * 4 + 16,
          group: ImageFormatGroup.bgra8888,
        );
        final Code code = await zx.processCameraImage(
          bgra,
          DecodeParams(imageFormat: cameraImageFormat(bgra)),
        );
        expect(code.text, 'camera');
      } finally {
        zx.stopCameraProcessing();
      }
    });

    test('processing runs until the last user stops', () async {
      await zx.startCameraProcessing();
      await zx.startCameraProcessing();
      zx.stopCameraProcessing();
      expect(
        (await zx.processCameraImage(yuv, DecodeParams())).isValid,
        isTrue,
      );
      zx.stopCameraProcessing();
      await expectLater(
        zx.processCameraImage(yuv, DecodeParams()),
        throwsStateError,
      );
    });

    test('a frame still being read when processing stops fails', () async {
      await zx.startCameraProcessing();
      final Future<Code> pending = zx.processCameraImage(yuv, DecodeParams());
      zx.stopCameraProcessing();
      await expectLater(pending, throwsStateError);
    });
  });

  test('every 3.x pixel format is read', () {
    final Encode qr = _qr('pixels', size: 90);
    for (final (int format, int bytesPerPixel) in <(int, int)>[
      (ImageFormat.lum, 1),
      (ImageFormat.lumA, 2),
      (ImageFormat.rgb, 3),
      (ImageFormat.bgr, 3),
      (ImageFormat.rgba, 4),
      (ImageFormat.argb, 4),
      (ImageFormat.bgra, 4),
      (ImageFormat.abgr, 4),
    ]) {
      final Code code = zx.readBarcode(
        _canvas(qr, width: 90, height: 90, bytesPerPixel: bytesPerPixel),
        DecodeParams(imageFormat: format, width: 90, height: 90),
      );
      expect(code.text, 'pixels', reason: format.toRadixString(16));
    }
  });

  test(
    'image files stb does not read are decoded with package:image',
    () async {
      final Encode qr = _qr('fallback');
      final imglib.Image image = imglib.Image(
        width: qr.width!,
        height: qr.height!,
      );
      for (int y = 0; y < qr.height!; y++) {
        for (int x = 0; x < qr.width!; x++) {
          final int v = qr.data![y * qr.width! + x];
          image.setPixelRgb(x, y, v, v, v);
        }
      }
      final Directory dir = Directory.systemTemp.createTempSync(
        'zx_native_test',
      );
      try {
        for (final (String name, List<int> bytes) in <(String, List<int>)>[
          ('symbol.tiff', imglib.encodeTiff(image)),
          ('symbol.tga', imglib.encodeTga(image)),
        ]) {
          final File file = File('${dir.path}/$name')..writeAsBytesSync(bytes);
          final Code code = await zx.readBarcodeImagePathString(
            file.path,
            DecodeParams(),
          );
          expect(code.text, 'fallback', reason: '$name: ${code.error}');
          final Codes codes = await zx.readBarcodesImagePathString(
            file.path,
            DecodeParams(),
          );
          expect(codes.codes.map((Code c) => c.text), <String>['fallback']);
        }
      } finally {
        dir.deleteSync(recursive: true);
      }
    },
  );

  test('the synchronous calls work on other isolates', () async {
    final String? text = await Isolate.run(() {
      final Encode qr = zx.encodeBarcode(
        contents: 'isolate',
        params: EncodeParams(margin: 10),
      );
      return zx
          .readBarcode(
            qr.data!,
            DecodeParams(width: qr.width!, height: qr.height!),
          )
          .text;
    });
    expect(text, 'isolate');
  });

  test('every format 3.x could create is created and read back', () {
    for (final int format in <int>[
      ...CodeFormat.supportedEncodeFormats,
      Format.pdf417,
    ]) {
      final bool linear = (Format.linearCodes & format) != 0;
      final String text = format == Format.pdf417
          ? 'This is a PDF417'
          : format.demoText;
      final Encode encode = zx.encodeBarcode(
        contents: text,
        params: EncodeParams(
          format: format,
          width: 300,
          height: linear ? 100 : 300,
          margin: 20,
          eccLevel: EccLevel.medium,
        ),
      );
      expect(encode.isValid, isTrue, reason: '${format.name}: ${encode.error}');
      final Code code = zx.readBarcode(
        encode.data!,
        DecodeParams(
          format: format,
          width: encode.width!,
          height: encode.height!,
        ),
      );
      expect(code.isValid, isTrue, reason: '${format.name}: ${code.error}');
      expect(code.format, format, reason: format.name);
      if (!linear) {
        expect(code.text, text, reason: format.name);
      } else if ((_retail & format) == 0) {
        // Readers add the check digit some linear formats carry.
        expect(code.text, startsWith(text), reason: format.name);
      }
      // zxing-cpp reports EAN/UPC as EAN-13 digits with the check digit
      // (UPC-E 0123456 reads 0012345000065).
    }
  });

  test('Data Matrix stays square, as 3.x made it', () {
    final Encode encode = zx.encodeBarcode(
      contents: 'square',
      params: EncodeParams(format: Format.dataMatrix, width: 0, height: 0),
    );
    expect(encode.width, encode.height);
  });

  test('a format 3.x could not create is an invalid result', () {
    final Encode encode = zx.encodeBarcode(
      contents: 'x',
      params: EncodeParams(format: Format.maxiCode),
    );
    expect(encode.isValid, isFalse);
    expect(encode.error, isNotEmpty);
  });
}
