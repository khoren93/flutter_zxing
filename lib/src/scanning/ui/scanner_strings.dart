import 'package:flutter/widgets.dart';

import '../../content/barcode_content.dart';
import '../../content/link_service.dart';
import 'scanner_theme.dart';

/// The texts of the scanner widgets: button labels for screen readers,
/// states, result sheets. English by default; pass your translations to
/// `BarcodeScanner(strings: ...)`:
///
/// ```dart
/// BarcodeScanner(
///   strings: ScannerStrings(
///     close: 'Scanner schließen',
///     starting: 'Kamera wird gestartet…',
///     itemCount: (n) => n == 1 ? '1 Artikel' : '$n Artikel',
///   ),
/// )
/// ```
@immutable
final class ScannerStrings {
  /// Creates the texts; every one has an English default.
  const ScannerStrings({
    this.close = 'Close the scanner',
    this.torchOn = 'Turn on the torch',
    this.torchOff = 'Turn off the torch',
    this.switchCamera = 'Switch camera',
    this.pickImage = 'Read a code from a photo',
    this.zoom = 'Zoom',
    this.autoZoom = 'Auto',
    this.autoZoomOn = 'Turn on automatic zoom',
    this.autoZoomOff = 'Turn off automatic zoom',
    this.starting = 'Starting the camera…',
    this.permissionTitle = 'Camera access is off',
    this.permissionMessage =
        'Turn on camera access for this app in Settings to scan codes.',
    this.unavailableTitle = "The camera isn't available",
    this.unavailableMessage =
        'Another app may be using it, or this device has none.',
    this.photoFallback = 'You can still read a code from a photo.',
    this.openSettings = 'Open Settings',
    this.tryAgain = 'Try again',
    this.choosePhoto = 'Choose a photo',
    this.noCodeInPhoto = 'No code found in this photo',
    this.backToCamera = 'Back to the camera',
    this.backToCodes = 'Back to the codes',
    this.copy = 'Copy',
    this.copied = 'Copied',
    this.scanAgain = 'Scan again',
    this.done = 'Done',
    this.scanned = 'Scanned',
    this.emptyList = 'Codes you scan appear here',
    this.itemCount = _itemCount,
    this.byteCount = _byteCount,
    this.link = 'Link',
    this.wifi = 'Wi‑Fi network',
    this.wifiOpen = 'Open network',
    this.wifiPassword = 'password in the code',
    this.contact = 'Contact',
    this.event = 'Event',
    this.email = 'Email',
    this.phone = 'Phone',
    this.sms = 'Text message',
    this.location = 'Location',
    this.gs1 = 'GS1',
    this.faceTime = 'FaceTime',
    this.payment = 'Payment',
    this.otp = 'One-time password',
    this.esim = 'eSIM',
    this.crypto = 'Crypto payment',
    this.wifiDevice = 'Wi‑Fi device',
    this.smartHome = 'Smart home device',
    this.boardingPass = 'Boarding pass',
    this.driverLicense = "Driver's license",
    this.vehicle = 'Vehicle',
    this.product = 'Product',
    this.book = 'Book',
    this.secret = 'Secret',
    this.show = 'Show',
    this.hide = 'Hide',
    this.otpType = 'Type',
    this.otpTimeBased = 'Time-based',
    this.otpCounterBased = 'Counter-based',
    this.otpDigits = 'Digits',
    this.otpPeriod = 'Every',
    this.otpCounter = 'Counter',
    this.seconds = _seconds,
    this.matchingId = 'Matching ID',
    this.confirmationCode = 'Confirmation code',
    this.needed = 'Needed',
    this.setupCode = 'Setup code',
    this.vendorId = 'Vendor',
    this.productId = 'Product',
    this.discriminator = 'Discriminator',
    this.category = 'Category',
    this.setupId = 'Setup ID',
    this.gtin = 'GTIN',
    this.addOn = 'Add-on',
    this.passenger = 'Passenger',
    this.date = 'Date',
    this.seat = 'Seat',
    this.cabin = 'Class',
    this.booking = 'Booking',
    this.sequence = 'Sequence',
    this.flightOf = _flightOf,
    this.licenseNumber = 'Number',
    this.born = 'Born',
    this.expires = 'Expires',
    this.city = 'City',
    this.state = 'State',
    this.country = 'Country',
    this.expired = 'Expired',
    this.makerCode = 'Maker code',
    this.modelYear = 'Model year',
    this.checkDigit = 'Check digit',
    this.valid = 'Valid',
    this.macAddress = 'MAC',
    this.channels = 'Channels',
    this.dayAndMonth = _dayAndMonth,
    this.fullDate = _fullDate,
    this.vinRegion = _vinRegion,
    this.money = _money,
    this.payerEntersAmount = 'The payer enters the amount',
    this.reusable = 'Reusable',
    this.copyIban = 'Copy IBAN',
    this.copyAccount = 'Copy account',
    this.copyUpiId = 'Copy UPI ID',
    this.copyPixKey = 'Copy key',
    this.iban = 'IBAN',
    this.bic = 'BIC',
    this.accountNumber = 'Account',
    this.paymentReference = 'Reference',
    this.address = 'Address',
    this.payableBy = 'Payable by',
    this.bank = 'Bank',
    this.inn = 'INN',
    this.kpp = 'KPP',
    this.upiId = 'UPI ID',
    this.pixKey = 'PIX key',
    this.transaction = 'Transaction',
    this.variableSymbol = 'Variable symbol',
    this.binary = 'Binary data',
    this.text = 'Text',
    this.batch = 'Batch',
    this.serial = 'Serial',
    this.sscc = 'SSCC',
    this.quantity = 'Quantity',
    this.bestBefore = 'Best before',
    this.loyaltyCard = 'Loyalty card',
    this.cardNumber = 'Card number',
    this.accepted = 'Accepted',
    this.needsAttention = 'Check this code',
    this.rejected = 'Not accepted',
    this.checkedIn = _checkedIn,
    this.codesInView = _codesInView,
    this.pickCode = 'Pick this code',
    this.scanCode = 'Scan a code',
  });

