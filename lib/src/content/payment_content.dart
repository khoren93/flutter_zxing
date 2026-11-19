import 'dart:convert';

import 'barcode_content.dart';
import 'content_util.dart';
import 'payment_checks.dart';

// Parsing and building the payment kinds: EPC (SEPA), Swiss QR-bill,
// ГОСТ Р 56042-2014, UPI, EMVCo merchant-presented QR and SPAYD.

String _t(String? value) => value?.trim() ?? '';

/// [lines] of a multi-line payload, `\r\n` or `\n`, trailing spaces kept
/// out; missing lines read as empty.
List<String> _lines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

String _at(List<String> lines, int i) =>
    i < lines.length ? lines[i].trim() : '';

/// Fields of line-based formats: a line break would shift the fields after
/// it.
ContentIssue? _lineBreak(String field, String? value, String what) =>
    _t(value).contains(RegExp(r'[\r\n]'))
    ? ContentIssue(field, '$what cannot contain line breaks')
    : null;

ContentIssue? _tooLong(String field, String? value, int max, String what) =>
    value != null && value.length > max
    ? ContentIssue(
        field,
        '$what is longer than $max characters',
        kind: ContentIssueKind.tooLong,
        limit: max,
      )
    : null;

final RegExp _bic = RegExp(r'^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$');

ContentIssue? _ibanIssue(String field, String iban) {
  final String i = compactIban(iban);
  if (i.isEmpty) {
    return ContentIssue(field, 'IBAN is empty', kind: ContentIssueKind.empty);
  }
  if (isValidIban(i)) {
    return null;
  }
  return ContentIssue(
    field,
    'Not a valid IBAN: $iban',
    kind: hasIbanShape(i)
        ? ContentIssueKind.checksum
        : ContentIssueKind.invalid,
  );
}

/// A decimal amount with up to [decimals] places and at most [digits]
/// digits before the point.
bool _isAmount(String amount, {int digits = 9, int decimals = 2}) =>
    RegExp('^\\d{1,$digits}(\\.\\d{1,$decimals})?\$').hasMatch(amount) &&
    RegExp('[1-9]').hasMatch(amount);

// --- EPC (SEPA) ----------------------------------------------------------------------

/// `BCD\n001|002\n<charset>\nSCT\n…`.
EpcPaymentContent? parseEpc(String text) {
  final List<String> l = _lines(text.trim());
  if (_at(l, 0) != 'BCD' ||
      !<String>{'001', '002'}.contains(_at(l, 1)) ||
      _at(l, 3) != 'SCT') {
    return null;
  }
  final String name = _at(l, 5);
  final String iban = compactIban(_at(l, 6));
  if (name.isEmpty || !isValidIban(iban)) {
    return null;
  }
  final String amount = _at(l, 7);
  String? euros;
  if (amount.isNotEmpty) {
    final RegExpMatch? m = RegExp(
      r'^EUR(\d+(?:\.\d{1,2})?)$',
    ).firstMatch(amount);
    if (m == null) {
      return null;
    }
    euros = m.group(1);
  }
  return EpcPaymentContent(
    name: name,
    iban: iban,
    bic: orNull(_at(l, 4).toUpperCase()),
    amount: euros,
    purposeCode: orNull(_at(l, 8)),
    creditorReference: orNull(_at(l, 9)),
    text: orNull(_at(l, 10)),
    information: orNull(_at(l, 11)),
  );
}

