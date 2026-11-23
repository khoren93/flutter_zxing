# What is in a code

`barcode.content` parses what a code holds into a `BarcodeContent`: a link,
a Wi-Fi network, a contact, a payment… Parsing never throws: anything it
does not recognise is `TextContent` or `BinaryContent`.

```dart
void handle(Barcode barcode) {
  switch (barcode.content) {
    case UrlContent(:final url):
      launchUrl(url);
    case WifiContent(:final ssid, :final password):
      print('Join $ssid with $password');
    case ContactContent contact:
      print('Save ${contact.name}');
    case Gs1Content(:final gtin):
      print('Look up $gtin');
    default: // new kinds come in minor versions
      print(barcode.text);
  }
}
```

New kinds come in minor versions, so a `switch` over `BarcodeContent` or
`PaymentContent` needs a `default`.

## Open it

`content.uri` is a link to open the content with `url_launcher`:
`https://`, `mailto:`, `tel:`, `sms:`, `geo:`… It is `null` for kinds
without a link, such as Wi-Fi networks and contacts.

```dart
Future<void> open(Barcode barcode) async {
  if (barcode.content.uri case final Uri uri) {
    await launchUrl(uri);
  }
}
```

## The kinds

**Built** means the kind has a `toPayload()` that writes the standard
format, see [Building content](./building). **Parsed only** kinds come from
codes that others issue (airlines, states, device makers); their
`toPayload()` returns the text as read.

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
| `Gs1Content` | Application Identifiers and values; `gtin`, `sscc`, `contentsGtin`, `count`, `batch`, `serial`, `expiryDate`, `bestBeforeDate` | GS1 element strings | yes, with `encodeContent` or `gs1: true` |
| `BinaryContent` | bytes | binary | with `encodeContent` or `BarcodeView.bytes` |
| `PaymentContent` | payee, account, amount, currency, reference; a kind per standard | see [Payments](./payments) | yes |
| `WifiDppContent` | public key, channels, MAC address, information | `DPP:…;;` (Wi‑Fi Easy Connect) | parsed only |
| `SmartHomeContent` | Matter or HomeKit; setup code, vendor and product id, discriminator, category, setup id | `MT:…`, `X-HM://…` | parsed only |
| `ProductContent` | `gtin` (always a GTIN-14), `number` as printed, add-on; ISBN-13, ISBN-10, ISSN | EAN-13, EAN-8, UPC-A, UPC-E barcodes | parsed only |
| `BoardingPassContent` | passenger, legs: booking, from, to, carrier, flight, day of the year and its `date()`, cabin, seat, sequence | IATA BCBP (`M1…`) | parsed only |
| `DriverLicenseContent` | number, names, `birthDate`, issue and `expiryDate`, address, state, country | AAMVA DL/ID (PDF417) | parsed only |
| `VinContent` | VIN, WMI, region, model year, check digit | 17 characters (ISO 3779) | parsed only |

`ProductContent` comes only from EAN and UPC codes, and `Gs1Content` and
`BinaryContent` only from codes marked GS1 or binary.

## GS1 labels and boarding passes

A GS1 label names its data by Application Identifier: `elements['17']` is
the expiry date as printed. The getters read the common ones. On a
pallet's label, `sscc` is the pallet itself and `contentsGtin` (AI 02) the
goods on it, next to their `count`; `gtin` (AI 01) is a trade item itself.

```dart
void receive(Gs1Content label) {
  if (label.sscc case final String pallet) {
    print('Pallet $pallet: ${label.count} x ${label.contentsGtin}');
  } else {
    print('Item ${label.gtin}, batch ${label.batch}, expires ${label.expiryDate}');
  }
}
```

A boarding pass gives the day of the year of each flight, not the year.
`leg.date()` picks the year closest to today: a pass for 2 January scanned
on 30 December is for next year's flight.

```dart
DateTime? firstFlight(BoardingPassContent pass) => pass.legs.first.date();
```

## Text you already have

`BarcodeContent.parseText` parses text that did not come from a scan, such
as a saved history entry:

```dart
final BarcodeContent content = BarcodeContent.parseText('WIFI:T:WPA;S:Home;P:secret;;');
```

It cannot tell GS1, binary and product codes apart in a saved string:
those come only from `barcode.content`.

## Privacy

`OtpContent` holds a secret that logs in as the account's second factor,
and `DriverLicenseContent` personal data. Their `toString()` leaves these
out, and the scanner's result sheet does not show an OTP secret.
