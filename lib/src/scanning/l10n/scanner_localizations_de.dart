// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'scanner_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class ScannerLocalizationsDe extends ScannerLocalizations {
  ScannerLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get close => 'Scanner schließen';

  @override
  String get torchOn => 'Taschenlampe einschalten';

  @override
  String get torchOff => 'Taschenlampe ausschalten';

  @override
  String get switchCamera => 'Kamera wechseln';

  @override
  String get pickImage => 'Code aus Foto lesen';

  @override
  String get zoom => 'Zoom';

  @override
  String get autoZoom => 'Auto';

  @override
  String get autoZoomOn => 'Auto-Zoom einschalten';

  @override
  String get autoZoomOff => 'Auto-Zoom ausschalten';

  @override
  String get starting => 'Kamera wird gestartet …';

  @override
  String get permissionTitle => 'Kein Kamerazugriff';

  @override
  String get permissionMessage =>
      'Kamerazugriff für diese App in den Einstellungen erlauben, um Codes zu scannen.';

  @override
  String get unavailableTitle => 'Kamera nicht verfügbar';

  @override
  String get unavailableMessage =>
      'Möglicherweise wird sie von einer anderen App verwendet oder dieses Gerät hat keine Kamera.';

  @override
  String get inUseMessage =>
      'Eine andere App verwendet die Kamera. Bitte diese App schließen und erneut versuchen.';

  @override
  String get unsupportedMessage =>
      'Kamerazugriff ist hier nicht verfügbar. Im Web muss die Seite über https geöffnet werden.';

  @override
  String get photoFallback =>
      'Ein Code kann auch aus einem Foto gelesen werden.';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get choosePhoto => 'Foto auswählen';

  @override
  String get noCodeInPhoto => 'Kein Code in diesem Foto gefunden';

  @override
  String get backToCamera => 'Zurück zur Kamera';

  @override
  String get backToCodes => 'Zurück zu den Codes';

  @override
  String get copy => 'Kopieren';

  @override
  String get copied => 'Kopiert';

  @override
  String get scanAgain => 'Erneut scannen';

  @override
  String get done => 'Fertig';

  @override
  String get scanned => 'Gescannt';

  @override
  String get emptyList => 'Gescannte Codes erscheinen hier';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '$count Eintrag',
    );
    return '$_temp0';
  }

  @override
  String byteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Byte',
      one: '$count Byte',
    );
    return '$_temp0';
  }

  @override
  String get link => 'Link';

  @override
  String get wifi => 'WLAN-Netzwerk';

  @override
  String get wifiPassword => 'Passwort im Code';

  @override
  String wifiSecurity(String security) {
    String _temp0 = intl.Intl.selectLogic(security, {
      'none': 'Offenes Netzwerk',
      'wep': 'WEP',
      'wpa': 'WPA',
      'wpa3': 'WPA3',
      'enterprise': 'Enterprise',
      'other': 'Gesichert',
    });
    return '$_temp0';
  }

  @override
  String get contact => 'Kontakt';

  @override
  String get event => 'Termin';

  @override
  String get email => 'E-Mail';

  @override
  String get phone => 'Telefon';

  @override
  String get sms => 'SMS';

  @override
  String get location => 'Standort';

  @override
  String get gs1 => 'GS1';

  @override
  String get faceTime => 'FaceTime';

  @override
  String get payment => 'Zahlung';

  @override
  String get otp => 'Einmalpasswort';

  @override
  String get esim => 'eSIM';

  @override
  String get crypto => 'Kryptozahlung';

  @override
  String get wifiDevice => 'WLAN-Gerät';

  @override
  String get smartHome => 'Smart-Home-Gerät';

  @override
  String get boardingPass => 'Bordkarte';

  @override
  String get driverLicense => 'Führerschein';

  @override
  String get vehicle => 'Fahrzeug';

  @override
  String get product => 'Produkt';

  @override
  String get book => 'Buch';

  @override
  String get secret => 'Geheimer Schlüssel';

  @override
  String get show => 'Einblenden';

  @override
  String get hide => 'Ausblenden';

  @override
  String get otpType => 'Typ';

  @override
  String get otpTimeBased => 'Zeitbasiert';

  @override
  String get otpCounterBased => 'Zählerbasiert';

  @override
  String get otpDigits => 'Stellen';

  @override
  String get otpPeriod => 'Alle';

  @override
  String get otpCounter => 'Zähler';

  @override
  String seconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get matchingId => 'Matching-ID';

  @override
  String get confirmationCode => 'Bestätigungscode';

  @override
  String get needed => 'Erforderlich';

  @override
  String get setupCode => 'Einrichtungscode';

  @override
  String get vendorId => 'Hersteller';

  @override
  String get productId => 'Produkt';

  @override
  String get discriminator => 'Discriminator';

  @override
  String get category => 'Kategorie';

  @override
  String get setupId => 'Setup-ID';

  @override
  String get gtin => 'GTIN';

  @override
  String get addOn => 'Zusatzcode';

  @override
  String get passenger => 'Passagier';

  @override
  String get date => 'Datum';

  @override
  String get seat => 'Sitz';

  @override
  String get cabin => 'Klasse';

  @override
  String get booking => 'Buchung';

  @override
  String get sequence => 'Sequenznummer';

  @override
  String flightOf(int flight, int count) {
    return 'Flug $flight von $count';
  }

  @override
  String get licenseNumber => 'Nummer';

  @override
  String get born => 'Geboren';

  @override
  String get expires => 'Gültig bis';

  @override
  String get city => 'Ort';

  @override
  String get state => 'Bundesland';

  @override
  String get country => 'Land';

  @override
  String get expired => 'Abgelaufen';

  @override
  String get makerCode => 'Herstellercode';

  @override
  String get modelYear => 'Modelljahr';

  @override
  String get checkDigit => 'Prüfziffer';

  @override
  String get valid => 'Gültig';

  @override
  String get macAddress => 'MAC';

  @override
  String get channels => 'Kanäle';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'Jan.',
      'feb': 'Feb.',
      'mar': 'März',
      'apr': 'Apr.',
      'may': 'Mai',
      'jun': 'Juni',
      'jul': 'Juli',
      'aug': 'Aug.',
      'sep': 'Sept.',
      'oct': 'Okt.',
      'nov': 'Nov.',
      'dec': 'Dez.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String dayMonth(int day, String month) {
    return '$day. $month';
  }

  @override
  String dayMonthYear(int day, String month, int year) {
    return '$day. $month $year';
  }

  @override
  String vinRegion(String region) {
    String _temp0 = intl.Intl.selectLogic(region, {
      'africa': 'Afrika',
      'asia': 'Asien',
      'europe': 'Europa',
      'northAmerica': 'Nordamerika',
      'oceania': 'Ozeanien',
      'southAmerica': 'Südamerika',
      'other': 'Unbekannt',
    });
    return '$_temp0';
  }

  @override
  String amount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get anyAmount => 'Beliebiger Betrag';

  @override
  String get payerEntersAmount => 'Betrag wird vom Zahler eingegeben';

  @override
  String get reusable => 'Mehrfach nutzbar';

  @override
  String get copyIban => 'IBAN kopieren';

  @override
  String get copyAccount => 'Kontonummer kopieren';

  @override
  String get copyUpiId => 'UPI-ID kopieren';

  @override
  String get copyPixKey => 'Schlüssel kopieren';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get accountNumber => 'Konto';

  @override
  String get paymentReference => 'Verwendungszweck';

  @override
  String get address => 'Adresse';

  @override
  String get payableBy => 'Zahlbar durch';

  @override
  String get bank => 'Bank';

  @override
  String get inn => 'INN';

  @override
  String get kpp => 'KPP';

  @override
  String get upiId => 'UPI-ID';

  @override
  String get pixKey => 'PIX-Schlüssel';

  @override
  String get transaction => 'Transaktion';

  @override
  String get variableSymbol => 'Variables Symbol';

  @override
  String get binary => 'Binärdaten';

  @override
  String get text => 'Text';

  @override
  String get batch => 'Charge';

  @override
  String get serial => 'Seriennummer';

  @override
  String get sscc => 'SSCC';

  @override
  String get quantity => 'Menge';

  @override
  String get bestBefore => 'MHD';

  @override
  String get loyaltyCard => 'Kundenkarte';

  @override
  String get cardNumber => 'Kartennummer';

  @override
  String get accepted => 'Akzeptiert';

  @override
  String get needsAttention => 'Code prüfen';

  @override
  String get rejected => 'Nicht akzeptiert';

  @override
  String checkedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eingecheckt',
    );
    return '$_temp0';
  }

  @override
  String codesInView(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Codes',
      one: '$count Code',
    );
    return '$_temp0';
  }

  @override
  String get pickCode => 'Diesen Code auswählen';

  @override
  String get scanCode => 'Code scannen';

  @override
  String get hintCode => 'Kamera auf einen Code richten';

  @override
  String get hintQrCode => 'Auf einen QR-Code richten';

  @override
  String get hintBarcode => 'Auf den Barcode richten';

  @override
  String get hintCloser => 'Näher heran';

  @override
  String get hintTicket => 'Auf das Ticket richten';

  @override
  String get hintDataMatrix => 'Auf den Data-Matrix-Code richten';

  @override
  String get hintPick => 'Auf einen Code tippen';

  @override
  String get hintKiosk => 'Code vor die Kamera halten';

  @override
  String get hintVin => 'Windschutzscheibe oder Türsäule';

  @override
  String get hintCard => 'Auf den Barcode der Karte richten';

  @override
  String get hintField => 'Auf den Code richten';

  @override
  String get titlePayment => 'Mit QR bezahlen';

  @override
  String get titleTicket => 'Ticket scannen';

  @override
  String get titleSignIn => 'Zum Anmelden scannen';
}
