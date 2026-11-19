// What the generator makes: every kind of content the package builds, in
// groups, with the form each one asks for. The library builds the text
// (`toPayload`) and finds what is wrong (`validate`); this file only maps
// form fields to its classes, and prints them back as Dart.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// The groups of the kind picker.
enum KindGroup {
  basics('Basics'),
  social('Social and apps'),
  security('Security'),
  payments('Payments'),
  crypto('Crypto'),
  gs1('GS1');

  const KindGroup(this.label);

  final String label;

  List<CreateKind> get kinds => <CreateKind>[
    for (final CreateKind k in CreateKind.values)
      if (k.group == this) k,
  ];
}

/// What a field takes, for its keyboard and font.
enum FieldInput { text, multiline, url, email, phone, number, decimal, code }

/// A field of a kind's form. [key] is the name of the content class's
/// parameter, so that `ContentIssue.field` points at it.
@immutable
final class KindField {
  const KindField(
    this.key,
    this.label,
    this.example, {
    this.hint,
    this.optional = false,
    this.input = FieldInput.text,
  });

  final String key;
  final String label;

  /// The field's starting value: a valid example the person edits.
  final String example;
  final String? hint;
  final bool optional;
  final FieldInput input;

  bool get mono => input == FieldInput.code;
}

/// A choice of a few values, shown as a segmented button.
@immutable
final class KindChoice {
  const KindChoice(this.key, this.label, this.options);

  final String key;
  final String label;

  /// Value and label; the first is the default.
  final List<(String, String)> options;
}

/// A problem a form field has: from `validate()`, or from the form itself
/// (a date that is not a date).
final class FieldProblem implements Exception {
  const FieldProblem(this.field, this.message);

  final String field;
  final String message;
}

/// The kinds the generator makes.
enum CreateKind {
  text('Text', KindGroup.basics, Icons.notes_rounded),
  link('Link', KindGroup.basics, Icons.link_rounded),
  wifi('Wi‑Fi', KindGroup.basics, Icons.wifi_rounded),
  contact('Contact', KindGroup.basics, Icons.person_outline_rounded),
  email('Email', KindGroup.basics, Icons.mail_outline_rounded),
  phone('Phone', KindGroup.basics, Icons.call_outlined),
  sms('SMS', KindGroup.basics, Icons.sms_outlined),
  geo('Location', KindGroup.basics, Icons.place_outlined),
  event('Event', KindGroup.basics, Icons.event_outlined),
  service('Link to a service', KindGroup.social, Icons.forum_outlined),
  otp('2FA code', KindGroup.security, Icons.key_rounded),
  esim('eSIM', KindGroup.security, Icons.sim_card_outlined),
  epc('SEPA', KindGroup.payments, Icons.payments_outlined),
  swiss('Swiss QR‑bill', KindGroup.payments, Icons.add_box_outlined),
  gost('ГОСТ', KindGroup.payments, Icons.payments_outlined),
  upi('UPI', KindGroup.payments, Icons.payments_outlined),
  pix('PIX', KindGroup.payments, Icons.payments_outlined),
  spayd('SPAYD', KindGroup.payments, Icons.payments_outlined),
  bitcoin('Bitcoin', KindGroup.crypto, Icons.currency_bitcoin_rounded),
  ethereum('Ethereum', KindGroup.crypto, Icons.hexagon_outlined),
  lightning('Lightning', KindGroup.crypto, Icons.bolt_rounded),
  gs1('GS1 data', KindGroup.gs1, Icons.view_week_outlined);

  const CreateKind(this.label, this.group, this.icon);

  /// The name on a tile.
  final String label;
  final KindGroup group;
  final IconData icon;

  /// The name over the form.
  String get title => switch (this) {
    otp => 'Two-factor code',
    epc => 'SEPA transfer · EPC',
    swiss => 'Swiss QR-bill',
    gost => 'ГОСТ Р 56042',
    upi => 'UPI payment',
    pix => 'PIX payment',
    spayd => 'SPAYD payment',
    gs1 => 'GS1 element string',
    _ => label,
  };

