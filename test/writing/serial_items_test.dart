// SerialItems: patterns, numbering, check digits, the errors of the
// constructor, and the read-only list that makes nothing up front.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/src/writing/check_digit.dart';
import 'package:flutter_zxing/src/writing/serial_items.dart';

Matcher _argumentError(String text) => throwsA(
  isA<ArgumentError>().having(
    (ArgumentError e) => '${e.message}',
    'message',
    contains(text),
  ),
);

void main() {
  test('padding, prefix and suffix', () {
    expect(SerialItems('AA{n:6}', count: 3), <String>[
      'AA000001',
      'AA000002',
      'AA000003',
    ]);
    expect(SerialItems('{n}', count: 2), <String>['1', '2']);
    expect(SerialItems('BOX-{n:3}-EU', start: 7, count: 1), <String>[
      'BOX-007-EU',
    ]);
    expect(SerialItems('{{{n}}}', count: 1), <String>['{1}']);
    expect(SerialItems('{{n}}={n}', count: 1), <String>['{n}=1']);
  });

  test('start, step, counting down', () {
    expect(SerialItems('{n}', start: 0, count: 4, step: 5), <String>[
      '0',
      '5',
      '10',
      '15',
    ]);
    expect(SerialItems('{n:2}', start: 3, count: 4, step: -1), <String>[
      '03',
      '02',
      '01',
      '00',
    ]);
  });

  test('a number wider than its padding keeps its digits', () {
    expect(SerialItems('{n:3}', start: 998, count: 3), <String>[
      '998',
      '999',
      '1000',
    ]);
  });

  test('length, [] and elementAt make only the item asked for', () {
    final SerialItems items = SerialItems(
      'X{n:12}',
      count: 1000000000000,
      start: 0,
    );
    expect(items.length, 1000000000000);
    expect(items[999999999999], 'X999999999999');
    expect(items.elementAt(42), 'X000000000042');
    expect(items.last, 'X999999999999');
    expect(items.skip(5).first, 'X000000000005');
    expect(items.numberAt(10), 10);
    expect(() => items[-1], throwsRangeError);
    expect(() => items[1000000000000], throwsRangeError);
    expect(items.toString(), 'SerialItems(X{n:12}, 1000000000000 from 0)');
  });

  test('it cannot be changed', () {
    final SerialItems items = SerialItems('{n}', count: 2);
    expect(() => items.add('3'), throwsUnsupportedError);
    expect(() => items[0] = 'x', throwsUnsupportedError);
    expect(() => items.length = 1, throwsUnsupportedError);
  });

  test('check digits over the whole item', () {
    final SerialItems gtins = SerialItems(
      '400638{n:6}',
      start: 133393,
      count: 2,
      checkDigit: CheckDigit.gs1,
    );
    expect(gtins.first, '4006381333931');
    expect(CheckDigit.gs1.isValid(gtins[1]), isTrue);
    expect(
      SerialItems(
        '{n}',
        count: 1,
        start: 7992739871,
        checkDigit: CheckDigit.luhn,
      ).single,
      '79927398713',
    );
    expect(
      SerialItems(
        'AB{n}',
        count: 1,
        start: 0,
        checkDigit: CheckDigit.mod43,
      ).single,
      // A 10 + B 11 + 0 = 21: L.
      'AB0L',
    );
    expect(
      () => SerialItems('AA{n}', count: 1, checkDigit: CheckDigit.gs1),
      _argumentError("'A' at position 1"),
    );
  });

  test('errors', () {
    expect(() => SerialItems('AA', count: 1), _argumentError('no placeholder'));
    expect(
      () => SerialItems('{n}-{n}', count: 1),
      _argumentError('more than one placeholder'),
    );
    expect(
      () => SerialItems('{x}', count: 1),
      _argumentError('unknown placeholder at position 1'),
    );
    expect(
      () => SerialItems('{n:}', count: 1),
      _argumentError('unknown placeholder'),
    );
    expect(
      () => SerialItems('{n:0}', count: 1),
      _argumentError('give 1 to 64'),
    );
    expect(
      () => SerialItems('{n}}', count: 1),
      _argumentError("lone '}' at position 4"),
    );
    expect(() => SerialItems('{n}', count: 0), _argumentError('at least 1'));
    expect(() => SerialItems('{n}', count: 1, step: 0), throwsArgumentError);
    expect(() => SerialItems('{n}', count: 1, start: -1), throwsArgumentError);
    expect(
      () => SerialItems('{n}', count: 3, step: -1),
      _argumentError('go below 0'),
    );
    expect(
      () => SerialItems('{n}', count: 2, start: SerialItems.maxNumber),
      _argumentError('go above'),
    );
    expect(
      SerialItems('{n}', count: 1, start: SerialItems.maxNumber).single,
      '9007199254740991',
    );
  });
}
