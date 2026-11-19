import 'package:flutter/foundation.dart';

import '../barcode/barcode.dart';
import 'app_content.dart';
import 'content_builder.dart';
import 'content_parser.dart';
import 'gs1.dart';
import 'industry_content.dart';
import 'link_service.dart';
import 'payment_content.dart';

part 'barcode_content_apps.dart';
part 'barcode_content_industry.dart';
part 'barcode_content_payments.dart';

/// The payload of a [Barcode], parsed into a typed value.
///
/// Get it with [BarcodeContentOf.content] (`barcode.content`) and use
/// pattern matching. New kinds are added in minor versions, so a `switch`
/// over a content needs a `default` (or `_`) case; classes outside this
/// package cannot extend it:
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
/// | [PaymentContent] | EPC/SEPA (`BCD`), Swiss QR-bill (`SPC`), ГОСТ Р 56042 (`ST0001`), UPI, EMVCo (PIX, PayNow, PromptPay…), SPAYD |
/// | [OtpContent] | `otpauth://totp/…`, `otpauth://hotp/…` |
/// | [EsimContent] | `LPA:1$…` |
/// | [CryptoContent] | `bitcoin:`, `ethereum:`, `litecoin:`, `lightning:`, `lnbc…` |
/// | [WifiDppContent] | `DPP:` (Wi-Fi Easy Connect) |
/// | [SmartHomeContent] | `MT:` (Matter), `X-HM://` (HomeKit) |
/// | [BoardingPassContent] | IATA boarding passes (`M1…`) |
/// | [DriverLicenseContent] | AAMVA driver's licenses and IDs (`@…ANSI …`) |
/// | [VinContent] | vehicle identification numbers |
/// | [ProductContent] | EAN/UPC barcodes: GTIN, ISBN, ISSN |
/// | [Gs1Content] | GS1 barcodes ([BarcodeContentType.gs1]) |
/// | [BinaryContent] | binary barcodes ([BarcodeContentType.binary]) |
///
/// Parsing never throws: anything not recognised, or recognised but
/// malformed, is [TextContent].
///
/// The other way round, [toPayload] builds the text to put in a barcode,
/// with the escaping each format needs:
///
/// ```dart
/// const WifiContent wifi = WifiContent(ssid: 'Home', password: 'secret12');
/// BarcodeView(wifi.toPayload()); // WIFI:T:WPA;S:Home;P:secret12;;
/// ```
@immutable
abstract final class BarcodeContent {
  const BarcodeContent();

  /// The text to put in a barcode: `WIFI:…`, a vCard, `mailto:…` and so on.
  ///
  /// [BarcodeContent.parseText] reads it back, as an equal value for most
  /// kinds (not for [ProductContent], [Gs1Content] and [BinaryContent],
  /// which come only from barcodes). Values that are not in the form
  /// parsing returns are normalised first, so that building again gives the
  /// same text: spaces leave phone numbers, surrounding whitespace leaves
  /// fields, empty strings become `null`.
  ///
  /// Throws an [ArgumentError] if [validate] finds a problem, and an
  /// [UnsupportedError] for [BinaryContent], which has no text: encode its
  /// bytes with `BarcodeWriter.encodeBytes` or `BarcodeView.bytes`, or use
  /// `writer.encodeContent(content)`, which handles every kind.
  String toPayload();

  /// The problems that keep [toPayload] from building this value, such as
  /// an empty network name or a latitude out of range. Empty when the value
  /// can be built. For forms: show each [ContentIssue.message] next to its
  /// [ContentIssue.field].
  List<ContentIssue> validate();

