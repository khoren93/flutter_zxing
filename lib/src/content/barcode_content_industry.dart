part of 'barcode_content.dart';

/// A retail product number from an EAN-13, EAN-8, UPC-A or UPC-E barcode:
/// the GTIN, and the ISBN or ISSN when the number is a book or a
/// periodical (prefixes 978/979 and 977).
///
/// Only from barcodes, since a number alone does not say it is a product:
/// [BarcodeContent.parseText] never returns it. [toPayload] returns [raw].
final class ProductContent extends BarcodeContent {
  /// Creates product content.
  const ProductContent({
    required this.gtin,
    required this.number,
    required this.raw,
    this.addOn,
  });

  /// The GTIN-14: always 14 digits, zeros in front, as in
  /// [Gs1Content.gtin] and product databases. A UPC-E number is expanded
  /// to its UPC-A first: `01234565` is `00012345000065`.
  final String gtin;

  /// The number as printed under the barcode: 13 digits for EAN-13, 12
  /// for UPC-A, 8 for EAN-8 and UPC-E.
  final String number;

  /// The EAN-2 or EAN-5 add-on (issue number, price), if read.
  final String? addOn;

  /// The text as read.
  final String raw;

  /// [gtin] as 13 digits, or `null` if it does not start with a zero.
  String? get _ean13 =>
      gtin.length == 14 && gtin.startsWith('0') ? gtin.substring(1) : null;

  /// The ISBN-13 of a book (`978…`, `979…`), or `null`.
  String? get isbn13 => switch (_ean13) {
    final String ean when ean.startsWith('978') || ean.startsWith('979') => ean,
    _ => null,
  };

  /// The ISBN-10 of a book whose ISBN-13 starts with 978, or `null`: what
  /// older catalogues list.
  String? get isbn10 {
    final String? ean = _ean13;
    if (ean == null || !ean.startsWith('978')) {
      return null;
    }
    final String body = ean.substring(3, 12);
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += (10 - i) * (body.codeUnitAt(i) - 0x30);
    }
    final int check = (11 - sum % 11) % 11;
    return '$body${check == 10 ? 'X' : check}';
  }

  /// The ISSN of a periodical (`977…`), as `1234-5679`, or `null`.
  String? get issn {
    final String? ean = _ean13;
    if (ean == null || !ean.startsWith('977')) {
      return null;
    }
    final String body = ean.substring(3, 10);
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += (8 - i) * (body.codeUnitAt(i) - 0x30);
    }
    final int check = (11 - sum % 11) % 11;
    final String digits = '$body${check == 10 ? 'X' : check}';
    return '${digits.substring(0, 4)}-${digits.substring(4)}';
  }

  /// [raw], the text as read.
  @override
  String toPayload() => raw;

  @override
  List<ContentIssue> validate() => const <ContentIssue>[];

  @override
  bool operator ==(Object other) =>
      other is ProductContent &&
      other.gtin == gtin &&
      other.number == number &&
      other.addOn == addOn &&
      other.raw == raw;

  @override
  int get hashCode => Object.hash(gtin, number, addOn, raw);

  @override
  String toString() => 'ProductContent($number)';
}

/// One flight of a [BoardingPassContent].
@immutable
final class BoardingPassLeg {
  /// Creates a leg.
  const BoardingPassLeg({
    required this.bookingReference,
    required this.from,
    required this.to,
    required this.carrier,
    required this.flightNumber,
    required this.dayOfYear,
    required this.cabin,
    required this.seat,
    required this.sequenceNumber,
  });

  /// The booking reference (PNR), such as `ABC123`.
  final String bookingReference;

  /// The IATA code of the departure airport, such as `EVN`.
  final String from;

  /// The IATA code of the arrival airport.
  final String to;

  /// The IATA code of the airline, such as `LH`.
  final String carrier;

  /// The flight number without leading zeros, such as `1234` or `12A`.
  final String flightNumber;

  /// The day of the flight in its year (1–366), as the pass gives it;
  /// `null` if not given. The pass does not say which year.
  final int? dayOfYear;

  /// The compartment code, such as `Y` (economy) or `C` (business).
  final String cabin;

  /// The seat without leading zeros, such as `12A`; empty if not assigned.
  final String seat;

  /// The check-in sequence number without leading zeros.
  final String sequenceNumber;