String _epcText(EpcPaymentContent c) {
  final List<String> lines = <String>[
    'BCD',
    '002',
    '1',
    'SCT',
    _t(c.bic).toUpperCase(),
    _t(c.name),
    compactIban(c.iban),
    if (orNull(_t(c.amount)) case final String a) 'EUR$a' else '',
    _t(c.purposeCode),
    _t(c.creditorReference).toUpperCase(),
    _t(c.text),
    _t(c.information),
  ];
  while (lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

/// [EpcPaymentContent.toPayload].
String buildEpc(EpcPaymentContent c) {
  checkIssues(validateEpc(c));
  return _epcText(c);
}

/// [EpcPaymentContent.validate].
List<ContentIssue> validateEpc(EpcPaymentContent c) {
  final String amount = _t(c.amount);
  final String reference = _t(c.creditorReference).toUpperCase();
  return <ContentIssue>[
    if (_t(c.name).isEmpty)
      const ContentIssue('name', 'Name is empty', kind: ContentIssueKind.empty),
    ?_tooLong('name', _t(c.name), 70, 'Name'),
    ?_lineBreak('name', c.name, 'Name'),
    ?_lineBreak('creditorReference', c.creditorReference, 'Reference'),
    ?_lineBreak('text', c.text, 'Text'),
    ?_lineBreak('information', c.information, 'Information'),
    ?_ibanIssue('iban', c.iban),
    if (orNull(_t(c.bic)) case final String bic
        when !_bic.hasMatch(bic.toUpperCase()))
      ContentIssue('bic', 'Not a BIC: $bic'),
    if (amount.isNotEmpty && !_isAmount(amount))
      const ContentIssue(
        'amount',
        'Amount must be 0.01 to 999999999.99, two decimals at most',
      ),
    if (orNull(_t(c.purposeCode)) case final String p
        when !RegExp(r'^[A-Z0-9]{4}$').hasMatch(p))
      const ContentIssue('purposeCode', 'Purpose code must be 4 letters'),
    if (reference.isNotEmpty && orNull(_t(c.text)) != null)
      const ContentIssue(
        'text',
        'Give a reference or a text, not both',
        kind: ContentIssueKind.conflict,
      ),
    ?_tooLong('creditorReference', reference, 35, 'Reference'),
    if (reference.startsWith('RF') && !isValidCreditorReference(reference))
      const ContentIssue(
        'creditorReference',
        'RF reference check digits are wrong',
        kind: ContentIssueKind.checksum,
      ),
    ?_tooLong('text', _t(c.text), 140, 'Text'),
    ?_tooLong('information', _t(c.information), 70, 'Information'),
    if (utf8.encode(_epcText(c)).length > 331)
      const ContentIssue(
        'text',
        'The code is longer than 331 bytes',
        kind: ContentIssueKind.tooLong,
        limit: 331,
      ),
  ];
}

// --- Swiss QR-bill --------------------------------------------------------------------

SwissAddress? _swissAddress(List<String> l, int at) {
  final String type = _at(l, at);
  final String name = _at(l, at + 1);
  if (type.isEmpty && name.isEmpty) {
    return null;
  }
  if (type == 'K') {
    // Combined: the second line is "postal code and town".
    final String line2 = _at(l, at + 3);
    final int space = line2.indexOf(' ');
    return SwissAddress(
      name: name,
      street: orNull(_at(l, at + 2)),
      postalCode: space < 0 ? '' : line2.substring(0, space),
      town: space < 0 ? line2 : line2.substring(space + 1).trim(),
      country: _at(l, at + 6),
    );
  }
  return SwissAddress(
    name: name,
    street: orNull(_at(l, at + 2)),
    buildingNumber: orNull(_at(l, at + 3)),
    postalCode: _at(l, at + 4),
    town: _at(l, at + 5),
    country: _at(l, at + 6),
  );
}

/// `SPC\n0200\n1\n…\nEPD`.
SwissQrBillContent? parseSwissQrBill(String text) {
  final List<String> l = _lines(text.trim());
  if (_at(l, 0) != 'SPC' ||
      !_at(l, 1).startsWith('02') ||
      _at(l, 30) != 'EPD') {
    return null;
  }
  final String iban = compactIban(_at(l, 3));
  final SwissAddress? creditor = _swissAddress(l, 4);
  final SwissReferenceType? type = switch (_at(l, 27)) {
    'QRR' => SwissReferenceType.qrr,
    'SCOR' => SwissReferenceType.scor,
    'NON' => SwissReferenceType.none,
    _ => null,
  };
  final String reference = _at(l, 28).replaceAll(' ', '');
  if (!isValidIban(iban) ||
      creditor == null ||
      type == null ||
      (type == SwissReferenceType.qrr && !isValidQrReference(reference)) ||
      (type == SwissReferenceType.scor &&
          !isValidCreditorReference(reference.toUpperCase()))) {
    return null;
  }
  return SwissQrBillContent(
    iban: iban,
    creditor: creditor,
    amount: orNull(_at(l, 18)),
    currency: _at(l, 19),
    debtor: _swissAddress(l, 20),
    referenceType: type,
    qrReference: orNull(reference),
    message: orNull(_at(l, 29)),
    billInformation: orNull(_at(l, 31)),
    alternativeSchemes: List<String>.unmodifiable(<String>[
      for (int i = 32; i < 34; i++)
        if (_at(l, i).isNotEmpty) _at(l, i),
    ]),
  );
}

List<String> _addressLines(SwissAddress? a) => a == null
    ? List<String>.filled(7, '')
    : <String>[
        'S',
        _t(a.name),
        _t(a.street),
        _t(a.buildingNumber),
        _t(a.postalCode),
        _t(a.town),
        _t(a.country).toUpperCase(),
      ];

String _swissText(SwissQrBillContent c) {
  final List<String> tail = <String>[
    _t(c.billInformation),
    ...c.alternativeSchemes.map(_t),
  ];
  while (tail.isNotEmpty && tail.last.isEmpty) {
    tail.removeLast();
  }
  return <String>[
    'SPC',
    '0200',
    '1',
    compactIban(c.iban),
    ..._addressLines(c.creditor),
    ...List<String>.filled(7, ''),
    _t(c.amount),
    _t(c.currency).toUpperCase(),
    ..._addressLines(c.debtor),
    switch (c.referenceType) {
      SwissReferenceType.qrr => 'QRR',
      SwissReferenceType.scor => 'SCOR',
      SwissReferenceType.none => 'NON',
    },
    _t(c.qrReference).replaceAll(' ', '').toUpperCase(),
    _t(c.message),
    'EPD',
    ...tail,
  ].join('\n');
}

/// [SwissQrBillContent.toPayload].
String buildSwissQrBill(SwissQrBillContent c) {
  checkIssues(validateSwissQrBill(c));
  return _swissText(c);
}

/// The characters a QR-bill may hold: Latin, with Ș, ș, Ț, ț and €.
final RegExp _swissCharacters = RegExp(
  r'^[\u0020-\u007E\u00A0-\u017F\u0218-\u021B\u20AC]*$',
);

ContentIssue? _swissField(String field, String? value, String what) {
  final String v = _t(value);
  if (v.contains(RegExp(r'[\r\n]'))) {
    return _lineBreak(field, v, what);
  }
  return _swissCharacters.hasMatch(v)
      ? null
      : ContentIssue(field, '$what has characters a QR-bill cannot hold');
}

List<ContentIssue> _validateAddress(
  String field,
  SwissAddress a,
) => <ContentIssue>[
  ?_swissField(field, a.name, 'Name'),
  ?_swissField(field, a.street, 'Street'),
  ?_swissField(field, a.buildingNumber, 'Building number'),
  ?_swissField(field, a.postalCode, 'Postal code'),
  ?_swissField(field, a.town, 'Town'),
  if (_t(a.name).isEmpty)
    ContentIssue(field, 'Name is empty', kind: ContentIssueKind.empty),
  ?_tooLong(field, _t(a.name), 70, 'Name'),
  ?_tooLong(field, _t(a.street), 70, 'Street'),
  ?_tooLong(field, _t(a.buildingNumber), 16, 'Building number'),
  if (_t(a.postalCode).isEmpty)
    ContentIssue(field, 'Postal code is empty', kind: ContentIssueKind.empty),
  ?_tooLong(field, _t(a.postalCode), 16, 'Postal code'),
  if (_t(a.town).isEmpty)
    ContentIssue(field, 'Town is empty', kind: ContentIssueKind.empty),
  ?_tooLong(field, _t(a.town), 35, 'Town'),
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(_t(a.country).toUpperCase()))
    ContentIssue(field, 'Country must be a two-letter code'),
];

/// [SwissQrBillContent.validate].
List<ContentIssue> validateSwissQrBill(SwissQrBillContent c) {
  final String iban = compactIban(c.iban);
  final String reference = _t(c.qrReference).replaceAll(' ', '').toUpperCase();
  final String amount = _t(c.amount);
  final int message = _t(c.message).length + _t(c.billInformation).length;
  return <ContentIssue>[
    ?_ibanIssue('iban', c.iban),
    ?_swissField('message', c.message, 'Message'),
    ?_swissField('billInformation', c.billInformation, 'Bill information'),
    for (final String scheme in c.alternativeSchemes)
      ?_lineBreak('alternativeSchemes', scheme, 'An alternative scheme'),
    if (isValidIban(iban) && !iban.startsWith('CH') && !iban.startsWith('LI'))
      const ContentIssue(
        'iban',
        'The IBAN must be Swiss or from Liechtenstein',
        kind: ContentIssueKind.conflict,
      ),
    ..._validateAddress('creditor', c.creditor),
    if (c.debtor case final SwissAddress d) ..._validateAddress('debtor', d),
    if (amount.isNotEmpty &&
        !(RegExp(r'^\d{1,9}\.\d{2}$').hasMatch(amount) && _isAmount(amount)))
      const ContentIssue(
        'amount',
        'Amount must be 0.01 to 999999999.99 with two decimals',
      ),
    if (!<String>{'CHF', 'EUR'}.contains(_t(c.currency).toUpperCase()))
      const ContentIssue('currency', 'Currency must be CHF or EUR'),
    ...switch (c.referenceType) {
      SwissReferenceType.qrr => <ContentIssue>[
        if (!isQrIban(iban))
          const ContentIssue(
            'iban',
            'A QR reference needs a QR-IBAN',
            kind: ContentIssueKind.conflict,
          ),
        if (!isValidQrReference(reference))
          const ContentIssue(
            'qrReference',
            'QR reference must be 27 digits with a valid check digit',
            kind: ContentIssueKind.checksum,
          ),
      ],
      SwissReferenceType.scor => <ContentIssue>[
        if (isQrIban(iban))
          const ContentIssue(
            'iban',
            'A QR-IBAN needs a QR reference',
            kind: ContentIssueKind.conflict,
          ),
        if (!isValidCreditorReference(reference))
          const ContentIssue(
            'qrReference',
            'Not a valid RF creditor reference',
          ),
      ],
      SwissReferenceType.none => <ContentIssue>[
        if (isQrIban(iban))
          const ContentIssue(
            'iban',
            'A QR-IBAN needs a QR reference',
            kind: ContentIssueKind.conflict,
          ),
        if (reference.isNotEmpty)
          const ContentIssue(
            'qrReference',
            'No reference type, but a reference',
            kind: ContentIssueKind.conflict,
          ),
      ],
    },
    if (message > 140)
      const ContentIssue(
        'message',
        'Message and bill information are longer than 140 characters',
        kind: ContentIssueKind.tooLong,
        limit: 140,
      ),
    if (c.alternativeSchemes.length > 2)
      const ContentIssue(
        'alternativeSchemes',
        'At most two alternative schemes',
        kind: ContentIssueKind.tooLong,
        limit: 2,
      ),
    for (final String scheme in c.alternativeSchemes)
      ?_tooLong('alternativeSchemes', scheme, 100, 'An alternative scheme'),
    if (_swissText(c).length > 997)
      const ContentIssue(
        'message',
        'The code is longer than 997 characters',
        kind: ContentIssueKind.tooLong,
        limit: 997,
      ),
  ];
}

// --- ГОСТ Р 56042-2014 ------------------------------------------------------------------

const List<String> _gostKeys = <String>[
  'Name',
  'PersonalAcc',
  'BankName',
  'BIC',
  'CorrespAcc',
  'Sum',
  'Purpose',
  'PayeeINN',
  'KPP',
];

/// `ST0001` + encoding flag + separator + `Key=Value` pairs.
GostPaymentContent? parseGost(String text) {
  final String t = text.trim();
  if (t.length < 9 || !t.startsWith('ST0001') || !'123'.contains(t[6])) {
    return null;
  }
  final String separator = t[7];
  final Map<String, String> known = <String, String>{};
  final Map<String, String> extra = <String, String>{};
  for (final String pair in t.substring(8).split(separator)) {
    final int eq = pair.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final String key = pair.substring(0, eq).trim();
    final String value = pair.substring(eq + 1).trim();
    final String? canonical = _gostKeys
        .where((String k) => k.toLowerCase() == key.toLowerCase())
        .firstOrNull;
    if (canonical != null) {
      known.putIfAbsent(canonical, () => value);
    } else {
      extra.putIfAbsent(key, () => value);
    }
  }
  String? at(String key) => orNull(known[key]);
  final String? name = at('Name');
  final String? account = at('PersonalAcc');
  final String? bank = at('BankName');
  final String? bic = at('BIC');
  final String? correspondent = at('CorrespAcc');
  if (name == null ||
      account == null ||
      bank == null ||
      bic == null ||
      correspondent == null) {
    return null;
  }
  String? amount;
  if (at('Sum') case final String sum) {
    if (RegExp(r'^\d+$').hasMatch(sum)) {
      final String k = sum.padLeft(3, '0');
      final String rubles = k
          .substring(0, k.length - 2)
          .replaceFirst(RegExp('^0+(?=.)'), '');
      amount = '$rubles.${k.substring(k.length - 2)}';
    } else {
      extra['Sum'] = sum;
    }
  }
  return GostPaymentContent(
    name: name,
    personalAccount: account,
    bankName: bank,
    bic: bic,
    correspondentAccount: correspondent,
    amount: amount,
    purpose: at('Purpose'),
    payeeInn: at('PayeeINN'),
    kpp: at('KPP'),
    extra: Map<String, String>.unmodifiable(extra),
  );
}

/// Whether [bytes] are a ГОСТ code in Windows-1251 or KOI8-R (flags 1 and
/// 3), which a reader may have decoded as something else.
String? decodeGostBytes(List<int> bytes) {
  if (bytes.length < 8 ||
      latin1.decode(bytes.sublist(0, 6), allowInvalid: true) != 'ST0001') {
    return null;
  }
  final String? table = switch (bytes[6]) {
    0x31 => _cp1251,
    0x33 => _koi8r,
    _ => null,
  };
  if (table == null) {
    return null;
  }
  final StringBuffer out = StringBuffer();
  for (final int b in bytes) {
    if (b < 0x80) {
      out.writeCharCode(b);
    } else {
      out.write(table[b - 0x80]);
    }
  }
  return out.toString();
}

// The upper halves of Windows-1251 and KOI8-R; `?` for bytes no payment
// text uses.
const String _cp1251 =
    'ЂЃ‚ѓ„…†‡€‰Љ‹ЊЌЋЏђ‘’“”•–—?™љ›њќћџ\u00A0ЎўЈ¤Ґ¦§Ё©Є«¬­®Ї°±Ііґµ¶·ё№є»јЅѕїАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя';
const String _koi8r =
    '─│┌┐└┘├┤┬┴┼▀▄█▌▐░▒▓⌠■∙√≈≤≥ ⌡°²·÷═║╒ё╓╔╕╖╗╘╙╚╛╜╝╞╟╠╡Ё╢╣╤╥╦╧╨╩╪╫╬©юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ';

/// `'1250.5'` → `'125050'`, in text: amounts can pass the 2^53 integers
/// are exact to on the web.
String _kopecks(String amount) {
  final List<String> parts = amount.split('.');
  final String fraction = (parts.length > 1 ? parts[1] : '').padRight(2, '0');
  final String kopecks = '${parts[0]}$fraction'.replaceFirst(RegExp('^0+'), '');
  return kopecks.isEmpty ? '0' : kopecks;
}

/// [GostPaymentContent.toPayload].
String buildGost(GostPaymentContent c) {
  checkIssues(validateGost(c));
  return <String>[
    'ST00012',
    'Name=${_t(c.name)}',
    'PersonalAcc=${_t(c.personalAccount)}',
    'BankName=${_t(c.bankName)}',
    'BIC=${_t(c.bic)}',
    'CorrespAcc=${_t(c.correspondentAccount)}',
    if (orNull(_t(c.amount)) case final String a) 'Sum=${_kopecks(a)}',
    if (orNull(_t(c.purpose)) case final String p) 'Purpose=$p',
    if (orNull(_t(c.payeeInn)) case final String inn) 'PayeeINN=$inn',
    if (orNull(_t(c.kpp)) case final String kpp) 'KPP=$kpp',
    for (final MapEntry<String, String> e in c.extra.entries)
      '${e.key.trim()}=${e.value.trim()}',
  ].join('|');
}

/// [GostPaymentContent.validate].
List<ContentIssue> validateGost(GostPaymentContent c) {
  final String amount = _t(c.amount);
  final Map<String, String> values = <String, String>{
    'name': c.name,
    'personalAccount': c.personalAccount,
    'bankName': c.bankName,
    'bic': c.bic,
    'correspondentAccount': c.correspondentAccount,
    'purpose': c.purpose ?? '',
    'payeeInn': c.payeeInn ?? '',
    'kpp': c.kpp ?? '',
  };
  return <ContentIssue>[
    if (_t(c.name).isEmpty)
      const ContentIssue('name', 'Name is empty', kind: ContentIssueKind.empty),
    ?_tooLong('name', _t(c.name), 160, 'Name'),
    if (!RegExp(r'^\d{20}$').hasMatch(_t(c.personalAccount)))
      const ContentIssue('personalAccount', 'Account must be 20 digits'),
    if (_t(c.bankName).isEmpty)
      const ContentIssue(
        'bankName',
        'Bank is empty',
        kind: ContentIssueKind.empty,
      ),
    ?_tooLong('bankName', _t(c.bankName), 45, 'Bank name'),
    if (!RegExp(r'^\d{9}$').hasMatch(_t(c.bic)))
      const ContentIssue('bic', 'BIC must be 9 digits'),
    if (!RegExp(r'^(\d{20}|0)$').hasMatch(_t(c.correspondentAccount)))
      const ContentIssue(
        'correspondentAccount',
        'Correspondent account must be 20 digits or 0',
      ),
    if (amount.isNotEmpty && !_isAmount(amount, digits: 16))
      const ContentIssue(
        'amount',
        'Amount must be a number, two decimals at most',
      ),
    ?_tooLong('purpose', _t(c.purpose), 210, 'Purpose'),
    if (orNull(_t(c.payeeInn)) case final String inn
        when !RegExp(r'^(\d{10}|\d{12})$').hasMatch(inn))
      const ContentIssue('payeeInn', 'INN must be 10 or 12 digits'),
    if (orNull(_t(c.kpp)) case final String kpp
        when !RegExp(r'^\d{4}[0-9A-Z]{2}\d{3}$').hasMatch(kpp))
      const ContentIssue('kpp', 'KPP must be 9 characters'),
    for (final String key in c.extra.keys)
      if (_gostKeys.any((String k) => k.toLowerCase() == key.toLowerCase()) ||
          !RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(key))
        ContentIssue('extra', 'Not an extra field name: $key'),
    for (final MapEntry<String, String> e in values.entries)
      if (e.value.contains('|')) ContentIssue(e.key, 'Values cannot contain |'),
    for (final String value in c.extra.values)
      if (value.contains('|'))
        const ContentIssue('extra', 'Values cannot contain |'),
  ];
}

// --- UPI ---------------------------------------------------------------------------------

const List<String> _upiKeys = <String>[
  'pa',
  'pn',
  'am',
  'cu',
  'tn',
  'mc',
  'tr',
];
final RegExp _upiAddress = RegExp(r'^[A-Za-z0-9.\-_]+@[A-Za-z0-9.\-_]+$');

/// `upi://pay?pa=…`, after the `?`.
UpiPaymentContent? parseUpi(String query) {
  final Map<String, String> params;
  try {
    params = <String, String>{
      for (final MapEntry<String, String> e in Uri.splitQueryString(
        query,
      ).entries)
        e.key.toLowerCase(): e.value.trim(),
    };
  } on ArgumentError {
    return null;
  } on FormatException {
    return null;
  }
  final String? address = orNull(params['pa']);
  final String currency = (params['cu'] ?? 'INR').toUpperCase();
  final String? amount = orNull(params['am']);
  if (address == null ||
      !_upiAddress.hasMatch(address) ||
      (currency.isNotEmpty && currency != 'INR') ||
      (amount != null && !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount))) {
    return null;
  }
  return UpiPaymentContent(
    address: address,
    name: orNull(params['pn']),
    amount: amount,
    note: orNull(params['tn']),
    merchantCode: orNull(params['mc']),
    transactionReference: orNull(params['tr']),
    extra: Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, String> e in params.entries)
        if (!_upiKeys.contains(e.key)) e.key: e.value,
    }),
  );
}

