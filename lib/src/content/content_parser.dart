import 'dart:convert';

import '../barcode/barcode.dart';
import 'barcode_content.dart';
import 'gs1.dart';

/// [BarcodeContent.parse].
BarcodeContent parseBarcodeContent(Barcode barcode) {
  switch (barcode.contentType) {
    case BarcodeContentType.gs1:
      // The bytes are the raw element strings, with GS separators: they
      // split without ambiguity, unlike the human readable text.
      final Map<String, String>? elements =
          (barcode.bytes.isEmpty
              ? null
              : parseGs1(latin1.decode(barcode.bytes, allowInvalid: true))) ??
          parseGs1(barcode.text);
      return elements == null
          ? TextContent(barcode.text)
          : Gs1Content(elements);
    case BarcodeContentType.binary:
      return BinaryContent(barcode.bytes);
    case BarcodeContentType.iso15434:
    case BarcodeContentType.unknownEci:
      return TextContent(barcode.text);
    case BarcodeContentType.text:
    case BarcodeContentType.mixed:
      return parseTextContent(barcode.text);
  }
}

/// [BarcodeContent.parseText].
BarcodeContent parseTextContent(String text) {
  final String t = text.trim();
  final String head = (t.length > 16 ? t.substring(0, 16) : t).toUpperCase();
  final BarcodeContent? content;
  if (head.startsWith('WIFI:')) {
    content = _wifi(t.substring(5));
  } else if (head.startsWith('MECARD:')) {
    content = _meCard(t.substring(7));
  } else if (head.startsWith('BEGIN:VCARD')) {
    content = _vCard(t);
  } else if (head.startsWith('BEGIN:VEVENT') ||
      head.startsWith('BEGIN:VCALENDAR')) {
    content = _vEvent(t);
  } else if (head.startsWith('MEBKM:')) {
    content = _meBookmark(t.substring(6));
  } else if (head.startsWith('URLTO:')) {
    content = _urlTo(t.substring(6));
  } else if (head.startsWith('MAILTO:')) {
    content = _mailto(t.substring(7));
  } else if (head.startsWith('MATMSG:')) {
    content = _matmsg(t.substring(7));
  } else if (head.startsWith('SMTP:')) {
    content = _smtp(t.substring(5));
  } else if (head.startsWith('TEL:')) {
    content = _tel(t.substring(4));
  } else if (head.startsWith('SMSTO:') || head.startsWith('MMSTO:')) {
    content = _smsTo(t.substring(6));
  } else if (head.startsWith('SMS:') || head.startsWith('MMS:')) {
    content = _sms(t.substring(4));
  } else if (head.startsWith('GEO:')) {
    content = _geo(t.substring(4));
  } else {
    content = _webAddress(t);
  }
  return content ?? TextContent(text);
}

// --- Web addresses -----------------------------------------------------------

final RegExp _whitespace = RegExp(r'\s');
final RegExp _httpScheme = RegExp(r'^https?://', caseSensitive: false);
final RegExp _anyScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*:');

/// A whole payload that is a web address: `http(s)://…` or `www.…`.
/// Anything with whitespace is text that merely starts with an address.
UrlContent? _webAddress(String t) {
  if (t.isEmpty || t.contains(_whitespace)) {
    return null;
  }
  if (_httpScheme.hasMatch(t)) {
    final Uri? url = Uri.tryParse(t);
    return url != null && url.host.isNotEmpty ? UrlContent(url) : null;
  }
  if (t.length > 4 && t.substring(0, 4).toLowerCase() == 'www.') {
    final Uri? url = Uri.tryParse('https://$t');
    return url != null && url.host.contains('.') ? UrlContent(url) : null;
  }
  return null;
}

/// A field known to hold an address (vCard URL, MEBKM): any scheme, and a
/// bare domain gets `https://`.
Uri? _fieldUrl(String value) {
  final String v = value.trim();
  if (v.isEmpty || v.contains(_whitespace)) {
    return null;
  }
  if (_anyScheme.hasMatch(v) && !_hostWithPort.hasMatch(v)) {
    return Uri.tryParse(v);
  }
  final Uri? url = Uri.tryParse('https://$v');
  return url != null && url.host.contains('.') ? url : null;
}

