# Content types

`barcode.content` parses what a barcode holds into a sealed `BarcodeContent`
type. Every kind can also build the text for a new code with `toPayload()`,
and `BarcodeContent.parseText` reads that text back as an equal value.

```dart
import 'package:flutter_zxing/flutter_zxing.dart';

// Reading
switch (barcode.content) {
  case WifiContent(:final ssid, :final password):
    joinNetwork(ssid, password);
  case OtpContent otp:
    addToAuthenticator(otp);
  default:
    print(barcode.text);
}

// Creating
const event = EventContent(summary: 'Launch', start: ..., end: ...);
BarcodeView(event.toPayload());
```

## Kinds

**Built** means the kind has a `toPayload()` that writes the standard
format. **Parsed only** kinds come from codes that others issue (airlines,
states, device makers); their `toPayload()` returns the text as read.
Which built codes the iOS and Android camera apps open is being checked on
devices and will be added here.

| Kind | Holds | Payload | Built |
|---|---|---|---|
| `TextContent` | text | as is | yes |
| `UrlContent` | address, title, `service` | `https://…`; `MEBKM:` with a title | yes |
| `WifiContent` | network name, password, security, hidden | `WIFI:T:WPA;S:…;P:…;;` | yes |
| `ContactContent` | name, organization, title, phones, e-mails, web addresses, addresses, note, birthday | vCard 3.0, or `MECARD:` | yes |
| `EventContent` | title, start, end, all day, location, description | `BEGIN:VCALENDAR` with one `VEVENT` | yes |
| `EmailContent` | recipients, subject, body | `mailto:` | yes |
| `PhoneContent` | number; phone or FaceTime | `tel:`, `facetime:`, `facetime-audio:` | yes |
| `SmsContent` | recipients, message | `SMSTO:number:message` | yes |
| `GeoContent` | latitude, longitude, altitude, search | `geo:` | yes |
| `OtpContent` | secret, account, issuer, TOTP or HOTP, algorithm, digits, period, counter | `otpauth://totp/…` | yes |
| `EsimContent` | SM-DP+ address, Matching ID, OID, confirmation code | `LPA:1$…` | yes |
| `CryptoContent` | network, address, amount, label, message, chain id | `bitcoin:`, `litecoin:`, `ethereum:`, `lightning:` | yes |
| `Gs1Content` | Application Identifiers and values | GS1 element strings | yes, with `encodeContent` or `gs1: true` |
| `BinaryContent` | bytes | binary | with `encodeContent` or `BarcodeView.bytes` |
| `WifiDppContent` | public key, channels, MAC address, information | `DPP:…;;` (Wi‑Fi Easy Connect) | parsed only |
| `SmartHomeContent` | Matter or HomeKit; setup code, vendor and product id, discriminator, category, setup id | `MT:…`, `X-HM://…` | parsed only |
| `ProductContent` | GTIN, add-on; ISBN-13, ISBN-10, ISSN | EAN-13, EAN-8, UPC-A, UPC-E barcodes | parsed only |
| `BoardingPassContent` | passenger, legs: booking, from, to, carrier, flight, day, cabin, seat, sequence | IATA BCBP (`M1…`) | parsed only |
| `DriverLicenseContent` | number, names, dates of birth, issue and expiry, address, state, country | AAMVA DL/ID (PDF417) | parsed only |
| `VinContent` | VIN, WMI, region, model year, check digit | 17 characters (ISO 3779) | parsed only |

`ProductContent` comes only from EAN/UPC barcodes, and `Gs1Content` and
`BinaryContent` only from barcodes marked GS1 or binary: `parseText` cannot
tell those apart in a saved string.

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
with the field name of the constructor and an English message, without
throwing. `toPayload()` throws an `ArgumentError` with the same messages.

```dart
final List<ContentIssue> issues = WifiContent(ssid: ssid, password: pass).validate();
// [ssid: Network name is empty]
```

## Normal form

Building normalises what parsing would not give back as it is: spaces
leave phone numbers, surrounding whitespace leaves fields, empty strings
become `null`, OTP secrets lose spaces and padding. So
`parseText(c.toPayload()) == c` holds for values in that form, and building
again always gives the same text.

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
