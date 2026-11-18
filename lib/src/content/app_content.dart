import 'barcode_content.dart';
import 'content_util.dart';

// Parsing and building OtpContent, EsimContent, CryptoContent and
// WifiDppContent.

// --- One-time passwords ------------------------------------------------------------

final RegExp _base32 = RegExp(r'^[A-Z2-7]+$');

/// [secret] upper case, without spaces, dashes or padding.
String _normalBase32(String secret) =>
    secret.replaceAll(RegExp(r'[\s\-=]'), '').toUpperCase();

/// `otpauth://totp/Issuer:account?secret=…`, after the `otpauth://`.
OtpContent? parseOtp(String body) {
  final int slash = body.indexOf('/');
  if (slash < 0) {
    return null;
  }
  final OtpType? type = switch (body.substring(0, slash).toLowerCase()) {
    'totp' => OtpType.totp,
    'hotp' => OtpType.hotp,
    _ => null,
  };
  if (type == null) {
    return null;
  }
  final String rest = body.substring(slash + 1);
  final int q = rest.indexOf('?');
  final String label = decodeComponent(q < 0 ? rest : rest.substring(0, q));
  final Map<String, String> params = queryParameters(
    q < 0 ? '' : rest.substring(q + 1),
  );
  final String secret = _normalBase32(params['secret'] ?? '');
  if (!_base32.hasMatch(secret)) {
    return null;
  }
  final int colon = label.indexOf(':');
  final String? labelIssuer = colon < 0
      ? null
      : orNull(label.substring(0, colon).trim());
  final String account = (colon < 0 ? label : label.substring(colon + 1))
      .trim();
  final OtpAlgorithm? algorithm = switch (params['algorithm']
      ?.toUpperCase()
      .replaceAll('-', '')) {
    null || '' || 'SHA1' => OtpAlgorithm.sha1,
    'SHA256' => OtpAlgorithm.sha256,
    'SHA512' => OtpAlgorithm.sha512,
    _ => null,
  };
  final int? digits = int.tryParse(params['digits'] ?? '6');
  final int? period = int.tryParse(params['period'] ?? '30');
  final int? counter = int.tryParse(params['counter'] ?? '0');
  if (algorithm == null ||
      digits == null ||
      digits < 1 ||
      digits > 10 ||
      period == null ||
      period < 1 ||
      counter == null ||
      counter < 0) {
    return null;
  }
  return OtpContent(
    secret: secret,
    account: account,
    issuer: orNull(params['issuer']?.trim()) ?? labelIssuer,
    type: type,
    algorithm: algorithm,
    digits: digits,
    period: type == OtpType.totp ? period : 30,
    counter: type == OtpType.hotp ? counter : 0,
  );
}

String _encodeLabel(String value) =>
    Uri.encodeComponent(value).replaceAll('%40', '@');

/// [OtpContent.toPayload].
String buildOtp(OtpContent c) {
  checkIssues(validateOtp(c));
  final String? issuer = orNull(c.issuer?.trim());
  final String account = c.account.trim();
  final String label = issuer == null
      ? _encodeLabel(account)
      : '${_encodeLabel(issuer)}:${_encodeLabel(account)}';
  final List<String> params = <String>[
    'secret=${_normalBase32(c.secret)}',
    if (issuer != null) 'issuer=${_encodeLabel(issuer)}',
    if (c.algorithm != OtpAlgorithm.sha1)
      'algorithm=${c.algorithm.name.toUpperCase()}',
    if (c.digits != 6) 'digits=${c.digits}',
    if (c.type == OtpType.totp && c.period != 30) 'period=${c.period}',
    if (c.type == OtpType.hotp) 'counter=${c.counter}',
  ];
  return 'otpauth://${c.type.name}/$label?${params.join('&')}';
}

/// [OtpContent.validate].
List<ContentIssue> validateOtp(OtpContent c) {
  final String secret = _normalBase32(c.secret);
  final String? issuer = orNull(c.issuer?.trim());
  return <ContentIssue>[
    if (secret.isEmpty)
      const ContentIssue('secret', 'Secret is empty')
    else if (!_base32.hasMatch(secret))
      const ContentIssue('secret', 'Secret must be Base32: A–Z and 2–7'),
    if (c.account.trim().isEmpty)
      const ContentIssue('account', 'Account is empty')
    else if (issuer == null && c.account.contains(':'))
      const ContentIssue('account', 'Account cannot contain a colon'),
    if (issuer != null && issuer.contains(':'))
      const ContentIssue('issuer', 'Issuer cannot contain a colon'),
    if (c.digits < 6 || c.digits > 8)
      const ContentIssue('digits', 'Codes must have 6 to 8 digits'),
    if (c.type == OtpType.totp && c.period < 1)
      const ContentIssue('period', 'Period must be at least 1 second'),
    if (c.type == OtpType.hotp && c.counter < 0)
      const ContentIssue('counter', 'Counter cannot be negative'),
  ];
}