/// `example.com:8080/…` looks like a scheme to [_anyScheme].
final RegExp _hostWithPort = RegExp(r'^[^/:]+\.[^/:]+:\d+(?:[/?#]|$)');

UrlContent? _meBookmark(String body) {
  String? title;
  Uri? url;
  for (final (String key, String raw) in _fields(body)) {
    switch (key) {
      case 'TITLE':
        title = _orNull(_unescape(raw));
      case 'URL':
        url = _fieldUrl(_unescape(raw));
    }
  }
  return url == null ? null : UrlContent(url, title: title);
}

/// `URLTO:title:address`.
UrlContent? _urlTo(String body) {
  final int colon = body.indexOf(':');
  if (colon < 0) {
    return null;
  }
  final Uri? url = _fieldUrl(body.substring(colon + 1));
  return url == null
      ? null
      : UrlContent(url, title: _orNull(body.substring(0, colon).trim()));
}

// --- Wi-Fi ---------------------------------------------------------------------

/// `WIFI:T:WPA;S:name;P:password;H:true;;` (ZXing / Wi-Fi Alliance format).
WifiContent? _wifi(String body) {
  String? ssid;
  String? password;
  String? type;
  bool hidden = false;
  for (final (String key, String raw) in _fields(body)) {
    final String value = _unquote(_unescape(raw));
    switch (key) {
      case 'S':
        ssid = value;
      case 'P':
        password = value;
      case 'T':
        type = value.trim().toUpperCase();
      case 'H':
        hidden = value.trim().toLowerCase() == 'true';
    }
  }
  if (ssid == null || ssid.isEmpty) {
    return null;
  }
  final WifiSecurity security = switch (type) {
    null || '' =>
      password == null || password.isEmpty
          ? WifiSecurity.none
          : WifiSecurity.wpa,
    'NOPASS' || 'NONE' || 'OPEN' => WifiSecurity.none,
    'WEP' => WifiSecurity.wep,
    final String t when t.contains('EAP') => WifiSecurity.enterprise,
    final String t when t.startsWith('WPA') || t == 'SAE' => WifiSecurity.wpa,
    _ => WifiSecurity.unknown,
  };
  return WifiContent(
    ssid: ssid,
    password: security == WifiSecurity.none ? null : _orNull(password),
    security: security,
    hidden: hidden,
  );
}

String _unquote(String value) =>
    value.length >= 2 && value.startsWith('"') && value.endsWith('"')
    ? value.substring(1, value.length - 1)
    : value;

// --- Contacts ------------------------------------------------------------------

/// `MECARD:N:Owen,Sean;TEL:+12125658770;EMAIL:srowen@google.com;;`
ContactContent? _meCard(String body) {
  String? name;
  String? organization;
  String? title;
  String? note;
  final List<String> phones = <String>[];
  final List<String> emails = <String>[];
  final List<Uri> urls = <Uri>[];
  final List<String> addresses = <String>[];
  for (final (String key, String raw) in _fields(body)) {
    switch (key) {
      case 'N':
        // "Last,First" per the MeCard specification.
        final List<String> parts = _split(raw, ',');
        name = _orNull(
          <String>[...parts.skip(1), parts.first]
              .map((String p) => p.trim())
              .where((String p) => p.isNotEmpty)
              .join(' '),
        );
      case 'TEL' || 'TEL-AV':
        _addNotEmpty(phones, _unescape(raw));
      case 'EMAIL':
        _addNotEmpty(emails, _unescape(raw));
      case 'URL':
        final Uri? url = _fieldUrl(_unescape(raw));
        if (url != null) {
          urls.add(url);
        }
      case 'ADR':
        _addNotEmpty(addresses, _joinParts(_split(raw, ',')));
      case 'ORG':
        organization = _orNull(_unescape(raw).trim());
      case 'TITLE':
        title = _orNull(_unescape(raw).trim());
      case 'NOTE':
        note = _orNull(_unescape(raw).trim());
    }
  }
  return _contact(
    name: name,
    organization: organization,
    title: title,
    phones: phones,
    emails: emails,
    urls: urls,
    addresses: addresses,
    note: note,
  );
}

