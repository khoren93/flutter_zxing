part of 'barcode_content.dart';

/// A payment request: who to pay, into which account, how much and what
/// for. One subclass per standard, each with its own fields; the getters
/// here are what every standard has, so that one screen can show any of
/// them:
///
/// ```dart
/// if (barcode.content case final PaymentContent payment) {
///   showPayment(payment.payee, payment.amount, payment.currency);
/// }
/// ```
///
/// Amounts are text with a decimal point (`'12.50'`), never a `double`, so
/// nothing is lost to rounding. A code whose check digits or checksum are
/// wrong is not a payment: it parses as [TextContent].
///
/// New standards are added in minor versions, so a `switch` over a payment
/// needs a `default` (or `_`) case; classes outside this package cannot
/// extend it.
abstract final class PaymentContent extends BarcodeContent {
  const PaymentContent();

  /// Who is paid.
  String? get payee;

  /// The account paid into: an IBAN, an account number, a UPI address or a
  /// PIX key.
  String? get account;

  /// The amount with a decimal point, or `null` when the payer enters it.
  String? get amount;

  /// The ISO 4217 code of the currency, such as `EUR`.
  String? get currency;

  /// What the payment is for: a reference or a message.
  String? get reference;
}

/// A SEPA credit transfer (EPC QR code, "GiroCode", EPC069-12):
/// `BCD\n002\n1\nSCT\n…`. Always in euros.
final class EpcPaymentContent extends PaymentContent {
  /// Creates an EPC payment.
  const EpcPaymentContent({
    required this.name,
    required this.iban,
    this.bic,
    this.amount,
    this.purposeCode,
    this.creditorReference,
    this.text,
    this.information,
  });

  /// The beneficiary, up to 70 characters.
  final String name;

  /// The beneficiary's IBAN, without spaces.
  final String iban;

  /// The beneficiary's BIC; optional within the EEA.
  final String? bic;

  /// The amount in euros, 0.01–999999999.99, up to two decimals.
  @override
  final String? amount;

  /// A four-letter ISO 20022 purpose code, such as `CHAR` or `GDDS`.
  final String? purposeCode;

  /// A structured reference, such as an ISO 11649 `RF…` reference; not
  /// together with [text].
  final String? creditorReference;

  /// Remittance text for the beneficiary, up to 140 characters.
  final String? text;

  /// A note for the payer, up to 70 characters, not sent with the payment.
  final String? information;

  @override
  String get payee => name;

  @override
  String get account => iban;

  @override
  String get currency => 'EUR';

  @override
  String? get reference => creditorReference ?? text;

  /// Version 002 in UTF-8; the IBAN without spaces. At most 331 bytes.
  @override
  String toPayload() => buildEpc(this);

  @override
  List<ContentIssue> validate() => validateEpc(this);

  @override
  bool operator ==(Object other) =>
      other is EpcPaymentContent &&
      other.name == name &&
      other.iban == iban &&
      other.bic == bic &&
      other.amount == amount &&
      other.purposeCode == purposeCode &&
      other.creditorReference == creditorReference &&
      other.text == text &&
      other.information == information;

  @override
  int get hashCode => Object.hash(
    name,
    iban,
    bic,
    amount,
    purposeCode,
    creditorReference,
    text,
    information,
  );

  @override
  String toString() => 'EpcPaymentContent($name, ${amount ?? '-'} EUR)';
}

/// An address on a Swiss QR-bill.
@immutable
final class SwissAddress {
  /// Creates an address.
  const SwissAddress({
    required this.name,
    required this.postalCode,
    required this.town,
    required this.country,
    this.street,
    this.buildingNumber,
  });

  /// A person's or a company's name, up to 70 characters.
  final String name;

  /// The street, up to 70 characters.
  final String? street;

  /// The building number, up to 16 characters.
  final String? buildingNumber;

  /// The postal code without a country prefix, up to 16 characters.
  final String postalCode;

