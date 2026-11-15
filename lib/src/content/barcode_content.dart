import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';
import 'content_parser.dart';

/// The payload of a [Barcode], parsed into a typed value.
///
/// Get it with [Barcode.content] and use pattern matching:
///
/// ```dart
/// switch (barcode.content) {
///   case UrlContent(:final url): openUrl(url);
///   case WifiContent(:final ssid, :final password): connect(ssid, password);
///   case ContactContent contact: saveContact(contact);
///   case Gs1Content(:final elements): print(elements['01']); // GTIN
///   default: print(barcode.text);
/// }
/// ```
///
/// Recognised formats:
///
/// | Content | Payload |
/// |---|---|
/// | [UrlContent] | `https://…`, `http://…`, `www.…`, `MEBKM:`, `URLTO:` |
/// | [WifiContent] | `WIFI:T:WPA;S:name;P:password;;` |
/// | [ContactContent] | vCard 2.1/3.0/4.0, `MECARD:` |
/// | [EventContent] | `BEGIN:VEVENT`, alone or in a `VCALENDAR` |
/// | [EmailContent] | `mailto:`, `MATMSG:`, `SMTP:` |
/// | [PhoneContent] | `tel:` |
/// | [SmsContent] | `sms:`, `smsto:`, `mms:`, `mmsto:` |
/// | [GeoContent] | `geo:` |
/// | [Gs1Content] | GS1 barcodes ([BarcodeContentType.gs1]) |
/// | [BinaryContent] | binary barcodes ([BarcodeContentType.binary]) |
///
/// Parsing never throws: anything not recognised, or recognised but
/// malformed, is [TextContent].
@immutable
sealed class BarcodeContent {
  const BarcodeContent();

  /// Parses the payload of [barcode]. [Barcode.content] calls this once per
  /// barcode and keeps the result.
  static BarcodeContent parse(Barcode barcode) => parseBarcodeContent(barcode);

  /// Parses a payload that is only available as text, for example one saved
  /// earlier. Never returns [Gs1Content] or [BinaryContent]: whether a
  /// payload is GS1 or binary is known only from the barcode itself.
  static BarcodeContent parseText(String text) => parseTextContent(text);
}

/// Plain text, or anything not recognised as a more specific type.
final class TextContent extends BarcodeContent {
  /// Creates text content.
  const TextContent(this.text);

  /// The text.
  final String text;

  @override
  bool operator ==(Object other) => other is TextContent && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextContent("$text")';
}

/// Binary data.
final class BinaryContent extends BarcodeContent {
  /// Creates binary content.
  const BinaryContent(this.bytes);

  /// The bytes.
  final Uint8List bytes;

  @override
  bool operator ==(Object other) =>
      other is BinaryContent && listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hashAll(bytes);

  @override
  String toString() => 'BinaryContent(${bytes.length} bytes)';
}

/// A web address.
///
/// From `http://` and `https://` addresses, addresses starting with `www.`
/// (which get `https://`), and the `MEBKM:` and `URLTO:` bookmark formats.
/// Text that only starts with an address, such as an address followed by a
/// line of text, stays [TextContent].
final class UrlContent extends BarcodeContent {
  /// Creates URL content.
  const UrlContent(this.url, {this.title});

  /// The address.
  final Uri url;

  /// A title, if the format carries one (`MEBKM:`, `URLTO:`).
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is UrlContent && other.url == url && other.title == title;

  @override
  int get hashCode => Object.hash(url, title);

  @override
  String toString() => 'UrlContent($url${title == null ? '' : ', "$title"'})';
}

/// Security of a Wi-Fi network.
enum WifiSecurity {
  /// Open network.
  none,

  /// WEP.
  wep,

  /// WPA, WPA2 or WPA3 personal.
  wpa,

  /// WPA2/WPA3 enterprise (EAP).
  enterprise,

  /// Declared but not recognised.
  unknown,
}

/// Wi-Fi network credentials (`WIFI:` format).
///
/// When the code does not say how the network is secured, it is taken as
/// [WifiSecurity.wpa] if there is a password and [WifiSecurity.none] if not.
final class WifiContent extends BarcodeContent {
  /// Creates Wi-Fi content.
  const WifiContent({
    required this.ssid,
    this.password,
    this.security = WifiSecurity.wpa,
    this.hidden = false,
  });

  /// Network name.
  final String ssid;

  /// Password, or `null` for an open network.
  final String? password;

  /// Security type.
  final WifiSecurity security;

  /// Whether the network does not broadcast its name.
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      other is WifiContent &&
      other.ssid == ssid &&
      other.password == password &&
      other.security == security &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(ssid, password, security, hidden);

  @override
  String toString() =>
      'WifiContent("$ssid", ${security.name}${hidden ? ', hidden' : ''})';
}

/// An e-mail draft (`mailto:`, `MATMSG:`, `SMTP:`).
final class EmailContent extends BarcodeContent {
  /// Creates e-mail content.
  const EmailContent({required this.address, this.subject, this.body});

  /// Recipient address. Several recipients are separated by commas, as in
  /// `mailto:`; empty if the code leaves the recipient to the user.
  final String address;

