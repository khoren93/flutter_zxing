# Example

A whole app: a button that scans a code, and the code shown again with
`BarcodeView`. The [example app](https://github.com/khoren93/flutter_zxing/tree/4.0/example)
in the repository has every template, the creator and a history.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_zxing/scanner.dart';

void main() => runApp(const MaterialApp(home: HomePage()));

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Barcode? _barcode;

  Future<void> _scan() async {
    final Barcode? barcode = await scanBarcode(context);
    if (barcode != null) setState(() => _barcode = barcode);
  }

  @override
  Widget build(BuildContext context) {
    final Barcode? barcode = _barcode;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_zxing')),
      body: Center(
        child: barcode == null
            ? const Text('Nothing scanned yet')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BarcodeView(
                    barcode.text,
                    writer: barcode.format.canWrite
                        ? BarcodeWriter(barcode.format)
                        : const BarcodeWriter(BarcodeFormat.qrCode),
                    width: 240,
                  ),
                  const SizedBox(height: 16),
                  Text('${barcode.format.displayName}: ${barcode.content}'),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scan,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan'),
      ),
    );
  }
}
```

For iOS, add `NSCameraUsageDescription` to `ios/Runner/Info.plist`; see
[Installation](https://github.com/khoren93/flutter_zxing/blob/4.0/README.md#installation).