String _upiEncode(String value) =>
    Uri.encodeComponent(value).replaceAll('%40', '@');

/// [UpiPaymentContent.toPayload].
String buildUpi(UpiPaymentContent c) {
  checkIssues(validateUpi(c));
  final Map<String, String?> params = <String, String?>{
    'pa': _t(c.address),
    'pn': orNull(_t(c.name)),
    'am': orNull(_t(c.amount)),
    'cu': 'INR',
    'tn': orNull(_t(c.note)),
    'mc': orNull(_t(c.merchantCode)),
    'tr': orNull(_t(c.transactionReference)),
    for (final MapEntry<String, String> e in c.extra.entries)
      e.key.toLowerCase(): e.value,
  };
  return 'upi://pay?${<String>[for (final MapEntry<String, String?> e in params.entries)
    if (e.value != null) '${e.key}=${_upiEncode(e.value!)}'].join('&')}';
}

/// [UpiPaymentContent.validate].
List<ContentIssue> validateUpi(UpiPaymentContent c) {
  final String amount = _t(c.amount);
  return <ContentIssue>[
    if (!_upiAddress.hasMatch(_t(c.address)))
      ContentIssue('address', 'Not a UPI address: ${c.address}'),
    if (amount.isNotEmpty && !_isAmount(amount, digits: 10))
      const ContentIssue(
        'amount',
        'Amount must be a number, two decimals at most',
      ),
    if (orNull(_t(c.merchantCode)) case final String mc
        when !RegExp(r'^\d{4}$').hasMatch(mc))
      const ContentIssue('merchantCode', 'Merchant code must be 4 digits'),
    for (final String key in c.extra.keys)
      if (_upiKeys.contains(key.toLowerCase()) ||
          !RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(key))
        ContentIssue('extra', 'Not an extra parameter name: $key'),
  ];
}