  /// The town, up to 35 characters.
  final String town;

  /// The two-letter ISO 3166 country code, such as `CH`.
  final String country;

  @override
  bool operator ==(Object other) =>
      other is SwissAddress &&
      other.name == name &&
      other.street == street &&
      other.buildingNumber == buildingNumber &&
      other.postalCode == postalCode &&
      other.town == town &&
      other.country == country;

  @override
  int get hashCode =>
      Object.hash(name, street, buildingNumber, postalCode, town, country);

  @override
  String toString() => 'SwissAddress($name, $postalCode $town, $country)';
}

/// The kind of reference on a Swiss QR-bill.
enum SwissReferenceType {
  /// A QR reference: 27 digits, only with a QR-IBAN.
  qrr,

  /// An ISO 11649 creditor reference (`RF…`).
  scor,

  /// No reference.
  none,
}

/// A Swiss QR-bill (Swiss Payment Standards, version 2.3): `SPC\n0200\n1\n…`.
///
/// Draw it with the Swiss cross the standard requires:
///
/// ```dart
/// BarcodeView(bill.toPayload(), style: BarcodeStyle.swissQrBill)
/// ```
final class SwissQrBillContent extends PaymentContent {
  /// Creates a QR-bill.
  const SwissQrBillContent({
    required this.iban,
    required this.creditor,
    this.amount,
    this.currency = 'CHF',
    this.debtor,
    this.referenceType = SwissReferenceType.none,
    this.qrReference,
    this.message,
    this.billInformation,
    this.alternativeSchemes = const <String>[],
  });

  /// The creditor's IBAN or QR-IBAN (Switzerland or Liechtenstein), without
  /// spaces.
  final String iban;

  /// Who is paid.
  final SwissAddress creditor;

  /// The amount with two decimals (`'1949.75'`), or `null` for the payer to
  /// fill in.
  @override
  final String? amount;

  /// `CHF` or `EUR`.
  @override
  final String currency;

  /// Who pays, if known.
  final SwissAddress? debtor;

  /// The kind of [qrReference].
  final SwissReferenceType referenceType;

  /// The QR reference (27 digits) or creditor reference (`RF…`).
  final String? qrReference;

  /// An unstructured message, up to 140 characters together with
  /// [billInformation].
  final String? message;

  /// Structured bill information for the creditor's software (`//S1/…`).
  final String? billInformation;

  /// Up to two alternative procedures (`eBill/B/…`), as written.
  final List<String> alternativeSchemes;

  @override
  String get payee => creditor.name;

  @override
  String get account => iban;

  @override
  String? get reference => qrReference ?? message;

  /// The 0200 format with a structured creditor address, lines ending in a
  /// line feed. At most 997 characters.
  @override
  String toPayload() => buildSwissQrBill(this);

  @override
  List<ContentIssue> validate() => validateSwissQrBill(this);

  @override
  bool operator ==(Object other) =>
      other is SwissQrBillContent &&
      other.iban == iban &&
      other.creditor == creditor &&
      other.amount == amount &&
      other.currency == currency &&
      other.debtor == debtor &&
      other.referenceType == referenceType &&
      other.qrReference == qrReference &&
      other.message == message &&
      other.billInformation == billInformation &&
      listEquals(other.alternativeSchemes, alternativeSchemes);

  @override
  int get hashCode => Object.hash(
    iban,
    creditor,
    amount,
    currency,
    debtor,
    referenceType,
    qrReference,
    message,
    billInformation,
    Object.hashAll(alternativeSchemes),
  );

  @override
  String toString() =>
      'SwissQrBillContent(${creditor.name}, ${amount ?? '-'} $currency)';
}

