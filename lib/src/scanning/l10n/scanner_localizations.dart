import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

import 'scanner_localizations_de.dart';
import 'scanner_localizations_en.dart';
import 'scanner_localizations_lookup.dart';
import 'scanner_localizations_es.dart';
import 'scanner_localizations_fr.dart';
import 'scanner_localizations_ru.dart';
import 'scanner_localizations_zh.dart';

// ignore_for_file: type=lint

/// The texts of the scanner widgets: button labels for screen readers,
/// states, result sheets, the templates' titles and hints. Built in:
/// English, Russian, German, Spanish, French and Chinese (simplified),
/// chosen by the app's locale with no setup.
///
/// Get them with [ScannerLocalizations.of]. To change a text, subclass the
/// built-in translation and give it to a `ScannerScope`:
///
/// ```dart
/// class MyTexts extends ScannerLocalizationsEn {
///   @override
///   String get scanAgain => 'Next ticket';
/// }
///
/// ScannerScope(texts: MyTexts(), child: ...)
/// ```
///
/// Generated from `lib/l10n/scanner_*.arb` by `make l10n`; do not edit.
abstract class ScannerLocalizations {
  /// Texts in [locale], whose dates and plurals follow it: a subclass for
  /// another language passes that language's code.
  ScannerLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  /// The canonical name of the locale, such as `ru` or `en_US`.
  final String localeName;

  /// The texts for [context]: those given to the nearest `ScannerScope`,
  /// else those of [delegate] if the app registered it, else the built-in
  /// translation for the app's locale, English for a language without one.
  static ScannerLocalizations of(BuildContext context) =>
      scannerLocalizationsOf(context);

