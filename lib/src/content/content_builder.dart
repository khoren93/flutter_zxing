import 'dart:convert';

import 'barcode_content.dart';
import 'gs1.dart';

// Building payloads: the reverse of content_parser.dart. Every builder
// writes what the parser reads back, so that
// `parseText(content.toPayload()) == content` for values in normal form.

/// Throws the problems [validate] found.
void _check(List<ContentIssue> issues) {
  if (issues.isNotEmpty) {
    throw ArgumentError(issues.join('; '));
  }
}

// --- Text, binary ----------------------------------------------------------------

/// [TextContent.toPayload].
String buildText(TextContent c) {
  _check(validateText(c));
  return c.text;
}

/// [TextContent.validate].
List<ContentIssue> validateText(TextContent c) => <ContentIssue>[
  if (c.text.isEmpty) const ContentIssue('text', 'Text is empty'),
];

/// [BinaryContent.validate].
List<ContentIssue> validateBinary(BinaryContent c) => <ContentIssue>[
  if (c.bytes.isEmpty) const ContentIssue('bytes', 'No bytes'),
];

// --- Web addresses ---------------------------------------------------------------

/// [url] with `https://` if it has no scheme (`example.com/a`).
Uri _withScheme(Uri url) => url.hasScheme ? url : Uri.parse('https://$url');

/// [UrlContent.toPayload].
String buildUrl(UrlContent c) {
  _check(validateUrl(c));
  final String url = _withScheme(c.url).toString();
  final String? title = _orNull(c.title);
  if (title == null) {
    return url;
  }
  return 'MEBKM:TITLE:${_escape(title, r'\;:')};'
      'URL:${_escape(url, r'\;')};;';
}

/// [UrlContent.validate].
List<ContentIssue> validateUrl(UrlContent c) {
  final Uri url = _withScheme(c.url);
  return <ContentIssue>[
    if (url.scheme != 'http' && url.scheme != 'https')
      const ContentIssue('url', 'Only http and https addresses are web links')
    else if (url.host.isEmpty)
      const ContentIssue('url', 'Address has no host'),
  ];
}

// --- Wi-Fi -----------------------------------------------------------------------

/// [WifiContent.toPayload].
String buildWifi(WifiContent c) {
  _check(validateWifi(c));
  const String special = r'\;,:"';
  final StringBuffer out = StringBuffer('WIFI:');
  out.write(switch (c.security) {
    WifiSecurity.none => 'T:nopass;',
    WifiSecurity.wep => 'T:WEP;',
    _ => 'T:WPA;',
  });
  out.write('S:${_escape(c.ssid, special)};');
  if (c.security != WifiSecurity.none) {
    out.write('P:${_escape(c.password!, special)};');
  }
  if (c.hidden) {
    out.write('H:true;');
  }
  out.write(';');
  return out.toString();
}

/// [WifiContent.validate].
List<ContentIssue> validateWifi(WifiContent c) => <ContentIssue>[
  if (c.ssid.isEmpty)
    const ContentIssue('ssid', 'Network name is empty')
  else if (utf8.encode(c.ssid).length > 32)
    const ContentIssue('ssid', 'Network name is longer than 32 bytes'),
  if (c.security == WifiSecurity.enterprise)
    const ContentIssue(
      'security',
      'Enterprise (EAP) networks are not supported',
    )
  else if (c.security == WifiSecurity.unknown)
    const ContentIssue('security', 'Security type is unknown')
  else if (c.security != WifiSecurity.none && (c.password ?? '').isEmpty)
    const ContentIssue('password', 'Password is empty'),
];

// --- E-mail, phone, SMS ----------------------------------------------------------

final RegExp _emailAddress = RegExp(r'^[^@\s,]+@[^@\s,]+$');

List<String> _addresses(String value) => value
    .split(',')
    .map((String a) => a.trim())
    .where((String a) => a.isNotEmpty)
    .toList();

