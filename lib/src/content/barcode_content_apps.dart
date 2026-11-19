part of 'barcode_content.dart';

/// How an [OtpContent] counts.
enum OtpType {
  /// Time-based (TOTP): a new code every [OtpContent.period] seconds.
  totp,

  /// Counter-based (HOTP): a new code each time one is used.
  hotp,
}

/// The hash function of an [OtpContent].
enum OtpAlgorithm {
  /// SHA-1, what nearly every service uses.
  sha1,

  /// SHA-256.
  sha256,

  /// SHA-512.
  sha512,
}

/// A one-time password account for an authenticator app
/// (`otpauth://totp/Issuer:account?secret=…&issuer=Issuer`, the Key URI
/// format of Google Authenticator).
///
/// The [secret] is what the app generates codes from: whoever has it can
/// log in as the account's second factor. [toString] leaves it out, and a
/// result screen should not show it unless asked to.
final class OtpContent extends BarcodeContent {
  /// Creates one-time password content.
  const OtpContent({
    required this.secret,
    required this.account,
    this.issuer,
    this.type = OtpType.totp,
    this.algorithm = OtpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.counter = 0,
  });

  /// The shared secret in Base32, upper case, without spaces or padding.
  final String secret;

  /// The account, usually a user name or e-mail address.
  final String account;

  /// The service, such as `GitHub`, if given.
  final String? issuer;

  /// Time-based or counter-based.
  final OtpType type;

  /// The hash function.
  final OtpAlgorithm algorithm;

  /// Digits of each code: 6 or 8 (authenticator apps also take 7).
  final int digits;

  /// Seconds each code lasts, for [OtpType.totp].
  final int period;

  /// The first counter value, for [OtpType.hotp].
  final int counter;

  /// `otpauth://totp/Issuer:account?secret=…&issuer=Issuer`, with
  /// `algorithm`, `digits` and `period` only when they are not the
  /// defaults, which some apps do not read. The secret is written without
  /// spaces or padding.
  @override
  String toPayload() => buildOtp(this);

  @override
  List<ContentIssue> validate() => validateOtp(this);

  /// `otpauth://…`, as [toPayload]: authenticator apps add the account.
  @override
  Uri? get uri => payloadUri(this);

  @override
  bool operator ==(Object other) =>
      other is OtpContent &&
      other.secret == secret &&
      other.account == account &&
      other.issuer == issuer &&
      other.type == type &&
      other.algorithm == algorithm &&
      other.digits == digits &&
      other.period == period &&
      other.counter == counter;

  @override
  int get hashCode => Object.hash(
    secret,
    account,
    issuer,
    type,
    algorithm,
    digits,
    period,
    counter,
  );

  /// Without the secret.
  @override
  String toString() =>
      'OtpContent(${type.name}, ${issuer == null ? '' : '$issuer: '}$account)';
}

/// An eSIM activation code (`LPA:1$smdp.example.com$MATCHING-ID`, GSMA
/// SGP.22): where the phone downloads the profile from.
final class EsimContent extends BarcodeContent {
  /// Creates eSIM content.
  const EsimContent({
    required this.smdpAddress,
    this.matchingId,
    this.oid,
    this.confirmationCodeRequired = false,
  });

  /// The address of the operator's SM-DP+ server.
  final String smdpAddress;

  /// The activation code token (Matching ID), if given.
  final String? matchingId;

  /// The SM-DP+ server's object identifier, if given.
  final String? oid;

  /// Whether the operator also gave a confirmation code to type in.
  final bool confirmationCodeRequired;

  /// `LPA:1$address$matchingId[$oid[$1]]`.
  @override
  String toPayload() => buildEsim(this);

  @override
  List<ContentIssue> validate() => validateEsim(this);

  @override
  bool operator ==(Object other) =>
      other is EsimContent &&
      other.smdpAddress == smdpAddress &&
      other.matchingId == matchingId &&
      other.oid == oid &&
      other.confirmationCodeRequired == confirmationCodeRequired;

  @override
  int get hashCode =>
      Object.hash(smdpAddress, matchingId, oid, confirmationCodeRequired);

  @override
  String toString() => 'EsimContent($smdpAddress)';
}

/// The network of a [CryptoContent].
///
/// New networks are added in minor versions: a `switch` over it needs a
/// `default` (or `_`) case.
enum CryptoCurrency {
  /// Bitcoin (`bitcoin:`, BIP 21).
  bitcoin('bitcoin', 'BTC'),

  /// Ethereum (`ethereum:`, EIP-681).
  ethereum('ethereum', 'ETH'),