// --- eSIM --------------------------------------------------------------------------

/// `LPA:1$address$matchingId$oid$1`, after the `LPA:`.
EsimContent? parseEsim(String body) {
  final List<String> parts = body.split(r'$');
  if (parts.length < 2 || parts.first.trim() != '1') {
    return null;
  }
  final String address = parts[1].trim();
  if (address.isEmpty) {
    return null;
  }
  return EsimContent(
    smdpAddress: address,
    matchingId: parts.length > 2 ? orNull(parts[2].trim()) : null,
    oid: parts.length > 3 ? orNull(parts[3].trim()) : null,
    confirmationCodeRequired: parts.length > 4 && parts[4].trim() == '1',
  );
}

/// [EsimContent.toPayload].
String buildEsim(EsimContent c) {
  checkIssues(validateEsim(c));
  final String? oid = orNull(c.oid?.trim());
  return <String>[
    'LPA:1',
    c.smdpAddress.trim(),
    c.matchingId?.trim() ?? '',
    if (oid != null || c.confirmationCodeRequired) oid ?? '',
    if (c.confirmationCodeRequired) '1',
  ].join(r'$');
}

final RegExp _noDollarOrSpace = RegExp(r'^[^$\s]*$');

/// [EsimContent.validate].
List<ContentIssue> validateEsim(EsimContent c) => <ContentIssue>[
  if (c.smdpAddress.trim().isEmpty)
    const ContentIssue('smdpAddress', 'SM-DP+ address is empty')
  else if (!_noDollarOrSpace.hasMatch(c.smdpAddress.trim()))
    const ContentIssue('smdpAddress', r'Address cannot contain $ or spaces'),
  if (!_noDollarOrSpace.hasMatch(c.matchingId?.trim() ?? ''))
    const ContentIssue('matchingId', r'Matching ID cannot contain $ or spaces'),
  if (!_noDollarOrSpace.hasMatch(c.oid?.trim() ?? ''))
    const ContentIssue('oid', r'OID cannot contain $ or spaces'),
];

// --- Cryptocurrencies --------------------------------------------------------------

final RegExp _coins = RegExp(r'^\d+(\.\d{1,8})?$');
final RegExp _wei = RegExp(r'^\d+(\.\d+)?([eE]\d+)?$');
final RegExp _cryptoAddress = RegExp(r'^[^\s?&@/:]+$');

/// Lightning invoices (BOLT 11) and LNURLs, bare or after `lightning:`.
final RegExp _lightning = RegExp(
  r'^(lnbc|lntbs|lntb|lnbcrt|lnsb|lnurl)[0-9a-z]{10,}$',
  caseSensitive: false,
);

/// `bitcoin:`, `litecoin:`, `ethereum:`, `lightning:` and bare Lightning
/// invoices. [t] is the whole trimmed payload.
CryptoContent? parseCrypto(String t) {
  if (hasPrefix(t, 'BITCOIN:')) {
    return _bip21(CryptoCurrency.bitcoin, t.substring(8));
  }
  if (hasPrefix(t, 'LITECOIN:')) {
    return _bip21(CryptoCurrency.litecoin, t.substring(9));
  }
  if (hasPrefix(t, 'ETHEREUM:')) {
    return _eip681(t.substring(9));
  }
  final String invoice = hasPrefix(t, 'LIGHTNING:') ? t.substring(10) : t;
  return _lightning.hasMatch(invoice)
      ? CryptoContent(currency: CryptoCurrency.lightning, address: invoice)
      : null;
}

/// Whether [t] could be a cryptocurrency payload, for the dispatcher.
bool isCryptoPayload(String t) =>
    hasPrefix(t, 'BITCOIN:') ||
    hasPrefix(t, 'LITECOIN:') ||
    hasPrefix(t, 'ETHEREUM:') ||
    hasPrefix(t, 'LIGHTNING:') ||
    _lightning.hasMatch(t);

CryptoContent? _bip21(CryptoCurrency currency, String body) {
  final int q = body.indexOf('?');
  final String address = decodeComponent(
    q < 0 ? body : body.substring(0, q),
  ).trim();
  if (!_cryptoAddress.hasMatch(address)) {
    return null;
  }
  final Map<String, String> params = queryParameters(
    q < 0 ? '' : body.substring(q + 1),
  );
  // BIP 21: a required parameter this reader does not know voids the URI.
  if (params.keys.any((String k) => k.toLowerCase().startsWith('req-'))) {
    return null;
  }
  final String? amount = orNull(params['amount']?.trim());
  if (amount != null && !_coins.hasMatch(amount)) {
    return null;
  }
  return CryptoContent(
    currency: currency,
    address: address,
    amount: amount,
    label: orNull(params['label']),
    message: orNull(params['message']),
  );
}

