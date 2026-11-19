import 'barcode_content.dart';
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

final RegExp _aiDigits = RegExp(r'^\d{2,4}$');

/// Why the element [ai] = [value] cannot be encoded, or `null` if it can:
/// the identifier must be in the Application Identifier table, and the
/// value must have its length (fixed) or fit in it (variable). The issue is
/// about [field].
ContentIssue? gs1ElementIssue(String field, String ai, String value) {
  final (String, int)? info = _aiDigits.hasMatch(ai) ? _lookUp(ai, 0) : null;
  if (info == null || _aiSize(info.$1) != ai.length) {
    return ContentIssue(
      field,
      'Unknown Application Identifier ($ai)',
      kind: ContentIssueKind.unsupported,
    );
  }
  if (value.isEmpty) {
    return ContentIssue(field, '($ai) is empty', kind: ContentIssueKind.empty);
  }
  if (value.contains('(') || value.contains(')')) {
    return ContentIssue(field, '($ai) cannot contain parentheses');
  }
  final int size = info.$2;
  if (size > 0 && value.length != size) {
    return ContentIssue(field, '($ai) must be $size characters');
  }
  if (size < 0 && value.length > -size) {
    return ContentIssue(
      field,
      '($ai) must be at most ${-size} characters',
      kind: ContentIssueKind.tooLong,
      limit: -size,
    );
  }
  return null;
}

final RegExp _gs1DateDigits = RegExp(r'^\d{6}$');

/// The date of a GS1 date field (`YYMMDD`: AI 11, 13, 15, 16, 17), or
/// `null` if [value] is not one.
///
/// The century follows GS1 General Specifications 7.12: a year more than
/// 50 years ahead of [now] is in the previous century, one more than 49
/// years back is in the next. Day `00` means the last day of the month.
DateTime? gs1Date(String? value, [DateTime? now]) {
  if (value == null || !_gs1DateDigits.hasMatch(value)) {
    return null;
  }
  final int yy = int.parse(value.substring(0, 2));
  final int month = int.parse(value.substring(2, 4));
  final int day = int.parse(value.substring(4, 6));
  if (month < 1 || month > 12) {
    return null;
  }
  final int current = (now ?? DateTime.now()).year;
  final int century = current - current % 100;
  int year = century + yy;
  final int diff = yy - current % 100;
  if (diff > 50) {
    year -= 100;
  } else if (diff < -49) {
    year += 100;
  }
  // Day 0 of the next month is the last day of this one.
  final int last = DateTime.utc(year, month + 1, 0).day;
  if (day > last) {
    return null;
  }
  return DateTime(year, month, day == 0 ? last : day);
}
