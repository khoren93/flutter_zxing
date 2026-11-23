// A loyalty card at the till: scan the customer's card, look the number up
// and attach the customer and their points to the sale. Any card's barcode
// works: a card you do not know is enrolled. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class LoyaltyCardPage extends StatefulWidget {
  const LoyaltyCardPage({super.key});

  @override
  State<LoyaltyCardPage> createState() => _LoyaltyCardPageState();
}

typedef _Customer = ({String name, int points});

class _LoyaltyCardPageState extends State<LoyaltyCardPage> {
  // Your code: look the card number up in your loyalty system.
  final Map<String, _Customer> _members = {
    '4006123456789012': (name: 'Anna Petrova', points: 1240),
    '4006987654321098': (name: 'Lucas Martin', points: 85),
  };
  _Customer? _customer;

  Future<void> _scan() async {
    final _Customer? customer = await Navigator.of(context).push(
      MaterialPageRoute<_Customer>(
        builder: (context) => Scaffold(
          body: BarcodeScanner(
            template: ScannerTemplate.loyalty(
              title: 'Loyalty card',
              // The sheet shows the card number large, and under it the
              // customer the check found.
              check: (barcode) {
                final _Customer? member = _members[barcode.text];
                return member == null
                    ? const ScanVerdict.warn(
                        title: 'Unknown card',
                        message: 'It will be enrolled',
                        data: (name: 'New member', points: 0),
                      )
                    : ScanVerdict.accept(
                        title: member.name,
                        message: '${member.points} points',
                        data: member,
                      );
              },
              actionsBuilder: (context, result) => [
                ScannerAction(
                  label: 'Attach to the sale',
                  primary: true,
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(result.verdict?.data as _Customer?),
                ),
                ...result.defaultActions,
              ],
            ),
          ),
        ),
      ),
    );
    if (customer == null || !mounted) return; // closed
    setState(() => _customer = customer);
  }

  @override
  Widget build(BuildContext context) {
    final _Customer? customer = _customer;
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Till 1')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (customer != null) ...[
              Text(customer.name, style: text.headlineSmall),
              const SizedBox(height: 8),
              Text('${customer.points} points', style: text.titleMedium),
              const SizedBox(height: 24),
            ],
            FilledButton.icon(
              onPressed: _scan,
              icon: const Icon(Icons.card_membership),
              label: Text(
                customer == null ? 'Scan loyalty card' : 'Scan another',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
