// A business card: a vCard QR code that any phone camera offers to save as
// a contact, for a conference badge, an e-mail signature or the "share my
// contact" screen of an app. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class BusinessCardPage extends StatelessWidget {
  const BusinessCardPage({super.key});

  // Your code: the user's profile.
  static final ContactContent _contact = ContactContent(
    name: 'Anna Petrova',
    organization: 'Lumen Labs',
    title: 'Product designer',
    phones: const ['+374 91 234567'],
    emails: const ['anna@lumenlabs.example'],
    urls: [Uri.parse('https://lumenlabs.example')],
  );

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Business card')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_contact.name!, style: text.headlineSmall),
                  Text(
                    '${_contact.title}, ${_contact.organization}',
                    style: text.bodyMedium?.copyWith(color: colors.primary),
                  ),
                  const SizedBox(height: 16),
                  // A vCard 3.0; `toPayload(format: ContactFormat.meCard)`
                  // makes a smaller code with fewer fields.
                  BarcodeView(
                    _contact.toPayload(),
                    style: BarcodeStyle.soft,
                    width: 220,
                  ),
                  const SizedBox(height: 8),
                  Text('Scan to save my contact', style: text.bodySmall),
                  const SizedBox(height: 16),
                  for (final String line in [
                    ..._contact.phones,
                    ..._contact.emails,
                    for (final Uri url in _contact.urls) url.host,
                  ])
                    Text(line),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