/// vCard 2.1, 3.0 and 4.0.
ContactContent? _vCard(String text) {
  String? formattedName;
  String? structuredName;
  String? organization;
  String? title;
  String? note;
  final List<String> phones = <String>[];
  final List<String> emails = <String>[];
  final List<Uri> urls = <Uri>[];
  final List<String> addresses = <String>[];
  for (final _Line line in _contentLines(text)) {
    switch (line.name) {
      case 'FN':
        formattedName = _orNull(line.text.trim());
      case 'N':
        // Family; Given; Additional; Prefix; Suffix.
        final List<String> p = line.parts;
        String at(int i) => i < p.length ? p[i].trim() : '';
        structuredName = _orNull(
          <String>[
            at(3),
            at(1),
            at(2),
            at(0),
            at(4),
          ].where((String s) => s.isNotEmpty).join(' '),
        );
      case 'ORG':
        organization = _orNull(_joinParts(line.parts));
      case 'TITLE':
        title = _orNull(line.text.trim());
      case 'TEL':
        _addNotEmpty(phones, _stripScheme(line.text, 'tel:'));
      case 'EMAIL':
        _addNotEmpty(emails, _stripScheme(line.text, 'mailto:'));
      case 'URL':
        final Uri? url = _fieldUrl(line.text);
        if (url != null) {
          urls.add(url);
        }
      case 'ADR':
        _addNotEmpty(addresses, _joinParts(line.parts));
      case 'NOTE':
        note = _orNull(line.text.trim());
    }
  }
  return _contact(
    name: formattedName ?? structuredName,
    organization: organization,
    title: title,
    phones: phones,
    emails: emails,
    urls: urls,
    addresses: addresses,
    note: note,
  );
}

ContactContent? _contact({
  required String? name,
  required String? organization,
  required String? title,
  required List<String> phones,
  required List<String> emails,
  required List<Uri> urls,
  required List<String> addresses,
  required String? note,
}) {
  if (name == null &&
      organization == null &&
      title == null &&
      note == null &&
      phones.isEmpty &&
      emails.isEmpty &&
      urls.isEmpty &&
      addresses.isEmpty) {
    return null;
  }
  return ContactContent(
    name: name,
    organization: organization,
    title: title,
    phones: List<String>.unmodifiable(phones),
    emails: List<String>.unmodifiable(emails),
    urls: List<Uri>.unmodifiable(urls),
    addresses: List<String>.unmodifiable(addresses),
    note: note,
  );
}

String _stripScheme(String value, String scheme) {
  final String v = value.trim();
  return v.toLowerCase().startsWith(scheme) ? v.substring(scheme.length) : v;
}

String _joinParts(List<String> parts) => parts
    .map((String p) => p.trim())
    .where((String p) => p.isNotEmpty)
    .join(', ');

void _addNotEmpty(List<String> list, String value) {
  final String v = value.trim();
  if (v.isNotEmpty) {
    list.add(v);
  }
}

// --- Events --------------------------------------------------------------------

/// `BEGIN:VEVENT … END:VEVENT`, alone or inside a VCALENDAR.
EventContent? _vEvent(String text) {
  String summary = '';
  String? location;
  String? description;
  DateTime? start;
  DateTime? end;
  Duration? duration;
  bool inEvent = false;
  for (final _Line line in _contentLines(text)) {
    final String value = line.text;
    if (line.name == 'BEGIN' && value.trim().toUpperCase() == 'VEVENT') {
      inEvent = true;
      continue;
    }
    if (!inEvent) {
      continue;
    }
    switch (line.name) {
      case 'END':
        if (value.trim().toUpperCase() == 'VEVENT') {
          inEvent = false;
        }
      case 'SUMMARY':
        summary = value.trim();
      case 'LOCATION':
        location = _orNull(value.trim());
      case 'DESCRIPTION':
        description = _orNull(value.trim());
      case 'DTSTART':
        start = _calendarTime(value);
      case 'DTEND':
        end = _calendarTime(value);
      case 'DURATION':
        duration = _calendarDuration(value);
    }
    if (!inEvent && start != null) {
      break;
    }
  }
  if (start == null) {
    return null;
  }
  return EventContent(
    summary: summary,
    start: start,
    end: end ?? (duration == null ? null : start.add(duration)),
    location: location,
    description: description,
  );
}