  /// The strings of the nearest [ScannerScope], or the English defaults.
  static ScannerStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScannerScope>()?.strings ??
      const ScannerStrings();

  /// Label of the close button.
  final String close;

  /// Label of the torch button while the torch is off.
  final String torchOn;

  /// Label of the torch button while the torch is on.
  final String torchOff;

  /// Label of the switch camera button.
  final String switchCamera;

  /// Label of the photo button.
  final String pickImage;

  /// Label of the zoom buttons.
  final String zoom;

  /// Text of the automatic zoom button, before the zoom presets.
  final String autoZoom;

  /// Label of the automatic zoom button while it is off.
  final String autoZoomOn;

  /// Label of the automatic zoom button while it is on.
  final String autoZoomOff;

  /// Shown while the camera starts.
  final String starting;

  /// Title of the "no camera permission" card.
  final String permissionTitle;

  /// Text of the "no camera permission" card.
  final String permissionMessage;

  /// Title of the "camera not available" card.
  final String unavailableTitle;

  /// Text of the "camera not available" card.
  final String unavailableMessage;

  /// Added to the error cards when a photo can be read instead.
  final String photoFallback;

  /// The button that opens the app's settings.
  final String openSettings;

  /// The button that opens the camera again.
  final String tryAgain;

  /// The button that reads a photo instead of the camera.
  final String choosePhoto;

  /// Shown when a photo has no code.
  final String noCodeInPhoto;

  /// Leaves a photo whose codes `ScannerTemplate.pick` shows.
  final String backToCamera;

  /// Closes the result of a code picked in `ScannerTemplate.pick`.
  final String backToCodes;

  /// The button that copies a code's text.
  final String copy;

  /// The copy button after copying.
  final String copied;

  /// The button that hides a result and scans the next code.
  final String scanAgain;

