import 'dart:collection';

import 'check_digit.dart';

/// Numbered items made from a pattern, one when it is asked for: `AA000001`,
/// `AA000002` and on, for a label sheet or a batch export.
///
/// The [pattern] is text with one placeholder for the number: `{n}`, or
/// `{n:6}` for a number padded with zeros to 6 digits. Write `{{` and `}}`
/// for a literal brace. A number wider than the padding keeps all its
/// digits: `{n:3}` gives `999`, then `1000`.
///
/// ```dart
/// final SerialItems items = SerialItems('AA{n:6}', count: 10000);
/// print(items.first); // AA000001
/// print(items[9999]); // AA010000
/// print(items.length); // 10000, without making the items
///
/// final Uint8List pdf = await sheet.pdf(items);
/// ```
///
/// [checkDigit] appends a check character to each item, computed from the
/// whole item: `SerialItems('400638{n:6}', start: 133393, count: 100,
/// checkDigit: CheckDigit.gs1)` gives GTIN-13s from `4006381333931`.
///
/// It is a read-only [List]: [length], `items[i]` and `elementAt` take the
/// same time for 10 or 10 million items, and nothing is kept in memory.
/// Numbers go up to 2^53 - 1 (9 007 199 254 740 991, 16 digits), the
/// largest whole number exact on the web; put longer fixed parts, such as
/// a company prefix, in the pattern's text.
final class SerialItems extends ListBase<String> {
  /// Creates [count] items from [pattern], numbered from [start] by [step]
  /// (a negative [step] counts down).
  ///
  /// Throws [ArgumentError] if [pattern] has no placeholder or more than
  /// one, an unknown placeholder or a lone `{` or `}`; if [count] is not
  /// positive or [step] is 0; if a number would be negative or above
  /// 2^53 - 1; or if the text of the pattern has a character [checkDigit]
  /// does not take (anything but digits for [CheckDigit.gs1] and
  /// [CheckDigit.luhn]).
  factory SerialItems(
    String pattern, {
    required int count,
    int start = 1,
    int step = 1,
    CheckDigit? checkDigit,
  }) {
    final (String prefix, int width, String suffix) = _parse(pattern);
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'must be at least 1');
    }
    if (step == 0) {
      throw ArgumentError.value(step, 'step', 'cannot be 0');
    }
    if (start < 0 || start > maxNumber) {
      throw ArgumentError.value(start, 'start', 'must be from 0 to $maxNumber');
    }
    final int room = step > 0 ? (maxNumber - start) ~/ step : start ~/ -step;
    if (count - 1 > room) {
      throw ArgumentError(
        step > 0
            ? '$count items from $start by $step go above $maxNumber'
            : '$count items from $start by $step go below 0',
      );
    }
    if (checkDigit != null) {
      // The number is digits; the rest of the pattern must suit the check.
      checkDigit.of('$prefix$suffix'.isEmpty ? '0' : '$prefix$suffix');
    }
    return SerialItems._(
      pattern,
      prefix,
      width,
      suffix,
      start,
      count,
      step,
      checkDigit,
    );
  }

  SerialItems._(
    this.pattern,
    this._prefix,
    this._width,
    this._suffix,
    this.start,
    this.count,
    this.step,
    this.checkDigit,
  );

  /// The largest number an item can have: 2^53 - 1, the largest whole
  /// number exact on every platform, the web included.
  static const int maxNumber = 9007199254740991;

  /// The pattern, such as `AA{n:6}`.
  final String pattern;

  /// The number of the first item.
  final int start;

  /// How many items there are; the same as [length].
  final int count;

  /// What each number adds to the one before.
  final int step;

  /// The check character appended to each item, or `null` for none.
  final CheckDigit? checkDigit;

  final String _prefix;
  final int _width;
  final String _suffix;

  /// The number of item [index].
  ///
  /// Throws [RangeError] if [index] is not in `0..length - 1`.
  int numberAt(int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return start + index * step;
  }

  @override
  int get length => count;

  @override
  set length(int newLength) => _readOnly();

  @override
  String operator [](int index) {
    final String number = numberAt(index).toString().padLeft(_width, '0');
    final String item = '$_prefix$number$_suffix';
    return checkDigit?.append(item) ?? item;
  }

  @override
  void operator []=(int index, String value) => _readOnly();

  @override
  String toString() =>
      'SerialItems($pattern, $count from $start'
      '${step == 1 ? '' : ' by $step'}'
      '${checkDigit == null ? '' : ', ${checkDigit!.name}'})';

  static Never _readOnly() =>
      throw UnsupportedError('SerialItems cannot be changed');

  /// The text before and after the placeholder of [pattern] and its width
  /// (0 for none).
  static (String, int, String) _parse(String pattern) {
    final StringBuffer text = StringBuffer();
    String? prefix;
    int width = 0;
    int i = 0;
    while (i < pattern.length) {
      final String c = pattern[i];
      final String? next = i + 1 < pattern.length ? pattern[i + 1] : null;
      if ((c == '{' || c == '}') && next == c) {
        text.write(c);
        i += 2;
        continue;
      }
      if (c == '}') {
        throw ArgumentError.value(
          pattern,
          'pattern',
          "has a lone '}' at position ${i + 1}; write }} for a literal }",
        );
      }
      if (c != '{') {
        text.write(c);
        i++;
        continue;
      }
      final Match? m = _placeholder.matchAsPrefix(pattern, i);
      if (m == null) {
        throw ArgumentError.value(
          pattern,
          'pattern',
          'has an unknown placeholder at position ${i + 1}; write {n} or '
              '{n:6} for the number, {{ for a literal {',
        );
      }
      if (prefix != null) {
        throw ArgumentError.value(
          pattern,
          'pattern',
          'has more than one placeholder; write {{n}} for a literal {n}',
        );
      }
      if (m[1] != null) {
        width = int.parse(m[1]!);
        if (width < 1 || width > 64) {
          throw ArgumentError.value(
            pattern,
            'pattern',
            'pads the number to $width digits; give 1 to 64',
          );
        }
      }
      prefix = text.toString();
      text.clear();
      i = m.end;
    }
    if (prefix == null) {
      throw ArgumentError.value(
        pattern,
        'pattern',
        'has no placeholder; write {n} or {n:6} where the number goes',
      );
    }
    return (prefix, width, text.toString());
  }

  static final RegExp _placeholder = RegExp(r'\{n(?::(\d+))?\}');
}
