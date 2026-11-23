# Templates

A template is a finished scanner screen: glass buttons (close, torch, photo,
zoom, camera switch), a hint, brackets that lock onto the code, and what
happens next. Pass one to `BarcodeScanner` or `scanBarcode`:

```dart
BarcodeScanner(
  template: const ScannerTemplate.payment(),
  onDetect: (capture) => print(capture.barcode.text),
)
```

Every template takes your colours, scan window, icons and texts, in the
app's language ([Colours and texts](./scanning/theming)), and the same
settings: a title, a hint, its buttons and where they go, a check, your
own sound. `copyWith` changes any of them
([A ready-made screen](./scanning/templates#other-settings)). The
[Use cases](./use-cases) show them at work, one file each.
The screenshots below are the templates themselves, rendered by the
package's tests.

<TemplateGallery />