  /// The texts as a [LocalizationsDelegate], for an app that lists every
  /// delegate; [of] finds the texts without it.
  static const LocalizationsDelegate<ScannerLocalizations> delegate =
      _ScannerLocalizationsDelegate();

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ru'),
    Locale('zh'),
  ];

  /// Label of the close button.
  ///
  /// In en, this message translates to:
  /// **'Close the scanner'**
  String get close;

  /// Label of the torch button while the torch is off.
  ///
  /// In en, this message translates to:
  /// **'Turn on the torch'**
  String get torchOn;

  /// Label of the torch button while the torch is on.
  ///
  /// In en, this message translates to:
  /// **'Turn off the torch'**
  String get torchOff;

  /// Label of the switch camera button.
  ///
  /// In en, this message translates to:
  /// **'Switch camera'**
  String get switchCamera;

  /// Label of the photo button.
  ///
  /// In en, this message translates to:
  /// **'Read a code from a photo'**
  String get pickImage;

  /// Label of the zoom buttons.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get zoom;

  /// Text of the automatic zoom button, before the zoom presets.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get autoZoom;

  /// Label of the automatic zoom button while it is off.
  ///
  /// In en, this message translates to:
  /// **'Turn on automatic zoom'**
  String get autoZoomOn;

  /// Label of the automatic zoom button while it is on.
  ///
  /// In en, this message translates to:
  /// **'Turn off automatic zoom'**
  String get autoZoomOff;

  /// Shown while the camera starts.
  ///
  /// In en, this message translates to:
  /// **'Starting the camera…'**
  String get starting;

  /// Title of the "no camera permission" card.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get permissionTitle;

  /// Text of the "no camera permission" card.
  ///
  /// In en, this message translates to:
  /// **'Turn on camera access for this app in Settings to scan codes.'**
  String get permissionMessage;

  /// Title of the "camera not available" card.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available'**
  String get unavailableTitle;

  /// Text of the "camera not available" card.
  ///
  /// In en, this message translates to:
  /// **'Another app may be using it, or this device has none.'**
  String get unavailableMessage;

  /// Text of the "camera not available" card when another app uses the camera (CameraInUseException).
  ///
  /// In en, this message translates to:
  /// **'Another app is using the camera. Close it and try again.'**
  String get inUseMessage;

  /// Text of the "camera not available" card where cameras cannot be used at all (CameraUnsupportedException: a web page over http).
  ///
  /// In en, this message translates to:
  /// **'Camera access is not available here. On the web, the page must be opened over https.'**
  String get unsupportedMessage;

  /// Added to the error cards when a photo can be read instead.
  ///
  /// In en, this message translates to:
  /// **'You can still read a code from a photo.'**
  String get photoFallback;

  /// The button that opens the app's settings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// The button that opens the camera again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// The button that reads a photo instead of the camera.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get choosePhoto;

  /// Shown when a photo has no code.
  ///
  /// In en, this message translates to:
  /// **'No code found in this photo'**
  String get noCodeInPhoto;

  /// Leaves a photo whose codes ScannerTemplate.pick shows.
  ///
  /// In en, this message translates to:
  /// **'Back to the camera'**
  String get backToCamera;

  /// Closes the result of a code picked in ScannerTemplate.pick.
  ///
  /// In en, this message translates to:
  /// **'Back to the codes'**
  String get backToCodes;

  /// The button that copies a code's text.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// The copy button after copying.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// The button that hides a result and scans the next code.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// The button that ends a list of scanned codes.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Above the number of scanned codes.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get scanned;

  /// An empty list of scanned codes.
  ///
  /// In en, this message translates to:
  /// **'Codes you scan appear here'**
  String get emptyList;

  /// The number of scanned codes: "3 items".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String itemCount(int count);

  /// The size of binary data: "120 bytes".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} byte} other{{count} bytes}}'**
  String byteCount(int count);

  /// The kind of a UrlContent.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// The kind of a WifiContent.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi network'**
  String get wifi;

  /// A Wi‑Fi network whose password is in the code.
  ///
  /// In en, this message translates to:
  /// **'password in the code'**
  String get wifiPassword;

  /// How a Wi‑Fi network is secured, in plain words; security is the name of a WifiSecurity value (none, wep, wpa, wpa3, enterprise; other for unknown). Apps call wifiSecurityOf(WifiSecurity). The result sheet leaves WifiSecurity.unknown out.
  ///
  /// In en, this message translates to:
  /// **'{security, select, none{Open network} wep{WEP} wpa{WPA} wpa3{WPA3} enterprise{Enterprise} other{Secured}}'**
  String wifiSecurity(String security);

  /// The kind of a ContactContent.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// The kind of an EventContent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get event;

  /// The kind of an EmailContent.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// The kind of a PhoneContent.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// The kind of an SmsContent.
  ///
  /// In en, this message translates to:
  /// **'Text message'**
  String get sms;

  /// The kind of a GeoContent.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// The kind of a Gs1Content.
  ///
  /// In en, this message translates to:
  /// **'GS1'**
  String get gs1;

  /// The kind of a PhoneContent with CallType.faceTime or CallType.faceTimeAudio.
  ///
  /// In en, this message translates to:
  /// **'FaceTime'**
  String get faceTime;

  /// The kind of a PaymentContent.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// The kind of a OtpContent.
  ///
  /// In en, this message translates to:
  /// **'One-time password'**
  String get otp;

  /// The kind of a EsimContent.
  ///
  /// In en, this message translates to:
  /// **'eSIM'**
  String get esim;

  /// The kind of a CryptoContent.
  ///
  /// In en, this message translates to:
  /// **'Crypto payment'**
  String get crypto;

  /// The kind of a WifiDppContent.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi device'**
  String get wifiDevice;

  /// The kind of a SmartHomeContent.
  ///
  /// In en, this message translates to:
  /// **'Smart home device'**
  String get smartHome;

  /// The kind of a BoardingPassContent.
  ///
  /// In en, this message translates to:
  /// **'Boarding pass'**
  String get boardingPass;

  /// The kind of a DriverLicenseContent.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s license'**
  String get driverLicense;

  /// The kind of a VinContent.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// The kind of a ProductContent.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// The kind of a ProductContent with an ISBN or ISSN.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get book;

  /// The label of a hidden secret, such as an OtpContent key.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get secret;

  /// The button that shows a hidden secret.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// The button that hides a shown secret again.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hide;

  /// The label of an OtpContent's type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get otpType;

  /// An OtpContent of OtpType.totp.
  ///
  /// In en, this message translates to:
  /// **'Time-based'**
  String get otpTimeBased;

  /// An OtpContent of OtpType.hotp.
  ///
  /// In en, this message translates to:
  /// **'Counter-based'**
  String get otpCounterBased;

  /// The label of OtpContent.digits.
  ///
  /// In en, this message translates to:
  /// **'Digits'**
  String get otpDigits;

  /// The label of OtpContent.period.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get otpPeriod;

  /// The label of OtpContent.counter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get otpCounter;

  /// A number of seconds: "30 s".
  ///
  /// In en, this message translates to:
  /// **'{seconds} s'**
  String seconds(int seconds);

  /// The label of EsimContent.matchingId.
  ///
  /// In en, this message translates to:
  /// **'Matching ID'**
  String get matchingId;

  /// The label of EsimContent.confirmationCodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Confirmation code'**
  String get confirmationCode;

  /// A confirmation code is needed.
  ///
  /// In en, this message translates to:
  /// **'Needed'**
  String get needed;

  /// The title of a SmartHomeContent.
  ///
  /// In en, this message translates to:
  /// **'Setup code'**
  String get setupCode;

  /// The label of SmartHomeContent.vendorId.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendorId;

  /// The label of SmartHomeContent.productId.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get productId;

  /// The label of SmartHomeContent.discriminator.
  ///
  /// In en, this message translates to:
  /// **'Discriminator'**
  String get discriminator;

  /// The label of SmartHomeContent.category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// The label of SmartHomeContent.setupId.
  ///
  /// In en, this message translates to:
  /// **'Setup ID'**
  String get setupId;

  /// The label of ProductContent.gtin.
  ///
  /// In en, this message translates to:
  /// **'GTIN'**
  String get gtin;

  /// The label of ProductContent.addOn.
  ///
  /// In en, this message translates to:
  /// **'Add-on'**
  String get addOn;

  /// The label of BoardingPassContent.passengerName.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passenger;

  /// The label of a boarding pass's date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// The label of BoardingPassLeg.seat.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get seat;

  /// The label of BoardingPassLeg.cabin.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get cabin;

  /// The label of BoardingPassLeg.bookingReference.
  ///
  /// In en, this message translates to:
  /// **'Booking'**
  String get booking;

  /// The label of BoardingPassLeg.sequenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get sequence;

  /// Which leg of a boarding pass the sheet shows: "Flight 1 of 2".
  ///
  /// In en, this message translates to:
  /// **'Flight {flight} of {count}'**
  String flightOf(int flight, int count);

  /// The label of DriverLicenseContent.licenseNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get licenseNumber;

  /// The label of DriverLicenseContent.dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get born;

  /// The label of DriverLicenseContent.expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// The label of DriverLicenseContent.city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// The label of DriverLicenseContent.state.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// The label of DriverLicenseContent.country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// A document past its expiry date.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// The label of VinContent.wmi.
  ///
  /// In en, this message translates to:
  /// **'Maker code'**
  String get makerCode;

  /// The label of VinContent.modelYear.
  ///
  /// In en, this message translates to:
  /// **'Model year'**
  String get modelYear;

  /// The label of VinContent.hasValidCheckDigit.
  ///
  /// In en, this message translates to:
  /// **'Check digit'**
  String get checkDigit;

  /// A check digit that is right.
  ///
  /// In en, this message translates to:
  /// **'Valid'**
  String get valid;

  /// The label of WifiDppContent.macAddress.
  ///
  /// In en, this message translates to:
  /// **'MAC'**
  String get macAddress;

  /// The label of WifiDppContent.channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// The short name of a month, as dates use it inside dayMonth and dayMonthYear: "Nov". month is jan, feb, mar, apr, may, jun, jul, aug, sep, oct, nov or dec. In languages that decline month names, the form a date uses (Russian: «нояб.», genitive).
  ///
  /// In en, this message translates to:
  /// **'{month, select, jan{Jan} feb{Feb} mar{Mar} apr{Apr} may{May} jun{Jun} jul{Jul} aug{Aug} sep{Sep} oct{Oct} nov{Nov} dec{Dec} other{}}'**
  String monthShort(String month);

  /// A date without its year, as the boarding pass sheet shows it: "Nov 14". month is the text of monthShort. Apps call dayAndMonth(DateTime).
  ///
  /// In en, this message translates to:
  /// **'{month} {day}'**
  String dayMonth(int day, String month);

  /// A full date, as the sheets show expiry, best-before and birth dates: "Aug 31, 1977". month is the text of monthShort. Apps call fullDate(DateTime).
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String dayMonthYear(int day, String month, int year);

  /// Where a vehicle was made; region is the name of a VinRegion value. Apps call vinRegionOf(VinRegion).
  ///
  /// In en, this message translates to:
  /// **'{region, select, africa{Africa} asia{Asia} europe{Europe} northAmerica{North America} oceania{Oceania} southAmerica{South America} other{Unknown}}'**
  String vinRegion(String region);

  /// A payment amount with its currency, as the payment sheet shows it: "12.50 EUR". amount is in the main unit with a dot, as PaymentContent.amount gives it. Apps call amountOf(amount, currency), which also covers a missing amount or currency.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String amount(String amount, String currency);

  /// A payment amount the payer types in: the code has none.
  ///
  /// In en, this message translates to:
  /// **'Any amount'**
  String get anyAmount;

  /// A payment code without an amount.
  ///
  /// In en, this message translates to:
  /// **'The payer enters the amount'**
  String get payerEntersAmount;

  /// A payment code for any number of payments (EMVCo static).
  ///
  /// In en, this message translates to:
  /// **'Reusable'**
  String get reusable;

  /// The copy button of a payment to an IBAN.
  ///
  /// In en, this message translates to:
  /// **'Copy IBAN'**
  String get copyIban;

  /// The copy button of a payment to an account number.
  ///
  /// In en, this message translates to:
  /// **'Copy account'**
  String get copyAccount;

  /// The copy button of a UPI payment.
  ///
  /// In en, this message translates to:
  /// **'Copy UPI ID'**
  String get copyUpiId;

  /// The copy button of a PIX payment.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get copyPixKey;

  /// The label of an IBAN.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// The label of a bank's BIC.
  ///
  /// In en, this message translates to:
  /// **'BIC'**
  String get bic;

  /// The label of an account number.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountNumber;

  /// The label of a payment reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get paymentReference;

  /// The label of a payee's address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// The label of who pays a Swiss QR-bill.
  ///
  /// In en, this message translates to:
  /// **'Payable by'**
  String get payableBy;

  /// The label of a bank's name.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bank;

  /// The label of a Russian taxpayer number.
  ///
  /// In en, this message translates to:
  /// **'INN'**
  String get inn;

  /// The label of a Russian tax registration reason code.
  ///
  /// In en, this message translates to:
  /// **'KPP'**
  String get kpp;

  /// The label of a UPI address.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get upiId;

  /// The label of a PIX key.
  ///
  /// In en, this message translates to:
  /// **'PIX key'**
  String get pixKey;

  /// The label of a payment's transaction id.
  ///
  /// In en, this message translates to:
  /// **'Transaction'**
  String get transaction;

  /// The label of a Czech variable symbol.
  ///
  /// In en, this message translates to:
  /// **'Variable symbol'**
  String get variableSymbol;

  /// The kind of a BinaryContent.
  ///
  /// In en, this message translates to:
  /// **'Binary data'**
  String get binary;

  /// The kind of a TextContent.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// A batch or lot number (GS1 AI 10).
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get batch;

  /// A serial number (GS1 AI 21).
  ///
  /// In en, this message translates to:
  /// **'Serial'**
  String get serial;

  /// The shipping container code of a pallet or parcel (GS1 AI 00).
  ///
  /// In en, this message translates to:
  /// **'SSCC'**
  String get sscc;

  /// How many items a logistic unit holds (GS1 AI 37).
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// A best before date (GS1 AI 15).
  ///
  /// In en, this message translates to:
  /// **'Best before'**
  String get bestBefore;

  /// The kind above a card read by ScannerTemplate.loyalty.
  ///
  /// In en, this message translates to:
  /// **'Loyalty card'**
  String get loyaltyCard;

  /// The title of a card number.
  ///
  /// In en, this message translates to:
  /// **'Card number'**
  String get cardNumber;

  /// Above an accepted code without a title of its own (ScanVerdict.accept).
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// Above a code to look at without a title of its own (ScanVerdict.warn).
  ///
  /// In en, this message translates to:
  /// **'Check this code'**
  String get needsAttention;

  /// Above a refused code without a title of its own (ScanVerdict.reject).
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get rejected;

  /// The counter of accepted codes (ScannerTemplate.counter): "12 checked in".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} checked in}}'**
  String checkedIn(int count);

  /// How many codes ScannerTemplate.pick shows labels for: "3 codes".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} code} other{{count} codes}}'**
  String codesInView(int count);

  /// Hint for screen readers on a code's label in ScannerTemplate.pick.
  ///
  /// In en, this message translates to:
  /// **'Pick this code'**
  String get pickCode;

  /// Label of ScanFieldButton for screen readers.
  ///
  /// In en, this message translates to:
  /// **'Scan a code'**
  String get scanCode;

  /// The hint of ScannerTemplate.minimal.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a code'**
  String get hintCode;

  /// The hint of ScannerTemplate.content.
  ///
  /// In en, this message translates to:
  /// **'Point at a QR code'**
  String get hintQrCode;

  /// The hint of ScannerTemplate.product.
  ///
  /// In en, this message translates to:
  /// **'Point at the barcode'**
  String get hintBarcode;

  /// The hint of ScannerTemplate.small.
  ///
  /// In en, this message translates to:
  /// **'Move closer'**
  String get hintCloser;

  /// The hint of ScannerTemplate.checkIn.
  ///
  /// In en, this message translates to:
  /// **'Point at the ticket'**
  String get hintTicket;

  /// The hint of ScannerTemplate.pharma.
  ///
  /// In en, this message translates to:
  /// **'Point at the Data Matrix'**
  String get hintDataMatrix;

  /// The hint of ScannerTemplate.pick.
  ///
  /// In en, this message translates to:
  /// **'Tap a code'**
  String get hintPick;

  /// The hint of ScannerTemplate.kiosk.
  ///
  /// In en, this message translates to:
  /// **'Hold the code up to the camera'**
  String get hintKiosk;

  /// The hint of ScannerTemplate.vin.
  ///
  /// In en, this message translates to:
  /// **'Windshield or door pillar'**
  String get hintVin;

  /// The hint of ScannerTemplate.loyalty.
  ///
  /// In en, this message translates to:
  /// **'Point at the card\'s barcode'**
  String get hintCard;

  /// The hint of the scanner ScanFieldButton opens.
  ///
  /// In en, this message translates to:
  /// **'Point at the code'**
  String get hintField;

  /// The title of ScannerTemplate.payment.
  ///
  /// In en, this message translates to:
  /// **'Pay with QR'**
  String get titlePayment;

  /// The title of ScannerTemplate.ticket and ScannerTemplate.kiosk.
  ///
  /// In en, this message translates to:
  /// **'Scan your ticket'**
  String get titleTicket;

  /// The title of ScannerTemplate.signIn.
  ///
  /// In en, this message translates to:
  /// **'Scan to sign in'**
  String get titleSignIn;
}

class _ScannerLocalizationsDelegate
    extends LocalizationsDelegate<ScannerLocalizations> {
  const _ScannerLocalizationsDelegate();

  @override
  Future<ScannerLocalizations> load(Locale locale) {
    return SynchronousFuture<ScannerLocalizations>(
      lookupScannerLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_ScannerLocalizationsDelegate old) => false;
}

ScannerLocalizations lookupScannerLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return ScannerLocalizationsDe();
    case 'en':
      return ScannerLocalizationsEn();
    case 'es':
      return ScannerLocalizationsEs();
    case 'fr':
      return ScannerLocalizationsFr();
    case 'ru':
      return ScannerLocalizationsRu();
    case 'zh':
      return ScannerLocalizationsZh();
  }

  throw FlutterError(
    'ScannerLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