  /// A link that opens this content in the app made for it, for
  /// `launchUrl` of package:url_launcher; `null` when there is none.
  ///
  /// | Content | Link |
  /// |---|---|
  /// | [UrlContent] | the address, with `https://` if it has no scheme |
  /// | [EmailContent] | `mailto:address?subject=…&body=…` |
  /// | [PhoneContent] | `tel:`, `facetime:`, `facetime-audio:` |
  /// | [SmsContent] | `sms:number?body=…` (RFC 5724) |
  /// | [GeoContent] | `geo:latitude,longitude?q=…` |
  /// | [CryptoContent] | `bitcoin:…`, `ethereum:…`, `litecoin:…`, `lightning:…` |
  /// | [UpiPaymentContent] | `upi://pay?…` |
  /// | [OtpContent] | `otpauth://…` |
  ///
  /// Other kinds, such as Wi-Fi networks, contacts, events, most payments
  /// and product numbers, have no such link and give `null`; so does a
  /// value [validate] finds problems in.
  ///
  /// ```dart
  /// if (barcode.content.uri case final Uri uri) {
  ///   await launchUrl(uri);
  /// }
  /// ```
  Uri? get uri => null;

  /// Parses a payload that is only available as text, for example one saved
  /// earlier. Never returns [Gs1Content] or [BinaryContent]: whether a
  /// payload is GS1 or binary is known only from the barcode itself.
  static BarcodeContent parseText(String text) => parseTextContent(text);
}

/// `barcode.content`: the payload parsed into a typed value. Lives in the
/// content layer, so the core [Barcode] does not depend on parsing.
extension BarcodeContentOf on Barcode {
  /// The payload parsed into a typed value: a URL, a Wi-Fi network, a
  /// contact, GS1 data and so on. Falls back to [TextContent] or
  /// [BinaryContent]. Parsed once per barcode.
  ///
  /// ```dart
  /// switch (barcode.content) {
  ///   case UrlContent(:final url): openUrl(url);
  ///   case WifiContent(:final ssid, :final password): connect(ssid, password);
  ///   default: print(barcode.text);
  /// }
  /// ```
  BarcodeContent get content => _contents[this] ??= parseBarcodeContent(this);
}

final Expando<BarcodeContent> _contents = Expando<BarcodeContent>(
  'BarcodeContent',
);

/// What kind of problem a [ContentIssue] is, so that a form can say it in
/// its own language.
///
/// New values are added in minor versions: a `switch` over it needs a
/// `default` (or `_`) case.
enum ContentIssueKind {
  /// A required value is missing or empty.
  empty,

  /// A text or list is longer than [ContentIssue.limit] allows.
  tooLong,

  /// A value does not have the form the field needs: not an e-mail address,
  /// not 20 digits, a character the format cannot hold.
  invalid,

  /// Check digits or a checksum are wrong: an IBAN, an RF reference, a QR
  /// reference.
  checksum,

  /// A number is outside the range the field allows: a latitude, a year,
  /// the digits of a one-time password.
  outOfRange,

  /// Two fields do not go together: a reference and a text, a QR reference
  /// without a QR-IBAN, an event that ends before it starts.
  conflict,

  /// The value is valid but cannot be built: an enterprise Wi-Fi network,
  /// an unknown GS1 Application Identifier.
  unsupported,
}

/// A problem that keeps [BarcodeContent.toPayload] from building a value,
/// from [BarcodeContent.validate].
///
/// [message] is in English; to show the problem in another language, use
/// [field], [kind] and [limit]:
///
/// ```dart
/// String say(ContentIssue issue) => switch (issue.kind) {
///   ContentIssueKind.empty => 'Обязательное поле',
///   ContentIssueKind.tooLong => 'Не больше ${issue.limit} символов',
///   _ => issue.message,
/// };
/// ```
@immutable
final class ContentIssue {
  /// Creates an issue with [field].
  const ContentIssue(
    this.field,
    this.message, {
    this.kind = ContentIssueKind.invalid,
    this.limit,
  });

  /// The name of the field with the problem, as in the constructor:
  /// `ssid`, `latitude`, `emails`.
  final String field;

  /// What is wrong, in English: `Network name is empty`.
  final String message;

  /// What kind of problem it is.
  final ContentIssueKind kind;

