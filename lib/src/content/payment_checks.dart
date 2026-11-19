// Check digits and checksums of payment codes: IBAN (ISO 13616), creditor
// references (ISO 11649), Swiss QR references, and the CRC of EMVCo QR codes.

final RegExp _ibanShape = RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]{11,30}$');

/// [iban] without spaces, upper case.
String compactIban(String iban) =>
    iban.replaceAll(RegExp(r'\s'), '').toUpperCase();

/// Whether [value] is `n` mod 97 == 1 after moving its first four
/// characters to the end and letters to numbers (A = 10 … Z = 35): the IBAN
/// and ISO 11649 rule.
bool _mod97(String value) {
  final String moved = value.substring(4) + value.substring(0, 4);
  int rest = 0;
  for (int i = 0; i < moved.length; i++) {
    final int c = moved.codeUnitAt(i);
    final int v = c >= 0x41 ? c - 0x41 + 10 : c - 0x30;
    rest = (v >= 10 ? rest * 100 + v : rest * 10 + v) % 97;
  }
  return rest == 1;
}

/// Whether [iban] (compact, upper case) has an IBAN's shape: country,
/// check digits, 11 to 30 letters and digits.
bool hasIbanShape(String iban) => _ibanShape.hasMatch(iban);

/// Whether [iban] (compact, upper case) has an IBAN's shape and check
/// digits.
bool isValidIban(String iban) => _ibanShape.hasMatch(iban) && _mod97(iban);

final RegExp _creditorReference = RegExp(r'^RF\d{2}[A-Z0-9]{1,21}$');

/// Whether [reference] (compact, upper case) is an ISO 11649 creditor
/// reference: `RF` + check digits + up to 21 characters.
bool isValidCreditorReference(String reference) =>
    _creditorReference.hasMatch(reference) && _mod97(reference);

const List<int> _qrrTable = <int>[0, 9, 4, 6, 8, 2, 7, 1, 3, 5];

/// The check digit of a Swiss QR reference (recursive mod 10) for the
/// [digits] before it.
int qrReferenceCheckDigit(String digits) {
  int carry = 0;
  for (int i = 0; i < digits.length; i++) {
    carry = _qrrTable[(carry + digits.codeUnitAt(i) - 0x30) % 10];
  }
  return (10 - carry) % 10;
}

/// Whether [reference] is a Swiss QR reference: 27 digits, the last a
/// recursive mod 10 check digit.
bool isValidQrReference(String reference) =>
    RegExp(r'^\d{27}$').hasMatch(reference) &&
    qrReferenceCheckDigit(reference.substring(0, 26)) ==
        reference.codeUnitAt(26) - 0x30;

/// Whether [iban] is a Swiss QR-IBAN: its bank number (characters 5–9) is
/// 30000–31999, reserved for QR references.
bool isQrIban(String iban) {
  if (iban.length < 9) {
    return false;
  }
  final int? iid = int.tryParse(iban.substring(4, 9));
  return iid != null && iid >= 30000 && iid <= 31999;
}

/// CRC-16/CCITT-FALSE (polynomial 0x1021, start 0xFFFF) of [text]'s UTF-8
/// bytes, as four upper case hex digits: the checksum of EMVCo QR codes.
String emvCrc(List<int> bytes) {
  int crc = 0xFFFF;
  for (final int byte in bytes) {
    crc ^= byte << 8;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : crc << 1;
      crc &= 0xFFFF;
    }
  }
  return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
}
