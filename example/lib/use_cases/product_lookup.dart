// Look up a product: the EAN, UPC or ISBN barcode of a product or a book
// into your catalogue, found or not. To try it, scan 5901234123457 or the
// ISBN 9780306406157 (or any EAN). Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class ProductLookupPage extends StatelessWidget {
  const ProductLookupPage({super.key});

  // Your code: your catalogue, by GTIN-14 (14 digits, zeros in front), as
  // product databases list them. An app asks its server here.
  static const Map<String, (String, String)> _catalogue = {
    '05901234123457': ('Sparkling water 0.5 l', '€0.89'),
    '04006381333931': ('Highlighter, yellow', '€1.49'),
    '09780306406157': ('Introduction to Physics', '€24.90'),
  };

  static Widget _sheet(BuildContext context, ScannerResult result) {
    final BarcodeContent content = result.barcode.content;
    if (content is! ProductContent) {
      return BarcodeResultSheet(result.barcode, onScanAgain: result.scanAgain);
    }
    final ScannerTheme theme = ScannerTheme.of(context);
    final (String, String)? product = _catalogue[content.gtin];
    // A book shows its ISBN, anything else the number under the barcode.
    final String number = content.isbn13 == null
        ? content.number
        : 'ISBN ${content.isbn13}';
    return ScannerSheet(
      label: product?.$1 ?? 'Not in the catalogue',
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(number, style: theme.overlineStyle),
          const SizedBox(height: 4),
          if (product case (final String name, final String price)) ...[
            Text(name, style: theme.titleStyle),
            const SizedBox(height: 8),
            Text(price, style: theme.displayStyle),
          ] else ...[
            Text('Not in the catalogue', style: theme.titleStyle),
            const SizedBox(height: 8),
            const ScannerChip('Not found', tone: ScannerTone.warning),
          ],
          const SizedBox(height: 16),
          ScannerActions([
            if (product != null)
              ScannerAction(
                label: 'Add to cart',
                primary: true,
                onPressed: () {
                  // Your code: add the product to the cart.
                  result.scanAgain();
                },
              ),
            ScannerAction(
              label: 'Scan again',
              primary: product == null,
              onPressed: result.scanAgain,
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.product(resultBuilder: _sheet),
    ),
  );
}
