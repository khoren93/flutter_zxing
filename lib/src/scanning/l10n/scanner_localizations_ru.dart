// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'scanner_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class ScannerLocalizationsRu extends ScannerLocalizations {
  ScannerLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get close => 'Закрыть сканер';

  @override
  String get torchOn => 'Включить фонарик';

  @override
  String get torchOff => 'Выключить фонарик';

  @override
  String get switchCamera => 'Сменить камеру';

  @override
  String get pickImage => 'Считать код с фото';

  @override
  String get zoom => 'Масштаб';

  @override
  String get autoZoom => 'Авто';

  @override
  String get autoZoomOn => 'Включить автомасштаб';

  @override
  String get autoZoomOff => 'Выключить автомасштаб';

  @override
  String get starting => 'Запуск камеры…';

  @override
  String get permissionTitle => 'Нет доступа к камере';

  @override
  String get permissionMessage =>
      'Разрешите этому приложению доступ к камере в Настройках, чтобы сканировать коды.';

  @override
  String get unavailableTitle => 'Камера недоступна';

  @override
  String get unavailableMessage =>
      'Возможно, её использует другое приложение или на этом устройстве нет камеры.';

  @override
  String get inUseMessage =>
      'Камеру использует другое приложение. Закройте его и повторите попытку.';

  @override
  String get unsupportedMessage =>
      'Камера здесь недоступна. В браузере страница должна быть открыта по https.';

  @override
  String get photoFallback => 'Код можно считать с фото.';

  @override
  String get openSettings => 'Открыть Настройки';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get choosePhoto => 'Выбрать фото';

  @override
  String get noCodeInPhoto => 'На этом фото нет кода';

  @override
  String get backToCamera => 'Вернуться к камере';

  @override
  String get backToCodes => 'Вернуться к кодам';

  @override
  String get copy => 'Скопировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get scanAgain => 'Сканировать снова';

  @override
  String get done => 'Готово';

  @override
  String get scanned => 'Отсканировано';

  @override
  String get emptyList => 'Здесь появятся отсканированные коды';

  @override
  String itemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String byteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count байта',
      many: '$count байт',
      few: '$count байта',
      one: '$count байт',
    );
    return '$_temp0';
  }

  @override
  String get link => 'Ссылка';

  @override
  String get wifi => 'Сеть Wi‑Fi';

  @override
  String get wifiPassword => 'пароль в коде';

  @override
  String wifiSecurity(String security) {
    String _temp0 = intl.Intl.selectLogic(security, {
      'none': 'Открытая сеть',
      'wep': 'WEP',
      'wpa': 'WPA',
      'wpa3': 'WPA3',
      'enterprise': 'Корпоративная',
      'other': 'Защищённая',
    });
    return '$_temp0';
  }

  @override
  String get contact => 'Контакт';

  @override
  String get event => 'Событие';

  @override
  String get email => 'Эл. почта';

  @override
  String get phone => 'Телефон';

  @override
  String get sms => 'SMS-сообщение';

  @override
  String get location => 'Геопозиция';

  @override
  String get gs1 => 'GS1';

  @override
  String get faceTime => 'FaceTime';

  @override
  String get payment => 'Платёж';

  @override
  String get otp => 'Одноразовый пароль';

  @override
  String get esim => 'eSIM';

  @override
  String get crypto => 'Криптоплатёж';

  @override
  String get wifiDevice => 'Устройство Wi‑Fi';

  @override
  String get smartHome => 'Устройство умного дома';

  @override
  String get boardingPass => 'Посадочный талон';

  @override
  String get driverLicense => 'Водительское удостоверение';

  @override
  String get vehicle => 'Автомобиль';

  @override
  String get product => 'Товар';

  @override
  String get book => 'Книга';

  @override
  String get secret => 'Секретный ключ';

  @override
  String get show => 'Показать';

  @override
  String get hide => 'Скрыть';

  @override
  String get otpType => 'Тип';

  @override
  String get otpTimeBased => 'По времени';

  @override
  String get otpCounterBased => 'По счётчику';

  @override
  String get otpDigits => 'Цифр';

  @override
  String get otpPeriod => 'Каждые';

  @override
  String get otpCounter => 'Счётчик';

  @override
  String seconds(int seconds) {
    return '$seconds с';
  }

  @override
  String get matchingId => 'Matching ID';

  @override
  String get confirmationCode => 'Код подтверждения';

  @override
  String get needed => 'Нужен';

  @override
  String get setupCode => 'Код настройки';

  @override
  String get vendorId => 'Производитель';

  @override
  String get productId => 'Продукт';

  @override
  String get discriminator => 'Дискриминатор';

  @override
  String get category => 'Категория';

  @override
  String get setupId => 'Setup ID';

  @override
  String get gtin => 'GTIN';

  @override
  String get addOn => 'Доп. код';

  @override
  String get passenger => 'Пассажир';

  @override
  String get date => 'Дата';

  @override
  String get seat => 'Место';

  @override
  String get cabin => 'Класс';

  @override
  String get booking => 'Бронирование';

  @override
  String get sequence => 'Порядковый номер';

  @override
  String flightOf(int flight, int count) {
    return 'Рейс $flight из $count';
  }

  @override
  String get licenseNumber => 'Номер';

  @override
  String get born => 'Дата рождения';

  @override
  String get expires => 'Действует до';

  @override
  String get city => 'Город';

  @override
  String get state => 'Регион';

  @override
  String get country => 'Страна';

  @override
  String get expired => 'Срок истёк';

  @override
  String get makerCode => 'Код изготовителя';

  @override
  String get modelYear => 'Модельный год';

  @override
  String get checkDigit => 'Контрольная цифра';

  @override
  String get valid => 'Верна';

  @override
  String get macAddress => 'MAC';

  @override
  String get channels => 'Каналы';

  @override
  String monthShort(String month) {
    String _temp0 = intl.Intl.selectLogic(month, {
      'jan': 'янв.',
      'feb': 'февр.',
      'mar': 'мар.',
      'apr': 'апр.',
      'may': 'мая',
      'jun': 'июн.',
      'jul': 'июл.',
      'aug': 'авг.',
      'sep': 'сент.',
      'oct': 'окт.',
      'nov': 'нояб.',
      'dec': 'дек.',
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
      'africa': 'Африка',
      'asia': 'Азия',
      'europe': 'Европа',
      'northAmerica': 'Северная Америка',
      'oceania': 'Океания',
      'southAmerica': 'Южная Америка',
      'other': 'Неизвестно',
    });
    return '$_temp0';
  }

  @override
  String amount(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get anyAmount => 'Любая сумма';

  @override
  String get payerEntersAmount => 'Сумму вводит плательщик';

  @override
  String get reusable => 'Многоразовый';

  @override
  String get copyIban => 'Скопировать IBAN';

  @override
  String get copyAccount => 'Скопировать счёт';

  @override
  String get copyUpiId => 'Скопировать UPI ID';

  @override
  String get copyPixKey => 'Скопировать ключ';

  @override
  String get iban => 'IBAN';

  @override
  String get bic => 'БИК';

  @override
  String get accountNumber => 'Счёт';

  @override
  String get paymentReference => 'Назначение';

  @override
  String get address => 'Адрес';

  @override
  String get payableBy => 'Плательщик';

  @override
  String get bank => 'Банк';

  @override
  String get inn => 'ИНН';

  @override
  String get kpp => 'КПП';

  @override
  String get upiId => 'UPI ID';

  @override
  String get pixKey => 'Ключ PIX';

  @override
  String get transaction => 'Транзакция';

  @override
  String get variableSymbol => 'Переменный символ';

  @override
  String get binary => 'Двоичные данные';

  @override
  String get text => 'Текст';

  @override
  String get batch => 'Партия';

  @override
  String get serial => 'Серийный номер';

  @override
  String get sscc => 'SSCC';

  @override
  String get quantity => 'Количество';

  @override
  String get bestBefore => 'Годен до';

  @override
  String get loyaltyCard => 'Карта лояльности';

  @override
  String get cardNumber => 'Номер карты';

  @override
  String get accepted => 'Принят';

  @override
  String get needsAttention => 'Проверьте этот код';

  @override
  String get rejected => 'Не принят';

  @override
  String checkedIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отмечено: $count',
    );
    return '$_temp0';
  }

  @override
  String codesInView(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count кода',
      many: '$count кодов',
      few: '$count кода',
      one: '$count код',
    );
    return '$_temp0';
  }

  @override
  String get pickCode => 'Выбрать этот код';

  @override
  String get scanCode => 'Сканировать код';

  @override
  String get hintCode => 'Наведите камеру на код';

  @override
  String get hintQrCode => 'Наведите на QR-код';

  @override
  String get hintBarcode => 'Наведите на штрихкод';

  @override
  String get hintCloser => 'Поднесите ближе';

  @override
  String get hintTicket => 'Наведите на билет';

  @override
  String get hintDataMatrix => 'Наведите на код Data Matrix';

  @override
  String get hintPick => 'Коснитесь кода';

  @override
  String get hintKiosk => 'Поднесите код к камере';

  @override
  String get hintVin => 'Лобовое стекло или стойка двери';

  @override
  String get hintCard => 'Наведите на штрихкод карты';

  @override
  String get hintField => 'Наведите на код';

  @override
  String get titlePayment => 'Оплата по QR';

  @override
  String get titleTicket => 'Отсканируйте билет';

  @override
  String get titleSignIn => 'Отсканируйте, чтобы войти';
}
