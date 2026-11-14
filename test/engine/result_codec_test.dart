import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/barcode/barcode_format.dart';
import 'package:flutter_zxing/src/engine/engine_protocol.dart';
import 'package:flutter_zxing/src/engine/result_codec.dart';

/// Writes buffers in the layout of native/fzx.cpp.
class _Buffer {
  final BytesBuilder _b = BytesBuilder();

  void u8(int v) => _b.addByte(v);

  void u32(int v) => _b.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );

  void i32(int v) =>
      _b.add((ByteData(4)..setInt32(0, v, Endian.little)).buffer.asUint8List());

  void blob(List<int> bytes) {
    u32(bytes.length);
    _b.add(bytes);
  }

  void str(String s) => blob(utf8.encode(s));

  Uint8List get bytes => _b.toBytes();
}

void _barcode(
  _Buffer b, {
  int format = 0x2051, // QRCode
  int contentType = 0,
  int errorType = 0,
  int flags = 1,
  int orientation = 0,
  List<int> position = const <int>[1, 2, 30, 2, 30, 31, 1, 31],
  int sequenceIndex = -1,
  int sequenceSize = -1,
  String text = 'hello',
  List<int>? bytes,
  String symbologyIdentifier = ']Q1',
  String ecLevel = 'M',
  String version = '1',
  String sequenceId = '',
  String errorMessage = '',
  String extra = '',
}) {
  b
    ..u32(format)
    ..u8(contentType)
    ..u8(errorType)
    ..u8(flags)
    ..u8(0);
  b.i32(orientation);
  position.forEach(b.i32);
  b
    ..i32(7) // line count
    ..i32(sequenceIndex)
    ..i32(sequenceSize)
    ..str(text)
    ..blob(bytes ?? utf8.encode(text))
    ..str(symbologyIdentifier)
    ..str(ecLevel)
    ..str(version)
    ..str(sequenceId)
    ..str(errorMessage)
    ..str(extra);
}

_Buffer _header(int kind) => _Buffer()
  ..u32(fzxExpectedAbiVersion)
  ..u32(kind);

