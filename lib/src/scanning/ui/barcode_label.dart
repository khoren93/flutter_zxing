import '../../barcode/barcode.dart';
import '../../content/barcode_content.dart';

/// The text to show for [barcode] outside its result sheet. A one-time
/// password's code holds its secret, so it shows who the password is for.
String barcodeLabel(Barcode barcode) => switch (barcode.content) {
  OtpContent(:final String? issuer, :final String account) => issuer ?? account,
  _ => barcode.text,
};
