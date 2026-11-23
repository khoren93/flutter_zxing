// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'scanner_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ScannerLocalizationsEn extends ScannerLocalizations {
  ScannerLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get close => 'Close the scanner';

  @override
  String get torchOn => 'Turn on the torch';

  @override
  String get torchOff => 'Turn off the torch';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get pickImage => 'Read a code from a photo';

  @override
  String get zoom => 'Zoom';

  @override
  String get autoZoom => 'Auto';

  @override
  String get autoZoomOn => 'Turn on automatic zoom';

  @override
  String get autoZoomOff => 'Turn off automatic zoom';

  @override
  String get starting => 'Starting the camera…';

  @override
  String get permissionTitle => 'Camera access is off';

  @override
  String get permissionMessage =>
      'Turn on camera access for this app in Settings to scan codes.';

  @override
  String get unavailableTitle => 'The camera isn\'t available';

  @override
  String get unavailableMessage =>
      'Another app may be using it, or this device has none.';

  @override
  String get inUseMessage =>
      'Another app is using the camera. Close it and try again.';

  @override
  String get unsupportedMessage =>
      'Camera access is not available here. On the web, the page must be opened over https.';

  @override
  String get photoFallback => 'You can still read a code from a photo.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get tryAgain => 'Try again';

  @override
  String get choosePhoto => 'Choose a photo';

  @override
  String get noCodeInPhoto => 'No code found in this photo';

  @override
  String get backToCamera => 'Back to the camera';

  @override
  String get backToCodes => 'Back to the codes';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get done => 'Done';

  @override
  String get scanned => 'Scanned';

  @override
  String get emptyList => 'Codes you scan appear here';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String byteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bytes',
      one: '$count byte',
    );
    return '$_temp0';
  }

  @override
  String get link => 'Link';

  @override
  String get wifi => 'Wi‑Fi network';

  @override
  String get wifiPassword => 'password in the code';

  @override
  String wifiSecurity(String security) {
    String _temp0 = intl.Intl.selectLogic(security, {
      'none': 'Open network',
      'wep': 'WEP',
      'wpa': 'WPA',
      'wpa3': 'WPA3',
      'enterprise': 'Enterprise',
      'other': 'Secured',
    });
    return '$_temp0';
  }

  @override
  String get contact => 'Contact';

  @override
  String get event => 'Event';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone';

  @override
  String get sms => 'Text message';

  @override
  String get location => 'Location';

  @override
  String get gs1 => 'GS1';

  @override
  String get faceTime => 'FaceTime';

  @override
  String get payment => 'Payment';

  @override
  String get otp => 'One-time password';

  @override
  String get esim => 'eSIM';

  @override
  String get crypto => 'Crypto payment';

  @override
  String get wifiDevice => 'Wi‑Fi device';

  @override
  String get smartHome => 'Smart home device';

  @override
  String get boardingPass => 'Boarding pass';

  @override
  String get driverLicense => 'Driver\'s license';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get product => 'Product';

  @override
  String get book => 'Book';

  @override
  String get secret => 'Secret';

  @override
  String get show => 'Show';

  @override
  String get hide => 'Hide';

  @override
  String get otpType => 'Type';

  @override
  String get otpTimeBased => 'Time-based';

  @override
  String get otpCounterBased => 'Counter-based';

  @override
  String get otpDigits => 'Digits';

  @override
  String get otpPeriod => 'Every';

  @override
  String get otpCounter => 'Counter';

  @override
  String seconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get matchingId => 'Matching ID';

  @override
  String get confirmationCode => 'Confirmation code';

  @override
  String get needed => 'Needed';

  @override
  String get setupCode => 'Setup code';

  @override
  String get vendorId => 'Vendor';

  @override
  String get productId => 'Product';

  @override
  String get discriminator => 'Discriminator';

  @override
  String get category => 'Category';

  @override
  String get setupId => 'Setup ID';

  @override
  String get gtin => 'GTIN';

  @override
  String get addOn => 'Add-on';

  @override
  String get passenger => 'Passenger';

  @override
  String get date => 'Date';

  @override
  String get seat => 'Seat';

  @override
  String get cabin => 'Class';

  @override
  String get booking => 'Booking';

  @override
  String get sequence => 'Sequence';

  @override
  String flightOf(int flight, int count) {
    return 'Flight $flight of $count';
  }

  @override
  String get licenseNumber => 'Number';

  @override
  String get born => 'Born';

  @override
  String get expires => 'Expires';

  @override
  String get city => 'City';

  @override
  String get state => 'State';

  @override
  String get country => 'Country';

  @override
  String get expired => 'Expired';

  @override
  String get makerCode => 'Maker code';

  @override
  String get modelYear => 'Model year';

  @override
  String get checkDigit => 'Check digit';

  @override
  String get valid => 'Valid';

  @override
  String get macAddress => 'MAC';

  @override
  String get channels => 'Channels';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'Jan',
      'feb': 'Feb',
      'mar': 'Mar',
      'apr': 'Apr',
      'may': 'May',
      'jun': 'Jun',
      'jul': 'Jul',
      'aug': 'Aug',
      'sep': 'Sep',
      'oct': 'Oct',
      'nov': 'Nov',
      'dec': 'Dec',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String dayMonth(int day, String month) {
    return '$month $day';
  }

  @override
  String dayMonthYear(int day, String month, int year) {
    return '$month $day, $year';
  }

  @override
  String vinRegion(String region) {
    String _temp0 = intl.Intl.selectLogic(region, {
      'africa': 'Africa',
      'asia': 'Asia',
      'europe': 'Europe',
      'northAmerica': 'North America',
      'oceania': 'Oceania',
      'southAmerica': 'South America',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String amount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get anyAmount => 'Any amount';

  @override
  String get payerEntersAmount => 'The payer enters the amount';

  @override
  String get reusable => 'Reusable';

  @override
  String get copyIban => 'Copy IBAN';

  @override
  String get copyAccount => 'Copy account';

  @override
  String get copyUpiId => 'Copy UPI ID';

  @override
  String get copyPixKey => 'Copy key';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get accountNumber => 'Account';

  @override
  String get paymentReference => 'Reference';

  @override
  String get address => 'Address';

  @override
  String get payableBy => 'Payable by';

  @override
  String get bank => 'Bank';

  @override
  String get inn => 'INN';

  @override
  String get kpp => 'KPP';

  @override
  String get upiId => 'UPI ID';

  @override
  String get pixKey => 'PIX key';

  @override
  String get transaction => 'Transaction';

  @override
  String get variableSymbol => 'Variable symbol';

  @override
  String get binary => 'Binary data';

  @override
  String get text => 'Text';

  @override
  String get batch => 'Batch';

  @override
  String get serial => 'Serial';

  @override
  String get sscc => 'SSCC';

  @override
  String get quantity => 'Quantity';

  @override
  String get bestBefore => 'Best before';

  @override
  String get loyaltyCard => 'Loyalty card';

  @override
  String get cardNumber => 'Card number';

  @override
  String get accepted => 'Accepted';

  @override
  String get needsAttention => 'Check this code';

  @override
  String get rejected => 'Not accepted';

  @override
  String checkedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count checked in',
    );
    return '$_temp0';
  }

  @override
  String codesInView(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count codes',
      one: '$count code',
    );
    return '$_temp0';
  }

  @override
  String get pickCode => 'Pick this code';

  @override
  String get scanCode => 'Scan a code';

  @override
  String get hintCode => 'Point the camera at a code';

  @override
  String get hintQrCode => 'Point at a QR code';

  @override
  String get hintBarcode => 'Point at the barcode';

  @override
  String get hintCloser => 'Move closer';

  @override
  String get hintTicket => 'Point at the ticket';

  @override
  String get hintDataMatrix => 'Point at the Data Matrix';

  @override
  String get hintPick => 'Tap a code';

  @override
  String get hintKiosk => 'Hold the code up to the camera';

  @override
  String get hintVin => 'Windshield or door pillar';

  @override
  String get hintCard => 'Point at the card\'s barcode';

  @override
  String get hintField => 'Point at the code';

  @override
  String get titlePayment => 'Pay with QR';

  @override
  String get titleTicket => 'Scan your ticket';

  @override
  String get titleSignIn => 'Scan to sign in';
}
