// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'scanner_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ScannerLocalizationsFr extends ScannerLocalizations {
  ScannerLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get close => 'Fermer le scanner';

  @override
  String get torchOn => 'Allumer la lampe torche';

  @override
  String get torchOff => 'Éteindre la lampe torche';

  @override
  String get switchCamera => 'Changer de caméra';

  @override
  String get pickImage => 'Lire un code sur une photo';

  @override
  String get zoom => 'Zoom';

  @override
  String get autoZoom => 'Auto';

  @override
  String get autoZoomOn => 'Activer le zoom automatique';

  @override
  String get autoZoomOff => 'Désactiver le zoom automatique';

  @override
  String get starting => 'Démarrage de la caméra…';

  @override
  String get permissionTitle => 'Accès à la caméra désactivé';

  @override
  String get permissionMessage =>
      'Autorisez l’accès à la caméra pour cette app dans Réglages pour scanner des codes.';

  @override
  String get unavailableTitle => 'Caméra indisponible';

  @override
  String get unavailableMessage =>
      'Une autre app l’utilise peut-être, ou cet appareil n’en a pas.';

  @override
  String get inUseMessage =>
      'Une autre app utilise la caméra. Fermez-la et réessayez.';

  @override
  String get unsupportedMessage =>
      'La caméra n’est pas disponible ici. Sur le web, la page doit être ouverte en https.';

  @override
  String get photoFallback =>
      'Vous pouvez toujours lire un code sur une photo.';

  @override
  String get openSettings => 'Ouvrir Réglages';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get noCodeInPhoto => 'Aucun code sur cette photo';

  @override
  String get backToCamera => 'Retour à la caméra';

  @override
  String get backToCodes => 'Retour aux codes';

  @override
  String get copy => 'Copier';

  @override
  String get copied => 'Copié';

  @override
  String get scanAgain => 'Scanner à nouveau';

  @override
  String get done => 'Terminé';

  @override
  String get scanned => 'Scannés';

  @override
  String get emptyList => 'Les codes scannés apparaîtront ici';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '$count élément',
    );
    return '$_temp0';
  }

  @override
  String byteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count octets',
      one: '$count octet',
    );
    return '$_temp0';
  }

  @override
  String get link => 'Lien';

  @override
  String get wifi => 'Réseau Wi‑Fi';

  @override
  String get wifiPassword => 'mot de passe dans le code';

  @override
  String wifiSecurity(String security) {
    String _temp0 = intl.Intl.selectLogic(security, {
      'none': 'Réseau ouvert',
      'wep': 'WEP',
      'wpa': 'WPA',
      'wpa3': 'WPA3',
      'enterprise': 'Entreprise',
      'other': 'Sécurisé',
    });
    return '$_temp0';
  }

  @override
  String get contact => 'Contact';

  @override
  String get event => 'Événement';

  @override
  String get email => 'E-mail';

  @override
  String get phone => 'Téléphone';

  @override
  String get sms => 'SMS';

  @override
  String get location => 'Position';

  @override
  String get gs1 => 'GS1';

  @override
  String get faceTime => 'FaceTime';

  @override
  String get payment => 'Paiement';

  @override
  String get otp => 'Mot de passe à usage unique';

  @override
  String get esim => 'eSIM';

  @override
  String get crypto => 'Paiement crypto';

  @override
  String get wifiDevice => 'Appareil Wi‑Fi';

  @override
  String get smartHome => 'Appareil domotique';

  @override
  String get boardingPass => 'Carte d’embarquement';

  @override
  String get driverLicense => 'Permis de conduire';

  @override
  String get vehicle => 'Véhicule';

  @override
  String get product => 'Produit';

  @override
  String get book => 'Livre';

  @override
  String get secret => 'Clé secrète';

  @override
  String get show => 'Afficher';

  @override
  String get hide => 'Masquer';

  @override
  String get otpType => 'Type';

  @override
  String get otpTimeBased => 'Basé sur le temps';

  @override
  String get otpCounterBased => 'Basé sur un compteur';

  @override
  String get otpDigits => 'Chiffres';

  @override
  String get otpPeriod => 'Toutes les';

  @override
  String get otpCounter => 'Compteur';

  @override
  String seconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get matchingId => 'Matching ID';

  @override
  String get confirmationCode => 'Code de confirmation';

  @override
  String get needed => 'Requis';

  @override
  String get setupCode => 'Code de configuration';

  @override
  String get vendorId => 'Fabricant';

  @override
  String get productId => 'Produit';

  @override
  String get discriminator => 'Discriminateur';

  @override
  String get category => 'Catégorie';

  @override
  String get setupId => 'Setup ID';

  @override
  String get gtin => 'GTIN';

  @override
  String get addOn => 'Code add-on';

  @override
  String get passenger => 'Passager';

  @override
  String get date => 'Date';

  @override
  String get seat => 'Siège';

  @override
  String get cabin => 'Classe';

  @override
  String get booking => 'Réservation';

  @override
  String get sequence => 'Numéro d’ordre';

  @override
  String flightOf(int flight, int count) {
    return 'Vol $flight sur $count';
  }

  @override
  String get licenseNumber => 'Numéro';

  @override
  String get born => 'Date de naissance';

  @override
  String get expires => 'Expire le';

  @override
  String get city => 'Ville';

  @override
  String get state => 'État/Région';

  @override
  String get country => 'Pays';

  @override
  String get expired => 'Expiré';

  @override
  String get makerCode => 'Code constructeur';

  @override
  String get modelYear => 'Année modèle';

  @override
  String get checkDigit => 'Chiffre de contrôle';

  @override
  String get valid => 'Valide';

  @override
  String get macAddress => 'MAC';

  @override
  String get channels => 'Canaux';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'janv.',
      'feb': 'févr.',
      'mar': 'mars',
      'apr': 'avr.',
      'may': 'mai',
      'jun': 'juin',
      'jul': 'juil.',
      'aug': 'août',
      'sep': 'sept.',
      'oct': 'oct.',
      'nov': 'nov.',
      'dec': 'déc.',
      'other': '',
    });
    return '$_temp0';
  }

  @override
  String dayMonth(int day, String month) {
    return '$day $month';
  }

  @override
  String dayMonthYear(int day, String month, int year) {
    return '$day $month $year';
  }

  @override
  String vinRegion(String region) {
    String _temp0 = intl.Intl.selectLogic(region, {
      'africa': 'Afrique',
      'asia': 'Asie',
      'europe': 'Europe',
      'northAmerica': 'Amérique du Nord',
      'oceania': 'Océanie',
      'southAmerica': 'Amérique du Sud',
      'other': 'Inconnue',
    });
    return '$_temp0';
  }

  @override
  String amount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get anyAmount => 'Montant libre';

  @override
  String get payerEntersAmount => 'Le payeur saisit le montant';

  @override
  String get reusable => 'Réutilisable';

  @override
  String get copyIban => 'Copier l’IBAN';

  @override
  String get copyAccount => 'Copier le compte';

  @override
  String get copyUpiId => 'Copier l’ID UPI';

  @override
  String get copyPixKey => 'Copier la clé';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get accountNumber => 'Compte';

  @override
  String get paymentReference => 'Référence';

  @override
  String get address => 'Adresse';

  @override
  String get payableBy => 'Payable par';

  @override
  String get bank => 'Banque';

  @override
  String get inn => 'INN';

  @override
  String get kpp => 'KPP';

  @override
  String get upiId => 'ID UPI';

  @override
  String get pixKey => 'Clé PIX';

  @override
  String get transaction => 'Transaction';

  @override
  String get variableSymbol => 'Symbole variable';

  @override
  String get binary => 'Données binaires';

  @override
  String get text => 'Texte';

  @override
  String get batch => 'Lot';

  @override
  String get serial => 'N° de série';

  @override
  String get sscc => 'SSCC';

  @override
  String get quantity => 'Quantité';

  @override
  String get bestBefore => 'À consommer de préférence avant';

  @override
  String get loyaltyCard => 'Carte de fidélité';

  @override
  String get cardNumber => 'Numéro de carte';

  @override
  String get accepted => 'Accepté';

  @override
  String get needsAttention => 'Vérifiez ce code';

  @override
  String get rejected => 'Refusé';

  @override
  String checkedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enregistrés',
      one: '$count enregistré',
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
  String get pickCode => 'Choisir ce code';

  @override
  String get scanCode => 'Scanner un code';

  @override
  String get hintCode => 'Pointez la caméra vers un code';

  @override
  String get hintQrCode => 'Visez un QR code';

  @override
  String get hintBarcode => 'Visez le code-barres';

  @override
  String get hintCloser => 'Rapprochez-vous';

  @override
  String get hintTicket => 'Visez le billet';

  @override
  String get hintDataMatrix => 'Visez le code Data Matrix';

  @override
  String get hintPick => 'Touchez un code';

  @override
  String get hintKiosk => 'Présentez le code à la caméra';

  @override
  String get hintVin => 'Pare-brise ou montant de porte';

  @override
  String get hintCard => 'Visez le code-barres de la carte';

  @override
  String get hintField => 'Visez le code';

  @override
  String get titlePayment => 'Payer par QR code';

  @override
  String get titleTicket => 'Scannez votre billet';

  @override
  String get titleSignIn => 'Scannez pour vous connecter';
}