  /// For [ContentIssueKind.tooLong], the most the field may hold: characters,
  /// bytes or items, as [message] says; otherwise `null`.
  final int? limit;

  @override
  bool operator ==(Object other) =>
      other is ContentIssue &&
      other.field == field &&
      other.message == message &&
      other.kind == kind &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(field, message, kind, limit);

  @override
  String toString() => '$field: $message';
}

/// Plain text, or anything not recognised as a more specific type.
final class TextContent extends BarcodeContent {
  /// Creates text content.
  const TextContent(this.text);

  /// The text.
  final String text;

  /// [text] as it is. Text that looks like another kind, such as a web
  /// address, is parsed back as that kind.
  @override
  String toPayload() => buildText(this);

  @override
  List<ContentIssue> validate() => validateText(this);

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

  /// Always throws [UnsupportedError]: binary data has no text. Encode
  /// [bytes] with `BarcodeWriter.encodeBytes`, `BarcodeView.bytes` or
  /// `writer.encodeContent(content)`.
  @override
  String toPayload() => throw UnsupportedError(
    'BinaryContent has no text payload; encode its bytes with '
    'BarcodeWriter.encodeBytes, BarcodeView.bytes or encodeContent',
  );

  @override
  List<ContentIssue> validate() => validateBinary(this);

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

  /// The service the address belongs to, such as [LinkService.instagram]
  /// for `https://instagram.com/…`, or `null`. Build such links with
  /// [LinkService.link].
  LinkService? get service => linkServiceOf(url);

  /// The address; with a [title], a `MEBKM:` bookmark. An address without
  /// a scheme (`example.com`) gets `https://`. Only `http` and `https`
  /// addresses can be built; put other links in [TextContent].
  @override
  String toPayload() => buildUrl(this);

  @override
  List<ContentIssue> validate() => validateUrl(this);

  /// [url], with `https://` if it has no scheme.
  @override
  Uri? get uri => urlUri(this);

  @override
  bool operator ==(Object other) =>
      other is UrlContent && other.url == url && other.title == title;

  @override
  int get hashCode => Object.hash(url, title);

  @override
  String toString() => 'UrlContent($url${title == null ? '' : ', "$title"'})';
}

/// Security of a Wi-Fi network.
///
/// New values are added in minor versions: a `switch` over it needs a
/// `default` (or `_`) case.
enum WifiSecurity {
  /// Open network.
  none,

  /// WEP.
  wep,

  /// WPA or WPA2 personal, or WPA2/WPA3 transition mode (`T:WPA`).
  wpa,

  /// WPA3 personal only (`T:SAE`, or `T:WPA` with WPA3 transition disabled:
  /// `R:1`).
  wpa3,

  /// WPA2/WPA3 enterprise (EAP).
  enterprise,

  /// Declared but not recognised.
  unknown,
}

/// Wi-Fi network credentials (`WIFI:` format).
///
/// When the code does not say how the network is secured, it is taken as
/// [WifiSecurity.wpa] if there is a password and [WifiSecurity.none] if not.
/// The constructor does the same: `WifiContent(ssid: 'Cafe')` is an open
/// network, `WifiContent(ssid: 'Home', password: 'secret12')` a WPA one.
final class WifiContent extends BarcodeContent {
  /// Creates Wi-Fi content. Without [security], the network is
  /// [WifiSecurity.none] when [password] is `null` or empty, else
  /// [WifiSecurity.wpa].
  const WifiContent({
    required this.ssid,
    this.password,
    WifiSecurity? security,
    this.hidden = false,
  }) : security =
           security ??
           (password == null || password == ''
               ? WifiSecurity.none
               : WifiSecurity.wpa);

  /// Network name.
  final String ssid;

  /// Password, or `null` for an open network.
  final String? password;

  /// Security type.
  final WifiSecurity security;

  /// Whether the network does not broadcast its name.
  final bool hidden;

