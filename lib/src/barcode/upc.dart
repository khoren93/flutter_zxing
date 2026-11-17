// UPC-A and UPC-E as printed on them. zxing-cpp gives both as 13 digits,
// as ISO/IEC 15420 transmits them (a UPC-A is an EAN-13 starting with 0),
// and reports a UPC-A as EAN-13 whenever EAN-13 is asked for too. People
// and other scanners expect the 12 or 8 digits on the label. Not exported
// from the package.
import 'dart:convert';

import 'barcode.dart';
import 'barcode_format.dart';

final RegExp _gtin13 = RegExp(r'^\d{13}');

/// [barcode] as printed: an EAN-13 starting with 0 is a UPC-A of 12
/// digits, a UPC-E has its 8 digits; an add-on stays after them.
/// [formats] is the engine's format filter (zxing-cpp names, `''` for all):
/// a reader asking for EAN-13 but not UPC-A keeps getting EAN-13.
Barcode upcAsPrinted(Barcode barcode, String formats) {
  final String text = barcode.text;
  if (!_gtin13.hasMatch(text) || !text.startsWith('0')) {
    return barcode;
  }
  final String addOn = text.substring(13);
  switch (barcode.format) {
    case BarcodeFormat.ean13:
      final Set<String> asked = formats.isEmpty
          ? const <String>{}
          : formats.split(',').map((String f) => f.trim()).toSet();
      final bool wantsUpcA =
          asked.isEmpty || asked.contains('UPCA') || asked.contains('EANUPC');
      return wantsUpcA
          ? _with(barcode, BarcodeFormat.upcA, text.substring(1, 13) + addOn)
          : barcode;
    case BarcodeFormat.upcA:
      return _with(barcode, BarcodeFormat.upcA, text.substring(1, 13) + addOn);
    case BarcodeFormat.upcE:
      final String? upcE = upcEFromUpcA(text.substring(1, 13));
      return upcE == null
          ? barcode
          : _with(barcode, BarcodeFormat.upcE, upcE + addOn);
    default:
      return barcode;
  }
}

/// The 8 digits of the UPC-E that [upcA] (12 digits) zero-suppresses to,
/// or `null` if it has none.
String? upcEFromUpcA(String upcA) {
  if (upcA.length != 12 || !RegExp(r'^[01]\d{11}$').hasMatch(upcA)) {
    return null;
  }
  final String n = upcA[0];
  final String m = upcA.substring(1, 6);
  final String p = upcA.substring(6, 11);
  final String c = upcA[11];
  final String? six;
  if (m.endsWith('00') && '012'.contains(m[2]) && p.startsWith('00')) {
    six = '${m.substring(0, 2)}${p.substring(2)}${m[2]}';
  } else if (m.endsWith('00') && p.startsWith('000')) {
    six = '${m.substring(0, 3)}${p.substring(3)}3';
  } else if (m.endsWith('0') && p.startsWith('0000')) {
    six = '${m.substring(0, 4)}${p[4]}4';
  } else if (p.startsWith('0000') && '56789'.contains(p[4])) {
    six = '$m${p[4]}';
  } else {
    six = null;
  }
  return six == null ? null : '$n$six$c';
}

Barcode _with(Barcode b, BarcodeFormat format, String text) => Barcode(
  format: format,
  text: text,
  bytes: utf8.encode(text),
  position: b.position,
  contentType: b.contentType,
  orientation: b.orientation,
  isMirrored: b.isMirrored,
  isInverted: b.isInverted,
  ecLevel: b.ecLevel,
  version: b.version,
  symbologyIdentifier: b.symbologyIdentifier,
  sequence: b.sequence,
  error: b.error,
  symbol: b.symbol,
);