  /// The format the kind is made in when picked.
  BarcodeFormat get format =>
      this == gs1 ? BarcodeFormat.dataMatrix : BarcodeFormat.qrCode;

  /// The error correction the standard asks for (EPC, Swiss QR-bill: M).
  ErrorCorrection? get errorCorrection =>
      this == epc || this == swiss ? ErrorCorrection.medium : null;

  /// GS1 data is written with the GS1 flag (FNC1 first).
  bool get gs1Flag => this == gs1;

  /// The fields of the form, by the content class's parameter names.
  List<KindField> get fields => switch (this) {
    text => const <KindField>[
      KindField('text', 'Text', 'Anything', input: FieldInput.multiline),
    ],
    link => const <KindField>[
      KindField(
        'url',
        'Address',
        'https://pub.dev/packages/flutter_zxing',
        input: FieldInput.url,
      ),
      KindField(
        'title',
        'Title',
        '',
        optional: true,
        hint: 'With a title, the code is a MEBKM: bookmark',
      ),
    ],
    wifi => const <KindField>[
      KindField('ssid', 'Network name', 'Studio 5G'),
      KindField(
        'password',
        'Password',
        'lime-orbit-42',
        optional: true,
        input: FieldInput.code,
      ),
    ],
    contact => const <KindField>[
      KindField('name', 'Name', 'Lilit Ohanyan'),
      KindField('organization', 'Company', 'Lumen Studio', optional: true),
      KindField(
        'phones',
        'Phone',
        '+374 91 234567',
        optional: true,
        input: FieldInput.phone,
      ),
      KindField(
        'emails',
        'Email',
        'lilit@example.com',
        optional: true,
        input: FieldInput.email,
      ),
    ],
    email => const <KindField>[
      KindField('address', 'To', 'hello@example.com', input: FieldInput.email),
      KindField('subject', 'Subject', 'Hello', optional: true),
      KindField('body', 'Message', '', optional: true),
    ],
    phone => const <KindField>[
      KindField('number', 'Number', '+374 10 123456', input: FieldInput.phone),
    ],
    sms => const <KindField>[
      KindField('number', 'Number', '+374 91 234567', input: FieldInput.phone),
      KindField('message', 'Message', 'See you at 7', optional: true),
    ],
    geo => const <KindField>[
      KindField('latitude', 'Latitude', '40.1792', input: FieldInput.decimal),
      KindField('longitude', 'Longitude', '44.4991', input: FieldInput.decimal),
      KindField('query', 'Label', 'Republic Square', optional: true),
    ],
    event => const <KindField>[
      KindField('summary', 'Title', 'flutter_zxing meetup'),
      KindField(
        'start',
        'Starts',
        '2026-12-05 18:00',
        hint: 'YYYY-MM-DD HH:MM, local time',
      ),
      KindField('end', 'Ends', '2026-12-05 21:00', optional: true),
      KindField('location', 'Place', 'Lumen Studio', optional: true),
    ],
    service => const <KindField>[],
    otp => const <KindField>[
      KindField('issuer', 'Issuer', 'Acme', optional: true),
      KindField('account', 'Account', 'anna@example.com'),
      KindField(
        'secret',
        'Secret, Base32',
        'JBSW Y3DP EHPK 3PXP',
        input: FieldInput.code,
        hint: 'Spaces and lower case are fine; toPayload() normalises them',
      ),
    ],
    esim => const <KindField>[
      KindField('smdpAddress', 'SM-DP+ address', 'consumer.rsp.world'),
      KindField(
        'matchingId',
        'Activation code',
        'K2-1Q2W3E-4R5T6Y',
        optional: true,
        input: FieldInput.code,
      ),
    ],
    epc => const <KindField>[
      KindField('name', 'Payee', 'Radio Lumen e.V.'),
      KindField(
        'iban',
        'IBAN',
        'DE89 3704 0044 0532 0130 00',
        input: FieldInput.code,
      ),
      KindField(
        'amount',
        'Amount, EUR',
        '25.00',
        optional: true,
        input: FieldInput.decimal,
      ),
      KindField(
        'bic',
        'BIC',
        'COBADEFFXXX',
        optional: true,
        input: FieldInput.code,
      ),
      KindField('message', 'Message', 'Donation November', optional: true),
    ],
    swiss => const <KindField>[
      KindField(
        'iban',
        'IBAN or QR-IBAN',
        'CH93 0076 2011 6238 5295 7',
        input: FieldInput.code,
      ),
      KindField('creditor.name', 'Creditor', 'Lumen Café'),
      KindField('creditor.street', 'Street', 'Bahnhofstrasse', optional: true),
      KindField('creditor.buildingNumber', 'Number', '1', optional: true),
      KindField('creditor.postalCode', 'Postal code', '8001'),
      KindField('creditor.town', 'Town', 'Zürich'),
      KindField('creditor.country', 'Country', 'CH'),
      KindField(
        'amount',
        'Amount',
        '49.50',
        optional: true,
        input: FieldInput.decimal,
        hint: 'Empty: the payer enters it',
      ),
      KindField(
        'creditorReference',
        'Reference',
        '',
        optional: true,
        input: FieldInput.code,
      ),
      KindField('message', 'Message', 'Invoice 2026-11', optional: true),
    ],
    gost => const <KindField>[
      KindField('name', 'Получатель', 'ООО «Лумен»'),
      KindField(
        'personalAccount',
        'Расчётный счёт',
        '40702810138250123017',
        input: FieldInput.code,
      ),
      KindField('bankName', 'Банк', 'ПАО Сбербанк'),
      KindField('bic', 'БИК', '044525225', input: FieldInput.code),
      KindField(
        'correspondentAccount',
        'Корр. счёт',
        '30101810400000000225',
        input: FieldInput.code,
      ),
      KindField(
        'amount',
        'Сумма, ₽',
        '1250.50',
        optional: true,
        input: FieldInput.decimal,
      ),
      KindField('purpose', 'Назначение', 'Оплата по счёту 42', optional: true),
      KindField(
        'payeeInn',
        'ИНН',
        '7707083893',
        optional: true,
        input: FieldInput.code,
      ),
    ],
    upi => const <KindField>[
      KindField('address', 'UPI ID', 'shop@okbank', input: FieldInput.code),
      KindField('name', 'Payee', 'Lumen Café', optional: true),
      KindField(
        'amount',
        'Amount, INR',
        '99.50',
        optional: true,
        input: FieldInput.decimal,
      ),
      KindField('note', 'Note', 'Table 4', optional: true),
    ],
    pix => const <KindField>[
      KindField(
        'key',
        'PIX key',
        '123e4567-e12b-12d1-a456-426655440000',
        input: FieldInput.code,
      ),
      KindField('name', 'Merchant', 'Lumen Cafe'),
      KindField('city', 'City', 'Sao Paulo'),
      KindField(
        'amount',
        'Amount, BRL',
        '25.00',
        optional: true,
        input: FieldInput.decimal,
      ),
    ],
    spayd => const <KindField>[
      KindField(
        'iban',
        'IBAN',
        'CZ65 0800 0000 1920 0014 5399',
        input: FieldInput.code,
      ),
      KindField(
        'amount',
        'Amount, CZK',
        '450.00',
        optional: true,
        input: FieldInput.decimal,
      ),
      KindField('recipientName', 'Recipient', 'Lumen s.r.o.', optional: true),
      KindField('message', 'Message', 'Order 42', optional: true),
    ],
    bitcoin => const <KindField>[
      KindField(
        'address',
        'Address',
        'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
        input: FieldInput.code,
      ),
      KindField(
        'amount',
        'Amount, BTC',
        '0.0015',
        optional: true,
        input: FieldInput.decimal,
      ),
      KindField('label', 'Label', 'Lumen Café', optional: true),
    ],
    ethereum => const <KindField>[
      KindField(
        'address',
        'Address',
        '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed',
        input: FieldInput.code,
      ),
      KindField(
        'amount',
        'Amount, ETH',
        '0.02',
        optional: true,
        input: FieldInput.decimal,
      ),
    ],
    lightning => const <KindField>[
      KindField(
        'address',
        'Invoice or LNURL',
        'lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq9qrsgq357wnc5r2ueh7ck6q93dj32dlqnls087fxdwk8qakdyafkq3yap9us6v52vjjsrvywa6rt52cm9r9zqt8r2t7mlcwspyetp5h2tztugp9lfyql',
        input: FieldInput.code,
      ),
    ],
    gs1 => const <KindField>[
      KindField('01', 'GTIN (01)', '09506000134352', input: FieldInput.code),
      KindField(
        '17',
        'Expiry (17), YYMMDD',
        '271231',
        optional: true,
        input: FieldInput.number,
      ),
      KindField(
        '10',
        'Batch (10)',
        'A1B2C3',
        optional: true,
        input: FieldInput.code,
      ),
      KindField(
        '21',
        'Serial (21)',
        '7XK9Q2',
        optional: true,
        input: FieldInput.code,
      ),
    ],
  };

