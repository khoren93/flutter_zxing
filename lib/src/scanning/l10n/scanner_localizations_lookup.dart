import 'package:flutter/widgets.dart';

import '../../content/barcode_content.dart';
import '../../content/link_service.dart';
import '../ui/scanner_theme.dart';
import 'scanner_localizations.dart';

/// [ScannerLocalizations.of]: the texts of the nearest [ScannerScope], else
/// those of a registered `ScannerLocalizations.delegate`, else the built-in
/// translation for the locale of [context], else English.
ScannerLocalizations scannerLocalizationsOf(BuildContext context) {
  final ScannerLocalizations? given = context
      .dependOnInheritedWidgetOfExactType<ScannerScope>()
      ?.texts;
  if (given != null) {
    return given;
  }
  final ScannerLocalizations? registered =
      Localizations.of<ScannerLocalizations>(context, ScannerLocalizations);
  if (registered != null) {
    return registered;
  }
  return builtInScannerLocalizations(Localizations.maybeLocaleOf(context));
}

/// The built-in translation for [locale], English for a language without
/// one or for no locale. One instance per locale.
ScannerLocalizations builtInScannerLocalizations(Locale? locale) {
  final Locale chosen =
      locale != null && ScannerLocalizations.delegate.isSupported(locale)
      ? locale
      : const Locale('en');
  return _builtIn.putIfAbsent(chosen, () => lookupScannerLocalizations(chosen));
}

final Map<Locale, ScannerLocalizations> _builtIn =
    <Locale, ScannerLocalizations>{};

/// Texts made of content, on top of the generated messages.
extension ScannerLocalizationsContent on ScannerLocalizations {
  /// The kind of [content], as shown above a result's title.
  /// A link to a known service is named after it ("Instagram").
  String kindOf(BarcodeContent content) => switch (content) {
    UrlContent(:final LinkService service) => service.displayName,
    UrlContent() => link,
    WifiContent() => wifi,
    ContactContent() => contact,
    EventContent() => event,
    EmailContent() => email,
    PhoneContent(type: CallType.voice) => phone,
    PhoneContent() => faceTime,
    SmsContent() => sms,
    GeoContent() => location,
    PaymentContent() => payment,
    OtpContent() => otp,
    EsimContent() => esim,
    CryptoContent() => crypto,
    WifiDppContent() => wifiDevice,
    SmartHomeContent() => smartHome,
    BoardingPassContent() => boardingPass,
    DriverLicenseContent() => driverLicense,
    VinContent() => vehicle,
    ProductContent(isbn13: null, issn: null) => product,
    ProductContent() => book,
    Gs1Content() => gs1,
    BinaryContent() => binary,
    // TextContent, and kinds added in later versions.
    _ => text,
  };

  /// A date without its year, as the boarding pass sheet shows it:
  /// "Nov 14", «14 нояб.» ([dayMonth] with [monthShort]).
  String dayAndMonth(DateTime date) => dayMonth(date.day, _month(date));

  /// A full date, as the sheets show expiry, best-before and birth dates:
  /// "Aug 31, 1977", «31 авг. 1977» ([dayMonthYear] with [monthShort]).
  ///
  /// ```dart
  /// Text(ScannerLocalizations.of(context).fullDate(license.expiryDate!))
  /// ```
  String fullDate(DateTime date) =>
      dayMonthYear(date.day, _month(date), date.year);

  String _month(DateTime date) => monthShort(_months[date.month - 1]);

  /// How a Wi‑Fi network is secured, in plain words: "Open network",
  /// "WEP", "WPA", "WPA3", "Enterprise", "Secured" ([wifiSecurity]).
  ///
  /// ```dart
  /// Text(ScannerLocalizations.of(context).wifiSecurityOf(wifi.security))
  /// ```
  String wifiSecurityOf(WifiSecurity security) => wifiSecurity(security.name);

  /// Where a vehicle was made: "North America" ([vinRegion]).
  String vinRegionOf(VinRegion region) => vinRegion(region.name);

  /// A payment amount with its currency, as the payment sheet shows it:
  /// "12.50 EUR" ([amount]); [anyAmount] for a code without one, whose
  /// payer types it in. [amount] is in the main unit with a dot, as
  /// [PaymentContent.amount] gives it.
  ///
  /// ```dart
  /// Text(ScannerLocalizations.of(context)
  ///     .amountOf(payment.amount, payment.currency))
  /// ```
  String amountOf(String? amount, String? currency) =>
      switch ((amount, currency)) {
        (null, _) => anyAmount,
        (final String amount, null) => amount,
        (final String amount, final String currency) => this.amount(
          amount,
          currency,
        ),
      };
}

/// The `month` of [ScannerLocalizations.monthShort].
const List<String> _months = <String>[
  'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