// --- EMVCo merchant-presented QR -------------------------------------------------------

/// The data objects of an EMVCo string: two-digit id, two-digit length,
/// value; `null` if they do not add up.
Map<String, String>? _tlv(String text) {
  final Map<String, String> objects = <String, String>{};
  int at = 0;
  while (at < text.length) {
    if (at + 4 > text.length) {
      return null;
    }
    final String id = text.substring(at, at + 2);
    final String size = text.substring(at + 2, at + 4);
    if (!RegExp(r'^\d{2}$').hasMatch(id) ||
        !RegExp(r'^\d{2}$').hasMatch(size)) {
      return null;
    }
    final int length = int.parse(size);
    if (at + 4 + length > text.length) {
      return null;
    }
    objects.putIfAbsent(id, () => text.substring(at + 4, at + 4 + length));
    at += 4 + length;
  }
  return objects;
}

/// [EmvPaymentContent.template].
Map<String, String> parseEmvTemplate(String? value) => switch (value) {
  null => const <String, String>{},
  final String v => switch (_tlv(v)) {
    null => const <String, String>{},
    final Map<String, String> objects => Map<String, String>.unmodifiable(
      objects,
    ),
  },
};

String _serialize(Map<String, String> objects) => <String>[
  for (final MapEntry<String, String> e in objects.entries)
    '${e.key}${e.value.length.toString().padLeft(2, '0')}${e.value}',
].join();