  /// The kind's choices of a few values.
  List<KindChoice> get choices => switch (this) {
    wifi => const <KindChoice>[
      KindChoice('security', 'Security', <(String, String)>[
        ('wpa', 'WPA / WPA2'),
        ('wpa3', 'WPA3'),
        ('wep', 'WEP'),
        ('none', 'None'),
      ]),
    ],
    otp => const <KindChoice>[
      KindChoice('digits', 'Digits', <(String, String)>[
        ('6', '6'),
        ('8', '8'),
      ]),
      KindChoice('period', 'Every', <(String, String)>[
        ('30', '30 s'),
        ('60', '60 s'),
      ]),
    ],
    swiss => const <KindChoice>[
      KindChoice('currency', 'Currency', <(String, String)>[
        ('CHF', 'CHF'),
        ('EUR', 'EUR'),
      ]),
    ],
    _ => const <KindChoice>[],
  };

  /// The content [values] (by [fields] keys), [choices] and [linkService]
  /// describe. Throws a [FieldProblem] for a value the form cannot even
  /// hand to the library (a date that is not a date).
  BarcodeContent content(
    Map<String, String> values,
    Map<String, String> choices, {
    LinkService linkService = LinkService.whatsApp,
  }) {
    String v(String key) => (values[key] ?? '').trim();
    String? o(String key) => v(key).isEmpty ? null : v(key);
    String c(String key) =>
        choices[key] ??
        this.choices
            .firstWhere((KindChoice k) => k.key == key)
            .options
            .first
            .$1;
    double number(String key) =>
        double.tryParse(v(key)) ??
        (throw FieldProblem(key, 'Not a number: ${v(key)}'));
    DateTime date(String key) =>
        DateTime.tryParse(v(key)) ??
        (throw FieldProblem(key, 'Use YYYY-MM-DD HH:MM'));
    return switch (this) {
      text => TextContent(values['text'] ?? ''),
      link => UrlContent(Uri.tryParse(v('url')) ?? Uri(), title: o('title')),
      wifi => WifiContent(
        ssid: v('ssid'),
        password: o('password'),
        security: switch (c('security')) {
          'wep' => WifiSecurity.wep,
          'none' => WifiSecurity.none,
          'wpa3' => WifiSecurity.wpa3,
          _ => WifiSecurity.wpa,
        },
      ),
      contact => ContactContent(
        name: o('name'),
        organization: o('organization'),
        phones: <String>[?o('phones')],
        emails: <String>[?o('emails')],
      ),
      email => EmailContent(
        address: v('address'),
        subject: o('subject'),
        body: o('body'),
      ),
      phone => PhoneContent(v('number')),
      sms => SmsContent(number: v('number'), message: o('message')),
      geo => GeoContent(
        latitude: number('latitude'),
        longitude: number('longitude'),
        query: o('query'),
      ),
      event => EventContent(
        summary: v('summary'),
        start: date('start'),
        end: o('end') == null ? null : date('end'),
        location: o('location'),
      ),
      service => () {
        try {
          return linkService.link(
            v('value'),
            message: linkService == LinkService.whatsApp ? o('message') : null,
          );
        } on ArgumentError catch (e) {
          throw FieldProblem('value', '${e.message}');
        }
      }(),
      otp => OtpContent(
        issuer: o('issuer'),
        account: v('account'),
        secret: v('secret'),
        digits: int.parse(c('digits')),
        period: int.parse(c('period')),
      ),
      esim => EsimContent(
        smdpAddress: v('smdpAddress'),
        matchingId: o('matchingId'),
      ),
      epc => EpcPaymentContent(
        name: v('name'),
        iban: v('iban'),
        bic: o('bic'),
        amount: o('amount'),
        message: o('message'),
      ),
      swiss => SwissQrBillContent(
        iban: v('iban'),
        creditor: SwissAddress(
          name: v('creditor.name'),
          street: o('creditor.street'),
          buildingNumber: o('creditor.buildingNumber'),
          postalCode: v('creditor.postalCode'),
          town: v('creditor.town'),
          country: v('creditor.country'),
        ),
        amount: o('amount'),
        currency: c('currency'),
        creditorReference: o('creditorReference'),
        message: o('message'),
      ),
      gost => GostPaymentContent(
        name: v('name'),
        personalAccount: v('personalAccount'),
        bankName: v('bankName'),
        bic: v('bic'),
        correspondentAccount: v('correspondentAccount'),
        amount: o('amount'),
        purpose: o('purpose'),
        payeeInn: o('payeeInn'),
      ),
      upi => UpiPaymentContent(
        address: v('address'),
        name: o('name'),
        amount: o('amount'),
        note: o('note'),
      ),
      pix => EmvPaymentContent.pix(
        key: v('key'),
        name: v('name'),
        city: v('city'),
        amount: o('amount'),
      ),
      spayd => SpaydPaymentContent(
        iban: v('iban'),
        amount: o('amount'),
        recipientName: o('recipientName'),
        message: o('message'),
      ),
      bitcoin => CryptoContent(
        currency: CryptoCurrency.bitcoin,
        address: v('address'),
        amount: o('amount'),
        label: o('label'),
      ),
      ethereum => CryptoContent(
        currency: CryptoCurrency.ethereum,
        address: v('address'),
        amount: o('amount'),
      ),
      lightning => CryptoContent(
        currency: CryptoCurrency.lightning,
        address: v('address'),
      ),
      gs1 => Gs1Content(<String, String>{
        for (final KindField f in fields)
          if (o(f.key) case final String value) f.key: value,
      }),
    };
  }