/// A Russian bank transfer (ГОСТ Р 56042-2014): `ST00012|Name=…|…`.
///
/// Parsed in any of the standard's encodings, written in UTF-8.
final class GostPaymentContent extends PaymentContent {
  /// Creates a payment.
  const GostPaymentContent({
    required this.name,
    required this.personalAccount,
    required this.bankName,
    required this.bic,
    required this.correspondentAccount,
    this.amount,
    this.purpose,
    this.payeeInn,
    this.kpp,
    this.extra = const <String, String>{},
  });

  /// The payee (`Name`), up to 160 characters.
  final String name;

  /// The payee's account (`PersonalAcc`), 20 digits.
  final String personalAccount;

  /// The payee's bank (`BankName`), up to 45 characters.
  final String bankName;

  /// The bank's BIC (`BIC`), 9 digits.
  final String bic;

  /// The bank's correspondent account (`CorrespAcc`), 20 digits, or `0`.
  final String correspondentAccount;

  /// The amount in rubles with two decimals (`'1250.50'`); the code holds
  /// it in kopecks (`Sum`).
  @override
  final String? amount;

  /// What the payment is for (`Purpose`), up to 210 characters.
  final String? purpose;

  /// The payee's taxpayer number (`PayeeINN`), 10 or 12 digits.
  final String? payeeInn;

  /// The payee's tax registration reason code (`KPP`), 9 characters.
  final String? kpp;

  /// The other fields of the standard, by name, in order: `PayerAddress`,
  /// `PersAcc`, `UIN`, `CBC`, `OKTMO` and so on.
  final Map<String, String> extra;

  @override
  String get payee => name;

  @override
  String get account => personalAccount;

  @override
  String get currency => 'RUB';

  @override
  String? get reference => purpose;

  /// `ST00012|Name=…|PersonalAcc=…|BankName=…|BIC=…|CorrespAcc=…|…`.
  @override
  String toPayload() => buildGost(this);

  @override
  List<ContentIssue> validate() => validateGost(this);

