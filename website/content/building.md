# Building content

Every kind that can be built writes the text for a new code with
`toPayload()`, escaped as its format needs. Give that text to a
`BarcodeView`.

```dart
const wifi = WifiContent(ssid: 'Home', password: 'secret;12');

Widget wifiCode() => BarcodeView(wifi.toPayload(), width: 200);
// WIFI:T:WPA;S:Home;P:secret\;12;;
```

```dart
final event = EventContent(
  summary: 'Launch',
  start: DateTime(2027, 3, 1, 10),
  end: DateTime(2027, 3, 1, 11),
);

Widget eventCode() => BarcodeView(event.toPayload(), width: 200);
```

The table of kinds, and which can be built, is on
[What is in a code](./overview#the-kinds).

## Forms

`validate()` lists what keeps a value from being built, as `ContentIssue`s:
the field name of the constructor, an English message, a `kind` and, for
text that is too long, a `limit`. It does not throw; `toPayload()` throws an
`ArgumentError` with the same messages.

```dart
List<ContentIssue> check(String ssid, String password) =>
    WifiContent(ssid: ssid, password: password).validate();
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

## Links to services

`LinkService` builds links to messengers, social networks, music, app
stores and maps from a phone number, user name, id or search.
`UrlContent.service` recognises the service of a scanned link.

```dart
final UrlContent chat = LinkService.whatsApp.link('+374 91 234567', message: 'Hi');
// https://wa.me/37491234567?text=Hi
final UrlContent profile = LinkService.instagram.link('@flutter.dev');
// https://www.instagram.com/flutter.dev
final UrlContent place = LinkService.googleMaps.link('Republic Square, Yerevan');

Widget chatCode() => BarcodeView(chat.toPayload(), width: 200);
```

WhatsApp, Telegram, Signal, Instagram, Facebook, X, LinkedIn, TikTok,
YouTube, Snapchat, Pinterest, Threads, Discord, Twitch, Reddit, Spotify,
Apple Music, SoundCloud, App Store, Google Play, Google Maps, Apple Maps,
Yandex Maps and Google reviews. They are plain `https://` links: every
camera opens them, in the service's app when it is installed. Viber has no
web link to a chat, so it is not in the list.

## Normal form

Building normalises what parsing would not give back as it is: spaces
leave phone numbers, surrounding whitespace leaves fields, empty strings
become `null`, OTP secrets lose spaces and padding, web addresses without a
scheme get `https://`, `\r\n` line breaks become `\n`, event times lose
their milliseconds and all-day events keep only their local date, ГОСТ
amounts get two decimals (`1250.5` → `1250.50`). So
`BarcodeContent.parseText(c.toPayload()) == c` holds for values in that
form, and building again always gives the same text.

It does not hold for `ProductContent`, `Gs1Content` and `BinaryContent`,
which come only from codes, and for a few values that read back with more
filled in: an Ethereum `amount` also has its `value` in wei, and a SPAYD
payment with an empty currency comes back in CZK.

## Encoding any kind

`writer.encodeContent(content)` encodes text kinds as text, `Gs1Content` in
GS1 mode and `BinaryContent` as bytes:

```dart
Future<BarcodeSymbol> gs1Label() => const BarcodeWriter(BarcodeFormat.dataMatrix)
    .encodeContent(const Gs1Content({'01': '09501101530003', '17': '270101'}));
```

On screen, `BarcodeContentView(content)` does the same and adds what a
standard requires, such as the Swiss cross on a QR-bill; a content with
problems shows its `errorBuilder`:

```dart
Widget wifiCard(WifiContent wifi) => BarcodeContentView(
  wifi,
  width: 220,
  errorBuilder: (BuildContext context, BarcodeWriteException error) =>
      Text(error.message),
);
```
