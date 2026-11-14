import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';

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
/// Parsing never throws: anything not recognised is [TextContent] (or
/// [BinaryContent] for binary payloads).
@immutable
sealed class BarcodeContent {
  const BarcodeContent();

  /// Parses the payload of [barcode].
  static BarcodeContent parse(Barcode barcode) =>
      throw UnimplementedError('Stage 6: content parsing');
}

/// Plain text, or anything not recognised as a more specific type.
final class TextContent extends BarcodeContent {
  /// Creates text content.
  const TextContent(this.text);

  /// The text.
  final String text;
}

/// Binary data.
final class BinaryContent extends BarcodeContent {
  /// Creates binary content.
  const BinaryContent(this.bytes);

  /// The bytes.
  final Uint8List bytes;
}

/// A web address (`http`, `https` or a bare domain).
final class UrlContent extends BarcodeContent {
  /// Creates URL content.
  const UrlContent(this.url, {this.title});

  /// The address.
  final Uri url;

  /// A title, if the format carries one (MEBKM).
  final String? title;
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
}

/// An e-mail draft (`mailto:`, `MATMSG:`).
final class EmailContent extends BarcodeContent {
  /// Creates e-mail content.
  const EmailContent({required this.address, this.subject, this.body});

  /// Recipient address.
  final String address;

  /// Subject, if given.
  final String? subject;

  /// Body, if given.
  final String? body;
}

/// A phone number (`tel:`).
final class PhoneContent extends BarcodeContent {
  /// Creates phone content.
  const PhoneContent(this.number);

  /// The number as written in the barcode.
  final String number;
}

/// A text message draft (`sms:`, `smsto:`).
final class SmsContent extends BarcodeContent {
  /// Creates SMS content.
  const SmsContent({required this.number, this.message});

  /// Recipient number.
  final String number;

  /// Message text, if given.
  final String? message;
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

  /// Formatted name.
  final String? name;

  /// Company or organization.
  final String? organization;

  /// Job title.
  final String? title;

  /// Phone numbers.
  final List<String> phones;

  /// E-mail addresses.
  final List<String> emails;

  /// Web addresses.
  final List<Uri> urls;

  /// Postal addresses, one string each.
  final List<String> addresses;

  /// Free-form note.
  final String? note;
}

/// A calendar event (vEvent).
final class EventContent extends BarcodeContent {
  /// Creates event content.
  const EventContent({
    required this.summary,
    required this.start,
    this.end,
    this.location,
    this.description,
  });

  /// Event title.
  final String summary;

  /// Start time.
  final DateTime start;

  /// End time, if given.
  final DateTime? end;

  /// Location, if given.
  final String? location;

  /// Description, if given.
  final String? description;
}

/// GS1 data: Application Identifiers and their values.
final class Gs1Content extends BarcodeContent {
  /// Creates GS1 content.
  const Gs1Content(this.elements);

  /// Values by Application Identifier, in barcode order:
  /// `{'01': '09501101530003', '17': '250101', '10': 'ABC123'}`.
  final Map<String, String> elements;

  /// GTIN (AI 01), if present.
  String? get gtin => elements['01'];
}