  /// [dayOfYear] as a date in [year].
  DateTime? dateIn(int year) {
    final int? day = dayOfYear;
    return day == null ? null : DateTime(year, 1, day);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardingPassLeg &&
      other.bookingReference == bookingReference &&
      other.from == from &&
      other.to == to &&
      other.carrier == carrier &&
      other.flightNumber == flightNumber &&
      other.dayOfYear == dayOfYear &&
      other.cabin == cabin &&
      other.seat == seat &&
      other.sequenceNumber == sequenceNumber;

  @override
  int get hashCode => Object.hash(
    bookingReference,
    from,
    to,
    carrier,
    flightNumber,
    dayOfYear,
    cabin,
    seat,
    sequenceNumber,
  );

  @override
  String toString() => 'BoardingPassLeg($carrier $flightNumber $from–$to)';
}

/// An airline boarding pass (IATA Bar Coded Boarding Pass, Resolution 792):
/// the passenger and one leg per flight.
///
/// Only the mandatory fields are read; airline data is left in [raw].
/// [toPayload] returns [raw].
final class BoardingPassContent extends BarcodeContent {
  /// Creates boarding pass content.
  const BoardingPassContent({
    required this.passengerName,
    required this.legs,
    required this.raw,
    this.electronicTicket = false,
  });

  /// The name as printed, `SURNAME/GIVEN NAMES`.
  final String passengerName;

  /// The flights, at least one.
  final List<BoardingPassLeg> legs;

  /// Whether the ticket is electronic.
  final bool electronicTicket;

  /// The text as read.
  final String raw;

  /// [raw], the text as read.
  @override
  String toPayload() => raw;

  @override
  List<ContentIssue> validate() => const <ContentIssue>[];

  @override
  bool operator ==(Object other) =>
      other is BoardingPassContent &&
      other.passengerName == passengerName &&
      listEquals(other.legs, legs) &&
      other.electronicTicket == electronicTicket &&
      other.raw == raw;

  @override
  int get hashCode =>
      Object.hash(passengerName, Object.hashAll(legs), electronicTicket, raw);

  @override
  String toString() => 'BoardingPassContent($passengerName, $legs)';
}

/// A North American driver's license or ID card (AAMVA DL/ID standard,
/// the PDF417 on the back).
///
/// Only parsed. [toPayload] returns [raw]. The data is personal: keep it
/// only as long as the app needs it.
final class DriverLicenseContent extends BarcodeContent {
  /// Creates driver's license content.
  const DriverLicenseContent({
    required this.raw,
    this.licenseNumber,
    this.firstName,
    this.middleName,
    this.lastName,
    this.dateOfBirth,
    this.issueDate,
    this.expiryDate,
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
  });

  /// The license or ID number (`DAQ`).
  final String? licenseNumber;

  /// The first name (`DAC`, older cards `DCT`).
  final String? firstName;

  /// Middle names (`DAD`).
  final String? middleName;

  /// The family name (`DCS`).
  final String? lastName;

  /// The date of birth (`DBB`).
  final DateTime? dateOfBirth;

  /// The issue date (`DBD`).
  final DateTime? issueDate;

  /// The expiry date (`DBA`).
  final DateTime? expiryDate;

  /// The street address (`DAG`).
  final String? street;

  /// The city (`DAI`).
  final String? city;

  /// The state or province code, such as `CA` (`DAJ`).
  final String? state;

  /// The postal code (`DAK`), without trailing zeros of an unused ZIP+4.
  final String? postalCode;

  /// The country: `USA` or `CAN` (`DCG`).
  final String? country;

  /// The text as read.
  final String raw;

  /// [raw], the text as read.
  @override
  String toPayload() => raw;

  @override
  List<ContentIssue> validate() => const <ContentIssue>[];

  @override
  bool operator ==(Object other) =>
      other is DriverLicenseContent &&
      other.licenseNumber == licenseNumber &&
      other.firstName == firstName &&
      other.middleName == middleName &&
      other.lastName == lastName &&
      other.dateOfBirth == dateOfBirth &&
      other.issueDate == issueDate &&
      other.expiryDate == expiryDate &&
      other.street == street &&
      other.city == city &&
      other.state == state &&
      other.postalCode == postalCode &&
      other.country == country &&
      other.raw == raw;

  @override
  int get hashCode => Object.hash(
    licenseNumber,
    firstName,
    middleName,
    lastName,
    dateOfBirth,
    issueDate,
    expiryDate,
    street,
    city,
    state,
    postalCode,
    country,
    raw,
  );