/// [EmailContent.toPayload].
String buildEmail(EmailContent c) {
  _check(validateEmail(c));
  final String to = _addresses(
    c.address,
  ).map((String a) => Uri.encodeComponent(a).replaceAll('%40', '@')).join(',');
  final String? subject = _orNull(c.subject);
  final String? body = _orNull(c.body);
  return <String>[
    'mailto:$to',
    if (subject != null || body != null) '?',
    <String>[
      if (subject != null) 'subject=${Uri.encodeComponent(subject)}',
      if (body != null) 'body=${Uri.encodeComponent(body)}',
    ].join('&'),
  ].join();
}

/// [EmailContent.validate].
List<ContentIssue> validateEmail(EmailContent c) {
  final List<String> to = _addresses(c.address);
  return <ContentIssue>[
    for (final String a in to)
      if (!_emailAddress.hasMatch(a))
        ContentIssue('address', 'Not an e-mail address: $a'),
    if (to.isEmpty && _orNull(c.subject) == null && _orNull(c.body) == null)
      const ContentIssue('address', 'Add an address, a subject or a body'),
  ];
}

final RegExp _phoneCharacters = RegExp(r'^\+?[\d*#\s\-.()/]+$');
final RegExp _visualSeparators = RegExp(r'[\s\-.()/]');

/// [number] without visual separators: `+1 (212) 555-1234` →
/// `+12125551234`.
String _dialable(String number) =>
    number.trim().replaceAll(_visualSeparators, '');

List<ContentIssue> _validateNumber(String field, String number) {
  final String n = number.trim();
  if (n.isEmpty) {
    return <ContentIssue>[ContentIssue(field, 'Phone number is empty')];
  }
  if (!_phoneCharacters.hasMatch(n) || !n.contains(RegExp(r'\d'))) {
    return <ContentIssue>[ContentIssue(field, 'Not a phone number: $n')];
  }
  return const <ContentIssue>[];
}

/// [PhoneContent.toPayload].
String buildPhone(PhoneContent c) {
  _check(validatePhone(c));
  final String scheme = switch (c.type) {
    CallType.voice => 'tel',
    CallType.faceTime => 'facetime',
    CallType.faceTimeAudio => 'facetime-audio',
  };
  final String number = c.number.trim();
  // FaceTime also calls Apple accounts by e-mail address.
  final String target = _emailAddress.hasMatch(number)
      ? number
      : _dialable(number).replaceAll('#', '%23');
  return '$scheme:$target';
}

/// [PhoneContent.validate].
List<ContentIssue> validatePhone(PhoneContent c) =>
    c.type != CallType.voice && _emailAddress.hasMatch(c.number.trim())
    ? const <ContentIssue>[]
    : _validateNumber('number', c.number);

/// [SmsContent.toPayload].
String buildSms(SmsContent c) {
  _check(validateSms(c));
  final String numbers = c.number
      .split(',')
      .map(_dialable)
      .where((String n) => n.isNotEmpty)
      .join(',');
  final String? message = _orNull(c.message?.trim());
  return message == null ? 'SMSTO:$numbers' : 'SMSTO:$numbers:$message';
}

/// [SmsContent.validate].
List<ContentIssue> validateSms(SmsContent c) {
  final List<String> numbers = c.number
      .split(',')
      .where((String n) => n.trim().isNotEmpty)
      .toList();
  if (numbers.isEmpty) {
    return const <ContentIssue>[
      ContentIssue('number', 'Phone number is empty'),
    ];
  }
  return <ContentIssue>[
    for (final String n in numbers) ..._validateNumber('number', n),
  ];
}

// --- Geo -------------------------------------------------------------------------

/// [v] as a decimal number, the same on native and web: never in
/// exponent form (`1e-7`), whole numbers without `.0`.
String _decimal(double v) {
  String s = v.toString();
  if (s.contains('e')) {
    s = v.toStringAsFixed(12);
  }
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
  return s == '-0' ? '0' : s;
}

/// [GeoContent.toPayload].
String buildGeo(GeoContent c) {
  _check(validateGeo(c));
  final double? altitude = c.altitude;
  final String? query = _orNull(c.query);
  return 'geo:${_decimal(c.latitude)},${_decimal(c.longitude)}'
      '${altitude == null ? '' : ',${_decimal(altitude)}'}'
      '${query == null ? '' : '?q=${Uri.encodeQueryComponent(query)}'}';
}