final RegExp _calendarTimePattern = RegExp(
  r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$',
);

/// `20261114`, `20261114T093000` (local), `20261114T093000Z` (UTC). A time
/// with a TZID parameter is read as local time.
DateTime? _calendarTime(String value) {
  final String v = value.trim();
  final RegExpMatch? m = _calendarTimePattern.firstMatch(v);
  if (m == null) {
    return DateTime.tryParse(v);
  }
  int part(int group) => int.parse(m.group(group) ?? '0');
  final int year = part(1);
  final int month = part(2);
  final int day = part(3);
  final int hour = part(4);
  final int minute = part(5);
  final int second = part(6);
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 60) {
    return null;
  }
  return m.group(7) != null
      ? DateTime.utc(year, month, day, hour, minute, second)
      : DateTime(year, month, day, hour, minute, second);
}

final RegExp _durationPattern = RegExp(
  r'^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$',
);

/// RFC 5545 durations: `PT1H30M`, `P1D`, `P2W`.
Duration? _calendarDuration(String value) {
  final RegExpMatch? m = _durationPattern.firstMatch(value.trim());
  if (m == null) {
    return null;
  }
  int part(int group) => int.parse(m.group(group) ?? '0');
  final Duration d = Duration(
    days: part(2) * 7 + part(3),
    hours: part(4),
    minutes: part(5),
    seconds: part(6),
  );
  return m.group(1) == '-' ? -d : d;
}

// --- E-mail, phone, SMS, geo ---------------------------------------------------

/// `mailto:to?subject=…&body=…` (RFC 6068).
EmailContent _mailto(String body) {
  final int q = body.indexOf('?');
  final List<String> to = <String>[
    if (_decode(q < 0 ? body : body.substring(0, q)).trim() case final String a
        when a.isNotEmpty)
      a,
  ];
  String? subject;
  String? text;
  if (q >= 0) {
    for (final String pair in body.substring(q + 1).split('&')) {
      final int eq = pair.indexOf('=');
      final String key = (eq < 0 ? pair : pair.substring(0, eq)).toLowerCase();
      final String value = eq < 0 ? '' : _decode(pair.substring(eq + 1));
      switch (key) {
        case 'to':
          _addNotEmpty(to, value);
        case 'subject':
          subject = _orNull(value);
        case 'body':
          text = _orNull(value);
      }
    }
  }
  return EmailContent(address: to.join(','), subject: subject, body: text);
}

/// `MATMSG:TO:address;SUB:subject;BODY:text;;` (NTT DoCoMo).
EmailContent? _matmsg(String body) {
  String? to;
  String? subject;
  String? text;
  for (final (String key, String raw) in _fields(body)) {
    switch (key) {
      case 'TO':
        to = _unescape(raw).trim();
      case 'SUB':
        subject = _orNull(_unescape(raw));
      case 'BODY':
        text = _orNull(_unescape(raw));
    }
  }
  return to == null && subject == null && text == null
      ? null
      : EmailContent(address: to ?? '', subject: subject, body: text);
}

/// `SMTP:address:subject:text`.
EmailContent? _smtp(String body) {
  final List<String> parts = body.split(':');
  final String to = parts.first.trim();
  if (to.isEmpty) {
    return null;
  }
  return EmailContent(
    address: to,
    subject: parts.length > 1 ? _orNull(parts[1]) : null,
    body: parts.length > 2 ? _orNull(parts.skip(2).join(':')) : null,
  );
}

PhoneContent? _tel(String body) {
  final String number = _decode(body).trim();
  return number.isEmpty ? null : PhoneContent(number);
}

/// `SMSTO:number:text`.
SmsContent? _smsTo(String body) {
  final int colon = body.indexOf(':');
  final String number = (colon < 0 ? body : body.substring(0, colon)).trim();
  if (number.isEmpty) {
    return null;
  }
  return SmsContent(
    number: _decode(number),
    message: colon < 0 ? null : _orNull(body.substring(colon + 1)),
  );
}