  /// Litecoin (`litecoin:`, as BIP 21).
  litecoin('litecoin', 'LTC'),

  /// Bitcoin Lightning (`lightning:` and bare `lnbc…` invoices, LNURL).
  lightning('lightning', 'BTC');

  const CryptoCurrency(this.scheme, this.symbol);

  /// The URI scheme.
  final String scheme;

  /// The ticker symbol of the currency.
  final String symbol;
}

/// A cryptocurrency payment request: an address, optionally with an
/// amount.
///
/// From `bitcoin:` and `litecoin:` (BIP 21: `amount`, `label`, `message`),
/// `ethereum:` (EIP-681: an address with a chain id and a `value` in wei;
/// calls such as token transfers stay [TextContent]) and Lightning
/// invoices, which are recognised but not decoded.
///
/// [amount] is always in coins (BTC, ETH, LTC): an Ethereum link's wei are
/// divided by 10^18 as text, without rounding. The wei as written are in
/// [value].
final class CryptoContent extends BarcodeContent {
  /// Creates cryptocurrency content.
  const CryptoContent({
    required this.currency,
    required this.address,
    this.amount,
    this.value,
    this.label,
    this.message,
    this.chainId,
  });

  /// The network.
  final CryptoCurrency currency;

  /// The receiving address; for [CryptoCurrency.lightning], the invoice or
  /// LNURL.
  final String address;

  /// The amount in coins (`0.0015` BTC, `2.014` ETH), or `null` when the
  /// payer enters it. Kept as text, so nothing is lost to floating point;
  /// as written for Bitcoin and Litecoin, and for Ethereum the link's
  /// [value] in ether, without trailing zeros.
  final String? amount;

  /// For Ethereum, the EIP-681 `value` in wei as written (`2.014e18`), or
  /// `null`.
  ///
  /// When building, [value] is written as it is if given, else [amount]
  /// in wei; given both, they must be the same amount. Other networks have
  /// no [value].
  final String? value;

  /// The payee's name (BIP 21 `label`).
  final String? label;

  /// A note for the payer (BIP 21 `message`).
  final String? message;

  /// The Ethereum chain id (`@137`), if given; 1 is the main network.
  final int? chainId;

  /// `bitcoin:address?amount=…&label=…&message=…`,
  /// `ethereum:address@chainId?value=…` (wei), `lightning:invoice`.
  @override
  String toPayload() => buildCrypto(this);

  @override
  List<ContentIssue> validate() => validateCrypto(this);

  /// `bitcoin:…`, `ethereum:…`, `litecoin:…` or `lightning:…`, as
  /// [toPayload]: wallet apps open it.
  @override
  Uri? get uri => payloadUri(this);

  @override
  bool operator ==(Object other) =>
      other is CryptoContent &&
      other.currency == currency &&
      other.address == address &&
      other.amount == amount &&
      other.value == value &&
      other.label == label &&
      other.message == message &&
      other.chainId == chainId;

  @override
  int get hashCode =>
      Object.hash(currency, address, amount, value, label, message, chainId);

  @override
  String toString() => 'CryptoContent(${currency.name}, $address)';
}

/// A Wi-Fi Easy Connect (DPP) bootstrapping code: `DPP:K:…;;` on a router or
/// a smart device, which a phone scans to put the device on its network.
///
/// Only parsed: the code is made by the device. [toPayload] returns [raw].
final class WifiDppContent extends BarcodeContent {
  /// Creates Wi-Fi Easy Connect content.
  const WifiDppContent({
    required this.publicKey,
    required this.raw,
    this.channels,
    this.macAddress,
    this.information,
  });

  /// The device's public key (`K:`), Base64.
  final String publicKey;

  /// Operating classes and channels the device listens on (`C:81/1,117/40`).
  final String? channels;

  /// The device's MAC address (`M:`), as written.
  final String? macAddress;

  /// Free text from the manufacturer, such as a serial number (`I:`).
  final String? information;

  /// The code as read.
  final String raw;

  /// [raw], the code as read.
  @override
  String toPayload() => raw;

  @override
  List<ContentIssue> validate() => const <ContentIssue>[];

  @override
  bool operator ==(Object other) =>
      other is WifiDppContent &&
      other.publicKey == publicKey &&
      other.channels == channels &&
      other.macAddress == macAddress &&
      other.information == information &&
      other.raw == raw;

  @override
  int get hashCode =>
      Object.hash(publicKey, channels, macAddress, information, raw);

  @override
  String toString() => 'WifiDppContent(${information ?? macAddress ?? ''})';
}