  /// The Dart that builds the kind's content, where the generic printer
  /// cannot know how it was made (a PIX code, a service link).
  String? dart(
    Map<String, String> values, {
    LinkService linkService = LinkService.whatsApp,
  }) {
    String v(String key) => (values[key] ?? '').trim();
    return switch (this) {
      service => _call(
        'LinkService.${linkService.name}.link',
        <Object>[_q(v('value'))],
        <String, Object?>{
          if (linkService == LinkService.whatsApp && v('message').isNotEmpty)
            'message': _q(v('message')),
        },
      ),
      pix => _call('EmvPaymentContent.pix', const <Object>[], <String, Object?>{
        'key': _q(v('key')),
        'name': _q(v('name')),
        'city': _q(v('city')),
        if (v('amount').isNotEmpty) 'amount': _q(v('amount')),
      }),
      _ => null,
    };
  }
}

/// The value a service link asks for, as a field.
KindField serviceField(LinkService s) => switch (s.input) {
  LinkServiceInput.phone => const KindField(
    'value',
    'Phone number',
    '+49 151 2345 6789',
    input: FieldInput.phone,
    hint: 'With the country code. Spaces are fine.',
  ),
  LinkServiceInput.username => const KindField(
    'value',
    'User name',
    'flutterdev',
    hint: 'With or without @',
  ),
  LinkServiceInput.query => const KindField(
    'value',
    'Place or address',
    'Republic Square, Yerevan',
  ),
  LinkServiceInput.id => KindField(
    'value',
    switch (s) {
      LinkService.appStore => 'App id',
      LinkService.googlePlay => 'Package name',
      LinkService.googleReview => 'Place id',
      LinkService.discord => 'Invite code',
      _ => 'Path or link',
    },
    switch (s) {
      LinkService.spotify => 'artist/0TnOYISbd1XYRBk9myaseg',
      LinkService.appleMusic => 'us/album/1440857781',
      LinkService.appStore => '284882215',
      LinkService.googlePlay => 'com.google.android.apps.maps',
      LinkService.googleReview => 'ChIJN1t_tDeuEmsRUsoyG83frY4',
      _ => 'flutter',
    },
    input: FieldInput.code,
  ),
};

