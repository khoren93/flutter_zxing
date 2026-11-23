// zlib from dart:io for the streams of a label sheet PDF (Android, iOS,
// macOS, Windows, Linux). Not exported from the package.
import 'dart:io';
import 'dart:typed_data';

/// [data] compressed with zlib (PDF `FlateDecode`).
Uint8List? deflate(Uint8List data) {
  final List<int> out = ZLibCodec().encode(data);
  return out is Uint8List ? out : Uint8List.fromList(out);
}
