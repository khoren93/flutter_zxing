import 'dart:typed_data';

import '../writing/barcode_writer.dart';
import 'barcode_content.dart';

/// `writer.encodeContent(content)`: encodes a [BarcodeContent] the way its
/// kind needs. Lives in the content layer, so the core writer does not
/// depend on it.
extension BarcodeWriterContent on BarcodeWriter {
  /// Encodes [content]: [BinaryContent] as bytes, [Gs1Content] as GS1
  /// (whatever [BarcodeWriter.gs1] says), everything else as the text of
  /// [BarcodeContent.toPayload].
  ///
  /// ```dart
  /// const Gs1Content gs1 = Gs1Content(<String, String>{
  ///   '01': '09501101530003',
  ///   '17': '270101',
  /// });
  /// final BarcodeSymbol symbol =
  ///     await const BarcodeWriter(BarcodeFormat.dataMatrix).encodeContent(gs1);
  /// ```
  ///
  /// Throws an [ArgumentError] if [BarcodeContent.validate] finds a
  /// problem, and a `BarcodeWriteException` if the format cannot hold the
  /// payload.
  Future<BarcodeSymbol> encodeContent(BarcodeContent content) =>
      switch (content) {
        BinaryContent(:final Uint8List bytes) => () {
          final List<ContentIssue> issues = content.validate();
          if (issues.isNotEmpty) {
            throw ArgumentError(issues.join('; '));
          }
          return encodeBytes(bytes);
        }(),
        Gs1Content() => (gs1 ? this : copyWith(gs1: true)).encode(
          content.toPayload(),
        ),
        _ => encode(content.toPayload()),
      };
}
