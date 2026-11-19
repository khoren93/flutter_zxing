# Content types

`barcode.content` parses what a barcode holds into a sealed `BarcodeContent`
type. Every kind can also build the text for a new code with `toPayload()`,
and `BarcodeContent.parseText` reads that text back (see
[Normal form](#normal-form) for when the value is equal).

```dart
import 'package:flutter_zxing/flutter_zxing.dart';

// Reading
switch (barcode.content) {
  case WifiContent(:final ssid, :final password):
    joinNetwork(ssid, password);
  case OtpContent otp:
    addToAuthenticator(otp);
  default: // new kinds come in minor versions
    print(barcode.text);
}

// Opening: mailto:, tel:, geo:, web addresses… for package:url_launcher
if (barcode.content.uri case final Uri uri) {
  await launchUrl(uri);
}

// Creating
final event = EventContent(
  summary: 'Launch',
  start: DateTime(2027, 3, 1, 10),
  end: DateTime(2027, 3, 1, 11),
);
BarcodeView(event.toPayload());
```

`BarcodeContent` and `PaymentContent` get new kinds in minor versions, so a
`switch` over them needs a `default`. `uri` is `null` for kinds without a
link, such as Wi-Fi networks and contacts.

## Kinds

**Built** means the kind has a `toPayload()` that writes the standard
format. **Parsed only** kinds come from codes that others issue (airlines,
states, device makers); their `toPayload()` returns the text as read.
Which built codes the iOS and Android camera apps open is being checked on
devices and will be added here.

| Kind | Holds | Payload | Built |
|---|---|---|---|
| `TextContent` | text | as is | yes |
| `UrlContent` | `url`, `title`, `service` | `https://…`; `MEBKM:` with a title | yes |
| `WifiContent` | `ssid`, `password`, `security` (open, WEP, WPA, WPA3), `hidden` | `WIFI:T:WPA;S:…;P:…;;` | yes |
| `ContactContent` | name, organization, title, phones, e-mails, web addresses, addresses, note, `birthDate` | vCard 3.0, or `MECARD:` | yes |
| `EventContent` | title, start, end, all day, location, description | `BEGIN:VCALENDAR` with one `VEVENT` | yes |
| `EmailContent` | recipients, subject, body | `mailto:` | yes |
| `PhoneContent` | number; phone or FaceTime | `tel:`, `facetime:`, `facetime-audio:` | yes |
| `SmsContent` | recipients, message | `SMSTO:number:message` | yes |
| `GeoContent` | latitude, longitude, altitude, search | `geo:` | yes |
| `OtpContent` | secret, account, issuer, TOTP or HOTP, algorithm, digits, period, counter | `otpauth://totp/…` | yes |
| `EsimContent` | SM-DP+ address, Matching ID, OID, confirmation code | `LPA:1$…` | yes |
| `CryptoContent` | network, address, `amount` in coins, `value` as written (wei), label, message, chain id | `bitcoin:`, `litecoin:`, `ethereum:`, `lightning:` | yes |
| `Gs1Content` | Application Identifiers and values; `gtin`, `expiryDate`, `bestBeforeDate`, ... | GS1 element strings | yes, with `encodeContent` or `gs1: true` |
| `BinaryContent` | bytes | binary | with `encodeContent` or `BarcodeView.bytes` |
| `WifiDppContent` | public key, channels, MAC address, information | `DPP:…;;` (Wi‑Fi Easy Connect) | parsed only |
| `SmartHomeContent` | Matter or HomeKit; setup code, vendor and product id, discriminator, category, setup id | `MT:…`, `X-HM://…` | parsed only |
| `ProductContent` | `gtin` (always a GTIN-14), `number` as printed, add-on; ISBN-13, ISBN-10, ISSN | EAN-13, EAN-8, UPC-A, UPC-E barcodes | parsed only |
| `BoardingPassContent` | passenger, legs: booking, from, to, carrier, flight, day, cabin, seat, sequence | IATA BCBP (`M1…`) | parsed only |
| `DriverLicenseContent` | number, names, `birthDate`, issue and `expiryDate`, address, state, country | AAMVA DL/ID (PDF417) | parsed only |
| `VinContent` | VIN, WMI, region, model year, check digit | 17 characters (ISO 3779) | parsed only |

`ProductContent` comes only from EAN/UPC barcodes, and `Gs1Content` and
`BinaryContent` only from barcodes marked GS1 or binary: `parseText` cannot
tell those apart in a saved string.

## Payments

Every payment code is a `PaymentContent` with the same five questions
answered (`payee`, `account`, `amount`, `currency`, `reference`), and a
subclass per standard with its own fields. Amounts are text with a decimal
point, never a `double`. A code whose IBAN, reference or checksum is wrong
is not a payment: it parses as `TextContent`.

| Kind | Standard | Payload | Checks |
|---|---|---|---|
| `EpcPaymentContent` | EPC069-12 SEPA credit transfer ("GiroCode") | `BCD\n002\n1\nSCT\n…` | IBAN, BIC, RF reference, amount ≤ 999 999 999.99 EUR, 331 bytes |
| `SwissQrBillContent` | Swiss Payment Standards 2.3 | `SPC\n0200\n1\n…\nEPD` | IBAN or QR-IBAN, `creditorReference`: QR reference (mod 10) or RF, structured addresses, 997 characters |
| `GostPaymentContent` | ГОСТ Р 56042-2014 | `ST00012\|Name=…\|…` | account, BIC, correspondent account, INN, KPP; read in Windows-1251, UTF-8 and KOI8-R, written in UTF-8 |
| `UpiPaymentContent` | NPCI UPI | `upi://pay?pa=…` | UPI address, amount, INR |
| `EmvPaymentContent` | EMVCo merchant-presented QR: PIX, PayNow, PromptPay, QRIS, VietQR, DuitNow and others | `000201…6304XXXX` | CRC16; built with `EmvPaymentContent.pix(...)` |
| `SpaydPaymentContent` | Short Payment Descriptor (Czech Republic) | `SPD*1.0*ACC:…` | IBAN, BIC, symbols |

```dart
const epc = EpcPaymentContent(
  name: 'Kaffeehaus Lumen',
  iban: 'DE89370400440532013000',
  amount: '12.50',
  message: 'Invoice 42',
);
BarcodeView(
  epc.toPayload(),
  writer: const BarcodeWriter(
    BarcodeFormat.qrCode,
    errorCorrection: ErrorCorrection.medium,
  ),
);

// A Swiss QR-bill with the Swiss cross the standard requires
BarcodeView(bill.toPayload(), style: BarcodeStyle.swissQrBill);
```

PAY by square (Slovakia) is not supported yet: it is LZMA-compressed.

## Links to services

`LinkService` builds links to messengers, social networks, music, app
stores and maps from a phone number, user name, id or search, and
`UrlContent.service` recognises a scanned link's service:

```dart
LinkService.whatsApp.link('+374 91 234567', message: 'Hi');
// https://wa.me/37491234567?text=Hi
LinkService.instagram.link('@flutter.dev');
// https://www.instagram.com/flutter.dev
LinkService.googleMaps.link('Republic Square, Yerevan');

UrlContent(Uri.parse('https://youtu.be/…')).service; // LinkService.youTube
```

WhatsApp, Telegram, Signal, Instagram, Facebook, X, LinkedIn, TikTok,
YouTube, Snapchat, Pinterest, Threads, Discord, Twitch, Reddit, Spotify,
Apple Music, SoundCloud, App Store, Google Play, Google Maps, Apple Maps,
Yandex Maps and Google reviews. They are plain `https://` links: every
camera opens them, in the service's app when it is installed. Viber has no
web link to a chat, so it is not in the list.

## Forms

`validate()` lists what keeps a value from being built, as `ContentIssue`s
with the field name of the constructor, an English message, a `kind` and,
for text that is too long, a `limit`. It does not throw; `toPayload()`
throws an `ArgumentError` with the same messages.

```dart
final List<ContentIssue> issues = WifiContent(ssid: ssid, password: pass).validate();
// [ssid: Network name is empty]

// Your own texts, from the kind:
String say(ContentIssue issue) => switch (issue.kind) {
  ContentIssueKind.empty => 'Required',
  ContentIssueKind.tooLong => 'At most ${issue.limit} characters',
  _ => issue.message,
};
```

The kinds are `empty`, `tooLong`, `invalid`, `checksum`, `outOfRange`,
`conflict` and `unsupported`.

## Normal form

Building normalises what parsing would not give back as it is: spaces
leave phone numbers, surrounding whitespace leaves fields, empty strings
become `null`, OTP secrets lose spaces and padding. So
`parseText(c.toPayload()) == c` holds for values in that form, and building
again always gives the same text.

It does not hold for `ProductContent`, `Gs1Content` and `BinaryContent`,
which come only from barcodes (see above), and for a few values that read
back with more filled in: an Ethereum `amount` also has its `value` in wei,
and a SPAYD payment with an empty currency comes back in CZK.

## Encoding any kind

`writer.encodeContent(content)` encodes text kinds as text, `Gs1Content`
in GS1 mode and `BinaryContent` as bytes:

```dart
final symbol = await const BarcodeWriter(BarcodeFormat.dataMatrix)
    .encodeContent(const Gs1Content({'01': '09501101530003', '17': '270101'}));
```

## Privacy

`OtpContent` holds a secret that logs in as the account's second factor, and
`DriverLicenseContent` personal data. Their `toString()` leaves these out,
and the result sheet does not show an OTP secret.
