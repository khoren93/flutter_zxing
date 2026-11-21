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

Every template takes your colours and texts ([Colours and texts](./scanning/theming)),
and `copyWith` changes any of its settings ([A ready-made screen](./scanning/templates)).
The screenshots below are the templates themselves, rendered by the
package's tests.

<TemplateGallery />