/// Nested data objects as one value, for templates such as `26` and `62`.
String emvTemplate(Map<String, String> objects) => _serialize(objects);

/// `000201…6304XXXX`, the checksum checked.
EmvPaymentContent? parseEmv(String text) {
  final String t = text.trim();
  if (!t.startsWith('000201') || t.length < 12) {
    return null;
  }
  final Map<String, String>? objects = _tlv(t);
  final String crc = t.substring(t.length - 4);
  if (objects == null ||
      t.substring(t.length - 8, t.length - 4) != '6304' ||
      emvCrc(utf8.encode(t.substring(0, t.length - 4))) != crc.toUpperCase()) {
    return null;
  }
  objects.remove('63');
  return EmvPaymentContent(Map<String, String>.unmodifiable(objects));
}

/// [EmvPaymentContent.toPayload].
String buildEmv(EmvPaymentContent c) {
  checkIssues(validateEmv(c));
  final String body =
      '${_serialize(<String, String>{'00': c.fields['00']!, ...c.fields})}6304';
  return '$body${emvCrc(utf8.encode(body))}';
}

/// [EmvPaymentContent.validate].
List<ContentIssue> validateEmv(EmvPaymentContent c) {
  final Map<String, String> f = c.fields;
  return <ContentIssue>[
    if (f['00'] != '01')
      const ContentIssue('fields', 'Payload format (00) must be 01'),
    if (f.containsKey('63'))
      const ContentIssue(
        'fields',
        'The checksum (63) is written by toPayload',
        kind: ContentIssueKind.conflict,
      ),
    for (final MapEntry<String, String> e in f.entries)
      if (!RegExp(r'^\d{2}$').hasMatch(e.key))
        ContentIssue('fields', 'Not a two-digit id: ${e.key}')
      else if (e.value.isEmpty || e.value.length > 99)
        ContentIssue('fields', '(${e.key}) must have 1 to 99 characters'),
    for (final String id in <String>['52', '53', '58', '59', '60'])
      if (!f.containsKey(id))
        ContentIssue(
          'fields',
          '($id) is missing',
          kind: ContentIssueKind.empty,
        ),
    if (!f.keys.any((String id) {
      final int? n = int.tryParse(id);
      return n != null && n >= 2 && n <= 51;
    }))
      const ContentIssue(
        'fields',
        'A merchant account (02 to 51) is missing',
        kind: ContentIssueKind.empty,
      ),
    ?_tooLong('fields', f['59'], 25, 'Merchant name (59)'),
    ?_tooLong('fields', f['60'], 15, 'Merchant city (60)'),
    if (f['54'] case final String amount
        when amount.length > 13 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(amount))
      const ContentIssue(
        'fields',
        'Amount (54) must be a number, two decimals',
      ),
    if (f['53'] case final String currency
        when !RegExp(r'^\d{3}$').hasMatch(currency))
      const ContentIssue('fields', 'Currency (53) must be a numeric code'),
    if (f['58'] case final String country
        when !RegExp(r'^[A-Z]{2}$').hasMatch(country))
      const ContentIssue('fields', 'Country (58) must be two letters'),
  ];
}

