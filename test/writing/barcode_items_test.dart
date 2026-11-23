// BarcodeItems: lines, CSV (quotes, separators, line breaks, BOM, header,
// missing cells), column names, and the quick rules of checkItems.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/src/barcode/barcode_format.dart';
import 'package:flutter_zxing/src/writing/barcode_items.dart';

void main() {
  group('lines', () {
    test('trimmed, empty lines left out, any line break', () {
      expect(BarcodeItems.lines(' A1 \r\nB2\n\n  \rC3\n'), <String>[
        'A1',
        'B2',
        'C3',
      ]);
      expect(BarcodeItems.lines(''), isEmpty);
      expect(BarcodeItems.lines('﻿A\nB'), <String>['A', 'B']);
    });

    test('unique keeps the first of each', () {
      expect(BarcodeItems.lines('B\nA\nB\nC\nA', unique: true), <String>[
        'B',
        'A',
        'C',
      ]);
    });

    test('read-only', () {
      expect(() => BarcodeItems.lines('A').add('B'), throwsUnsupportedError);
    });
  });

  group('CSV', () {
    test('a column, the header, empty and missing cells', () {
      const String csv =
          'Name,EAN,Price\nTea,4006381333931,2.50\nCup,,4\nLid\n';
      expect(BarcodeItems.csv(csv), <String>['Name', 'Tea', 'Cup', 'Lid']);
      expect(BarcodeItems.csv(csv, column: 1, header: true), <String>[
        '4006381333931',
      ]);
      expect(BarcodeItems.csv(csv, column: 7), isEmpty);
      expect(() => BarcodeItems.csv(csv, column: -1), throwsArgumentError);
    });

    test('quotes: separators, line breaks and doubled quotes inside', () {
      const String csv =
          'id,text\n1,"a,b"\n2,"two\nlines"\n3,"say ""hi"""\n4," spaced "\n';
      expect(BarcodeItems.csv(csv, column: 1, header: true), <String>[
        'a,b',
        'two\nlines',
        'say "hi"',
        'spaced',
      ]);
      expect(BarcodeItems.csvRows(csv).toList()[4], <String>['4', ' spaced ']);
    });

    test('CRLF, CR, a BOM and no line break at the end', () {
      expect(BarcodeItems.csv('﻿a,1\r\nb,2\rc,3', column: 1), <String>[
        '1',
        '2',
        '3',
      ]);
      expect(
        BarcodeItems.csvRows('﻿a,1\r\n\r\nb,2\r\n').toList(),
        <List<String>>[
          <String>['a', '1'],
          <String>['b', '2'],
        ],
      );
    });

    test('the separator: ; and tab found in the first row, or given', () {
      const String excel = 'Name;EAN\n"Tea; green";4006381333931\n';
      expect(BarcodeItems.csv(excel, column: 1, header: true), <String>[
        '4006381333931',
      ]);
      expect(BarcodeItems.csv('a\tb\n1\t2', column: 1), <String>['b', '2']);
      // A comma inside quotes does not count.
      expect(BarcodeItems.csvHeaders('"a,b,c";d\n'), <String>['a,b,c', 'd']);
      expect(BarcodeItems.csv('a;b|c', column: 1, separator: '|'), <String>[
        'c',
      ]);
      expect(BarcodeItems.csv('a,b', separator: ';'), <String>['a,b']);
      expect(() => BarcodeItems.csv('a', separator: ',,'), throwsArgumentError);
      expect(() => BarcodeItems.csv('a', separator: '"'), throwsArgumentError);
    });

    test('column names, unique, an empty file', () {
      expect(BarcodeItems.csvHeaders(' Name , EAN \nTea,1\n'), <String>[
        'Name',
        'EAN',
      ]);
      expect(BarcodeItems.csvHeaders(''), isEmpty);
      expect(BarcodeItems.csv(''), isEmpty);
      expect(BarcodeItems.csv('a\nb\na', unique: true), <String>['a', 'b']);
      expect(BarcodeItems.csvRows('a,,\n').single, <String>['a', '', '']);
      expect(BarcodeItems.csvRows('""\n').single, <String>['']);
    });

    test('rows are read one at a time', () {
      final String big = List<String>.filled(100000, 'x,y').join('\n');
      expect(BarcodeItems.csvRows(big).take(2).length, 2);
    });
  });

  group('quick rules', () {
    String? p(BarcodeFormat f, String item) => itemProblem(f, item);

    test('EAN and UPC', () {
      expect(p(BarcodeFormat.ean13, '4006381333931'), isNull);
      expect(p(BarcodeFormat.ean13, '400638133393'), isNull);
      expect(p(BarcodeFormat.ean13, '12345'), isNull);
      expect(p(BarcodeFormat.ean13, '4006381333931+12'), isNull);
      expect(p(BarcodeFormat.ean13, '4006381333931 12345'), isNull);
      expect(
        p(BarcodeFormat.ean13, 'AB-1'),
        "'A' at position 1: EAN-13 takes digits only, and an add-on after + "
        'or a space',
      );
      expect(
        p(BarcodeFormat.ean13, '4006381333932'),
        "wrong check digit '2', expecting '1'",
      );
      expect(
        p(BarcodeFormat.ean13, '40063813339311'),
        '14 digits: EAN-13 takes up to 13',
      );
      expect(p(BarcodeFormat.ean13, '400638133393+123456'), isNotNull);
      expect(p(BarcodeFormat.ean8, '96385074'), isNull);
      expect(p(BarcodeFormat.ean8, '96385075'), isNotNull);
      expect(p(BarcodeFormat.upcA, '036000291452'), isNull);
      expect(p(BarcodeFormat.upcA, '036000291453'), isNotNull);
      expect(p(BarcodeFormat.upcE, '123456789'), isNotNull);
      expect(p(BarcodeFormat.upcE, '01234565'), isNull);
    });

    test('character sets', () {
      expect(p(BarcodeFormat.code39, r'abc-1 $/+%.'), isNull);
      expect(
        p(BarcodeFormat.code39, 'AB*C'),
        "'*' at position 3: Code 39 takes letters, digits, space and "
        r'- . $ / + % only',
      );
      expect(p(BarcodeFormat.code93, 'abc'), isNull);
      expect(p(BarcodeFormat.code93, 'aé'), contains("'é' at position 2"));
      expect(p(BarcodeFormat.code128, 'é'), isNull);
      expect(p(BarcodeFormat.code128, '€'), isNotNull);
      expect(p(BarcodeFormat.code128, 'a😀'), contains("'😀' at position 2"));
      expect(p(BarcodeFormat.itf, '12A'), isNotNull);
      expect(p(BarcodeFormat.qrCode, '😀 any text'), isNull);
    });

    test('Codabar, DataBar, Aztec Rune, Code 32, PZN', () {
      expect(p(BarcodeFormat.codabar, 'A123B'), isNull);
      expect(p(BarcodeFormat.codabar, 'a123b'), isNull);
      expect(p(BarcodeFormat.codabar, '123'), contains('begins with'));
      expect(p(BarcodeFormat.codabar, 'A123'), contains('ends with'));
      expect(
        p(BarcodeFormat.codabar, 'A12X3B'),
        startsWith("'X' at position 4"),
      );
      expect(p(BarcodeFormat.dataBar, '12345678901231'), isNull);
      expect(p(BarcodeFormat.dataBar, '12345678901234'), isNotNull);
      expect(p(BarcodeFormat.dataBar, '123456789012345'), isNotNull);
      expect(p(BarcodeFormat.dataBarLimited, '1950110153000'), isNull);
      expect(p(BarcodeFormat.dataBarLimited, '2234567890123'), isNotNull);
      expect(p(BarcodeFormat.aztecRune, '255'), isNull);
      expect(p(BarcodeFormat.aztecRune, '256'), isNotNull);
      expect(p(BarcodeFormat.code32, '123456789'), isNotNull);
      expect(p(BarcodeFormat.pzn, '123456789'), isNotNull);
    });
  });

  test('an issue names the item and its index', () {
    const BarcodeItemIssue issue = BarcodeItemIssue(36, 'AB-1', 'no letters');
    expect(issue.toString(), 'Item 36 ("AB-1"): no letters');
    expect(issue, const BarcodeItemIssue(36, 'AB-1', 'no letters'));
    expect(
      BarcodeItemIssue(0, 'x' * 100, 'm').toString(),
      'Item 0 ("${'x' * 57}..."): m',
    );
  });
}
