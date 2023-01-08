import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  zx.setLogEnabled(!kDebugMode);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Zxing Example',
      home: DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({Key? key}) : super(key: key);

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  Uint8List? createdCodeBytes;

  Code? result;

  bool showDebugInfo = true;
  int successScans = 0;
  int failedScans = 0;

  @override
  Widget build(BuildContext context) {
    final isCameraSupported = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Zxing Example'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scan Code'),
              Tab(text: 'Create Code'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            if (kIsWeb)
              const UnsupportedPlatformWidget()
            else if (!isCameraSupported)
              const Center(
                child: Text('Camera not supported on this platform'),
              )
            else if (result != null)
              ScanResultWidget(
                result: result?.text,
                format: result?.format?.name,
                onScanAgain: () => setState(() => result = null),
              )
            else if (result != null)
              ScanResultWidget(
                result: result?.text,
                onScanAgain: () => setState(() => result = null),
              )
            else
              Stack(
                children: [
                  ReaderWidget(
                    onScan: _onScanSuccess,
                    onScanFailure: () => _onScanFailure(null),
                    tryInverted: true,
                  ),
                  ScanFromGalleryWidget(
                    onScan: _onScanSuccess,
                    onScanFailure: _onScanFailure,
                  ),
                  if (showDebugInfo)
                    DebugInfoWidget(
                      successScans: successScans,
                      failedScans: failedScans,
                      onReset: _onReset,
                    ),
                ],
              ),
            if (kIsWeb)
              const UnsupportedPlatformWidget()
            else
              ListView(
                children: [
                  WriterWidget(
                    messages: const Messages(
                      createButton: 'Create Code',
                    ),
                    onSuccess: (result, bytes) {
                      setState(() {
                        createdCodeBytes = bytes;
                      });
                    },
                    onError: (error) {
                      _showMessage(context, 'Error: $error');
                    },
                  ),
                  if (createdCodeBytes != null)
                    Image.memory(createdCodeBytes ?? Uint8List(0), height: 200),
                ],
              ),
          ],
        ),
      ),
    );
  }

  _onScanSuccess(value) {
    setState(() {
      successScans++;
      result = value;
    });
  }

  _onScanFailure(String? error) {
    setState(() {
      failedScans++;
    });
    if (error != null) {
      _showMessage(context, error);
    }
  }

  _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  _onReset() {
    setState(() {
      successScans = 0;
      failedScans = 0;
    });
  }
}

class ScanResultWidget extends StatelessWidget {
  const ScanResultWidget({
    Key? key,
    this.result,
    this.format,
    this.onScanAgain,
  }) : super(key: key);

  final String? result;
  final String? format;
  final Function()? onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              format ?? '',
              style: Theme.of(context).textTheme.headline5,
            ),
            const SizedBox(height: 20),
            Text(
              result ?? '',
              style: Theme.of(context).textTheme.headline6,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: onScanAgain,
              child: const Text('Scan Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class ScanFromGalleryWidget extends StatelessWidget {
  const ScanFromGalleryWidget({
    Key? key,
    this.onScan,
    this.onScanFailure,
  }) : super(key: key);

  final Function(Code?)? onScan;
  final Function(String)? onScanFailure;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: _onFromGalleryButtonTapped,
        child: const Icon(Icons.image),
      ),
    );
  }

  void _onFromGalleryButtonTapped() async {
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      final Code? result = await zx.readBarcodeImagePath(
        file,
        params: DecodeParams(tryInverted: true),
      );
      if (result != null && result.isValid) {
        onScan?.call(result);
      } else {
        onScanFailure?.call('Failed to read barcode from image');
      }
    }
  }
}

class DebugInfoWidget extends StatelessWidget {
  const DebugInfoWidget({
    Key? key,
    required this.successScans,
    required this.failedScans,
    this.onReset,
  }) : super(key: key);

  final int successScans;
  final int failedScans;

  final Function()? onReset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Colors.white.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Success: $successScans\nFailed: $failedScans',
                  style: Theme.of(context).textTheme.headline6,
                ),
                TextButton(
                  onPressed: onReset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UnsupportedPlatformWidget extends StatelessWidget {
  const UnsupportedPlatformWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'This platform is not supported yet.',
        style: Theme.of(context).textTheme.headline6,
      ),
    );
  }
}