/// The first message of a WhatsApp chat.
const KindField whatsAppMessage = KindField(
  'message',
  'First message',
  'Hi!',
  optional: true,
);

/// [content] as the Dart that builds it.
String contentDart(BarcodeContent content) => switch (content) {
  TextContent(:final String text) => _call('TextContent', <Object>[_q(text)]),
  UrlContent(:final Uri url, :final String? title) => _call(
    'UrlContent',
    <Object>['Uri.parse(${_q('$url')})'],
    <String, Object?>{'title': _qn(title)},
  ),
  WifiContent(
    :final String ssid,
    :final String? password,
    :final WifiSecurity security,
    :final bool hidden,
  ) =>
    _call('WifiContent', const <Object>[], <String, Object?>{
      'ssid': _q(ssid),
      'password': _qn(password),
      // Without `security:`, a network with a password is WPA, one
      // without is open.
      if (security !=
          (password == null || password.isEmpty
              ? WifiSecurity.none
              : WifiSecurity.wpa))
        'security': 'WifiSecurity.${security.name}',
      if (hidden) 'hidden': 'true',
    }),
  ContactContent c =>
    _call('ContactContent', const <Object>[], <String, Object?>{
      'name': _qn(c.name),
      'organization': _qn(c.organization),
      if (c.phones.isNotEmpty) 'phones': _list(c.phones.map(_q)),
      if (c.emails.isNotEmpty) 'emails': _list(c.emails.map(_q)),
    }),
  EmailContent e => _call('EmailContent', const <Object>[], <String, Object?>{
    'address': _q(e.address),
    'subject': _qn(e.subject),
    'body': _qn(e.body),
  }),
  PhoneContent(:final String number) => _call('PhoneContent', <Object>[
    _q(number),
  ]),
  SmsContent(:final String number, :final String? message) => _call(
    'SmsContent',
    const <Object>[],
    <String, Object?>{'number': _q(number), 'message': _qn(message)},
  ),
  GeoContent g => _call('GeoContent', const <Object>[], <String, Object?>{
    'latitude': '${g.latitude}',
    'longitude': '${g.longitude}',
    'query': _qn(g.query),
  }),
  EventContent e => _call('EventContent', const <Object>[], <String, Object?>{
    'summary': _q(e.summary),
    'start': _date(e.start),
    if (e.end case final DateTime end) 'end': _date(end),
    'location': _qn(e.location),
  }),
  OtpContent o => _call('OtpContent', const <Object>[], <String, Object?>{
    'issuer': _qn(o.issuer),
    'account': _q(o.account),
    // As toPayload writes it: Base32 without spaces or padding.
    'secret': _q(o.secret.replaceAll(RegExp(r'[\s=]'), '').toUpperCase()),
    if (o.digits != 6) 'digits': '${o.digits}',
    if (o.period != 30) 'period': '${o.period}',
  }),
  EsimContent e => _call('EsimContent', const <Object>[], <String, Object?>{
    'smdpAddress': _q(e.smdpAddress),
    'matchingId': _qn(e.matchingId),
  }),
  EpcPaymentContent p =>
    _call('EpcPaymentContent', const <Object>[], <String, Object?>{
      'name': _q(p.name),
      'iban': _q(p.iban),
      'bic': _qn(p.bic),
      'amount': _qn(p.amount),
      'message': _qn(p.message),
    }),
  SwissQrBillContent p => _call(
    'SwissQrBillContent',
    const <Object>[],
    <String, Object?>{
      'iban': _q(p.iban),
      'creditor': _Code(
        _call('SwissAddress', const <Object>[], <String, Object?>{
          'name': _q(p.creditor.name),
          'street': _qn(p.creditor.street),
          'buildingNumber': _qn(p.creditor.buildingNumber),
          'postalCode': _q(p.creditor.postalCode),
          'town': _q(p.creditor.town),
          'country': _q(p.creditor.country),
        }),
      ),
      'amount': _qn(p.amount),
      if (p.currency != 'CHF') 'currency': _q(p.currency),
      'creditorReference': _qn(p.creditorReference),
      'message': _qn(p.message),
    },
  ),
  GostPaymentContent p =>
    _call('GostPaymentContent', const <Object>[], <String, Object?>{
      'name': _q(p.name),
      'personalAccount': _q(p.personalAccount),
      'bankName': _q(p.bankName),
      'bic': _q(p.bic),
      'correspondentAccount': _q(p.correspondentAccount),
      'amount': _qn(p.amount),
      'purpose': _qn(p.purpose),
      'payeeInn': _qn(p.payeeInn),
    }),
  UpiPaymentContent p =>
    _call('UpiPaymentContent', const <Object>[], <String, Object?>{
      'address': _q(p.address),
      'name': _qn(p.name),
      'amount': _qn(p.amount),
      'note': _qn(p.note),
    }),
  SpaydPaymentContent p =>
    _call('SpaydPaymentContent', const <Object>[], <String, Object?>{
      'iban': _q(p.iban),
      'amount': _qn(p.amount),
      if (p.currency != 'CZK') 'currency': _q(p.currency),
      'recipientName': _qn(p.recipientName),
      'message': _qn(p.message),
    }),
  CryptoContent c => _call('CryptoContent', const <Object>[], <String, Object?>{
    'currency': 'CryptoCurrency.${c.currency.name}',
    'address': _q(c.address),
    'amount': _qn(c.amount),
    'label': _qn(c.label),
  }),
  Gs1Content(:final Map<String, String> elements) => _call('Gs1Content', <
    Object
  >[
    _Code(
      elements.isEmpty
          ? '{}'
          : '{\n${elements.entries.map((MapEntry<String, String> e) => '  ${_q(e.key)}: ${_q(e.value)},').join('\n')}\n}',
    ),
  ]),
  _ => _call('BarcodeContent.parseText', <Object>[_q(content.toPayload())]),
};

