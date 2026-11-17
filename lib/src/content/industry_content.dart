import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import 'barcode_content.dart';
import 'content_util.dart';

// Parsing ProductContent, BoardingPassContent, DriverLicenseContent,
// VinContent and SmartHomeContent. None of them is built: the codes are
// made by stores, airlines, states, carmakers and device makers.

// --- Products ----------------------------------------------------------------------

/// The number of an EAN/UPC [barcode], or `null` for other formats.
/// zxing-cpp appends an add-on to the number without a separator, so the
/// format says where the number ends.
ProductContent? parseProduct(Barcode barcode) {
  if (barcode.format.symbology != BarcodeFormat.eanUpc) {
    return null;
  }
  final String text = barcode.text.trim();
  final List<int> lengths = switch (barcode.format) {
    BarcodeFormat.ean13 || BarcodeFormat.isbn => <int>[13],
    BarcodeFormat.upcA => <int>[12],
    BarcodeFormat.ean8 || BarcodeFormat.upcE => <int>[8],
    BarcodeFormat.ean2 || BarcodeFormat.ean5 => <int>[],
    _ => <int>[13, 12, 8],
  };
  for (final int length in lengths) {
    if (text.length < length) {
      continue;
    }
    final String gtin = text.substring(0, length);
    final String rest = text
        .substring(length)
        .replaceFirst(RegExp(r'^[ \-]'), '');
    if (RegExp(r'^\d+$').hasMatch(gtin) &&
        (rest.isEmpty || RegExp(r'^(\d{2}|\d{5})$').hasMatch(rest))) {
      return ProductContent(
        gtin: gtin,
        addOn: rest.isEmpty ? null : rest,
        raw: barcode.text,
      );
    }
  }
  return null;
}

// --- Boarding passes ---------------------------------------------------------------

final RegExp _airport = RegExp(r'^[A-Z]{3}$');
final RegExp _leadingZeros = RegExp('^0+(?=.)');

/// IATA BCBP (Resolution 792), format M: the mandatory items of each leg.
BoardingPassContent? parseBoardingPass(String text) {
  if (text.length < 60 || text[0] != 'M') {
    return null;
  }
  final int? legCount = int.tryParse(text[1]);
  if (legCount == null || legCount < 1 || legCount > 4) {
    return null;
  }
  final String name = text.substring(2, 22).trim();
  if (name.isEmpty) {
    return null;
  }
  final List<BoardingPassLeg> legs = <BoardingPassLeg>[];
  int at = 23;
  for (int i = 0; i < legCount && at + 37 <= text.length; i++) {
    String field(int offset, int length) =>
        text.substring(at + offset, at + offset + length).trim();
    final String from = field(7, 3);
    final String to = field(10, 3);
    if (!_airport.hasMatch(from) || !_airport.hasMatch(to)) {
      break;
    }
    final int? day = int.tryParse(field(21, 3));
    legs.add(
      BoardingPassLeg(
        bookingReference: field(0, 7),
        from: from,
        to: to,
        carrier: field(13, 3),
        flightNumber: field(16, 5).replaceFirst(_leadingZeros, ''),
        dayOfYear: day != null && day >= 1 && day <= 366 ? day : null,
        cabin: field(24, 1),
        seat: field(25, 4).replaceFirst(_leadingZeros, ''),
        sequenceNumber: field(29, 5).replaceFirst(_leadingZeros, ''),
      ),
    );
    final int? conditional = int.tryParse(field(35, 2), radix: 16);
    if (conditional == null) {
      break;
    }
    at += 37 + conditional;
  }
  if (legs.isEmpty) {
    return null;
  }
  return BoardingPassContent(
    passengerName: name,
    legs: List<BoardingPassLeg>.unmodifiable(legs),
    electronicTicket: text[22] == 'E',
    raw: text,
  );
}

// --- Driver's licenses -------------------------------------------------------------

final RegExp _aamvaLine = RegExp(r'[\n\r\x1e]');
final RegExp _firstElement = RegExp(r'(?:DL|ID)(D[A-Z]{2}.*)$');
final RegExp _subfileElement = RegExp(r'^(?:DL|ID)(?=D[A-Z]{2})');

/// Whether [text] starts like an AAMVA card (`@` and an `ANSI ` header).
bool isAamva(String text) {
  if (!text.startsWith('@')) {
    return false;
  }
  final String head = text.length > 40 ? text.substring(0, 40) : text;
  return head.contains('ANSI ') || head.contains('AAMVA');
}