  /// `WIFI:T:WPA;S:name;P:password;;`, with `\ ; , : "` escaped.
  /// [WifiSecurity.wpa3] is written as `T:WPA` with `R:1` (Wi-Fi Alliance
  /// WPA3 specification): phones that do not know `R` still join it as
  /// WPA2/WPA3. [WifiSecurity.enterprise] and [WifiSecurity.unknown] cannot
  /// be built.
  @override
  String toPayload() => buildWifi(this);

  @override
  List<ContentIssue> validate() => validateWifi(this);

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

  /// `mailto:address?subject=…&body=…`, percent-encoded (RFC 6068).
  @override
  String toPayload() => buildEmail(this);

  @override
  List<ContentIssue> validate() => validateEmail(this);

  /// `mailto:address?subject=…&body=…`, as [toPayload].
  @override
  Uri? get uri => payloadUri(this);

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

/// How a [PhoneContent] calls.
enum CallType {
  /// A phone call (`tel:`).
  voice,

  /// A FaceTime video call (`facetime:`), Apple devices only.
  faceTime,

  /// A FaceTime audio call (`facetime-audio:`), Apple devices only.
  faceTimeAudio,
}

/// A phone number to call (`tel:`, `facetime:`, `facetime-audio:`).
final class PhoneContent extends BarcodeContent {
  /// Creates phone content.
  const PhoneContent(this.number, {this.type = CallType.voice});

  /// The number as written in the barcode; for FaceTime, also an e-mail
  /// address.
  final String number;

  /// Phone or FaceTime.
  final CallType type;

  /// `tel:+12125551234` (`facetime:`, `facetime-audio:`). Visual
  /// separators (spaces, `-`, `.`, brackets) are removed; `+`, digits, `*`
  /// and `#` are kept.
  @override
  String toPayload() => buildPhone(this);

  @override
  List<ContentIssue> validate() => validatePhone(this);

  /// `tel:`, `facetime:` or `facetime-audio:`, as [toPayload].
  @override
  Uri? get uri => payloadUri(this);

  @override
  bool operator ==(Object other) =>
      other is PhoneContent && other.number == number && other.type == type;

  @override
  int get hashCode => Object.hash(number, type);

  @override
  String toString() =>
      'PhoneContent($number${type == CallType.voice ? '' : ', ${type.name}'})';
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

  /// `SMSTO:number:message`, the form both iOS and Android camera apps
  /// open. Numbers lose their visual separators, as in [PhoneContent].
  @override
  String toPayload() => buildSms(this);

  @override
  List<ContentIssue> validate() => validateSms(this);

  /// `sms:number?body=message` (RFC 5724), which messaging apps open with
  /// the message filled in; [toPayload] is the `SMSTO:` form camera apps
  /// read.
  @override
  Uri? get uri => smsUri(this);

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

  /// `geo:latitude,longitude[,altitude][?q=query]` (RFC 5870).
  @override
  String toPayload() => buildGeo(this);

  @override
  List<ContentIssue> validate() => validateGeo(this);

  /// `geo:latitude,longitude?q=query`, as [toPayload].
  @override
  Uri? get uri => payloadUri(this);

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

/// How [ContactContent.toPayload] writes a contact.
enum ContactFormat {
  /// vCard 3.0: every field, understood everywhere.
  vCard,

  /// `MECARD:`: shorter, so the QR code is smaller.
  meCard,
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
    this.birthDate,
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

  /// Date of birth (vCard `BDAY`, MeCard `BDAY`), at local midnight. A
  /// birthday without a year (vCard 4.0 `--0517`) is not kept.
  final DateTime? birthDate;

  /// A vCard 3.0, or with [ContactFormat.meCard] a shorter `MECARD:` that
  /// makes a smaller QR code. [name] is written as the formatted name and,
  /// split at its last space, as the family and given names.
  @override
  String toPayload({ContactFormat format = ContactFormat.vCard}) =>
      buildContact(this, format);