  /// The button that ends a list of scanned codes.
  final String done;

  /// Above the number of scanned codes.
  final String scanned;

  /// An empty list of scanned codes.
  final String emptyList;

  /// The number of scanned codes ("3 items").
  final String Function(int count) itemCount;

  /// The size of binary data ("120 bytes").
  final String Function(int count) byteCount;

  /// The kind of a [UrlContent].
  final String link;

  /// The kind of a [WifiContent].
  final String wifi;

  /// A Wi‑Fi network without a password.
  final String wifiOpen;

  /// A Wi‑Fi network whose password is in the code.
  final String wifiPassword;

  /// The kind of a [ContactContent].
  final String contact;

  /// The kind of an [EventContent].
  final String event;

  /// The kind of an [EmailContent].
  final String email;

  /// The kind of a [PhoneContent].
  final String phone;

  /// The kind of an [SmsContent].
  final String sms;

  /// The kind of a [GeoContent].
  final String location;

  /// The kind of a [Gs1Content].
  final String gs1;

  /// The kind of a [PhoneContent] with [CallType.faceTime] or [CallType.faceTimeAudio].
  final String faceTime;

  /// The kind of a [PaymentContent].
  final String payment;

  /// The kind of a [OtpContent].
  final String otp;

  /// The kind of a [EsimContent].
  final String esim;

  /// The kind of a [CryptoContent].
  final String crypto;

  /// The kind of a [WifiDppContent].
  final String wifiDevice;

  /// The kind of a [SmartHomeContent].
  final String smartHome;

  /// The kind of a [BoardingPassContent].
  final String boardingPass;

  /// The kind of a [DriverLicenseContent].
  final String driverLicense;

  /// The kind of a [VinContent].
  final String vehicle;

  /// The kind of a [ProductContent].
  final String product;

  /// The kind of a [ProductContent] with an ISBN or ISSN.
  final String book;

  /// The label of a hidden secret, such as an [OtpContent] key.
  final String secret;

  /// The button that shows a hidden secret.
  final String show;

  /// The button that hides a shown secret again.
  final String hide;

  /// The label of an [OtpContent]'s type.
  final String otpType;

  /// An [OtpContent] of [OtpType.totp].
  final String otpTimeBased;

  /// An [OtpContent] of [OtpType.hotp].
  final String otpCounterBased;

  /// The label of [OtpContent.digits].
  final String otpDigits;

  /// The label of [OtpContent.period].
  final String otpPeriod;

  /// The label of [OtpContent.counter].
  final String otpCounter;

  /// A number of seconds: "30 s".
  final String Function(int seconds) seconds;

  /// The label of [EsimContent.matchingId].
  final String matchingId;

  /// The label of [EsimContent.confirmationCodeRequired].
  final String confirmationCode;

  /// A confirmation code is needed.
  final String needed;

  /// The title of a [SmartHomeContent].
  final String setupCode;

  /// The label of [SmartHomeContent.vendorId].
  final String vendorId;

  /// The label of [SmartHomeContent.productId].
  final String productId;

  /// The label of [SmartHomeContent.discriminator].
  final String discriminator;

  /// The label of [SmartHomeContent.category].
  final String category;

  /// The label of [SmartHomeContent.setupId].
  final String setupId;

  /// The label of [ProductContent.gtin].
  final String gtin;

  /// The label of [ProductContent.addOn].
  final String addOn;

  /// The label of [BoardingPassContent.passengerName].
  final String passenger;

  /// The label of a boarding pass's date.
  final String date;

  /// The label of [BoardingPassLeg.seat].
  final String seat;

  /// The label of [BoardingPassLeg.cabin].
  final String cabin;

  /// The label of [BoardingPassLeg.bookingReference].
  final String booking;

  /// The label of [BoardingPassLeg.sequenceNumber].
  final String sequence;

  /// Which leg of a pass the sheet shows: "Flight 1 of 2".
  final String Function(int flight, int count) flightOf;

  /// The label of [DriverLicenseContent.licenseNumber].
  final String licenseNumber;

