// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'scanner_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class ScannerLocalizationsEs extends ScannerLocalizations {
  ScannerLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get close => 'Cerrar el escáner';

  @override
  String get torchOn => 'Encender la linterna';

  @override
  String get torchOff => 'Apagar la linterna';

  @override
  String get switchCamera => 'Cambiar de cámara';

  @override
  String get pickImage => 'Leer un código de una foto';

  @override
  String get zoom => 'Zoom';

  @override
  String get autoZoom => 'Auto';

  @override
  String get autoZoomOn => 'Activar zoom automático';

  @override
  String get autoZoomOff => 'Desactivar zoom automático';

  @override
  String get starting => 'Iniciando la cámara…';

  @override
  String get permissionTitle => 'Sin acceso a la cámara';

  @override
  String get permissionMessage =>
      'Permita el acceso a la cámara para esta app en Ajustes para escanear códigos.';

  @override
  String get unavailableTitle => 'La cámara no está disponible';

  @override
  String get unavailableMessage =>
      'Puede que otra app la esté usando o que este dispositivo no tenga cámara.';

  @override
  String get inUseMessage =>
      'Otra app está usando la cámara. Ciérrela e inténtelo de nuevo.';

  @override
  String get unsupportedMessage =>
      'El acceso a la cámara no está disponible aquí. En la web, la página debe abrirse por https.';

  @override
  String get photoFallback => 'Aún puede leer un código de una foto.';

  @override
  String get openSettings => 'Abrir Ajustes';

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get choosePhoto => 'Elegir una foto';

  @override
  String get noCodeInPhoto => 'No hay ningún código en esta foto';

  @override
  String get backToCamera => 'Volver a la cámara';

  @override
  String get backToCodes => 'Volver a los códigos';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get scanAgain => 'Escanear de nuevo';

  @override
  String get done => 'Listo';

  @override
  String get scanned => 'Escaneados';

  @override
  String get emptyList => 'Los códigos escaneados aparecen aquí';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '$count elemento',
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
  String get link => 'Enlace';

  @override
  String get wifi => 'Red Wi‑Fi';

  @override
  String get wifiPassword => 'contraseña en el código';

  @override
  String wifiSecurity(String security) {
    String _temp0 = intl.Intl.selectLogic(security, {
      'none': 'Red abierta',
      'wep': 'WEP',
      'wpa': 'WPA',
      'wpa3': 'WPA3',
      'enterprise': 'Empresarial',
      'other': 'Protegida',
    });
    return '$_temp0';
  }

  @override
  String get contact => 'Contacto';

  @override
  String get event => 'Evento';

  @override
  String get email => 'Correo electrónico';

  @override
  String get phone => 'Teléfono';

  @override
  String get sms => 'Mensaje de texto';

  @override
  String get location => 'Ubicación';

  @override
  String get gs1 => 'GS1';

  @override
  String get faceTime => 'FaceTime';

  @override
  String get payment => 'Pago';

  @override
  String get otp => 'Contraseña de un solo uso';

  @override
  String get esim => 'eSIM';

  @override
  String get crypto => 'Pago con criptomonedas';

  @override
  String get wifiDevice => 'Dispositivo Wi‑Fi';

  @override
  String get smartHome => 'Dispositivo del hogar inteligente';

  @override
  String get boardingPass => 'Tarjeta de embarque';

  @override
  String get driverLicense => 'Licencia de conducir';

  @override
  String get vehicle => 'Vehículo';

  @override
  String get product => 'Producto';

  @override
  String get book => 'Libro';

  @override
  String get secret => 'Clave secreta';

  @override
  String get show => 'Mostrar';

  @override
  String get hide => 'Ocultar';

  @override
  String get otpType => 'Tipo';

  @override
  String get otpTimeBased => 'Por tiempo';

  @override
  String get otpCounterBased => 'Por contador';

  @override
  String get otpDigits => 'Dígitos';

  @override
  String get otpPeriod => 'Cada';

  @override
  String get otpCounter => 'Contador';

  @override
  String seconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get matchingId => 'Matching ID';

  @override
  String get confirmationCode => 'Código de confirmación';

  @override
  String get needed => 'Necesario';

  @override
  String get setupCode => 'Código de configuración';

  @override
  String get vendorId => 'Fabricante';

  @override
  String get productId => 'Producto';

  @override
  String get discriminator => 'Discriminador';

  @override
  String get category => 'Categoría';

  @override
  String get setupId => 'Setup ID';

  @override
  String get gtin => 'GTIN';

  @override
  String get addOn => 'Complemento';

  @override
  String get passenger => 'Pasajero';

  @override
  String get date => 'Fecha';

  @override
  String get seat => 'Asiento';

  @override
  String get cabin => 'Clase';

  @override
  String get booking => 'Reserva';

  @override
  String get sequence => 'Secuencia';

  @override
  String flightOf(int flight, int count) {
    return 'Vuelo $flight de $count';
  }

  @override
  String get licenseNumber => 'Número';

  @override
  String get born => 'Nacimiento';

  @override
  String get expires => 'Válido hasta';

  @override
  String get city => 'Ciudad';

  @override
  String get state => 'Estado/Provincia';

  @override
  String get country => 'País';

  @override
  String get expired => 'Caducado';

  @override
  String get makerCode => 'Código del fabricante';

  @override
  String get modelYear => 'Año del modelo';

  @override
  String get checkDigit => 'Dígito de control';

  @override
  String get valid => 'Válido';

  @override
  String get macAddress => 'MAC';

  @override
  String get channels => 'Canales';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'ene.',
      'feb': 'feb.',
      'mar': 'mar.',
      'apr': 'abr.',
      'may': 'may.',
      'jun': 'jun.',
      'jul': 'jul.',
      'aug': 'ago.',
      'sep': 'sept.',
      'oct': 'oct.',
      'nov': 'nov.',
      'dec': 'dic.',
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
      'africa': 'África',
      'asia': 'Asia',
      'europe': 'Europa',
      'northAmerica': 'Norteamérica',
      'oceania': 'Oceanía',
      'southAmerica': 'Sudamérica',
      'other': 'Desconocida',
    });
    return '$_temp0';
  }

  @override
  String amount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get anyAmount => 'Cualquier importe';

  @override
  String get payerEntersAmount => 'El pagador introduce el importe';

  @override
  String get reusable => 'Reutilizable';

  @override
  String get copyIban => 'Copiar IBAN';

  @override
  String get copyAccount => 'Copiar cuenta';

  @override
  String get copyUpiId => 'Copiar UPI ID';

  @override
  String get copyPixKey => 'Copiar clave';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'BIC';

  @override
  String get accountNumber => 'Cuenta';

  @override
  String get paymentReference => 'Concepto';

  @override
  String get address => 'Dirección';

  @override
  String get payableBy => 'Pagadero por';

  @override
  String get bank => 'Banco';

  @override
  String get inn => 'INN';

  @override
  String get kpp => 'KPP';

  @override
  String get upiId => 'UPI ID';

  @override
  String get pixKey => 'Clave PIX';

  @override
  String get transaction => 'Transacción';

  @override
  String get variableSymbol => 'Símbolo variable';

  @override
  String get binary => 'Datos binarios';

  @override
  String get text => 'Texto';

  @override
  String get batch => 'Lote';

  @override
  String get serial => 'N.º de serie';

  @override
  String get sscc => 'SSCC';

  @override
  String get quantity => 'Cantidad';

  @override
  String get bestBefore => 'Consumo preferente';

  @override
  String get loyaltyCard => 'Tarjeta de fidelidad';

  @override
  String get cardNumber => 'Número de tarjeta';

  @override
  String get accepted => 'Aceptado';

  @override
  String get needsAttention => 'Revise este código';

  @override
  String get rejected => 'No aceptado';

  @override
  String checkedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registrados',
      one: '$count registrado',
    );
    return '$_temp0';
  }

  @override
  String codesInView(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count códigos',
      one: '$count código',
    );
    return '$_temp0';
  }

  @override
  String get pickCode => 'Elegir este código';

  @override
  String get scanCode => 'Escanear un código';

  @override
  String get hintCode => 'Apunte la cámara a un código';

  @override
  String get hintQrCode => 'Apunte a un código QR';

  @override
  String get hintBarcode => 'Apunte al código de barras';

  @override
  String get hintCloser => 'Acérquese más';

  @override
  String get hintTicket => 'Apunte a la entrada';

  @override
  String get hintDataMatrix => 'Apunte al código Data Matrix';

  @override
  String get hintPick => 'Toque un código';

  @override
  String get hintKiosk => 'Acerque el código a la cámara';

  @override
  String get hintVin => 'Parabrisas o marco de la puerta';

  @override
  String get hintCard => 'Apunte al código de barras de la tarjeta';

  @override
  String get hintField => 'Apunte al código';

  @override
  String get titlePayment => 'Pagar con QR';

  @override
  String get titleTicket => 'Escanee su entrada';

  @override
  String get titleSignIn => 'Escanee para iniciar sesión';
}