  @override
  List<ContentIssue> validate() => validateContact(this);

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
      other.note == note &&
      other.birthDate == birthDate;

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
    birthDate,
  );

  @override
  String toString() => 'ContactContent(${name ?? organization ?? ''})';
}

/// A calendar event (vEvent).
///
/// Times marked UTC (`…Z`) are UTC [DateTime]s; all others, including times
/// with a named time zone (`TZID=`), are read as local time. An event with a
/// `DURATION` instead of an end gets [end] = [start] + duration. An
/// all-day event (`DTSTART;VALUE=DATE:20261117`) starts at local midnight.
final class EventContent extends BarcodeContent {
  /// Creates event content.
  const EventContent({
    required this.summary,
    required this.start,
    this.end,
    this.allDay = false,
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

  /// Whether the event takes whole days: only the dates of [start] and
  /// [end] count, and [end] is the day after the last one, as in
  /// iCalendar.
  final bool allDay;

  /// Description, if given.
  final String? description;

  /// A `VCALENDAR` with one `VEVENT`. UTC times are written as UTC
  /// (`…Z`), local times as floating local times; seconds are kept,
  /// milliseconds are not.
  @override
  String toPayload() => buildEvent(this);

  @override
  List<ContentIssue> validate() => validateEvent(this);

  @override
  bool operator ==(Object other) =>
      other is EventContent &&
      other.summary == summary &&
      other.start == start &&
      other.end == end &&
      other.allDay == allDay &&
      other.location == location &&
      other.description == description;

  @override
  int get hashCode =>
      Object.hash(summary, start, end, allDay, location, description);

  @override
  String toString() => 'EventContent("$summary", $start)';
}

/// GS1 data: Application Identifiers and their values.
///
/// The data is split with the Application Identifier table and rules
/// zxing-cpp uses for the parentheses of the human readable [Barcode.text].
/// An identifier that occurs twice keeps its last value.
final class Gs1Content extends BarcodeContent {
  /// Creates GS1 content.
  const Gs1Content(this.elements);

  /// Values by Application Identifier, in barcode order:
  /// `{'01': '09501101530003', '17': '250101', '10': 'ABC123'}`.
  final Map<String, String> elements;

  /// GTIN (AI 01), if present.
  String? get gtin => elements['01'];

  /// The Serial Shipping Container Code (AI 00) of a logistic unit, such
  /// as a pallet, if present.
  String? get sscc => elements['00'];

  /// The batch or lot number (AI 10), if present.
  String? get batch => elements['10'];

  /// The serial number (AI 21), if present.
  String? get serial => elements['21'];

  /// How many trade items a logistic unit holds (AI 37), if present.
  int? get count => switch (elements['37']) {
    final String value => int.tryParse(value),
    null => null,
  };

  /// The expiry date (AI 17), if present and valid; a day of `00` is the
  /// last day of the month.
  DateTime? get expiryDate => gs1Date(elements['17']);

  /// The best before date (AI 15), if present and valid.
  DateTime? get bestBeforeDate => gs1Date(elements['15']);

  /// Whether the [expiryDate] has passed: the item may be used through
  /// that day. `false` without an expiry date. [now] defaults to the
  /// current time.
  bool isExpired([DateTime? now]) {
    final DateTime? expiry = gs1Date(elements['17'], now);
    if (expiry == null) {
      return false;
    }
    final DateTime today = now ?? DateTime.now();
    return DateTime(today.year, today.month, today.day).isAfter(expiry);
  }

  /// The elements with their identifiers in parentheses,
  /// `(01)09501101530003(17)250101`, the form GS1 encoding takes
  /// (`BarcodeWriter(…, gs1: true)`, also in `BarcodeView`, or
  /// `writer.encodeContent(content)`, which sets it).
  @override
  String toPayload() => buildGs1(this);

  @override
  List<ContentIssue> validate() => validateGs1(this);

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