  /// Without the personal data.
  @override
  String toString() => 'DriverLicenseContent(${state ?? country ?? ''})';
}

/// Where a vehicle was made, from the first character of its VIN.
enum VinRegion {
  /// `A`–`H`.
  africa,

  /// `J`–`R`.
  asia,

  /// `S`–`Z`.
  europe,

  /// `1`–`5`.
  northAmerica,

  /// `6`–`7`.
  oceania,

  /// `8`–`9`.
  southAmerica,
}

/// A vehicle identification number (ISO 3779): 17 characters, from the
/// Code 39 or Data Matrix on a windshield, door pillar or title.
///
/// Only what the number itself says: where the vehicle was made and the
/// manufacturer code (WMI); the model year and check digit follow North
/// American rules. [toPayload] returns [raw].
final class VinContent extends BarcodeContent {
  /// Creates VIN content.
  const VinContent({required this.vin, required this.raw});

  /// The 17 characters, upper case.
  final String vin;

  /// The text as read: some labels put an `I` (imported) before the VIN.
  final String raw;

  /// The World Manufacturer Identifier, the first three characters.
  String get wmi => vin.substring(0, 3);

  /// Where the vehicle was made.
  VinRegion get region => vinRegion(vin);

  /// Whether character 9 is the check digit North American VINs carry.
  /// Other VINs may use it for something else.
  bool get hasValidCheckDigit => vinCheckDigit(vin) == vin[8];

  /// The model year of a North American passenger vehicle, from character
  /// 10 and the 30-year cycle that character 7 picks; `null` if character
  /// 10 is not a year code.
  int? get modelYear => vinModelYear(vin);

  /// [raw], the text as read.
  @override
  String toPayload() => raw;

  @override
  List<ContentIssue> validate() => const <ContentIssue>[];

  @override
  bool operator ==(Object other) =>
      other is VinContent && other.vin == vin && other.raw == raw;

  @override
  int get hashCode => Object.hash(vin, raw);

  @override
  String toString() => 'VinContent($vin)';
}

/// The smart home standard of a [SmartHomeContent].
///
/// New standards are added in minor versions: a `switch` over it needs a
/// `default` (or `_`) case.
enum SmartHomePlatform {
  /// Matter (`MT:`).
  matter,

  /// Apple HomeKit (`X-HM://`).
  homeKit,
}

/// A smart home device's setup code: Matter (`MT:…`) or HomeKit
/// (`X-HM://…`), from the label on the device or its box.
///
/// Only parsed. [toPayload] returns [raw].
final class SmartHomeContent extends BarcodeContent {
  /// Creates smart home content.
  const SmartHomeContent({
    required this.platform,
    required this.setupCode,
    required this.raw,
    this.vendorId,
    this.productId,
    this.discriminator,
    this.category,
    this.setupId,
  });

  /// Matter or HomeKit.
  final SmartHomePlatform platform;

  /// The code a person would type instead: the Matter passcode as 8 digits
  /// (`20202021`), the HomeKit code as `123-45-678`.
  final String setupCode;

  /// The Matter vendor id.
  final int? vendorId;

  /// The Matter product id.
  final int? productId;

  /// The Matter discriminator (12 bits), which tells devices apart while
  /// pairing.
  final int? discriminator;

  /// The HomeKit accessory category: 5 is a light, 7 an outlet, 8 a
  /// switch, 9 a thermostat, 10 a sensor and so on.
  final int? category;

  /// The HomeKit setup id (4 characters).
  final String? setupId;

  /// The text as read.
  final String raw;

  /// [raw], the text as read.
  @override
  String toPayload() => raw;

  @override
  List<ContentIssue> validate() => const <ContentIssue>[];

  @override
  bool operator ==(Object other) =>
      other is SmartHomeContent &&
      other.platform == platform &&
      other.setupCode == setupCode &&
      other.vendorId == vendorId &&
      other.productId == productId &&
      other.discriminator == discriminator &&
      other.category == category &&
      other.setupId == setupId &&
      other.raw == raw;

  @override
  int get hashCode => Object.hash(
    platform,
    setupCode,
    vendorId,
    productId,
    discriminator,
    category,
    setupId,
    raw,
  );

  /// Without the setup code.
  @override
  String toString() => 'SmartHomeContent(${platform.name})';
}