  /// The label of [DriverLicenseContent.dateOfBirth].
  final String born;

  /// The label of [DriverLicenseContent.expiryDate].
  final String expires;

  /// The label of [DriverLicenseContent.city].
  final String city;

  /// The label of [DriverLicenseContent.state].
  final String state;

  /// The label of [DriverLicenseContent.country].
  final String country;

  /// A document past its expiry date.
  final String expired;

  /// The label of [VinContent.wmi].
  final String makerCode;

  /// The label of [VinContent.modelYear].
  final String modelYear;

  /// The label of [VinContent.hasValidCheckDigit].
  final String checkDigit;

  /// A check digit that is right.
  final String valid;

  /// The label of [WifiDppContent.macAddress].
  final String macAddress;

  /// The label of [WifiDppContent.channels].
  final String channels;

  /// A date without its year: "14 Nov".
  final String Function(DateTime date) dayAndMonth;

  /// A date: "31 Aug 1977".
  final String Function(DateTime date) fullDate;

  /// Where a vehicle was made: "North America".
  final String Function(VinRegion region) vinRegion;

  /// An amount as the sheet shows it: "12.50 EUR". Give your own to format money for a locale, such as "€12,50".
  final String Function(String amount, String? currency) money;

  /// A payment code without an amount.
  final String payerEntersAmount;

  /// A payment code for any number of payments (EMVCo static).
  final String reusable;

  /// The copy button of a payment to an IBAN.
  final String copyIban;

  /// The copy button of a payment to an account number.
  final String copyAccount;

  /// The copy button of a UPI payment.
  final String copyUpiId;

  /// The copy button of a PIX payment.
  final String copyPixKey;

  /// The label of an IBAN.
  final String iban;

  /// The label of a bank's BIC.
  final String bic;

  /// The label of an account number.
  final String accountNumber;

  /// The label of a payment reference.
  final String paymentReference;

  /// The label of a payee's address.
  final String address;

  /// The label of who pays a Swiss QR-bill.
  final String payableBy;

  /// The label of a bank's name.
  final String bank;

  /// The label of a Russian taxpayer number.
  final String inn;

  /// The label of a Russian tax registration reason code.
  final String kpp;

  /// The label of a UPI address.
  final String upiId;

  /// The label of a PIX key.
  final String pixKey;

  /// The label of a payment's transaction id.
  final String transaction;

  /// The label of a Czech variable symbol.
  final String variableSymbol;

  /// The kind of a [BinaryContent].
  final String binary;

  /// The kind of a [TextContent].
  final String text;

  /// A batch or lot number (GS1 AI 10).
  final String batch;

  /// A serial number (GS1 AI 21).
  final String serial;

  /// The shipping container code of a pallet or parcel (GS1 AI 00).
  final String sscc;

  /// How many items a logistic unit holds (GS1 AI 37).
  final String quantity;

  /// A best before date (GS1 AI 15).
  final String bestBefore;

  /// The kind above a card read by `ScannerTemplate.loyalty`.
  final String loyaltyCard;

  /// The title of a card number.
  final String cardNumber;

  /// Above an accepted code without a title of its own (`ScanVerdict.accept`).
  final String accepted;

  /// Above a code to look at without a title of its own (`ScanVerdict.warn`).
  final String needsAttention;

  /// Above a refused code without a title of its own (`ScanVerdict.reject`).
  final String rejected;

  /// The counter of accepted codes (`ScannerTemplate.counter`): "12 checked in".
  final String Function(int count) checkedIn;

  /// How many codes `ScannerTemplate.pick` shows labels for: "3 codes".
  final String Function(int count) codesInView;

  /// Hint for screen readers on a code's label in `ScannerTemplate.pick`.
  final String pickCode;

  /// Label of `ScanFieldButton` for screen readers.
  final String scanCode;

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

