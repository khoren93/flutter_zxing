// Open a link safely: the sheet shows where a QR code leads before the
// browser opens it, and warns about a link without https. Android, iOS,
// macOS, the web. Also needs url_launcher.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenLinkPage extends StatelessWidget {
  const OpenLinkPage({super.key});

  // A link without https gets a warning on the sheet, under its domain.
  static ScanVerdict? _check(Barcode barcode) => switch (barcode.content) {
    UrlContent(:final url) when url.scheme == 'http' => const ScanVerdict.warn(
      title: 'Not secure',
      message:
          'What you send there can be read on the way: '
          'no passwords or card numbers.',
    ),
    _ => null,
  };

  static List<ScannerAction> _actions(
    BuildContext context,
    ScannerResult result,
  ) => [
    if (result.barcode.content case UrlContent(:final url))
      ScannerAction(
        label: result.verdict?.kind == ScanVerdictKind.warn
            ? 'Open anyway'
            : 'Open',
        icon: ScannerIcons.open,
        primary: true,
        onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
      ),
    ...result.defaultActions,
  ];

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.content(
        check: _check,
        actionsBuilder: _actions,
      ),
    ),
  );
}
