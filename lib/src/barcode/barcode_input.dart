/// @docImport 'barcode_format.dart';
library;

/// What `BarcodeWriter` accepts for a format ([BarcodeFormat.input]): a
/// [description] for a form field, an [example] that encodes, and the kind
/// of keyboard.
///
/// It guides the input; the writer checks it and throws a
/// `BarcodeWriteException` that says what is wrong.
///
/// ```dart
/// final BarcodeInput input = BarcodeFormat.ean13.input!;
/// print(input.description); // 12 digits, or 13 with the check digit
/// print(input.example); // 9501101530003
/// ```
final class BarcodeInput {
  /// Describes the input of a format.
  const BarcodeInput(
    this.description,
    this.example, {
    this.digits = false,
    this.anyText = false,
  });

  /// The data the format holds, in a few words: `12 digits, or 13 with the
  /// check digit`. English, for a helper text or a tooltip.
  final String description;

  /// Data the format encodes, e.g. `9501101530003` for EAN-13.
  final String example;

  /// Only digits: show a numeric keyboard.
  final bool digits;

  /// Holds any text, long enough for a link, Wi-Fi credentials or a contact
  /// card (QR Code, Data Matrix, Aztec, PDF417). Otherwise the format takes
  /// a short or restricted value, as [description] says.
  final bool anyText;

  @override
  String toString() => 'BarcodeInput($description, e.g. $example)';
}
