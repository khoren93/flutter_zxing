// Open a link safely: the sheet shows where a QR code leads before the
// browser opens it, and a link without https asks once more. Android, iOS,
// macOS, the web. Also needs url_launcher.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenLinkPage extends StatelessWidget {
  const OpenLinkPage({super.key});

  // The sheet already shows the link's domain; these are its buttons.
  static List<ScannerAction> _actions(
    BuildContext context,
    ScannerResult result,
  ) {
    final BarcodeContent content = result.barcode.content;
    final Uri? uri = content.uri;
    if (content is! UrlContent || uri == null) return result.defaultActions;
    final bool secure = uri.scheme == 'https';
    return [
      ScannerAction(
        label: secure ? 'Open' : 'Open (not secure)',
        icon: ScannerIcons.open,
        primary: true,
        onPressed: () => _open(context, uri, secure),
      ),
      ...result.defaultActions,
    ];
  }

  static Future<void> _open(BuildContext context, Uri uri, bool secure) async {
    if (!secure) {
      // http: what the user sends there can be read on the way.
      final bool? go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.lock_open_rounded),
          title: Text(uri.host),
          content: const Text(
            'This link is not secure (http). Do not enter passwords or card '
            'numbers there.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open anyway'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.content(actionsBuilder: _actions),
    ),
  );
}