  @override
  bool operator ==(Object other) =>
      other is ScannerStrings &&
      other.close == close &&
      other.torchOn == torchOn &&
      other.torchOff == torchOff &&
      other.switchCamera == switchCamera &&
      other.pickImage == pickImage &&
      other.zoom == zoom &&
      other.autoZoom == autoZoom &&
      other.autoZoomOn == autoZoomOn &&
      other.autoZoomOff == autoZoomOff &&
      other.starting == starting &&
      other.permissionTitle == permissionTitle &&
      other.permissionMessage == permissionMessage &&
      other.unavailableTitle == unavailableTitle &&
      other.unavailableMessage == unavailableMessage &&
      other.photoFallback == photoFallback &&
      other.openSettings == openSettings &&
      other.tryAgain == tryAgain &&
      other.choosePhoto == choosePhoto &&
      other.noCodeInPhoto == noCodeInPhoto &&
      other.backToCamera == backToCamera &&
      other.backToCodes == backToCodes &&
      other.copy == copy &&
      other.copied == copied &&
      other.scanAgain == scanAgain &&
      other.done == done &&
      other.scanned == scanned &&
      other.emptyList == emptyList &&
      other.itemCount == itemCount &&
      other.byteCount == byteCount &&
      other.link == link &&
      other.wifi == wifi &&
      other.wifiOpen == wifiOpen &&
      other.wifiPassword == wifiPassword &&
      other.contact == contact &&
      other.event == event &&
      other.email == email &&
      other.phone == phone &&
      other.sms == sms &&
      other.location == location &&
      other.gs1 == gs1 &&
      other.faceTime == faceTime &&
      other.payment == payment &&
      other.otp == otp &&
      other.esim == esim &&
      other.crypto == crypto &&
      other.wifiDevice == wifiDevice &&
      other.smartHome == smartHome &&
      other.boardingPass == boardingPass &&
      other.driverLicense == driverLicense &&
      other.vehicle == vehicle &&
      other.product == product &&
      other.book == book &&
      other.secret == secret &&
      other.show == show &&
      other.hide == hide &&
      other.otpType == otpType &&
      other.otpTimeBased == otpTimeBased &&
      other.otpCounterBased == otpCounterBased &&
      other.otpDigits == otpDigits &&
      other.otpPeriod == otpPeriod &&
      other.otpCounter == otpCounter &&
      other.seconds == seconds &&
      other.matchingId == matchingId &&
      other.confirmationCode == confirmationCode &&
      other.needed == needed &&
      other.setupCode == setupCode &&
      other.vendorId == vendorId &&
      other.productId == productId &&
      other.discriminator == discriminator &&
      other.category == category &&
      other.setupId == setupId &&
      other.gtin == gtin &&
      other.addOn == addOn &&
      other.passenger == passenger &&
      other.date == date &&
      other.seat == seat &&
      other.cabin == cabin &&
      other.booking == booking &&
      other.sequence == sequence &&
      other.flightOf == flightOf &&
      other.licenseNumber == licenseNumber &&
      other.born == born &&
      other.expires == expires &&
      other.city == city &&
      other.state == state &&
      other.country == country &&
      other.expired == expired &&
      other.makerCode == makerCode &&
      other.modelYear == modelYear &&
      other.checkDigit == checkDigit &&
      other.valid == valid &&
      other.macAddress == macAddress &&
      other.channels == channels &&
      other.dayAndMonth == dayAndMonth &&
      other.fullDate == fullDate &&
      other.vinRegion == vinRegion &&
      other.money == money &&
      other.payerEntersAmount == payerEntersAmount &&
      other.reusable == reusable &&
      other.copyIban == copyIban &&
      other.copyAccount == copyAccount &&
      other.copyUpiId == copyUpiId &&
      other.copyPixKey == copyPixKey &&
      other.iban == iban &&
      other.bic == bic &&
      other.accountNumber == accountNumber &&
      other.paymentReference == paymentReference &&
      other.address == address &&
      other.payableBy == payableBy &&
      other.bank == bank &&
      other.inn == inn &&
      other.kpp == kpp &&
      other.upiId == upiId &&
      other.pixKey == pixKey &&
      other.transaction == transaction &&
      other.variableSymbol == variableSymbol &&
      other.binary == binary &&
      other.text == text &&
      other.batch == batch &&
      other.serial == serial &&
      other.sscc == sscc &&
      other.quantity == quantity &&
      other.bestBefore == bestBefore &&
      other.loyaltyCard == loyaltyCard &&
      other.cardNumber == cardNumber &&
      other.accepted == accepted &&
      other.needsAttention == needsAttention &&
      other.rejected == rejected &&
      other.checkedIn == checkedIn &&
      other.codesInView == codesInView &&
      other.pickCode == pickCode &&
      other.scanCode == scanCode;

