/// A check character computed from the data before it: [gs1] for GTIN,
/// EAN, UPC, SSCC and GLN, [luhn] for card and account numbers, [mod43]
/// for Code 39.
///
/// [of] gives the check character, [append] the data with it, [isValid]
/// tells whether the last character of a text is the right one.
///
/// ```dart
/// CheckDigit.gs1.of('400638133393'); // '1'
/// CheckDigit.gs1.append('400638133393'); // '4006381333931'
/// CheckDigit.gs1.isValid('4006381333931'); // true
/// CheckDigit.luhn.of('7992739871'); // '3'
/// ```
///
/// EAN-13, EAN-8, UPC-A, UPC-E and GS1 DataBar add their check digit
/// themselves when it is left out: give `BarcodeWriter` the data without
/// one, or with the right one.
enum CheckDigit {
  /// The GS1 mod 10 check digit (GS1 General Specifications 7.9.1): the
  /// digits weighted 3 and 1 from the right, the check digit makes the sum
  /// a multiple of 10. The last digit of a GTIN (EAN-13, EAN-8, UPC-A,
  /// GTIN-14), SSCC and GLN. Digits only.
  gs1,

  /// The Luhn mod 10 check digit (ISO/IEC 7812): every second digit from
  /// the right doubled. The last digit of payment card numbers, IMEI and
  /// many account and membership numbers. Digits only.
  luhn,

  /// The Code 39 mod 43 check character: the values of the characters
  /// (`0-9`, `A-Z`, then `-`, `.`, space, `$`, `/`, `+`, `%`) added up,
  /// modulo 43. Capital letters, digits, space and `- . $ / + %` only.
  mod43;

  /// The check character of [data], without it: one digit for [gs1] and
  /// [luhn], one Code 39 character for [mod43].
  ///
  /// Throws [ArgumentError] if [data] is empty or has a character the
  /// check does not take (anything but digits for [gs1] and [luhn]).
  String of(String data) {
    if (data.isEmpty) {
      throw ArgumentError.value(data, 'data', 'is empty');
    }
    final int? bad = _invalidAt(data);
    if (bad != null) {
      throw ArgumentError.value(
        data,
        'data',
        "'${data[bad]}' at position ${bad + 1}: the $name check takes "
            '${this == mod43 ? r'capital letters, digits, space and - . $ / + %' : 'digits'} only',
      );
    }
    return switch (this) {
      gs1 => String.fromCharCode(0x30 + _gs1(data)),
      luhn => String.fromCharCode(0x30 + _luhn(data)),
      mod43 => _code39[_mod43(data)],
    };
  }

  /// [data] with its check character after it.
  ///
  /// Throws [ArgumentError] as [of] does.
  String append(String data) => '$data${of(data)}';

  /// Whether the last character of [text] is the check character of the
  /// rest. `false` for a text shorter than two characters or with a
  /// character the check does not take.
  bool isValid(String text) {
    if (text.length < 2 || _invalidAt(text) != null) {
      return false;
    }
    final String data = text.substring(0, text.length - 1);
    return of(data) == text[text.length - 1];
  }

  /// The index of the first character of [data] this check does not take.
  int? _invalidAt(String data) {
    for (int i = 0; i < data.length; i++) {
      final int c = data.codeUnitAt(i);
      final bool ok = this == mod43
          ? _code39.contains(data[i])
          : c >= 0x30 && c <= 0x39;
      if (!ok) {
        return i;
      }
    }
    return null;
  }

  static int _gs1(String digits) {
    int sum = 0;
    int weight = 3;
    for (int i = digits.length - 1; i >= 0; i--) {
      sum += (digits.codeUnitAt(i) - 0x30) * weight;
      weight = 4 - weight;
    }
    return (10 - sum % 10) % 10;
  }

  static int _luhn(String digits) {
    int sum = 0;
    bool double = true;
    for (int i = digits.length - 1; i >= 0; i--) {
      int d = digits.codeUnitAt(i) - 0x30;
      if (double) {
        d *= 2;
        if (d > 9) {
          d -= 9;
        }
      }
      sum += d;
      double = !double;
    }
    return (10 - sum % 10) % 10;
  }

  static int _mod43(String data) {
    int sum = 0;
    for (int i = 0; i < data.length; i++) {
      sum += _code39.indexOf(data[i]);
    }
    return sum % 43;
  }

  static const String _code39 = r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%';
}
