// My profile QR code: a styled QR code of a profile or referral link, on
// screen and shared as a PNG in the same style. Android, iOS, macOS, the
// web. Also needs share_plus.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

class ProfileQrPage extends StatelessWidget {
  const ProfileQrPage({super.key});

  // Your code: the signed-in user's link.
  static const String _link = 'https://example.com/u/anna';

  static const BarcodeStyle _style = BarcodeStyle(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
    ),
    moduleShape: ModuleShape.rounded,
    finderShape: FinderShape.rounded,
    caption: BarcodeCaption('@anna'),
    card: BarcodeCard(color: Colors.white, elevation: 6),
  );

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    // The same look as on screen, sharp at 1024 px.
    final png = await _style.encodePng(
      const BarcodeWriter(BarcodeFormat.qrCode),
      _link,
      size: 1024,
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: ['my-qr.png'],
        // Where the share sheet points from on iPad.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My QR code')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BarcodeView(_link, style: _style, width: 260),
          const SizedBox(height: 16),
          const Text('Scan to follow me'),
          const SizedBox(height: 24),
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: () => _share(context),
              icon: const Icon(Icons.ios_share),
              label: const Text('Share as an image'),
            ),
          ),
        ],
      ),
    ),
  );
}
