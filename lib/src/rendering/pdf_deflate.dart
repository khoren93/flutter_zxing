// Compresses the streams of a label sheet PDF where dart:io has zlib; this
// stub (the web) leaves them uncompressed. Not exported from the package.
import 'dart:typed_data';

/// [data] compressed with zlib (PDF `FlateDecode`), or `null` where zlib
/// is not available.
Uint8List? deflate(Uint8List data) => null;