/// `sms:number?body=text` (RFC 5724), and the `sms:number:text` some
/// generators write.
SmsContent? _sms(String body) {
  final int q = body.indexOf('?');
  String target = q < 0 ? body : body.substring(0, q);
  String? message;
  if (q < 0) {
    final int colon = target.indexOf(':');
    if (colon >= 0) {
      message = _orNull(target.substring(colon + 1));
      target = target.substring(0, colon);
    }
  } else {
    for (final String pair in body.substring(q + 1).split('&')) {
      final int eq = pair.indexOf('=');
      if (eq > 0 && pair.substring(0, eq).toLowerCase() == 'body') {
        message = _orNull(_decode(pair.substring(eq + 1)));
      }
    }
  }
  // Parameters such as ;via= are not part of the number.
  final int semicolon = target.indexOf(';');
  final String number = _decode(
    semicolon < 0 ? target : target.substring(0, semicolon),
  ).trim();
  return number.isEmpty ? null : SmsContent(number: number, message: message);
}

/// `geo:latitude,longitude[,altitude][;params][?q=query]` (RFC 5870).
GeoContent? _geo(String body) {
  final int q = body.indexOf('?');
  String coordinates = q < 0 ? body : body.substring(0, q);
  final int semicolon = coordinates.indexOf(';');
  if (semicolon >= 0) {
    coordinates = coordinates.substring(0, semicolon);
  }
  final List<String> parts = coordinates.split(',');
  if (parts.length < 2 || parts.length > 3) {
    return null;
  }
  final double? latitude = double.tryParse(parts[0].trim());
  final double? longitude = double.tryParse(parts[1].trim());
  final double? altitude = parts.length > 2
      ? double.tryParse(parts[2].trim())
      : null;
  if (latitude == null ||
      longitude == null ||
      latitude.abs() > 90 ||
      longitude.abs() > 180 ||
      (parts.length > 2 && altitude == null)) {
    return null;
  }
  String? query;
  if (q >= 0) {
    for (final String pair in body.substring(q + 1).split('&')) {
      final int eq = pair.indexOf('=');
      if (eq > 0 && pair.substring(0, eq).toLowerCase() == 'q') {
        query = _orNull(_decodeQuery(pair.substring(eq + 1)));
      }
    }
  }
  return GeoContent(
    latitude: latitude,
    longitude: longitude,
    altitude: altitude,
    query: query,
  );
}

// --- Shared helpers ------------------------------------------------------------

String? _orNull(String? value) => value == null || value.isEmpty ? null : value;

String _decode(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  } on FormatException {
    return value;
  }
}

String _decodeQuery(String value) {
  try {
    return Uri.decodeQueryComponent(value);
  } on ArgumentError {
    return value;
  } on FormatException {
    return value;
  }
}

