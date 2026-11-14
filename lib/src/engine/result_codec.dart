// Parses the flat result buffers of native/fzx.cpp (the layouts are
// described at the top of that file).
//
// One parser for every platform: on native platforms the buffer is a view of
// the engine's memory, on the web a buffer transferred from the worker.
// Everything returned is copied out of [buffer], so the buffer may be reused
// as soon as the call returns.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import 'engine_protocol.dart';

const int _kindBarcodes = 1;
const int _kindSymbol = 2;

/// Parses a "barcodes" buffer (`fzx_read`, `fzx_read_file`).
///
/// When only a part of an image was decoded, [offset] is where that part
/// starts and [imageSize] the size of the whole image: positions are moved
/// into the whole image and the result reports its size. [mirrorWidth] is
/// the width of a part that was flipped left to right before decoding:
/// positions are flipped back first.
EngineReadResult decodeBarcodes(
  Uint8List buffer, {
  Offset offset = Offset.zero,
  Size? imageSize,
  double? mirrorWidth,
}) {
  final _Reader r = _Reader(buffer, _kindBarcodes, offset, mirrorWidth);
  final int decodedWidth = r.i32();
  final int decodedHeight = r.i32();
  final int imageWidth = imageSize?.width.round() ?? decodedWidth;
  final int imageHeight = imageSize?.height.round() ?? decodedHeight;
  final int count = r.i32();
  final List<Barcode> barcodes = List<Barcode>.generate(count, (_) {
    final BarcodeFormat format = BarcodeFormatInternal.fromId(r.u32());
    final int contentType = r.u8();
    final int errorType = r.u8();
    final int flags = r.u8();
    r.u8(); // reserved
    final int orientation = r.i32();
    final BarcodePosition position = BarcodePosition(
      topLeft: r.point(),
      topRight: r.point(),
      bottomRight: r.point(),
      bottomLeft: r.point(),
    );
    r.i32(); // line count: not part of the public API
    final int sequenceIndex = r.i32();
    final int sequenceSize = r.i32();
    final String text = r.str();
    final Uint8List bytes = r.bytes();
    final String symbologyIdentifier = r.str();
    final String ecLevel = r.str();
    final String version = r.str();
    final String sequenceId = r.str();
    final String errorMessage = r.str();
    r.skipBlob(); // extra (JSON): not part of the public API yet
    return Barcode(
      format: format,
      text: text,
      bytes: bytes,
      position: position,
      contentType: contentType < BarcodeContentType.values.length
          ? BarcodeContentType.values[contentType]
          : BarcodeContentType.binary,
      orientation: orientation,
      isInverted: flags & 2 != 0,
      isMirrored: flags & 4 != 0,
      ecLevel: ecLevel.isEmpty ? null : ecLevel,
      version: version.isEmpty ? null : version,
      symbologyIdentifier: symbologyIdentifier,
      sequence: sequenceSize > -1 && sequenceIndex > -1
          ? BarcodeSequence(
              index: sequenceIndex,
              size: sequenceSize,
              id: sequenceId,
            )
          : null,
      error: errorType == 0
          ? null
          : BarcodeError(
              errorType <= BarcodeErrorKind.values.length
                  ? BarcodeErrorKind.values[errorType - 1]
                  : BarcodeErrorKind.unsupported,
              errorMessage,
            ),
    );
  });
  return EngineReadResult(
    barcodes: barcodes,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
}

/// Parses a "symbol" buffer (`fzx_write`).
EngineSymbol decodeSymbol(Uint8List buffer) {
  final _Reader r = _Reader(buffer, _kindSymbol);
  final BarcodeFormat format = BarcodeFormatInternal.fromId(r.u32());
  final int width = r.i32();
  final int height = r.i32();
  final int left = r.i32();
  final int top = r.i32();
  final int right = r.i32();
  final int bottom = r.i32();
  final String text = r.str();
  final String ecLevel = r.str();
  final String version = r.str();
  final Uint8List modules = r.bytes();
  if (modules.length != width * height) {
    throw StateError(
      'Corrupt symbol: ${modules.length} modules for $width x $height',
    );
  }
  return EngineSymbol(
    format: format,
    width: width,
    height: height,
    modules: modules,
    quietZoneLeft: left,
    quietZoneTop: top,
    quietZoneRight: right,
    quietZoneBottom: bottom,
    text: text,
    ecLevel: ecLevel,
    version: version,
  );
}

class _Reader {
  _Reader(
    this._buffer,
    int kind, [
    this._shift = Offset.zero,
    this._mirrorWidth,
  ]) : _data = ByteData.sublistView(_buffer) {
    final int abi = u32();
    if (abi != fzxExpectedAbiVersion) {
      throw StateError(
        'Engine result of ABI version $abi, expected $fzxExpectedAbiVersion',
      );
    }
    final int actual = u32();
    if (actual != kind) {
      throw StateError('Engine result of kind $actual, expected $kind');
    }
  }

  final Uint8List _buffer;
  final ByteData _data;
  // Added to every position: where the decoded part starts in the image.
  final Offset _shift;
  // Width of a decoded part that was mirrored, to flip positions back.
  final double? _mirrorWidth;
  int _offset = 0;

  int u8() => _data.getUint8(_offset++);

  int u32() {
    final int v = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  int i32() {
    final int v = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  /// A position, flipped back if the decoded part was mirrored and moved by
  /// its offset.
  Offset point() {
    final double x = i32().toDouble();
    final double y = i32().toDouble();
    final double? w = _mirrorWidth;
    return Offset(w == null ? x : w - x, y) + _shift;
  }

  Uint8List _view() {
    final int n = u32();
    final Uint8List v = Uint8List.sublistView(_buffer, _offset, _offset + n);
    _offset += n;
    return v;
  }

  /// A copy, detached from the engine's memory.
  Uint8List bytes() => Uint8List.fromList(_view());

  String str() => utf8.decode(_view(), allowMalformed: true);

  void skipBlob() {
    // Not `_offset += u32()`: that reads _offset before u32() advances it.
    final int n = u32();
    _offset += n;
  }
}