void main() {
  group('decodeBarcodes', () {
    test('reads every field', () {
      final _Buffer b = _header(1)
        ..i32(640)
        ..i32(480)
        ..i32(1);
      _barcode(
        b,
        format: BarcodeFormat.dataMatrix.id,
        contentType: 3, // GS1
        flags: 1 | 2 | 4,
        orientation: 90,
        sequenceIndex: 1,
        sequenceSize: 3,
        sequenceId: '42',
        text: '(01)09501101530003',
        bytes: <int>[0x1D, 0x30, 0x31],
        symbologyIdentifier: ']d2',
        ecLevel: '',
        version: '16x16',
        extra: '{"Version":"16x16"}',
      );
      final EngineReadResult r = decodeBarcodes(b.bytes);
      expect(r.imageWidth, 640);
      expect(r.imageHeight, 480);
      expect(r.barcodes, hasLength(1));
      final Barcode code = r.barcodes.single;
      expect(code.format, BarcodeFormat.dataMatrix);
      expect(code.contentType, BarcodeContentType.gs1);
      expect(code.text, '(01)09501101530003');
      expect(code.bytes, <int>[0x1D, 0x30, 0x31]);
      expect(code.orientation, 90);
      expect(code.isInverted, isTrue);
      expect(code.isMirrored, isTrue);
      expect(code.symbologyIdentifier, ']d2');
      expect(code.ecLevel, isNull);
      expect(code.version, '16x16');
      expect(code.sequence, const BarcodeSequence(index: 1, size: 3, id: '42'));
      expect(code.error, isNull);
      expect(code.isValid, isTrue);
      expect(
        code.position,
        const BarcodePosition(
          topLeft: Offset(1, 2),
          topRight: Offset(30, 2),
          bottomRight: Offset(30, 31),
          bottomLeft: Offset(1, 31),
        ),
      );
    });

    // Regression: skipping the trailing `extra` string lost four bytes,
    // which broke every result with more than one barcode.
    test('reads several barcodes, with and without extra', () {
      final _Buffer b = _header(1)
        ..i32(100)
        ..i32(100)
        ..i32(3);
      _barcode(b, text: 'first');
      _barcode(b, text: 'second', extra: '{"ECLevel":"M"}');
      _barcode(b, text: 'third');
      expect(
        decodeBarcodes(b.bytes).barcodes.map((Barcode c) => c.text),
        <String>['first', 'second', 'third'],
      );
    });

    test('maps errors and unknown values', () {
      final _Buffer b = _header(1)
        ..i32(1)
        ..i32(1)
        ..i32(2);
      _barcode(
        b,
        format: 0x7a7a, // not a format this version knows
        errorType: 2,
        flags: 0,
        errorMessage: 'checksum',
        contentType: 99,
      );
      _barcode(b, errorType: 9);
      final List<Barcode> codes = decodeBarcodes(b.bytes).barcodes;
      expect(codes[0].format, BarcodeFormat.unknown);
      expect(
        codes[0].error,
        const BarcodeError(BarcodeErrorKind.checksum, 'checksum'),
      );
      expect(codes[0].isValid, isFalse);
      expect(codes[0].contentType, BarcodeContentType.binary);
      expect(codes[1].error!.kind, BarcodeErrorKind.unsupported);
    });

    test('copies bytes out of the buffer', () {
      final _Buffer b = _header(1)
        ..i32(1)
        ..i32(1)
        ..i32(1);
      _barcode(b, bytes: <int>[1, 2, 3]);
      final Uint8List buffer = b.bytes;
      final Barcode code = decodeBarcodes(buffer).barcodes.single;
      buffer.fillRange(0, buffer.length, 0);
      expect(code.bytes, <int>[1, 2, 3]);
    });

    test('rejects another ABI version or kind', () {
      final Uint8List otherAbi =
          (_Buffer()
                ..u32(fzxExpectedAbiVersion + 1)
                ..u32(1)
                ..i32(0)
                ..i32(0)
                ..i32(0))
              .bytes;
      expect(() => decodeBarcodes(otherAbi), throwsStateError);
      final Uint8List symbol = (_header(2)..u32(0)).bytes;
      expect(() => decodeBarcodes(symbol), throwsStateError);
    });
  });

  group('decodeSymbol', () {
    test('reads the module matrix and quiet zones', () {
      final _Buffer b = _header(2)
        ..u32(BarcodeFormat.ean13.id)
        ..i32(3)
        ..i32(2)
        ..i32(11)
        ..i32(0)
        ..i32(7)
        ..i32(0)
        ..str('9501101530003')
        ..str('')
        ..str('')
        ..blob(<int>[1, 0, 1, 0, 1, 0]);
      final EngineSymbol s = decodeSymbol(b.bytes);
      expect(s.format, BarcodeFormat.ean13);
      expect(s.width, 3);
      expect(s.height, 2);
      expect(s.modules, <int>[1, 0, 1, 0, 1, 0]);
      expect(
        <int>[
          s.quietZoneLeft,
          s.quietZoneTop,
          s.quietZoneRight,
          s.quietZoneBottom,
        ],
        <int>[11, 0, 7, 0],
      );
      expect(s.text, '9501101530003');
    });

    test('rejects a module count that does not match the size', () {
      final _Buffer b = _header(2)
        ..u32(BarcodeFormat.qrCode.id)
        ..i32(21)
        ..i32(21);
      for (int i = 0; i < 4; i++) {
        b.i32(4);
      }
      b
        ..str('')
        ..str('')
        ..str('')
        ..blob(<int>[1, 2, 3]);
      expect(() => decodeSymbol(b.bytes), throwsStateError);
    });
  });
}
