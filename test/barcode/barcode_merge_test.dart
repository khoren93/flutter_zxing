// Barcode.merge: structured append sequences.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

Barcode _part(
  String text,
  int index,
  int size, {
  String id = '42',
  double x = 0,
  BarcodeError? error,
  BarcodeContentType type = BarcodeContentType.text,
}) => Barcode(
  format: BarcodeFormat.qrCode,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: BarcodePosition(
    topLeft: Offset(x, 0),
    topRight: Offset(x + 10, 0),
    bottomRight: Offset(x + 10, 10),
    bottomLeft: Offset(x, 10),
  ),
  contentType: type,
  ecLevel: 'M',
  symbologyIdentifier: ']Q1',
  sequence: BarcodeSequence(index: index, size: size, id: id),
  error: error,
);

void main() {
  test('joins the parts in sequence order', () {
    final Barcode? merged = Barcode.merge(<Barcode>[
      _part('lo, ', 1, 3, x: 20),
      _part('world', 2, 3, x: 40),
      _part('Hel', 0, 3),
    ]);
    expect(merged, isNotNull);
    expect(merged!.text, 'Hello, world');
    expect(merged.bytes, utf8.encode('Hello, world'));
    expect(merged.sequence, isNull);
    expect(merged.format, BarcodeFormat.qrCode);
    expect(merged.ecLevel, 'M');
    expect(merged.symbologyIdentifier, ']Q1');
    expect(merged.position.bounds, const Rect.fromLTRB(0, 0, 50, 10));
  });

  test('null until every part is there', () {
    expect(
      Barcode.merge(<Barcode>[_part('a', 0, 3), _part('c', 2, 3)]),
      isNull,
    );
    expect(Barcode.merge(const <Barcode>[]), isNull);
  });

  test('repeated parts, plain barcodes and failed parts are skipped', () {
    final Barcode plain = Barcode(
      format: BarcodeFormat.ean13,
      text: '5901234123457',
      bytes: Uint8List(0),
      position: _part('', 0, 1).position,
    );
    expect(
      Barcode.merge(<Barcode>[
        plain,
        _part('a', 0, 2),
        _part('a', 0, 2),
        _part('b', 1, 2),
      ])?.text,
      'ab',
    );
    expect(
      Barcode.merge(<Barcode>[
        _part('a', 0, 2),
        _part('b', 1, 2, error: const BarcodeError(BarcodeErrorKind.checksum)),
      ]),
      isNull,
    );
  });

  test('a size known only from the last part', () {
    expect(
      Barcode.merge(<Barcode>[
        _part('a', 0, 0),
        _part('b', 1, 0),
        _part('c', 2, 3),
      ])?.text,
      'abc',
    );
    expect(Barcode.merge(<Barcode>[_part('a', 0, 0)]), isNull);
  });

  test('the first complete sequence wins', () {
    expect(
      Barcode.merge(<Barcode>[
        _part('x', 0, 2, id: '1'),
        _part('a', 0, 2, id: '2'),
        _part('b', 1, 2, id: '2'),
      ])?.text,
      'ab',
    );
  });

  test('mixed content types become mixed', () {
    expect(
      Barcode.merge(<Barcode>[
        _part('a', 0, 2),
        _part('b', 1, 2, type: BarcodeContentType.binary),
      ])?.contentType,
      BarcodeContentType.mixed,
    );
  });
}
