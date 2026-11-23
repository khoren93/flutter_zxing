# Scan one code

When the app needs one code and then goes on, `scanBarcode` opens a scanner,
waits for a code and closes with it. It returns `null` when the user closes
the scanner.

```dart
Future<void> scanTicket(BuildContext context) async {
  final Barcode? barcode = await scanBarcode(
    context,
    formats: {BarcodeFormat.qrCode},
    hint: 'Point the camera at a QR code',
  );
  if (barcode == null) return; // closed
  print(barcode.text);
}
```

The screen is the [Minimal template](./templates) without its result sheet:
the brackets lock onto the code and the screen closes.

| Parameter | What it does |
|---|---|
| `formats` | The formats to look for; all by default. Fewer decode faster. |
| `hint` | The text under the scan window; `''` for none. |
| `scanWindow` | The part of the preview that is decoded. |
| `facing` | `CameraFacing.back` (the default) or `front`. |
| `check` | Accepts or refuses each code before the scanner closes, below. |
| `presentation` | `ScannerPresentation.page` (the default) or `sheet`, below. |
| `template` | Another screen, such as `ScannerTemplate.ticket()`. A template that collects codes or keeps scanning takes one code here. |
| `theme`, `strings` | Colours and texts, see [Colours and texts](./theming). |

## As a sheet

`ScannerPresentation.sheet` opens the scanner over the lower part of the
screen. The page under it, such as the form being filled in, stays in view,
and a tap above the sheet closes it.

```dart
final Barcode? barcode = await scanBarcode(
  context,
  presentation: ScannerPresentation.sheet,
);
```

## Check the code first

A `check` decides whether a code is the one the app wants. Return
`ScanVerdict.reject` to refuse it: the scanner stays open and shows the
verdict's text. Return `null` or `ScanVerdict.accept` to accept it. The
check may be asynchronous, such as a request to your server; codes found
meanwhile are skipped.

```dart
final Barcode? barcode = await scanBarcode(
  context,
  check: (barcode) {
    if (!barcode.text.startsWith('https://example.com/join/')) {
      return const ScanVerdict.reject(
        title: 'Not an invitation',
        message: 'Scan the code on the invitation card.',
      );
    }
    return null; // accepted
  },
);
```

## One kind of content

`scanContent` accepts only one kind of content, such as a 2FA code or a
Wi‑Fi network, and returns it typed. Other codes are refused and the
scanner stays open:

```dart
Future<void> addAccount(BuildContext context) async {
  final OtpContent? otp = await scanContent<OtpContent>(
    context,
    hint: 'Scan the QR code from the service’s 2FA settings',
    reject: const ScanVerdict.reject(title: 'Not a 2FA code'),
  );
  if (otp != null) print('${otp.issuer}: ${otp.account}');
}
```

`acceptOnly<T>()` is the same check for a template:
`ScannerTemplate.content(check: acceptOnly<WifiContent>())`.

## More than the code

`scanBarcode` returns the code. To return something else, such as what a
check found on your server, open the template with its sheet:
`openScanner<T>` returns what the sheet passes to `result.finish`. See
[What the check found](./templates#what-the-check-found).

## Fill a text field

`ScanFieldButton` goes in a text field: a tap opens the scanner in a sheet
over the form and puts the code into the field.

```dart
class TrackingField extends StatefulWidget {
  const TrackingField({super.key});

  @override
  State<TrackingField> createState() => _TrackingFieldState();
}

class _TrackingFieldState extends State<TrackingField> {
  final tracking = TextEditingController();

  @override
  void dispose() {
    tracking.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: tracking,
    decoration: InputDecoration(
      labelText: 'Tracking number',
      suffixIcon: ScanFieldButton(controller: tracking, title: 'Tracking number'),
    ),
  );
}
```

It takes `formats`, `check`, `template`, `theme` and `strings` like
`scanBarcode`, and `valueOf` to put something other than the text into the
field.

## The result

A `Barcode` has the decoded `text`, its `format`, the raw `bytes`, where it
was (`position`), and `content`: what the text means, such as a link, a
Wi-Fi network or a payment. See [What is in a code](../content/overview).

```dart
void show(Barcode barcode) {
  print(barcode.format.displayName); // QR Code
  print(barcode.text);
  if (barcode.content.uri case final Uri uri) {
    launchUrl(uri); // package:url_launcher
  }
}
```
