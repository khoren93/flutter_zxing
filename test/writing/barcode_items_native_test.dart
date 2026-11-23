// Batches on the real engine: the quick rules of checkItems never reject
// what the writer takes and agree with it on what it refuses; checkItems
// finds the item at fault; SerialItems feeds a label sheet lazily.
@Tags(<String>['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/writing/barcode_items.dart' show itemProblem;

const Map<BarcodeFormat, List<String>> _samples = <BarcodeFormat, List<String>>{
  BarcodeFormat.ean13: <String>[
    '1',
    '123456789012',
    '1234567890128',
    '1234567890123',
    '12345678901234',
    '123456789012+1',
    '123456789012+12',
    '123456789012+123',
    '1234567890128+12345',
    '1234567890128 12',
    '123456789012+123456',
    '+12',
    'AB-1',
    '12-3',
  ],
  BarcodeFormat.eanUpc: <String>['123', '12345678901234'],
  BarcodeFormat.ean8: <String>[
    '1',
    '1234567',
    '12345670',
    '12345671',
    '123456789',
    '1234567+12',
  ],
  BarcodeFormat.upcA: <String>[
    '1',
    '12345678901',
    '123456789012',
    '123456789013',
    '1234567890123',
  ],
  BarcodeFormat.upcE: <String>['1', '123456', '01234565', '123456789', 'A'],
  BarcodeFormat.itf: <String>['1', '123', '12A'],
  BarcodeFormat.code39: <String>['abc', 'AB*C', r'AB C-.$/+%', 'é'],
  BarcodeFormat.code39Extended: <String>['abc*', 'é'],
  BarcodeFormat.code93: <String>['abc', 'é'],
  BarcodeFormat.telepen: <String>['abc', 'é'],
  BarcodeFormat.code128: <String>['é', 'Ā', '€', 'abc'],
  BarcodeFormat.codabar: <String>[
    '123',
    'A123B',
    'A12X3B',
    'a123b',
    'A123',
    'ABCD',
  ],
  BarcodeFormat.dataBar: <String>[
    '1',
    '1234567890123',
    '12345678901231',
    '12345678901234',
    '123456789012345',
    'A',
  ],
  BarcodeFormat.dataBarStacked: <String>['12345678901234', '1234567890123'],
  BarcodeFormat.dataBarLimited: <String>[
    '1234567890123',
    '2234567890123',
    '09501101530003',
    '1950110153000',
  ],
  BarcodeFormat.code32: <String>['12345678', '123456789', 'A'],
  BarcodeFormat.pzn: <String>['1234567', '123456789', 'A'],
  BarcodeFormat.aztecRune: <String>['0', '255', '256', '-1', 'a'],
};

void main() {
  setUpAll(warmUpBarcodeEngine);

  test('the quick rules refuse only what the writer refuses', () async {
    final List<String> wrong = <String>[];
    for (final MapEntry<BarcodeFormat, List<String>> e in _samples.entries) {
      for (final String item in e.value) {
        final String? problem = itemProblem(e.key, item);
        bool encodes = true;
        try {
          await BarcodeWriter(e.key).encode(item);
        } on BarcodeWriteException {
          encodes = false;
        }
        if (problem != null && encodes) {
          wrong.add(
            '${e.key.name} "$item" refused ($problem), writer takes it',
          );
        }
      }
    }
    expect(wrong, isEmpty);
  });

  test('the example of every writable format passes the quick rules', () {
    for (final BarcodeFormat f in BarcodeFormat.values) {
      if (f.canWrite) {
        expect(itemProblem(f, f.input!.example), isNull, reason: f.name);
      }
    }
  });

  group('checkItems', () {
    const BarcodeWriter ean13 = BarcodeWriter(BarcodeFormat.ean13);

    test('a fine list, an empty list', () async {
      expect(
        await ean13.checkItems(
          SerialItems('400638{n:6}', count: 5000, checkDigit: CheckDigit.gs1),
        ),
        isNull,
      );
      expect(await ean13.checkItems(const <String>[]), isNull);
    });

    test('the quick rules name the first item at fault', () async {
      final List<String> items = <String>[
        for (int i = 0; i < 100; i++) '40063813339${i % 10}',
      ];
      items[36] = 'AB-1';
      items[50] = '';
      expect(
        await ean13.checkItems(items),
        const BarcodeItemIssue(
          36,
          'AB-1',
          "'A' at position 1: EAN-13 takes digits only, and an add-on after "
              '+ or a space',
        ),
      );
      items[36] = '400638133393';
      expect(
        await ean13.checkItems(items),
        const BarcodeItemIssue(50, '', 'is empty'),
      );
    });

    test('the longest item is encoded: too long for a QR code', () async {
      final List<String> items = <String>[
        for (int i = 0; i < 100; i++) 'item $i',
      ];
      items[40] = 'x' * 4000;
      final BarcodeItemIssue? issue = await const BarcodeWriter(
        BarcodeFormat.qrCode,
      ).checkItems(items);
      expect(issue?.index, 40);
      expect(issue?.message, isNotEmpty);
    });

    test('encodeAll finds what the rules and the samples miss', () async {
      const BarcodeWriter isbn = BarcodeWriter(BarcodeFormat.isbn);
      final List<String> items = <String>[
        '9781234567897',
        '9781234567898', // wrong ISBN check digit: no quick rule
        '9781234567897',
      ];
      expect(await isbn.checkItems(items), isNull);
      final BarcodeItemIssue? issue = await isbn.checkItems(
        items,
        encodeAll: true,
      );
      expect(issue?.index, 1);
      expect(issue?.message, contains('check digit'));
    });

    test('GS1 data skips the quick rules', () async {
      const BarcodeWriter gs1 = BarcodeWriter(BarcodeFormat.code128, gs1: true);
      expect(await gs1.checkItems(<String>['(01)09501101530003']), isNull);
      expect(await gs1.checkItems(<String>['no AI']), isNotNull);
    });
  });

  test('SerialItems feed a label sheet a page at a time', () async {
    const BarcodeLabelSheet sheet = BarcodeLabelSheet(columns: 3, rows: 8);
    final SerialItems items = SerialItems('AA{n:6}', count: 10000);
    expect(sheet.pageCount(items.length), 417);
    final String page = await sheet.svgPages(items).first;
    expect(RegExp('<svg x=').allMatches(page), hasLength(24));
    expect(page, contains('>AA000001</text>'));
    expect(page, contains('>AA000024</text>'));
    expect(page, isNot(contains('AA000025')));

    // A billion items: only the first page is ever made.
    final SerialItems huge = SerialItems('{n:10}', count: 1000000000);
    expect(sheet.pageCount(huge.length), 41666667);
    expect(await sheet.svgPages(huge).first, contains('>0000000024</text>'));
  });
}