/// The AAMVA DL/ID data elements of [text].
DriverLicenseContent? parseDriverLicense(String text) {
  final Map<String, String> elements = <String, String>{};
  for (String line in text.split(_aamvaLine)) {
    if (line.contains('ANSI ') || line.contains('AAMVA')) {
      // The header; the first element may follow its subfile directory.
      final RegExpMatch? first = _firstElement.firstMatch(line);
      if (first == null) {
        continue;
      }
      line = first.group(1)!;
    } else {
      line = line.replaceFirst(_subfileElement, '');
    }
    if (line.length > 3) {
      final String value = line.substring(3).trim();
      if (value.isNotEmpty && value.toUpperCase() != 'NONE') {
        elements.putIfAbsent(line.substring(0, 3), () => value);
      }
    }
  }
  String? at(String id) => elements[id];
  final String? country = at('DCG');
  // Version 1 cards: DAA "LAST,FIRST,MIDDLE", DAB family, DCT given names.
  final List<String> full = (at('DAA') ?? '').split(RegExp(r'[,$]'));
  String? part(int i) => i < full.length ? orNull(full[i].trim()) : null;
  final String? lastName = at('DCS') ?? at('DAB') ?? part(0);
  final String? licenseNumber = at('DAQ');
  if (lastName == null && licenseNumber == null) {
    return null;
  }
  final List<String> given = (at('DCT') ?? '').split(RegExp(r'[,\s]+'));
  return DriverLicenseContent(
    licenseNumber: licenseNumber,
    firstName: at('DAC') ?? orNull(given.first) ?? part(1),
    middleName:
        at('DAD') ??
        (given.length > 1 ? orNull(given.skip(1).join(' ')) : null) ??
        part(2),
    lastName: lastName,
    dateOfBirth: _aamvaDate(at('DBB'), country),
    issueDate: _aamvaDate(at('DBD'), country),
    expiryDate: _aamvaDate(at('DBA'), country),
    street: at('DAG'),
    city: at('DAI'),
    state: at('DAJ'),
    postalCode: _postalCode(at('DAK')),
    country: country,
    raw: text,
  );
}

/// `MMDDCCYY` in the USA, `CCYYMMDD` in Canada; without a country, the
/// order that gives a valid date.
DateTime? _aamvaDate(String? value, String? country) {
  if (value == null || !RegExp(r'^\d{8}$').hasMatch(value)) {
    return null;
  }
  DateTime? date(int y, int m, int d) {
    final DateTime t = DateTime(y, m, d);
    return t.year == y && t.month == m && t.day == d && y > 1800 ? t : null;
  }

  int n(int start, int end) => int.parse(value.substring(start, end));
  final DateTime? us = date(n(4, 8), n(0, 2), n(2, 4));
  final DateTime? iso = date(n(0, 4), n(4, 6), n(6, 8));
  return switch (country) {
    'USA' => us,
    'CAN' => iso,
    _ => us ?? iso,
  };
}

String? _postalCode(String? value) {
  final String? v = value?.trim();
  if (v == null) {
    return null;
  }
  return v.length == 9 && v.endsWith('0000') ? v.substring(0, 5) : v;
}

// --- VINs --------------------------------------------------------------------------

final RegExp _vin = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

/// A VIN in [text], with an optional `I` (imported) before it. Unless
/// [trusted] (a Code 39 label, which is where VINs are), the check digit
/// must be right, so that other 17-character codes stay text.
VinContent? parseVin(String text, {bool trusted = false}) {
  String vin = text.trim();
  if (vin.length == 18 && vin.startsWith('I')) {
    vin = vin.substring(1);
  }
  if (!_vin.hasMatch(vin) ||
      !vin.contains(RegExp('[A-Z]')) ||
      !vin.contains(RegExp('[0-9]'))) {
    return null;
  }
  if (!trusted && vinCheckDigit(vin) != vin[8]) {
    return null;
  }
  return VinContent(vin: vin, raw: text);
}

const List<int> _vinWeights = <int>[
  8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2, //
];