/// [EmvPaymentContent.scheme].
EmvScheme emvScheme(EmvPaymentContent c) {
  for (int id = 26; id <= 51; id++) {
    final String gui = (c.template('$id')['00'] ?? '').toUpperCase();
    final EmvScheme? scheme = switch (gui) {
      'BR.GOV.BCB.PIX' => EmvScheme.pix,
      'SG.PAYNOW' => EmvScheme.payNow,
      'MY.COM.PAYNET' => EmvScheme.duitNow,
      _ when gui.startsWith('A000000677') => EmvScheme.promptPay,
      _ when gui.startsWith('ID.CO.QRIS') => EmvScheme.qris,
      _ when gui.startsWith('A000000727') => EmvScheme.vietQr,
      _ => null,
    };
    if (scheme != null) {
      return scheme;
    }
  }
  return EmvScheme.unknown;
}

/// [EmvPaymentContent.pixKey].
String? emvPixKey(EmvPaymentContent c) {
  for (int id = 26; id <= 51; id++) {
    final Map<String, String> t = c.template('$id');
    if ((t['00'] ?? '').toUpperCase() == 'BR.GOV.BCB.PIX') {
      return t['01'];
    }
  }
  return null;
}

/// [EmvPaymentContent.reference].
String? emvReference(EmvPaymentContent c) {
  final String? label = c.template('62')['05'];
  return label == null || label == '***' ? null : label;
}