/// `ethereum:[pay-]address[@chainId][?value=…]`. Function calls
/// (`/transfer?…`) are not a payment to [CryptoContent.address]: `null`.
CryptoContent? _eip681(String body) {
  String b = body;
  if (b.toLowerCase().startsWith('pay-')) {
    b = b.substring(4);
  }
  final int q = b.indexOf('?');
  final String target = q < 0 ? b : b.substring(0, q);
  // Another request type than `pay-`; ENS names may hold hyphens too.
  if (target.contains('/') ||
      RegExp(r'^[a-z]+-0x[0-9a-f]', caseSensitive: false).hasMatch(target)) {
    return null;
  }
  final int at = target.indexOf('@');
  final String address = (at < 0 ? target : target.substring(0, at)).trim();
  final int? chainId = at < 0 ? null : int.tryParse(target.substring(at + 1));
  if (!_cryptoAddress.hasMatch(address) || (at >= 0 && chainId == null)) {
    return null;
  }
  final String? value = orNull(
    queryParameters(q < 0 ? '' : b.substring(q + 1))['value']?.trim(),
  );
  if (value != null && !_wei.hasMatch(value)) {
    return null;
  }
  return CryptoContent(
    currency: CryptoCurrency.ethereum,
    address: address,
    amount: value,
    chainId: chainId,
  );
}

/// [CryptoContent.toPayload].
String buildCrypto(CryptoContent c) {
  checkIssues(validateCrypto(c));
  final String address = c.address.trim();
  final String? amount = orNull(c.amount?.trim());
  switch (c.currency) {
    case CryptoCurrency.bitcoin || CryptoCurrency.litecoin:
      final List<String> params = <String>[
        if (amount != null) 'amount=$amount',
        if (orNull(c.label) case final String label)
          'label=${Uri.encodeComponent(label)}',
        if (orNull(c.message) case final String message)
          'message=${Uri.encodeComponent(message)}',
      ];
      return '${c.currency.scheme}:$address'
          '${params.isEmpty ? '' : '?${params.join('&')}'}';
    case CryptoCurrency.ethereum:
      return 'ethereum:$address'
          '${c.chainId == null ? '' : '@${c.chainId}'}'
          '${amount == null ? '' : '?value=$amount'}';
    case CryptoCurrency.lightning:
      return 'lightning:$address';
  }
}

/// [CryptoContent.validate].
List<ContentIssue> validateCrypto(CryptoContent c) {
  final String address = c.address.trim();
  final String? amount = orNull(c.amount?.trim());
  final bool lightning = c.currency == CryptoCurrency.lightning;
  final bool ethereum = c.currency == CryptoCurrency.ethereum;
  return <ContentIssue>[
    if (address.isEmpty)
      const ContentIssue('address', 'Address is empty')
    else if (lightning && !_lightning.hasMatch(address))
      const ContentIssue('address', 'Not a Lightning invoice or LNURL')
    else if (!lightning && !_cryptoAddress.hasMatch(address))
      const ContentIssue('address', 'Address has characters it cannot have'),
    if (amount != null && lightning)
      const ContentIssue('amount', 'A Lightning invoice carries its amount')
    else if (amount != null && ethereum && !_wei.hasMatch(amount))
      const ContentIssue('amount', 'Value must be a number of wei')
    else if (amount != null && !ethereum && !_coins.hasMatch(amount))
      const ContentIssue(
        'amount',
        'Amount must be a number, 8 decimals at most',
      ),
    if ((ethereum || lightning) && orNull(c.label) != null)
      ContentIssue('label', '${c.currency.name} links have no label'),
    if ((ethereum || lightning) && orNull(c.message) != null)
      ContentIssue('message', '${c.currency.name} links have no message'),
    if (!ethereum && c.chainId != null)
      const ContentIssue('chainId', 'Only Ethereum links have a chain id')
    else if (c.chainId case final int id when id < 1)
      const ContentIssue('chainId', 'Chain id must be positive'),
  ];
}

// --- Wi-Fi Easy Connect ------------------------------------------------------------

/// `DPP:C:81/1;M:…;I:…;K:…;;`, after the `DPP:`. [raw] is the whole
/// payload.
WifiDppContent? parseWifiDpp(String body, String raw) {
  final Map<String, String> fields = <String, String>{};
  for (final String field in body.split(';')) {
    final int colon = field.indexOf(':');
    if (colon > 0) {
      fields.putIfAbsent(
        field.substring(0, colon).trim().toUpperCase(),
        () => field.substring(colon + 1).trim(),
      );
    }
  }
  final String? key = orNull(fields['K']);
  if (key == null) {
    return null;
  }
  return WifiDppContent(
    publicKey: key,
    channels: orNull(fields['C']),
    macAddress: orNull(fields['M']),
    information: orNull(fields['I']),
    raw: raw,
  );
}