/// [GeoContent.validate].
List<ContentIssue> validateGeo(GeoContent c) => <ContentIssue>[
  if (!c.latitude.isFinite || c.latitude.abs() > 90)
    const ContentIssue('latitude', 'Latitude must be between -90 and 90'),
  if (!c.longitude.isFinite || c.longitude.abs() > 180)
    const ContentIssue('longitude', 'Longitude must be between -180 and 180'),
  if (c.altitude case final double a when !a.isFinite)
    const ContentIssue('altitude', 'Altitude must be a number'),
];

// --- Contacts --------------------------------------------------------------------

/// [ContactContent.toPayload].
String buildContact(ContactContent c, ContactFormat format) {
  _check(validateContact(c));
  return switch (format) {
    ContactFormat.vCard => _vCard(c),
    ContactFormat.meCard => _meCard(c),
  };
}

/// [ContactContent.validate].
List<ContentIssue> validateContact(ContactContent c) {
  final bool empty =
      _orNull(c.name?.trim()) == null &&
      _orNull(c.organization?.trim()) == null &&
      _orNull(c.title?.trim()) == null &&
      _orNull(c.note?.trim()) == null &&
      c.birthday == null &&
      _notEmpty(c.phones).isEmpty &&
      _notEmpty(c.emails).isEmpty &&
      c.urls.isEmpty &&
      _notEmpty(c.addresses).isEmpty;
  return <ContentIssue>[
    if (empty)
      const ContentIssue('name', 'Add a name, a phone, an e-mail or more'),
    for (final String e in _notEmpty(c.emails))
      if (!_emailAddress.hasMatch(e))
        ContentIssue('emails', 'Not an e-mail address: $e'),
    if (c.birthday case final DateTime b when b.year < 1 || b.year > 9999)
      const ContentIssue('birthday', 'Year must be between 1 and 9999'),
  ];
}

List<String> _notEmpty(List<String> values) => <String>[
  for (final String v in values)
    if (v.trim().isNotEmpty) v.trim(),
];

/// [name] split at its last space into (family, given).
(String, String) _splitName(String name) {
  final int space = name.lastIndexOf(' ');
  return space < 0
      ? (name, '')
      : (name.substring(space + 1), name.substring(0, space).trim());
}

String _vCard(ContactContent c) {
  String text(String value) => _escapeText(value.trim());
  final String? name = _orNull(c.name?.trim());
  final (String family, String given) = name == null
      ? ('', '')
      : _splitName(name);
  final DateTime? birthday = c.birthday;
  return <String>[
    'BEGIN:VCARD',
    'VERSION:3.0',
    'N:${text(family)};${text(given)};;;',
    'FN:${name == null ? '' : text(name)}',
    if (_orNull(c.organization?.trim()) case final String org)
      'ORG:${text(org)}',
    if (_orNull(c.title?.trim()) case final String title)
      'TITLE:${text(title)}',
    for (final String phone in _notEmpty(c.phones)) 'TEL:${text(phone)}',
    for (final String email in _notEmpty(c.emails)) 'EMAIL:${text(email)}',
    for (final Uri url in c.urls) 'URL:${_withScheme(url)}',
    for (final String address in _notEmpty(c.addresses))
      'ADR:;;${text(address)};;;;',
    if (_orNull(c.note?.trim()) case final String note) 'NOTE:${text(note)}',
    if (birthday != null)
      'BDAY:${_year(birthday)}-${_two(birthday.month)}-${_two(birthday.day)}',
    'END:VCARD',
  ].join('\n');
}