  @override
  bool operator ==(Object other) =>
      other is GostPaymentContent &&
      other.name == name &&
      other.personalAccount == personalAccount &&
      other.bankName == bankName &&
      other.bic == bic &&
      other.correspondentAccount == correspondentAccount &&
      other.amount == amount &&
      other.purpose == purpose &&
      other.payeeInn == payeeInn &&
      other.kpp == kpp &&
      mapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    name,
    personalAccount,
    bankName,
    bic,
    correspondentAccount,
    amount,
    purpose,
    payeeInn,
    kpp,
    Object.hashAllUnordered(
      extra.entries.map(
        (MapEntry<String, String> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() => 'GostPaymentContent($name, ${amount ?? '-'} RUB)';
}

/// An Indian UPI payment: `upi://pay?pa=name@bank&pn=…&am=…`.
final class UpiPaymentContent extends PaymentContent {
  /// Creates a UPI payment.
  const UpiPaymentContent({
    required this.address,
    this.name,
    this.amount,
    this.note,
    this.merchantCode,
    this.transactionReference,
    this.extra = const <String, String>{},
  });

  /// The payee's UPI address (`pa`), such as `shop@okbank`.
  final String address;

  /// The payee's name (`pn`).
  final String? name;

  /// The amount in rupees (`am`), up to two decimals.
  @override
  final String? amount;

  /// A note for the payment (`tn`).
  final String? note;

  /// The merchant category code (`mc`).
  final String? merchantCode;

  /// The merchant's transaction reference (`tr`).
  final String? transactionReference;

  /// Other parameters, by name, as written (`tid`, `mode`, `purpose`…).
  final Map<String, String> extra;

  @override
  String get payee => name ?? address;

  @override
  String get account => address;

  @override
  String get currency => 'INR';

  @override
  String? get reference => note;

  /// `upi://pay?pa=…&pn=…&am=…&cu=INR&tn=…`, percent-encoded.
  @override
  String toPayload() => buildUpi(this);

  @override
  List<ContentIssue> validate() => validateUpi(this);

  @override
  bool operator ==(Object other) =>
      other is UpiPaymentContent &&
      other.address == address &&
      other.name == name &&
      other.amount == amount &&
      other.note == note &&
      other.merchantCode == merchantCode &&
      other.transactionReference == transactionReference &&
      mapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    address,
    name,
    amount,
    note,
    merchantCode,
    transactionReference,
    Object.hashAllUnordered(
      extra.entries.map(
        (MapEntry<String, String> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() => 'UpiPaymentContent($address, ${amount ?? '-'} INR)';
}

/// The national payment scheme of an [EmvPaymentContent], from the
/// globally unique identifier of its merchant account.
///
/// New schemes are added in minor versions: a `switch` over it needs a
/// `default` (or `_`) case.
enum EmvScheme {
  /// Brazil's PIX (`br.gov.bcb.pix`).
  pix,

  /// Singapore's PayNow (`SG.PAYNOW`).
  payNow,

  /// Thailand's PromptPay (`A000000677…`).
  promptPay,

  /// Indonesia's QRIS (`ID.CO.QRIS…`).
  qris,

  /// Vietnam's VietQR / NAPAS (`A000000727`).
  vietQr,

  /// Malaysia's DuitNow (`MY.COM.PAYNET`).
  duitNow,

  /// Another scheme, or card networks only.
  unknown,
}

/// An EMVCo merchant-presented QR code (EMV QRCPS): the format of PIX,
/// PayNow, PromptPay, QRIS, VietQR, DuitNow and many other national
/// schemes. `000201…6304XXXX`.
///
/// [fields] holds the data objects by their two-digit id, in order;
/// templates (merchant accounts 26–51, additional data 62) keep their
/// nested data objects as written. The checksum (`63`) is checked when
/// parsing and written by [toPayload]. Build a PIX code with
/// [EmvPaymentContent.pix].
final class EmvPaymentContent extends PaymentContent {
  /// Creates an EMVCo payment from its data objects, without `63`.
  const EmvPaymentContent(this.fields);

  /// A PIX payment (Banco Central do Brasil): [key] is the PIX key (an
  /// e-mail address, a phone number such as `+5511912345678`, a CPF/CNPJ
  /// or a random key); [name] up to 25 and [city] up to 15 characters;
  /// [txid] up to 25 letters and digits, `***` for none.
  factory EmvPaymentContent.pix({
    required String key,
    required String name,
    required String city,
    String? amount,
    String txid = '***',
    String? description,
  }) => EmvPaymentContent(
    Map<String, String>.unmodifiable(<String, String>{
      '00': '01',
      '26': emvTemplate(<String, String>{
        '00': 'br.gov.bcb.pix',
        '01': key,
        if (description != null && description.isNotEmpty) '02': description,
      }),
      '52': '0000',
      '53': '986',
      '54': ?amount,
      '58': 'BR',
      '59': name,
      '60': city,
      '62': emvTemplate(<String, String>{'05': txid}),
    }),
  );

  /// The data objects by id, without the checksum (`63`).
  final Map<String, String> fields;

  /// The scheme of the first merchant account that names one.
  EmvScheme get scheme => emvScheme(this);

  /// The merchant's name (`59`).
  String? get merchantName => fields['59'];

  /// The merchant's city (`60`).
  String? get merchantCity => fields['60'];

  /// The two-letter country code (`58`).
  String? get countryCode => fields['58'];

  /// The ISO 4217 numeric currency code (`53`), such as `986`.
  String? get currencyCode => fields['53'];

  /// The merchant category code (`52`).
  String? get merchantCategoryCode => fields['52'];

  /// Whether the code is for one payment (`01` = `12`) rather than reusable.
  bool get isDynamic => fields['01'] == '12';

  /// The nested data objects of template [id] (`26`–`51`, `62`, `64`), or an
  /// empty map.
  Map<String, String> template(String id) => parseEmvTemplate(fields[id]);

  /// The PIX key, for [EmvScheme.pix].
  String? get pixKey => emvPixKey(this);

  @override
  String? get payee => merchantName;

  @override
  String? get account => pixKey;

  @override
  String? get amount => fields['54'];

  /// The alphabetic code of [currencyCode] for common currencies, else the
  /// numeric code.
  @override
  String? get currency => emvCurrency(currencyCode);

  /// The reference label of the additional data (`62`, `05`), such as a
  /// PIX txid; `null` for `***`.
  @override
  String? get reference => emvReference(this);

  /// The data objects in order, then the checksum.
  @override
  String toPayload() => buildEmv(this);

  @override
  List<ContentIssue> validate() => validateEmv(this);

  @override
  bool operator ==(Object other) =>
      other is EmvPaymentContent && mapEquals(other.fields, fields);

  @override
  int get hashCode => Object.hashAllUnordered(
    fields.entries.map(
      (MapEntry<String, String> e) => Object.hash(e.key, e.value),
    ),
  );

  @override
  String toString() =>
      'EmvPaymentContent(${scheme.name}, ${merchantName ?? ''}, ${amount ?? '-'})';
}

/// A Czech payment (Short Payment Descriptor, SPAYD):
/// `SPD*1.0*ACC:CZ…*AM:480.50*CC:CZK*MSG:…`.
final class SpaydPaymentContent extends PaymentContent {
  /// Creates a SPAYD payment.
  const SpaydPaymentContent({
    required this.iban,
    this.bic,
    this.amount,
    this.currency,
    this.recipientName,
    this.message,
    this.dueDate,
    this.variableSymbol,
    this.specificSymbol,
    this.constantSymbol,
    this.extra = const <String, String>{},
  });

  /// The recipient's IBAN (`ACC`), without spaces.
  final String iban;

  /// The recipient bank's BIC (`ACC:…+BIC`).
  final String? bic;

  /// The amount (`AM`), up to two decimals.
  @override
  final String? amount;

  /// The currency (`CC`); `null` means Czech crowns.
  @override
  final String? currency;

  /// The recipient's name (`RN`), up to 35 characters.
  final String? recipientName;

  /// A message for the recipient (`MSG`), up to 60 characters.
  final String? message;

  /// The due date (`DT`), at local midnight.
  final DateTime? dueDate;

  /// The variable symbol (`X-VS`), up to 10 digits.
  final String? variableSymbol;

  /// The specific symbol (`X-SS`), up to 10 digits.
  final String? specificSymbol;

  /// The constant symbol (`X-KS`), up to 10 digits.
  final String? constantSymbol;

  /// Other keys, as written (`RF`, `X-PER`, `X-URL`…). `CRC32` is not kept.
  final Map<String, String> extra;

  @override
  String? get payee => recipientName;

  @override
  String get account => iban;

  @override
  String? get reference => message ?? variableSymbol;

  /// `SPD*1.0*ACC:…*AM:…*CC:…*…`, with `*` in values written `%2A`.
  @override
  String toPayload() => buildSpayd(this);

  @override
  List<ContentIssue> validate() => validateSpayd(this);

  @override
  bool operator ==(Object other) =>
      other is SpaydPaymentContent &&
      other.iban == iban &&
      other.bic == bic &&
      other.amount == amount &&
      other.currency == currency &&
      other.recipientName == recipientName &&
      other.message == message &&
      other.dueDate == dueDate &&
      other.variableSymbol == variableSymbol &&
      other.specificSymbol == specificSymbol &&
      other.constantSymbol == constantSymbol &&
      mapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    iban,
    bic,
    amount,
    currency,
    recipientName,
    message,
    dueDate,
    variableSymbol,
    specificSymbol,
    constantSymbol,
    Object.hashAllUnordered(
      extra.entries.map(
        (MapEntry<String, String> e) => Object.hash(e.key, e.value),
      ),
    ),
  );

  @override
  String toString() =>
      'SpaydPaymentContent($iban, ${amount ?? '-'} ${currency ?? 'CZK'})';
}
