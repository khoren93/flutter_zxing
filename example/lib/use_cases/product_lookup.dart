// Look up a product: the EAN, UPC or ISBN barcode of a product or a book
// in your catalogue, found or not. The check asks your server and keeps
// what it found for the sheet. To try it, scan 5901234123457 or the ISBN
// 9780306406157 (or any EAN). Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

typedef _Product = ({String name, String price});

class ProductLookupPage extends StatelessWidget {
  const ProductLookupPage({super.key});

  // Your code: ask your server. Products are listed by GTIN-14 (14 digits,
  // zeros in front), as product databases list them.
  static Future<_Product?> _find(String gtin) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const <String, _Product>{
      '05901234123457': (name: 'Sparkling water 0.5 l', price: '€0.89'),
      '04006381333931': (name: 'Highlighter, yellow', price: '€1.49'),
      '09780306406157': (name: 'Introduction to Physics', price: '€24.90'),
    }[gtin];
  }

  // Runs before the sheet: it may wait for the server. The sheet shows the
  // verdict's title and message; its data goes to the buttons.
  static Future<ScanVerdict?> _check(Barcode barcode) async {
    final BarcodeContent content = barcode.content;
    if (content is! ProductContent) return null;
    final _Product? product = await _find(content.gtin);
    if (product == null) {
      return const ScanVerdict.warn(title: 'Not in the catalogue');
    }
    return ScanVerdict.accept(
      title: product.name,
      message: product.price,
      data: product,
    );
  }

  static List<ScannerAction> _actions(
    BuildContext context,
    ScannerResult result,
  ) => [
    if (result.verdict?.data case final _Product product)
      ScannerAction(
        label: 'Add to cart',
        primary: true,
        onPressed: () {
          // Your code: add the product to the cart.
          debugPrint('Added ${product.name}');
          result.scanAgain();
        },
      ),
    ...result.defaultActions,
  ];

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: BarcodeScanner(
      template: ScannerTemplate.product(
        check: _check,
        actionsBuilder: _actions,
      ),
    ),
  );
}
