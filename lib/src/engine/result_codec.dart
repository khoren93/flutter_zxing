// Parses the flat result buffers of native/fzx.cpp (the layouts are
// described at the top of that file).
//
// One parser for every platform: on native platforms the buffer is a view of
// the engine's memory, on the web a buffer transferred from the worker.
// Everything returned is copied out of [buffer], so the buffer may be reused
// as soon as the call returns.
import 'dart:convert';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../barcode/barcode.dart';
import '../barcode/barcode_format.dart';
import '../writing/barcode_writer.dart';
import '../writing/creator_options.dart' show errorCorrectionOf;
import 'engine_protocol.dart';
import 'function_patterns.dart';

const int _kindBarcodes = 1;
const int _kindSymbol = 2;
const int _kindMerged = 3;

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
  final List<EngineBarcodeDetails> details = <EngineBarcodeDetails>[];
  final List<Barcode> barcodes = List<Barcode>.generate(count, (_) {
    final BarcodeFormat format = BarcodeFormatInternal.fromId(r.u32());
    final int contentType = r.u8();
    final int errorType = r.u8();
    final int flags = r.u8();
    r.u8(); // reserved
    final int rotation = r.i32();
    final BarcodePosition position = BarcodePosition(
      topLeft: r.point(),
      topRight: r.point(),
      bottomRight: r.point(),
      bottomLeft: r.point(),
    );
    final int lineCount = r.i32();
    final int sequenceIndex = r.i32();
    final int sequenceSize = r.i32();
    final String text = r.str();
    final Uint8List bytes = r.bytes();
    final String symbologyIdentifier = r.str();
    final String ecLevel = r.str();
    final String version = r.str();
    final String sequenceId = r.str();
    final String errorMessage = r.str();
    details.add(EngineBarcodeDetails(lineCount: lineCount, extra: r.str()));
    final int symbolWidth = r.i32();
    final int symbolHeight = r.i32();
    final Uint8List modules = r.bytes();
    final Uint8List mergeData = r.bytes();
    final Barcode barcode = Barcode(
      format: format,
      text: text,
      bytes: bytes,
      position: position,
      contentType: contentType < BarcodeContentType.values.length
          ? BarcodeContentType.values[contentType]
          : BarcodeContentType.binary,
      rotation: rotation,
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
      symbol: symbolWidth > 0 && symbolHeight > 0
          ? BarcodeSymbol(
              format: format,
              width: symbolWidth,
              height: symbolHeight,
              modules: withQrFunctionPatterns(
                format,
                symbolWidth,
                symbolHeight,
                modules,
                mirrored: flags & 4 != 0,
              ),
              quietZone: readQuietZone(format),
              errorCorrection: errorCorrectionOf(format, ecLevel),
            )
          : null,
    );
    // What BarcodeReader.merge hands back to the engine: the content with
    // the encoding of each segment.
    return barcodeWithMergeData(barcode, mergeData);
  });
  return EngineReadResult(
    barcodes: barcodes,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    details: details,
  );
}

/// Parses a "merged" buffer (`fzx_merge`).
EngineMerged decodeMerged(Uint8List buffer) {
  final _Reader r = _Reader(buffer, _kindMerged);
  final int contentType = r.u8();
  return EngineMerged(
    contentType: contentType < BarcodeContentType.values.length
        ? BarcodeContentType.values[contentType]
        : BarcodeContentType.binary,
    text: r.str(),
    bytes: r.bytes(),
  );
}

/// The input of `fzx_merge` for [parts] in sequence order, or `null` if a
/// part did not come from the engine.
Uint8List? mergeInput(List<Barcode> parts) {
  final BytesBuilder out = BytesBuilder(copy: false);
  for (final Barcode part in parts) {
    final Uint8List? data = mergeDataOf(part);
    if (data == null || data.isEmpty) {
      return null;
    }
    out
      ..add(
        (ByteData(
          4,
        )..setUint32(0, data.length, Endian.little)).buffer.asUint8List(),
      )
      ..add(data);
  }
  return out.takeBytes();
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
}

/// The quiet zone a read symbol of [format] needs around it, in modules:
/// what each symbology's specification asks for.
int readQuietZone(BarcodeFormat format) => switch (format.symbology) {
  BarcodeFormat.qrCode =>
    format == BarcodeFormat.microQrCode || format == BarcodeFormat.rmqrCode
        ? 2
        : 4,
  BarcodeFormat.pdf417 => format == BarcodeFormat.microPdf417 ? 1 : 2,
  BarcodeFormat.dataMatrix || BarcodeFormat.maxiCode => 1,
  _ => 0,
};
