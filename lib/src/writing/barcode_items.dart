/// @docImport 'serial_items.dart';
library;

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../barcode/barcode_format.dart';
import '../errors.dart';
import 'barcode_writer.dart';
import 'check_digit.dart';

/// Items for a label sheet or a batch export read from text: one a line
/// ([BarcodeItems.lines]) or one column of a CSV file
/// ([BarcodeItems.csv]).
///
/// A read-only list of the items, trimmed of spaces, empty ones left out.
/// For numbered items made from a pattern see [SerialItems].
///
/// ```dart
/// final BarcodeItems skus = BarcodeItems.lines('SKU-1\nSKU-2\n\nSKU-3\n');
/// print(skus); // [SKU-1, SKU-2, SKU-3]
///
/// final String csv = await File('products.csv').readAsString();
/// print(BarcodeItems.csvHeaders(csv)); // [Name, EAN, Price]
/// final BarcodeItems eans = BarcodeItems.csv(csv, column: 1, header: true);
/// final Uint8List pdf = await sheet.pdf(eans);
/// ```
///
/// Check the items before a long export with [BarcodeWriter.checkItems].
final class BarcodeItems extends UnmodifiableListView<String> {
  BarcodeItems._(super.source);

  /// One item a line of [text]: lines end with `\n`, `\r\n` or `\r`. Each
  /// line is trimmed of spaces; empty lines are left out. With [unique],
  /// an item that came before is left out too.
  ///
  /// ```dart
  /// BarcodeItems.lines(' A1 \r\nB2\n\nA1', unique: true); // [A1, B2]
  /// ```
  factory BarcodeItems.lines(String text, {bool unique = false}) =>
      BarcodeItems._(
        _collect(_withoutBom(text).split(_lineBreak), unique: unique),
      );

  /// The cells of one [column] (0 is the first) of the CSV [text]: one
  /// item a row, trimmed of spaces. Empty cells and rows without that
  /// column are left out. With [header] the first row is the column
  /// names, not an item; with [unique] an item that came before is left
  /// out.
  ///
  /// The text is read as RFC 4180 says: a cell in double quotes may hold
  /// the separator, line breaks and quotes (written twice: `""`). Rows end
  /// with `\n`, `\r\n` or `\r`; a byte order mark at the start is skipped.
  ///
  /// [separator] is one character. `null` (the default) takes the one the
  /// first row has most of among `,`, `;` and tab: Excel saves CSV with
  /// `;` in many countries.
  ///
  /// ```dart
  /// const String csv = 'Name;EAN\n"Tea; green";4006381333931\n';
  /// BarcodeItems.csv(csv, column: 1, header: true); // [4006381333931]
  /// ```
  ///
  /// Throws [ArgumentError] if [column] is negative or [separator] is not
  /// one character other than a quote or a line break.
  factory BarcodeItems.csv(
    String text, {
    int column = 0,
    bool header = false,
    String? separator,
    bool unique = false,
  }) {
    if (column < 0) {
      throw ArgumentError.value(column, 'column', 'cannot be negative');
    }
    final Iterable<List<String>> rows = csvRows(text, separator: separator);
    return BarcodeItems._(
      _collect(<String>[
        for (final List<String> row in header ? rows.skip(1) : rows)
          if (column < row.length) row[column],
      ], unique: unique),
    );
  }

  /// The cells of the first row of the CSV [text], trimmed: the column
  /// names for a column picker. Only the first row is read. Empty for an
  /// empty text. [separator] is as in [BarcodeItems.csv].
  ///
  /// ```dart
  /// BarcodeItems.csvHeaders('Name,EAN\nTea,4006381333931'); // [Name, EAN]
  /// ```
  static List<String> csvHeaders(String text, {String? separator}) {
    for (final List<String> row in csvRows(text, separator: separator)) {
      return <String>[for (final String cell in row) cell.trim()];
    }
    return <String>[];
  }

