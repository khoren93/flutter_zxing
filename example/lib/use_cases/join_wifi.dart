// Wi‑Fi from a QR code: the network's name, its security and the password
// with a Copy button, for the code on a café table or a router. Joining the
// network from the app needs a platform plugin. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class JoinWifiPage extends StatelessWidget {
  const JoinWifiPage({super.key});

  // Other QR codes keep the scanner open.
  static final ScannerCheck _check = acceptOnly<WifiContent>(
    reject: const ScanVerdict.reject(title: 'Not a Wi‑Fi code'),
  );

  static Widget? _sheet(BuildContext context, ScannerResult result) {
    final BarcodeContent content = result.barcode.content;
    // Anything else, such as a code from a photo: the default sheet.
    if (content is! WifiContent) return null;
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerLocalizations texts = ScannerLocalizations.of(context);
    final String? password = content.password;
    return ScannerSheet(
      label: 'Wi‑Fi network',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('WI‑FI', style: theme.overlineStyle),
          const SizedBox(height: 4),
          Text(content.ssid, style: theme.titleStyle),
          Text(texts.wifiSecurityOf(content.security), style: theme.mutedStyle),
          if (content.hidden) Text('Hidden network', style: theme.mutedStyle),
          if (password != null && password.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Password', style: theme.labelStyle),
            SelectableText(password, style: theme.dataStyle),
          ],
          const SizedBox(height: 16),
          // Your code: join the network with a Wi‑Fi plugin; without one,
          // the user pastes the password in the system's Wi‑Fi settings.
          ScannerActions([
            if (password != null && password.isNotEmpty)
              ScannerAction.copy(
                password,
                label: 'Copy password',
                primary: true,
              ),
            ScannerAction.scanAgain(result.scanAgain),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.content(
        hint: 'Scan the Wi‑Fi code',
        check: _check,
        resultBuilder: _sheet,
      ),
    ),
  );
}
