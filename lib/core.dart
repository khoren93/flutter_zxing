/// The core of flutter_zxing: zxing-cpp for Flutter.
///
/// Reads barcodes from images and pixels ([BarcodeReader]) and creates them
/// ([BarcodeWriter] → [BarcodeSymbol], exported black on white as SVG, PNG
/// or a grayscale image), and lists of items for many codes at once
/// ([SerialItems], [BarcodeItems], [CheckDigit]). Nothing here interprets
/// the payload or draws UI: those are the layers on top, `content.dart`,
/// `rendering.dart` and `scanner.dart`. `flutter_zxing.dart` exports all
/// of them.
library;

export 'src/barcode/barcode.dart' hide barcodeWithMergeData, mergeDataOf;
export 'src/barcode/barcode_format.dart' hide BarcodeFormatInternal;
export 'src/barcode/barcode_input.dart';
export 'src/engine/barcode_engine.dart';
export 'src/errors.dart';
export 'src/reading/barcode_reader.dart';
export 'src/reading/pixel_buffer.dart';
export 'src/reading/reader_options.dart';
export 'src/writing/barcode_items.dart' hide checkWriterItems, itemProblem;
export 'src/writing/barcode_writer.dart';
export 'src/writing/check_digit.dart';
export 'src/writing/serial_items.dart';
