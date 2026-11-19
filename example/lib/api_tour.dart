// The flutter_zxing 4 API in eight scenarios. Compiled with the example so
// the documented usage cannot drift from the real signatures.
// ignore_for_file: avoid_print, unused_element

import 'dart:typed_data';

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; this package still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

// 1. A scanner out of the box: camera, overlay, scan window, outlines.
Widget scannerOutOfTheBox() =>
    BarcodeScanner(onDetect: (capture) => print(capture.barcode.text));

// 1b. A whole scanner screen from a template, in your brand's colors.
Widget scannerScreen() => BarcodeScanner(
  template: const ScannerTemplate.minimal(),
  theme: const ScannerTheme(
    accent: Color(0xFFFF6A1A),
    windowRadius: 6,
    buttonShape: ScannerButtonShape.roundedSquare,
  ),
  onDetect: (capture) => print(capture.barcode.content),
);

// 2. Scan one code and come back.
Future<void> scanOnce(BuildContext context) async {
  final Barcode? barcode = await scanBarcode(
    context,
    formats: {BarcodeFormat.qrCode},
    hint: 'Point the camera at a QR code',
  );
  if (barcode != null) print(barcode.text);
}

// 3. Your own UI and programmatic control.
class CustomScannerPage extends StatefulWidget {
  const CustomScannerPage({super.key});

  @override
  State<CustomScannerPage> createState() => _CustomScannerPageState();
}

class _CustomScannerPageState extends State<CustomScannerPage> {
  final ScannerController controller = ScannerController(
    formats: {BarcodeFormat.qrCode, BarcodeFormat.ean13},
    scanWindow: const ScanWindow.centered(width: 0.8, aspectRatio: 1.6),
  );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BarcodeScanner(
      controller: controller,
      theme: const ScannerTheme(accent: Colors.amber),
      onDetect: (capture) async {
        await controller.pause();
        if (!context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          builder: (_) => ListTile(title: Text(capture.barcode.text)),
        );
        await controller.resume();
      },
      overlayBuilder: (context, layout) => Stack(
        children: [
          ScannerOverlay(layout),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TorchButton(controller),
                  const SizedBox(width: 16),
                  SwitchCameraButton(controller),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// 4. A photo, a file, the clipboard.
Future<void> readFile(Uint8List bytes) async {
  const reader = BarcodeReader();
  final Barcode? first = await reader.read(bytes); // fast: stops at the first
  final List<Barcode> all = await reader.readAll(bytes);
  print('${first?.text}, ${all.length} in total');

  const qrOnly = BarcodeReader(formats: {BarcodeFormat.qrCode});
  print(await qrOnly.read(bytes));
}

// 5. Your own frames (video, network, another camera plugin).
Future<void> readFrame(
  Uint8List yPlane,
  int width,
  int height,
  int stride,
) async {
  const reader = BarcodeReader(options: ReaderOptions.camera());
  final Barcode? barcode = await reader.readPixels(
    PixelBuffer(yPlane, width: width, height: height, rowStride: stride),
  );
  print(barcode?.position.bounds);
}

// 6. Generation.
Future<void> generate() async {
  const writer = BarcodeWriter(
    BarcodeFormat.qrCode,
    errorCorrection: ErrorCorrection.high,
  );
  final String svg = await writer.toSvg(
    'https://pub.dev/packages/flutter_zxing',
  );
  final BarcodeImage image = await writer.toImage('https://pub.dev', size: 512);
  final Uint8List png = await image.toPng();
  print('${svg.length} ${png.length}');

  // Export with a style: the same picture as BarcodeView shows.
  const style = BarcodeStyle(
    color: Color(0xFF1B4DFF),
    moduleShape: ModuleShape.rounded,
    finderShape: FinderShape.rounded,
  );
  final Uint8List styledPng = await style.encodePng(
    writer,
    'https://pub.dev',
    size: 1024,
  );
  final String styledSvg = await style.encodeSvg(writer, 'https://pub.dev');
  print('${styledPng.length} ${styledSvg.length}');

  // Binary data: encode once, render as needed.
  final BarcodeSymbol symbol = await const BarcodeWriter(
    BarcodeFormat.dataMatrix,
  ).encodeBytes(Uint8List.fromList([0x00, 0x01, 0xFE, 0xFF]));
  final String binarySvg = symbol.toSvg();
  final BarcodeImage binaryImage = await symbol.toImage(moduleSize: 8);
  print(
    '${symbol.width}x${symbol.height} ${binarySvg.length} ${binaryImage.width}',
  );

  try {
    await const BarcodeWriter(BarcodeFormat.ean13).toSvg('not digits');
  } on BarcodeWriteException catch (e) {
    print(e.message);
  }
}

// 7. A barcode widget (vector, sharp at any DPI).
Widget barcodeWidgets() => Column(
  children: [
    const BarcodeView('https://pub.dev', width: 200),
    const BarcodeView(
      '4006381333931',
      writer: BarcodeWriter(BarcodeFormat.ean13),
      width: 240,
    ),
    BarcodeView.bytes(
      Uint8List.fromList([0xCA, 0xFE]),
      writer: BarcodeWriter(BarcodeFormat.dataMatrix),
      width: 120,
    ),
    BarcodeView(
      'https://flutter.dev',
      width: 200,
      style: const BarcodeStyle(
        moduleShape: ModuleShape.rounded,
        finderShape: FinderShape.rounded,
        logo: BarcodeLogo(AssetImage('assets/logo.png')),
      ),
    ),
  ],
);

// 8. What is in the barcode.
void handle(Barcode barcode) {
  switch (barcode.content) {
    case UrlContent(:final url):
      print('open $url');
    case WifiContent(:final ssid, :final password):
      print('join $ssid with $password');
    case ContactContent contact:
      print('save ${contact.name}');
    case Gs1Content(:final gtin):
      print('product $gtin');
    default:
      print(barcode.text);
  }
}

// Optional: start the engine early so the first scan is instant.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await warmUpBarcodeEngine();
  print('zxing-cpp $zxingCppVersion');
}