  /// Every row of the CSV [text], each a list of its cells as they are in
  /// the file (quotes removed, spaces kept), read one row at a time: for a
  /// preview table. Empty lines are left out. [separator] is as in
  /// [BarcodeItems.csv].
  ///
  /// ```dart
  /// BarcodeItems.csvRows('a,"b ""c"""\n1,2').toList(); // [[a, b "c"], [1, 2]]
  /// ```
  static Iterable<List<String>> csvRows(
    String text, {
    String? separator,
  }) sync* {
    final String csv = _withoutBom(text);
    final String sep = separator ?? _detectSeparator(csv);
    if (sep.length != 1 || sep == '"' || sep == '\n' || sep == '\r') {
      throw ArgumentError.value(
        separator,
        'separator',
        'must be one character other than a quote or a line break',
      );
    }
    final int sepUnit = sep.codeUnitAt(0);
    List<String> row = <String>[];
    final StringBuffer cell = StringBuffer();
    bool quoted = false;
    bool cellStarted = false;
    int i = 0;
    while (i < csv.length) {
      final int c = csv.codeUnitAt(i);
      if (quoted) {
        if (c == _quote) {
          if (i + 1 < csv.length && csv.codeUnitAt(i + 1) == _quote) {
            cell.writeCharCode(_quote);
            i += 2;
            continue;
          }
          quoted = false;
        } else {
          cell.writeCharCode(c);
        }
        i++;
        continue;
      }
      if (c == _quote && cell.isEmpty) {
        quoted = true;
        cellStarted = true;
      } else if (c == sepUnit) {
        row.add(cell.toString());
        cell.clear();
        cellStarted = true;
      } else if (c == _cr || c == _lf) {
        if (c == _cr && i + 1 < csv.length && csv.codeUnitAt(i + 1) == _lf) {
          i++;
        }
        if (cellStarted || cell.isNotEmpty || row.isNotEmpty) {
          row.add(cell.toString());
          yield row;
        }
        row = <String>[];
        cell.clear();
        cellStarted = false;
      } else {
        cell.writeCharCode(c);
      }
      i++;
    }
    if (cellStarted || cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      yield row;
    }
  }

  static const int _quote = 0x22;
  static const int _cr = 0x0D;
  static const int _lf = 0x0A;

  static final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

  static String _withoutBom(String text) =>
      text.startsWith('﻿') ? text.substring(1) : text;

  /// The one of `,`, `;` and tab that the first row of [csv] has most of,
  /// outside quotes; `,` if it has none.
  static String _detectSeparator(String csv) {
    final Map<String, int> counts = <String, int>{',': 0, ';': 0, '\t': 0};
    bool quoted = false;
    for (int i = 0; i < csv.length; i++) {
      final String c = csv[i];
      if (c == '"') {
        quoted = !quoted;
      } else if (!quoted && (c == '\n' || c == '\r')) {
        break;
      } else if (!quoted && counts.containsKey(c)) {
        counts[c] = counts[c]! + 1;
      }
    }
    String best = ',';
    for (final MapEntry<String, int> e in counts.entries) {
      if (e.value > counts[best]!) {
        best = e.key;
      }
    }
    return best;
  }

  static List<String> _collect(Iterable<String> cells, {required bool unique}) {
    final Iterable<String> items = cells
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty);
    return unique
        ? LinkedHashSet<String>.of(items).toList(growable: false)
        : items.toList(growable: false);
  }
}

/// An item that cannot be encoded: its [index] (0 for the first), the
/// [item] and what is wrong. [BarcodeWriter.checkItems] finds it.
///
/// ```dart
/// final BarcodeItemIssue? issue = await writer.checkItems(items);
/// if (issue != null) {
///   print('Row ${issue.index + 1} (${issue.item}): ${issue.message}');
/// }
/// ```
@immutable
final class BarcodeItemIssue {
  /// Describes an item that cannot be encoded.
  const BarcodeItemIssue(this.index, this.item, this.message);

  /// The position of the item in the list, 0 for the first.
  final int index;

  /// The item.
  final String item;

