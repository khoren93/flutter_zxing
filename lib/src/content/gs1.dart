import 'gs1_table.g.dart';

const int _gs = 0x1D;

/// Splits GS1 element strings into Application Identifiers and values.
///
/// [data] is either the raw form the barcode holds (`0109501101530003`
/// `17250101`, variable length fields ended by a GS character) or the human
/// readable form with the identifiers in parentheses
/// (`(01)09501101530003(17)250101`). Returns `null` if the data is not
/// valid GS1, for example because it uses an unknown identifier.
Map<String, String>? parseGs1(String data) {
  if (data.isEmpty) {
    return null;
  }
  return data.codeUnitAt(0) == 0x28 /* ( */ ? _parseHri(data) : _parseRaw(data);
}

/// The raw form, split the way zxing-cpp's HRIFromGS1 does.
Map<String, String>? _parseRaw(String data) {
  final Map<String, String> elements = <String, String>{};
  int at = 0;
  // A leading separator (an FNC1 some readers pass on) carries no data.
  while (at < data.length && data.codeUnitAt(at) == _gs) {
    at++;
  }
  while (at < data.length) {
    final (String, int)? info = _lookUp(data, at);
    if (info == null) {
      return null;
    }
    final int aiSize = _aiSize(info.$1);
    if (data.length - at < aiSize) {
      return null;
    }
    final String ai = data.substring(at, at + aiSize);
    at += aiSize;

    int fieldSize = info.$2.abs();
    if (info.$2 < 0) {
      final int gs = data.indexOf(String.fromCharCode(_gs), at);
      final int available = (gs < 0 ? data.length : gs) - at;
      if (available < fieldSize) {
        fieldSize = available;
      }
    }
    if (fieldSize == 0 || data.length - at < fieldSize) {
      return null;
    }
    elements[ai] = data.substring(at, at + fieldSize);
    at += fieldSize;
    // GS1 General Specifications 7.8.6.3: a separator after any element
    // string is tolerated, needed or not.
    if (at < data.length && data.codeUnitAt(at) == _gs) {
      at++;
    }
  }
  return elements.isEmpty ? null : elements;
}

final RegExp _hriElement = RegExp(r'\((\d{2,4})\)([^(]*)');

/// The human readable form. A value that itself contains `(` cannot be told
/// apart from the next identifier here; the raw form has no such problem and
/// is preferred whenever the bytes are available.
Map<String, String>? _parseHri(String data) {
  final Map<String, String> elements = <String, String>{};
  int at = 0;
  for (final RegExpMatch m in _hriElement.allMatches(data)) {
    if (m.start != at || m.group(2)!.isEmpty) {
      return null;
    }
    elements[m.group(1)!] = m.group(2)!;
    at = m.end;
  }
  return at == data.length && elements.isNotEmpty ? elements : null;
}

(String, int)? _lookUp(String data, int at) {
  for (final (String, int) info in gs1FieldSizes) {
    if (data.startsWith(info.$1, at)) {
      return info;
    }
  }
  return null;
}

/// Length of the identifier itself: 4 digits for the measure (31nn-36nn,
/// 39nn) and 703n/723n families, otherwise the length of the table prefix.
int _aiSize(String prefix) {
  if (prefix.length >= 2 &&
      prefix.codeUnitAt(0) == 0x33 /* 3 */ &&
      '1234569'.contains(prefix[1])) {
    return 4;
  }
  if (prefix == '703' || prefix == '723') {
    return 4;
  }
  return prefix.length;
}