/// Splits the `KEY:value;KEY:value;;` fields of MECARD, MEBKM, MATMSG and
/// WIFI. A backslash escapes the next character; keys come back upper case,
/// values raw (still escaped), so that a field can be split further.
List<(String, String)> _fields(String body) {
  final List<(String, String)> fields = <(String, String)>[];
  final StringBuffer key = StringBuffer();
  final StringBuffer value = StringBuffer();
  bool inValue = false;
  bool escaped = false;
  void finish() {
    final String k = key.toString().trim().toUpperCase();
    if (k.isNotEmpty) {
      fields.add((k, value.toString()));
    }
    key.clear();
    value.clear();
    inValue = false;
  }

  for (int i = 0; i < body.length; i++) {
    final String c = body[i];
    if (escaped) {
      (inValue ? value : key)
        ..write(r'\')
        ..write(c);
      escaped = false;
    } else if (c == r'\') {
      escaped = true;
    } else if (c == ';') {
      finish();
    } else if (c == ':' && !inValue) {
      inValue = true;
    } else {
      (inValue ? value : key).write(c);
    }
  }
  finish();
  return fields;
}

/// Removes backslash escapes. With [newlines], `\n` is a line break (vCard,
/// iCalendar); in the DoCoMo formats it is just `n`.
String _unescape(String raw, {bool newlines = false}) {
  if (!raw.contains(r'\')) {
    return raw;
  }
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final String c = raw[i];
    if (c == r'\' && i + 1 < raw.length) {
      final String next = raw[++i];
      out.write(newlines && (next == 'n' || next == 'N') ? '\n' : next);
    } else {
      out.write(c);
    }
  }
  return out.toString();
}

/// Splits [raw] at unescaped [separator]s and unescapes the parts.
List<String> _split(String raw, String separator, {bool newlines = false}) {
  final List<String> parts = <String>[];
  int start = 0;
  for (int i = 0; i < raw.length; i++) {
    final String c = raw[i];
    if (c == r'\') {
      i++;
    } else if (c == separator) {
      parts.add(_unescape(raw.substring(start, i), newlines: newlines));
      start = i + 1;
    }
  }
  parts.add(_unescape(raw.substring(start), newlines: newlines));
  return parts;
}

/// One content line of a vCard or iCalendar object.
final class _Line {
  _Line(this.name, this.raw);

  /// Property name, upper case, without a group prefix (`item1.TEL` → TEL).
  final String name;

  /// The value, decoded but still escaped.
  final String raw;

  /// The value as text.
  String get text => _unescape(raw, newlines: true);

  /// A structured value (N, ADR, ORG) split into its components.
  List<String> get parts => _split(raw, ';', newlines: true);
}

/// The content lines of a vCard or iCalendar object: unfolded (RFC 6350
/// 3.2, and vCard 2.1 quoted-printable soft breaks), values decoded.
List<_Line> _contentLines(String text) {
  final List<String> physical = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final List<String> logical = <String>[];
  for (final String line in physical) {
    if (logical.isNotEmpty &&
        line.isNotEmpty &&
        (line[0] == ' ' || line[0] == '\t')) {
      logical.last += line.substring(1);
    } else if (logical.isNotEmpty &&
        logical.last.endsWith('=') &&
        _isQuotedPrintable(logical.last)) {
      logical.last = logical.last.substring(0, logical.last.length - 1) + line;
    } else {
      logical.add(line);
    }
  }

  final List<_Line> lines = <_Line>[];
  for (final String line in logical) {
    final int colon = _valueStart(line);
    if (colon <= 0) {
      continue;
    }
    final List<String> head = line.substring(0, colon).split(';');
    String name = head.first.trim().toUpperCase();
    final int dot = name.lastIndexOf('.');
    if (dot >= 0) {
      name = name.substring(dot + 1);
    }
    String value = line.substring(colon + 1);
    final List<String> params = head
        .skip(1)
        .map((String p) => p.trim().toUpperCase())
        .toList();
    if (params.any(
      (String p) => p == 'QUOTED-PRINTABLE' || p == 'ENCODING=QUOTED-PRINTABLE',
    )) {
      final String charset = params
          .firstWhere((String p) => p.startsWith('CHARSET='), orElse: () => '')
          .replaceFirst('CHARSET=', '');
      value = _decodeQuotedPrintable(value, charset);
    }
    lines.add(_Line(name, value));
  }
  return lines;
}

/// The colon between the property (with its parameters) and the value;
/// colons inside quoted parameter values do not count.
int _valueStart(String line) {
  bool quoted = false;
  for (int i = 0; i < line.length; i++) {
    final String c = line[i];
    if (c == '"') {
      quoted = !quoted;
    } else if (c == ':' && !quoted) {
      return i;
    }
  }
  return -1;
}

bool _isQuotedPrintable(String line) {
  final int colon = _valueStart(line);
  return colon > 0 &&
      line.substring(0, colon).toUpperCase().contains('QUOTED-PRINTABLE');
}

String _decodeQuotedPrintable(String value, String charset) {
  final List<int> bytes = <int>[];
  for (int i = 0; i < value.length; i++) {
    final int c = value.codeUnitAt(i);
    if (c == 0x3D /* = */ && i + 2 < value.length) {
      final int? byte = int.tryParse(value.substring(i + 1, i + 3), radix: 16);
      if (byte != null) {
        bytes.add(byte);
        i += 2;
        continue;
      }
    }
    if (c < 0x80) {
      bytes.add(c);
    } else {
      bytes.addAll(utf8.encode(value[i]));
    }
  }
  return switch (charset) {
    'ISO-8859-1' ||
    'LATIN1' ||
    'WINDOWS-1252' => latin1.decode(bytes.map((int b) => b & 0xFF).toList()),
    _ => utf8.decode(bytes, allowMalformed: true),
  };
}