String _meCard(ContactContent c) {
  const String special = r'\;:,';
  String field(String key, String value) => '$key:${_escape(value, special)};';
  final StringBuffer out = StringBuffer('MECARD:');
  if (_orNull(c.name?.trim()) case final String name) {
    final (String family, String given) = _splitName(name);
    out.write(
      'N:${_escape(family, special)}'
      '${given.isEmpty ? '' : ',${_escape(given, special)}'};',
    );
  }
  if (_orNull(c.organization?.trim()) case final String org) {
    out.write(field('ORG', org));
  }
  if (_orNull(c.title?.trim()) case final String title) {
    out.write(field('TITLE', title));
  }
  for (final String phone in _notEmpty(c.phones)) {
    out.write(field('TEL', phone));
  }
  for (final String email in _notEmpty(c.emails)) {
    out.write(field('EMAIL', email));
  }
  for (final Uri url in c.urls) {
    // Readers split a field at its first colon only: the URL keeps its own.
    out.write('URL:${_escape(_withScheme(url).toString(), r'\;')};');
  }
  for (final String address in _notEmpty(c.addresses)) {
    out.write(field('ADR', address));
  }
  if (_orNull(c.note?.trim()) case final String note) {
    out.write(field('NOTE', note.replaceAll('\r\n', '\n')));
  }
  if (c.birthday case final DateTime b) {
    out.write('BDAY:${_year(b)}${_two(b.month)}${_two(b.day)};');
  }
  out.write(';');
  return out.toString();
}

// --- Events ----------------------------------------------------------------------

/// [EventContent.toPayload].
String buildEvent(EventContent c) {
  _check(validateEvent(c));
  String text(String value) => _escapeText(value.trim());
  String time(String property, DateTime t) => c.allDay
      ? '$property;VALUE=DATE:${_date(t)}'
      : '$property:${_date(t)}T${_two(t.hour)}${_two(t.minute)}'
            '${_two(t.second)}${t.isUtc ? 'Z' : ''}';
  final DateTime? end = c.end;
  return <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    if (c.summary.trim().isNotEmpty) 'SUMMARY:${text(c.summary)}',
    time('DTSTART', c.start),
    if (end != null) time('DTEND', end),
    if (_orNull(c.location?.trim()) case final String location)
      'LOCATION:${text(location)}',
    if (_orNull(c.description?.trim()) case final String description)
      'DESCRIPTION:${text(description)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\n');
}

/// [EventContent.validate].
List<ContentIssue> validateEvent(EventContent c) {
  final DateTime? end = c.end;
  bool outOfRange(DateTime t) => t.year < 0 || t.year > 9999;
  return <ContentIssue>[
    if (outOfRange(c.start))
      const ContentIssue('start', 'Year must be between 0 and 9999'),
    if (end != null && outOfRange(end))
      const ContentIssue('end', 'Year must be between 0 and 9999')
    else if (end != null && end.isBefore(c.start))
      const ContentIssue('end', 'Event ends before it starts'),
  ];
}

String _date(DateTime t) => '${_year(t)}${_two(t.month)}${_two(t.day)}';

// --- GS1 -------------------------------------------------------------------------

/// [Gs1Content.toPayload].
String buildGs1(Gs1Content c) {
  _check(validateGs1(c));
  return c.elements.entries
      .map((MapEntry<String, String> e) => '(${e.key})${e.value}')
      .join();
}

/// [Gs1Content.validate].
List<ContentIssue> validateGs1(Gs1Content c) => <ContentIssue>[
  if (c.elements.isEmpty) const ContentIssue('elements', 'No elements'),
  for (final MapEntry<String, String> e in c.elements.entries)
    if (gs1ElementIssue(e.key, e.value) case final String message)
      ContentIssue('elements', message),
];

// --- Shared helpers --------------------------------------------------------------

String? _orNull(String? value) => value == null || value.isEmpty ? null : value;

String _two(int v) => v.toString().padLeft(2, '0');

String _year(DateTime t) => t.year.toString().padLeft(4, '0');

/// Puts a backslash before each of the [special] characters in [value]
/// (MECARD, MEBKM and WIFI fields).
String _escape(String value, String special) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < value.length; i++) {
    final String c = value[i];
    if (special.contains(c)) {
      out.write(r'\');
    }
    out.write(c);
  }
  return out.toString();
}

/// A vCard or iCalendar text value: `\`, `;` and `,` escaped, line breaks
/// as `\n` (RFC 6350 3.4, RFC 5545 3.3.11).
String _escapeText(String value) => _escape(
  value.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
  r'\;,',
).replaceAll('\n', r'\n');
