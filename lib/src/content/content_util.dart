import 'barcode_content.dart';

// Helpers shared by the parsers and builders of the content kinds.

/// Throws the problems `validate` found, as `toPayload` documents.
void checkIssues(List<ContentIssue> issues) {
  if (issues.isNotEmpty) {
    throw ArgumentError(issues.join('; '));
  }
}

/// `null` for `null` and empty strings.
String? orNull(String? value) => value == null || value.isEmpty ? null : value;

/// Percent-decodes [value]; malformed escapes stay as they are.
String decodeComponent(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  } on FormatException {
    return value;
  }
}

/// The `key=value` pairs after the `?` of [query], keys lower case, values
/// percent-decoded. A key that occurs twice keeps its first value.
Map<String, String> queryParameters(String query) {
  final Map<String, String> params = <String, String>{};
  for (final String pair in query.split('&')) {
    if (pair.isEmpty) {
      continue;
    }
    final int eq = pair.indexOf('=');
    final String key = (eq < 0 ? pair : pair.substring(0, eq)).toLowerCase();
    params.putIfAbsent(
      key,
      () => eq < 0 ? '' : decodeComponent(pair.substring(eq + 1)),
    );
  }
  return params;
}

/// Whether [text] starts with [prefix], ignoring case.
bool hasPrefix(String text, String prefix) =>
    text.length >= prefix.length &&
    text.substring(0, prefix.length).toUpperCase() == prefix;

final RegExp _textNumber = RegExp(r'^\+?[\d*#\s\-.()/]+$');

// RFC 3966 §5.1.5: `;ext=` after the number. The pauses `,` and `;`
// (wait) are not in the RFC, but phones dial them, and conference numbers
// use them.
final RegExp _callNumber = RegExp(
  r'^\+?[\d*#\s\-.()/,;]+(?:;ext=[\d\-.()]+)?$',
  caseSensitive: false,
);

final RegExp _digit = RegExp(r'\d');

/// Whether [number] (trimmed) is a phone number [PhoneContent] and
/// [SmsContent] can build: digits, `*`, `#`, a leading `+` and visual
/// separators. With [call], also the pauses `,` and `;` and an extension
/// `;ext=` (RFC 3966 §5.1.5); letters (`1-800-FLOWERS`) never.
bool isPhoneNumber(String number, {bool call = false}) =>
    (call ? _callNumber : _textNumber).hasMatch(number) &&
    number.contains(_digit);

/// One e-mail address.
final RegExp emailAddress = RegExp(r'^[^\s@,]+@[^\s@,]+$');