  @override
  int get hashCode => Object.hashAll(<Object>[
    close,
    torchOn,
    torchOff,
    switchCamera,
    pickImage,
    zoom,
    autoZoom,
    autoZoomOn,
    autoZoomOff,
    starting,
    permissionTitle,
    permissionMessage,
    unavailableTitle,
    unavailableMessage,
    photoFallback,
    openSettings,
    tryAgain,
    choosePhoto,
    noCodeInPhoto,
    backToCamera,
    backToCodes,
    copy,
    copied,
    scanAgain,
    done,
    scanned,
    emptyList,
    itemCount,
    byteCount,
    link,
    wifi,
    wifiOpen,
    wifiPassword,
    contact,
    event,
    email,
    phone,
    sms,
    location,
    gs1,
    faceTime,
    payment,
    otp,
    esim,
    crypto,
    wifiDevice,
    smartHome,
    boardingPass,
    driverLicense,
    vehicle,
    product,
    book,
    secret,
    show,
    hide,
    otpType,
    otpTimeBased,
    otpCounterBased,
    otpDigits,
    otpPeriod,
    otpCounter,
    seconds,
    matchingId,
    confirmationCode,
    needed,
    setupCode,
    vendorId,
    productId,
    discriminator,
    category,
    setupId,
    gtin,
    addOn,
    passenger,
    date,
    seat,
    cabin,
    booking,
    sequence,
    flightOf,
    licenseNumber,
    born,
    expires,
    city,
    state,
    country,
    expired,
    makerCode,
    modelYear,
    checkDigit,
    valid,
    macAddress,
    channels,
    dayAndMonth,
    fullDate,
    vinRegion,
    money,
    payerEntersAmount,
    reusable,
    copyIban,
    copyAccount,
    copyUpiId,
    copyPixKey,
    iban,
    bic,
    accountNumber,
    paymentReference,
    address,
    payableBy,
    bank,
    inn,
    kpp,
    upiId,
    pixKey,
    transaction,
    variableSymbol,
    binary,
    text,
    batch,
    serial,
    sscc,
    quantity,
    bestBefore,
    loyaltyCard,
    cardNumber,
    accepted,
    needsAttention,
    rejected,
    checkedIn,
    codesInView,
    pickCode,
    scanCode,
  ]);

  static String _itemCount(int count) => count == 1 ? '1 item' : '$count items';

  static String _checkedIn(int count) => '$count checked in';

  static String _codesInView(int count) =>
      count == 1 ? '1 code' : '$count codes';

  static String _byteCount(int count) => count == 1 ? '1 byte' : '$count bytes';

  static String _seconds(int seconds) => '$seconds s';

  static String _money(String amount, String? currency) =>
      currency == null ? amount : '$amount $currency';

  static String _flightOf(int flight, int count) => 'Flight $flight of $count';

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _dayAndMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  static String _fullDate(DateTime date) =>
      '${_dayAndMonth(date)} ${date.year}';

  static String _vinRegion(VinRegion region) => switch (region) {
    VinRegion.africa => 'Africa',
    VinRegion.asia => 'Asia',
    VinRegion.europe => 'Europe',
    VinRegion.northAmerica => 'North America',
    VinRegion.oceania => 'Oceania',
    VinRegion.southAmerica => 'South America',
  };
}
