// The scanner end to end in a browser whose camera is a video file
// (Chrome's --use-file-for-fake-video-capture), driven by
// tool/web_scanner_test.mjs. Prints the state and every outline, in widget
// coordinates, to the console:
//   FZX_SCANNER {"status": "running", ...}
//   FZX_OUTLINE {"text": "...", "bounds": [l, t, r, b], "size": [w, h]}
//
//   flutter build web -t lib/scanner_web.dart [--wasm]
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() => runApp(const _ScannerPage());

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  // ?facing=front mirrors the preview and the outlines, like a selfie camera.
  final ScannerController _controller = ScannerController(
    detection: DetectionMode.continuous,
    facing: Uri.base.queryParameters['facing'] == 'front'
        ? CameraFacing.front
        : CameraFacing.back,
  );
  String _lastState = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_logState);
  }

  void _logState() {
    final ScannerState s = _controller.value;
    final String line = jsonEncode(<String, Object?>{
      'status': s.status.name,
      'error': s.error?.toString(),
      'preview': s.previewSize == null
          ? null
          : <double>[s.previewSize!.width, s.previewSize!.height],
    });
    if (line != _lastState) {
      _lastState = line;
      // ignore: avoid_print
      print('FZX_SCANNER $line');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: BarcodeScanner(
      controller: _controller,
      overlayBuilder: (BuildContext context, ScannerLayout layout) {
        for (final VisibleBarcode b in layout.barcodes) {
          final Rect r = b.bounds;
          // ignore: avoid_print
          print(
            'FZX_OUTLINE ${jsonEncode(<String, Object>{
              'text': b.barcode.text,
              'bounds': <double>[r.left, r.top, r.right, r.bottom],
              'size': <double>[layout.size.width, layout.size.height],
              'window': <double>[layout.scanWindow.left, layout.scanWindow.top, layout.scanWindow.right, layout.scanWindow.bottom],
            })}',
          );
        }
        return ScannerOverlay(layout);
      },
    ),
  );
}