  /// Subject, if given.
  final String? subject;

  /// Body, if given.
  final String? body;

  @override
  bool operator ==(Object other) =>
      other is EmailContent &&
      other.address == address &&
      other.subject == subject &&
      other.body == body;

  @override
  int get hashCode => Object.hash(address, subject, body);

  @override
  String toString() => 'EmailContent($address)';
}

/// A phone number (`tel:`).
final class PhoneContent extends BarcodeContent {
  /// Creates phone content.
  const PhoneContent(this.number);

  /// The number as written in the barcode.
  final String number;

  @override
  bool operator ==(Object other) =>
      other is PhoneContent && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'PhoneContent($number)';
}

/// A text message draft (`sms:`, `smsto:`, `mms:`, `mmsto:`).
final class SmsContent extends BarcodeContent {
  /// Creates SMS content.
  const SmsContent({required this.number, this.message});

  /// Recipient number. Several recipients are separated by commas, as in
  /// `sms:`.
  final String number;

  /// Message text, if given.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is SmsContent && other.number == number && other.message == message;

  @override
  int get hashCode => Object.hash(number, message);

  @override
  String toString() => 'SmsContent($number)';
}

/// A location (`geo:`).
final class GeoContent extends BarcodeContent {
  /// Creates geo content.
  const GeoContent({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.query,
  });

  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Altitude in metres, if given.
  final double? altitude;

  /// Search query (`?q=`), if given.
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is GeoContent &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.altitude == altitude &&
      other.query == query;

  @override
  int get hashCode => Object.hash(latitude, longitude, altitude, query);

  @override
  String toString() => 'GeoContent($latitude, $longitude)';
}

/// A contact card (vCard or MeCard).
final class ContactContent extends BarcodeContent {
  /// Creates contact content.
  const ContactContent({
    this.name,
    this.organization,
    this.title,
    this.phones = const <String>[],
    this.emails = const <String>[],
    this.urls = const <Uri>[],
    this.addresses = const <String>[],
    this.note,
  });

  /// Formatted name, e.g. `Sean Owen` (from vCard `FN`, else `N`; the
  /// MeCard `N:Owen,Sean` is turned around).
  final String? name;

  /// Company or organization.
  final String? organization;

  /// Job title.
  final String? title;

  /// Phone numbers.
  final List<String> phones;

  /// E-mail addresses.
  final List<String> emails;

  /// Web addresses. One without a scheme gets `https://`.
  final List<Uri> urls;

  /// Postal addresses, one string each, components separated by commas.
  final List<String> addresses;

  /// Free-form note.
  final String? note;

  @override
  bool operator ==(Object other) =>
      other is ContactContent &&
      other.name == name &&
      other.organization == organization &&
      other.title == title &&
      listEquals(other.phones, phones) &&
      listEquals(other.emails, emails) &&
      listEquals(other.urls, urls) &&
      listEquals(other.addresses, addresses) &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
    name,
    organization,
    title,
    Object.hashAll(phones),
    Object.hashAll(emails),
    Object.hashAll(urls),
    Object.hashAll(addresses),
    note,
  );

  @override
  String toString() => 'ContactContent(${name ?? organization ?? ''})';
}

/// A calendar event (vEvent).
///
/// Times marked UTC (`…Z`) are UTC [DateTime]s; all others, including times
/// with a named time zone (`TZID=`), are read as local time. An event with a
/// `DURATION` instead of an end gets [end] = [start] + duration.
final class EventContent extends BarcodeContent {
  /// Creates event content.
  const EventContent({
    required this.summary,
    required this.start,
    this.end,
    this.location,
    this.description,
  });

  /// Event title; empty if the event has none.
  final String summary;

  /// Start time.
  final DateTime start;

  /// End time, if given.
  final DateTime? end;

  /// Location, if given.
  final String? location;

  /// Description, if given.
  final String? description;

  @override
  bool operator ==(Object other) =>
      other is EventContent &&
      other.summary == summary &&
      other.start == start &&
      other.end == end &&
      other.location == location &&
      other.description == description;

  @override
  int get hashCode => Object.hash(summary, start, end, location, description);

  @override
  String toString() => 'EventContent("$summary", $start)';
}

/// GS1 data: Application Identifiers and their values.
///
/// The data is split with the same Application Identifier table zxing-cpp
/// uses for the human readable [Barcode.text], so the elements always match
/// the parentheses there.
final class Gs1Content extends BarcodeContent {
  /// Creates GS1 content.
  const Gs1Content(this.elements);

  /// Values by Application Identifier, in barcode order:
  /// `{'01': '09501101530003', '17': '250101', '10': 'ABC123'}`.
  final Map<String, String> elements;

  /// GTIN (AI 01), if present.
  String? get gtin => elements['01'];

  @override
  bool operator ==(Object other) =>
      other is Gs1Content && mapEquals(other.elements, elements);

  @override
  int get hashCode => Object.hashAllUnordered(
    elements.entries.map(
      (MapEntry<String, String> e) => Object.hash(e.key, e.value),
    ),
  );

  @override
  String toString() => 'Gs1Content($elements)';
}