/// [EmvPaymentContent.currency].
String? emvCurrency(String? numeric) =>
    numeric == null ? null : _currencies[numeric] ?? numeric;

const Map<String, String> _currencies = <String, String>{
  '036': 'AUD', '050': 'BDT', '104': 'MMK', '116': 'KHR', '124': 'CAD', //
  '144': 'LKR', '152': 'CLP', '156': 'CNY', '170': 'COP', '344': 'HKD', //
  '356': 'INR', '360': 'IDR', '392': 'JPY', '404': 'KES', '410': 'KRW', //
  '418': 'LAK', '458': 'MYR', '484': 'MXN', '524': 'NPR', '566': 'NGN', //
  '586': 'PKR', '604': 'PEN', '608': 'PHP', '643': 'RUB', '682': 'SAR', //
  '702': 'SGD', '704': 'VND', '710': 'ZAR', '764': 'THB', '784': 'AED', //
  '826': 'GBP', '840': 'USD', '901': 'TWD', '949': 'TRY', '978': 'EUR', //
  '986': 'BRL', '032': 'ARS',
};

// --- SPAYD ---------------------------------------------------------------------------------

const List<String> _spaydKeys = <String>[
  'ACC', 'AM', 'CC', 'RN', 'MSG', 'DT', 'X-VS', 'X-SS', 'X-KS', 'CRC32', //
];

String _spaydDecode(String value) =>
    value.replaceAll('%2A', '*').replaceAll('%2a', '*').replaceAll('%25', '%');

String _spaydEncode(String value) =>
    value.replaceAll('%', '%25').replaceAll('*', '%2A');