  /// What is wrong, in English: `'A' at position 1: EAN-13 takes digits
  /// only`.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is BarcodeItemIssue &&
      other.index == index &&
      other.item == item &&
      other.message == message;

  @override
  int get hashCode => Object.hash(index, item, message);

  @override
  String toString() {
    final String shown = item.length > 60
        ? '${item.substring(0, 57)}...'
        : item;
    return 'Item $index ("$shown"): $message';
  }
}

/// The first of [items] that [writer] cannot encode; see
/// [BarcodeWriter.checkItems]. Not exported from the package.
Future<BarcodeItemIssue?> checkWriterItems(
  BarcodeWriter writer,
  Iterable<String> items, {
  required bool encodeAll,
}) async {
  final String options = (writer.zxingOptions ?? '').toLowerCase();
  final bool rules = !writer.gs1 && !options.contains('gs1');
  int index = 0;
  String? first;
  String? last;
  String? longest;
  int lastIndex = 0;
  int longestIndex = 0;
  for (final String item in items) {
    final String? problem = item.isEmpty
        ? 'is empty'
        : rules
        ? itemProblem(writer.format, item)
        : null;
    if (problem != null) {
      return BarcodeItemIssue(index, item, problem);
    }
    if (encodeAll) {
      final BarcodeItemIssue? issue = await _encodes(writer, index, item);
      if (issue != null) {
        return issue;
      }
    } else {
      first ??= item;
      last = item;
      lastIndex = index;
      if (longest == null || item.length > longest.length) {
        longest = item;
        longestIndex = index;
      }
      if (index % 20000 == 19999) {
        // Let the UI draw a frame now and then on a long list.
        await Future<void>.delayed(Duration.zero);
      }
    }
    index++;
  }
  if (encodeAll || first == null) {
    return null;
  }
  final SplayTreeMap<int, String> samples = SplayTreeMap<int, String>.of(
    <int, String>{0: first, longestIndex: longest!, lastIndex: last!},
  );
  for (final MapEntry<int, String> s in samples.entries) {
    final BarcodeItemIssue? issue = await _encodes(writer, s.key, s.value);
    if (issue != null) {
      return issue;
    }
  }
  return null;
}

Future<BarcodeItemIssue?> _encodes(
  BarcodeWriter writer,
  int index,
  String item,
) async {
  try {
    await writer.encode(item);
    return null;
  } on BarcodeWriteException catch (e) {
    return BarcodeItemIssue(index, item, e.message);
  }
}

/// What makes [item] unfit for [format] by the format's simple rules
/// (characters, length, check digit), or `null` if they pass. A pass does
/// not promise the item encodes: capacity and the rarer rules are left to
/// the engine. Never rejects an item the engine takes.
String? itemProblem(BarcodeFormat format, String item) {
  final String name = format.displayName;
  switch (format) {
    case BarcodeFormat.eanUpc || BarcodeFormat.ean13:
      return _eanProblem(name, item, max: 13, checked: true);
    case BarcodeFormat.ean8:
      return _eanProblem(name, item, max: 8, checked: true);
    case BarcodeFormat.upcA:
      return _eanProblem(name, item, max: 12, checked: true);
    case BarcodeFormat.upcE:
      return _eanProblem(name, item, max: 8, checked: false);
    case BarcodeFormat.dataBar ||
        BarcodeFormat.dataBarOmni ||
        BarcodeFormat.dataBarStacked ||
        BarcodeFormat.dataBarStackedOmni ||
        BarcodeFormat.dataBarLimited:
      final String? problem =
          _charsProblem(name, item, _isDigit, 'digits only') ??
          _lengthProblem(name, item, 14) ??
          _checkProblem(item, 14);
      if (problem != null || format != BarcodeFormat.dataBarLimited) {
        return problem;
      }
      final String body = item.length == 14 ? item.substring(0, 13) : item;
      return int.parse(body) > 1999999999999
          ? '$name takes a GTIN starting with 0 or 1'
          : null;
    case BarcodeFormat.itf:
      return _charsProblem(name, item, _isDigit, 'digits only');
    case BarcodeFormat.code32:
      return _charsProblem(name, item, _isDigit, 'digits only') ??
          _lengthProblem(name, item, 8);
    case BarcodeFormat.pzn:
      return _charsProblem(name, item, _isDigit, 'digits only') ??
          _lengthProblem(name, item, 8);
    case BarcodeFormat.aztecRune:
      return _charsProblem(name, item, _isDigit, 'digits only') ??
          (item.length <= 18 && int.parse(item) > 255
              ? '$name takes a number from 0 to 255'
              : null);
    case BarcodeFormat.code39 || BarcodeFormat.code39Standard:
      return _charsProblem(
        name,
        item,
        (int c) => _code39.contains(String.fromCharCode(c).toUpperCase()),
        r'letters, digits, space and - . $ / + % only',
      );
    case BarcodeFormat.code39Extended ||
        BarcodeFormat.code93 ||
        BarcodeFormat.telepen:
      return _charsProblem(name, item, (int c) => c < 0x80, 'ASCII only');
    case BarcodeFormat.code128:
      return _charsProblem(
        name,
        item,
        (int c) => c <= 0xFF,
        'ASCII and Latin-1 only',
      );
    case BarcodeFormat.codabar:
      return _codabarProblem(name, item);
    default:
      return null;
  }
}

bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

const String _code39 = r'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-. $/+%';

String? _charsProblem(
  String name,
  String item,
  bool Function(int c) allowed,
  String what, {
  int offset = 0,
}) {
  for (int i = 0; i < item.length; i++) {
    if (!allowed(item.codeUnitAt(i))) {
      final int before = item.substring(0, i).runes.length;
      final int rune = item.runes.elementAt(before);
      return "'${String.fromCharCode(rune)}' at position "
          '${offset + before + 1}: $name takes $what';
    }
  }
  return null;
}

String? _lengthProblem(String name, String digits, int max) =>
    digits.length > max
    ? '${digits.length} digits: $name takes up to $max'
    : null;

String? _checkProblem(String digits, int full) {
  if (digits.length != full || CheckDigit.gs1.isValid(digits)) {
    return null;
  }
  final String expected = CheckDigit.gs1.of(digits.substring(0, full - 1));
  return "wrong check digit '${digits[full - 1]}', expecting '$expected'";
}

/// EAN and UPC: digits, an add-on of up to 5 digits after `+` or a space.
String? _eanProblem(
  String name,
  String item, {
  required int max,
  required bool checked,
}) {
  final String? chars = _charsProblem(
    name,
    item,
    (int c) => _isDigit(c) || c == 0x2B || c == 0x20,
    'digits only, and an add-on after + or a space',
  );
  if (chars != null) {
    return chars;
  }
  final int split = item.indexOf(RegExp('[+ ]'));
  final String main = split < 0 ? item : item.substring(0, split);
  final String? addOn = split < 0 ? null : item.substring(split + 1);
  if (addOn != null && !RegExp(r'^\d{1,5}$').hasMatch(addOn)) {
    return '$name takes an add-on of 2 or 5 digits';
  }
  return _lengthProblem(name, main, max) ??
      (checked ? _checkProblem(main, max) : null);
}

String? _codabarProblem(String name, String item) {
  bool isStartStop(int c) =>
      (c >= 0x41 && c <= 0x44) || (c >= 0x61 && c <= 0x64);
  if (!isStartStop(item.codeUnitAt(0))) {
    return '$name begins with A, B, C or D';
  }
  if (item.length < 2 || !isStartStop(item.codeUnitAt(item.length - 1))) {
    return '$name ends with A, B, C or D';
  }
  return _charsProblem(
    name,
    item.substring(1, item.length - 1),
    (int c) => _isDigit(c) || r'-$:/.+'.codeUnits.contains(c),
    r'digits and - $ : / . + between the start and stop letters',
    offset: 1,
  );
}