int _vinValue(String c) {
  final int i = '0123456789'.indexOf(c);
  if (i >= 0) {
    return i;
  }
  // A–H are 1–8, J–R 1–9 (no I, O, Q), S–Z 2–9.
  const String letters = 'ABCDEFGHJKLMNPRSTUVWXYZ';
  const List<int> values = <int>[
    1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 7, 9, 2, 3, 4, 5, 6, 7, 8, 9, //
  ];
  final int l = letters.indexOf(c);
  return l < 0 ? 0 : values[l];
}

/// The North American check digit of [vin] (character 9): `0`–`9` or `X`.
String vinCheckDigit(String vin) {
  int sum = 0;
  for (int i = 0; i < 17; i++) {
    sum += _vinValue(vin[i]) * _vinWeights[i];
  }
  final int check = sum % 11;
  return check == 10 ? 'X' : '$check';
}

/// [VinContent.region].
VinRegion vinRegion(String vin) {
  final String c = vin[0];
  if ('12345'.contains(c)) {
    return VinRegion.northAmerica;
  }
  if ('67'.contains(c)) {
    return VinRegion.oceania;
  }
  if ('890'.contains(c)) {
    return VinRegion.southAmerica;
  }
  if ('ABCDEFGH'.contains(c)) {
    return VinRegion.africa;
  }
  if ('JKLMNPR'.contains(c)) {
    return VinRegion.asia;
  }
  return VinRegion.europe;
}

/// [VinContent.modelYear].
int? vinModelYear(String vin) {
  const String codes = 'ABCDEFGHJKLMNPRSTVWXY123456789';
  final int i = codes.indexOf(vin[9]);
  if (i < 0) {
    return null;
  }
  // A letter in position 7 marks the 2010–2039 cycle.
  final bool later = RegExp('[A-Z]').hasMatch(vin[6]);
  return 1980 + i + (later ? 30 : 0);
}

// --- Smart home --------------------------------------------------------------------

const String _base38 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-.';

/// A Matter onboarding payload, after the `MT:`.
SmartHomeContent? parseMatter(String body, String raw) {
  final List<int> bytes = <int>[];
  int at = 0;
  while (at < body.length) {
    final int chars = body.length - at >= 5 ? 5 : body.length - at;
    final int count = switch (chars) {
      5 => 3,
      4 => 2,
      2 => 1,
      _ => -1,
    };
    if (count < 0) {
      return null;
    }
    int value = 0;
    for (int i = chars - 1; i >= 0; i--) {
      final int digit = _base38.indexOf(body[at + i]);
      if (digit < 0) {
        return null;
      }
      value = value * 38 + digit;
    }
    for (int i = 0; i < count; i++) {
      bytes.add(value % 256);
      value ~/= 256;
    }
    at += chars;
  }
  if (bytes.length < 11) {
    return null;
  }
  int bits(int offset, int length) {
    int value = 0;
    for (int i = 0; i < length; i++) {
      final int bit = offset + i;
      if ((bytes[bit >> 3] >> (bit & 7)) & 1 == 1) {
        value += 1 << i;
      }
    }
    return value;
  }

  final int passcode = bits(57, 27);
  if (bits(0, 3) != 0 || passcode < 1 || passcode > 99999998) {
    return null;
  }
  return SmartHomeContent(
    platform: SmartHomePlatform.matter,
    setupCode: passcode.toString().padLeft(8, '0'),
    vendorId: bits(3, 16),
    productId: bits(19, 16),
    discriminator: bits(45, 12),
    raw: raw,
  );
}

final RegExp _homeKit = RegExp(r'^([0-9A-Z]{9})([0-9A-Z]{4})$');

/// A HomeKit setup payload, after the `X-HM://`.
SmartHomeContent? parseHomeKit(String body, String raw) {
  final RegExpMatch? m = _homeKit.firstMatch(body.toUpperCase());
  if (m == null) {
    return null;
  }
  // Up to 36^9: within the 2^53 exact on the web too, so no shifts above
  // 32 bits.
  final int value = int.parse(m.group(1)!, radix: 36);
  final int code = value % 134217728; // 27 bits
  final int category = (value ~/ 2147483648) % 256; // bits 31–38
  final String digits = code.toString().padLeft(8, '0');
  return SmartHomeContent(
    platform: SmartHomePlatform.homeKit,
    setupCode:
        '${digits.substring(0, 3)}-${digits.substring(3, 5)}-'
        '${digits.substring(5)}',
    category: category,
    setupId: m.group(2),
    raw: raw,
  );
}