/// `SPD*1.0*ACC:…*…`.
SpaydPaymentContent? parseSpayd(String text) {
  final List<String> parts = text.trim().split('*');
  if (parts.length < 3 ||
      parts.first.toUpperCase() != 'SPD' ||
      !RegExp(r'^\d+\.\d+$').hasMatch(parts[1])) {
    return null;
  }
  final Map<String, String> fields = <String, String>{};
  for (final String part in parts.skip(2)) {
    final int colon = part.indexOf(':');
    if (colon > 0) {
      fields.putIfAbsent(
        part.substring(0, colon).trim().toUpperCase(),
        () => _spaydDecode(part.substring(colon + 1).trim()),
      );
    }
  }
  final List<String> account = (fields['ACC'] ?? '').split('+');
  final String iban = compactIban(account.first);
  if (!isValidIban(iban)) {
    return null;
  }
  DateTime? due;
  if (fields['DT'] case final String dt when RegExp(r'^\d{8}$').hasMatch(dt)) {
    final int year = int.parse(dt.substring(0, 4));
    final int month = int.parse(dt.substring(4, 6));
    final int day = int.parse(dt.substring(6, 8));
    final DateTime date = DateTime(year, month, day);
    // DateTime carries an impossible date over to another one.
    if (date.month == month && date.day == day) {
      due = date;
    }
  }
  return SpaydPaymentContent(
    iban: iban,
    bic: account.length > 1 ? orNull(account[1].trim().toUpperCase()) : null,
    amount: orNull(fields['AM']),
    currency: orNull(fields['CC']?.toUpperCase()),
    recipientName: orNull(fields['RN']),
    message: orNull(fields['MSG']),
    dueDate: due,
    variableSymbol: orNull(fields['X-VS']),
    specificSymbol: orNull(fields['X-SS']),
    constantSymbol: orNull(fields['X-KS']),
    extra: Map<String, String>.unmodifiable(<String, String>{
      for (final MapEntry<String, String> e in fields.entries)
        if (!_spaydKeys.contains(e.key)) e.key: e.value,
    }),
  );
}

/// [SpaydPaymentContent.toPayload].
String buildSpayd(SpaydPaymentContent c) {
  checkIssues(validateSpayd(c));
  String two(int v) => v.toString().padLeft(2, '0');
  final DateTime? due = c.dueDate;
  final Map<String, String?> fields = <String, String?>{
    'ACC':
        compactIban(c.iban) +
        (orNull(_t(c.bic)) == null ? '' : '+${_t(c.bic).toUpperCase()}'),
    'AM': orNull(_t(c.amount)),
    'CC': orNull(_t(c.currency).toUpperCase()),
    'RN': orNull(_t(c.recipientName)),
    'MSG': orNull(_t(c.message)),
    'DT': due == null
        ? null
        : '${due.year.toString().padLeft(4, '0')}${two(due.month)}${two(due.day)}',
    'X-VS': orNull(_t(c.variableSymbol)),
    'X-SS': orNull(_t(c.specificSymbol)),
    'X-KS': orNull(_t(c.constantSymbol)),
    for (final MapEntry<String, String> e in c.extra.entries)
      e.key.toUpperCase(): e.value,
  };
  return <String>[
    'SPD',
    '1.0',
    for (final MapEntry<String, String?> e in fields.entries)
      if (e.value != null) '${e.key}:${_spaydEncode(e.value!)}',
  ].join('*');
}

/// [SpaydPaymentContent.validate].
List<ContentIssue> validateSpayd(SpaydPaymentContent c) {
  final String amount = _t(c.amount);
  final RegExp symbol = RegExp(r'^\d{1,10}$');
  return <ContentIssue>[
    ?_ibanIssue('iban', c.iban),
    if (orNull(_t(c.bic)) case final String bic
        when !_bic.hasMatch(bic.toUpperCase()))
      ContentIssue('bic', 'Not a BIC: $bic'),
    if (amount.isNotEmpty && !_isAmount(amount, digits: 10))
      const ContentIssue(
        'amount',
        'Amount must be a number, two decimals at most',
      ),
    if (orNull(_t(c.currency)) case final String cc
        when !RegExp(r'^[A-Z]{3}$').hasMatch(cc.toUpperCase()))
      const ContentIssue('currency', 'Currency must be a three-letter code'),
    ?_tooLong('recipientName', _t(c.recipientName), 35, 'Name'),
    ?_tooLong('message', _t(c.message), 60, 'Message'),
    for (final (String field, String? value) in <(String, String?)>[
      ('variableSymbol', c.variableSymbol),
      ('specificSymbol', c.specificSymbol),
      ('constantSymbol', c.constantSymbol),
    ])
      if (orNull(_t(value)) case final String v when !symbol.hasMatch(v))
        ContentIssue(field, 'Symbols are up to 10 digits'),
    for (final String key in c.extra.keys)
      if (_spaydKeys.contains(key.toUpperCase()) ||
          !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(key))
        ContentIssue('extra', 'Not an extra key: $key'),
  ];
}
