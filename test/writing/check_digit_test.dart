// CheckDigit against published GTIN, UPC, SSCC, ISBN, card and IMEI
// numbers, and the GS1 key check of GS1 content, which uses it.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/src/writing/check_digit.dart';

void main() {
  test('GS1 mod 10: GTIN-13, GTIN-8, UPC-A, GTIN-14, SSCC, GLN, ISBN', () {
    const Map<String, String> known = <String, String>{
      '400638133393': '1', // EAN-13 4006381333931
      '950110153000': '3', // EAN-13 9501101530003 (GS1 example)
      '9638507': '4', // EAN-8 96385074
      '03600029145': '2', // UPC-A 036000291452
      '01234567890': '5', // UPC-A 012345678905
      '1001234567890': '2', // GTIN-14
      '10614141234567890': '8', // SSCC 106141412345678908
      '061414100001': '2', // GLN 0614141000012
      '978030640615': '7', // ISBN-13 9780306406157
    };
    known.forEach((String data, String digit) {
      expect(CheckDigit.gs1.of(data), digit, reason: data);
      expect(CheckDigit.gs1.isValid('$data$digit'), isTrue, reason: data);
      expect(CheckDigit.gs1.append(data), '$data$digit');
    });
    expect(CheckDigit.gs1.isValid('4006381333932'), isFalse);
  });

  test('Luhn: the Wikipedia example, card numbers, IMEI', () {
    expect(CheckDigit.luhn.of('7992739871'), '3');
    expect(CheckDigit.luhn.isValid('79927398713'), isTrue);
    expect(CheckDigit.luhn.isValid('79927398710'), isFalse);
    expect(CheckDigit.luhn.isValid('4111111111111111'), isTrue); // Visa
    expect(CheckDigit.luhn.isValid('378282246310005'), isTrue); // Amex
    expect(CheckDigit.luhn.isValid('490154203237518'), isTrue); // IMEI
    expect(CheckDigit.luhn.isValid('4111111111111112'), isFalse);
  });

  test('Code 39 mod 43', () {
    expect(CheckDigit.mod43.of('ABC'), 'X'); // 10 + 11 + 12 = 33
    expect(CheckDigit.mod43.of('CODE 39'), 'R'); // 113 % 43 = 27
    expect(CheckDigit.mod43.of('%'), '%'); // 42
    expect(CheckDigit.mod43.isValid('ABCX'), isTrue);
    expect(CheckDigit.mod43.isValid('abcX'), isFalse);
  });

  test('characters a check does not take', () {
    expect(() => CheckDigit.gs1.of(''), throwsArgumentError);
    expect(
      () => CheckDigit.gs1.of('12A4'),
      throwsA(
        isA<ArgumentError>().having(
          (ArgumentError e) => e.message,
          'message',
          contains("'A' at position 3"),
        ),
      ),
    );
    expect(() => CheckDigit.luhn.of('12 3'), throwsArgumentError);
    expect(() => CheckDigit.mod43.of('abc'), throwsArgumentError);
    expect(CheckDigit.gs1.isValid('1'), isFalse);
    expect(CheckDigit.gs1.isValid('12A4'), isFalse);
    expect(CheckDigit.luhn.isValid(''), isFalse);
  });
}