/// A Dart string literal of [s].
String _q(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n')}'";

String? _qn(String? s) => s == null ? null : _q(s);

String _list(Iterable<String> items) => '[${items.join(', ')}]';

String _date(DateTime d) {
  final List<int> parts = <int>[d.year, d.month, d.day, d.hour, d.minute];
  while (parts.length > 3 && parts.last == 0) {
    parts.removeLast();
  }
  return '${d.isUtc ? 'DateTime.utc' : 'DateTime'}(${parts.join(', ')})';
}

/// Code that spans lines: indented as a whole where it goes.
final class _Code {
  const _Code(this.code);

  final String code;
}

/// `name(positional, named: value)`, on one line if it is short, otherwise
/// one argument a line. Null named values are left out.
String _call(
  String name,
  List<Object> positional, [
  Map<String, Object?> named = const <String, Object?>{},
]) {
  String text(Object v) => v is _Code ? v.code : '$v';
  final List<String> args = <String>[
    for (final Object p in positional) text(p),
    for (final MapEntry<String, Object?> e in named.entries)
      if (e.value != null) '${e.key}: ${text(e.value!)}',
  ];
  final String line = '$name(${args.join(', ')})';
  if (line.length <= 60 && !line.contains('\n')) {
    return line;
  }
  String indent(String s) => s.split('\n').join('\n  ');
  return '$name(\n${args.map((String a) => '  ${indent(a)},').join('\n')}\n)';
}
