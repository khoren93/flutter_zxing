// dart:ffi bindings to native/fzx.h, resolved through the native asset
// `package:flutter_zxing/fzx` that hook/build.dart builds. Written by hand:
// the C API is small and stable, ffigen would add more than it saves.
//
// Never `isLeaf: true` on a call that can take long (fzx_read*, fzx_write).
// Isolates of one group share a heap; a leaf call cannot reach a GC
// safepoint, so the UI isolate would wait for the decode at its next GC
// (measured: a 144 ms freeze on a 12 MP photo).
@DefaultAsset('package:flutter_zxing/fzx')
library;

import 'dart:ffi';

/// An fzx context (`fzx_ctx*`).
final class FzxContext extends Opaque {}

@Native<Int Function()>(symbol: 'fzx_abi_version', isLeaf: true)
external int fzxAbiVersion();

@Native<Pointer<Char> Function()>(symbol: 'fzx_version', isLeaf: true)
external Pointer<Char> fzxVersion();

@Native<Int Function()>(symbol: 'fzx_has_writer', isLeaf: true)
external int fzxHasWriter();

@Native<Pointer<FzxContext> Function()>(symbol: 'fzx_new')
external Pointer<FzxContext> fzxNew();

@Native<Void Function(Pointer<FzxContext>)>(symbol: 'fzx_free')
external void fzxFree(Pointer<FzxContext> ctx);

@Native<Pointer<Uint8> Function(Pointer<FzxContext>, Int)>(symbol: 'fzx_input')
external Pointer<Uint8> fzxInput(Pointer<FzxContext> ctx, int size);

@Native<
  Int Function(
    Pointer<FzxContext>,
    Pointer<Uint8>,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    Int,
    Pointer<Char>,
    Uint32,
    Int,
    Int,
    Int,
  )
>(symbol: 'fzx_read')
external int fzxRead(
  Pointer<FzxContext> ctx,
  Pointer<Uint8> data,
  int width,
  int height,
  int rowStride,
  int pixelLayout,
  int cropLeft,
  int cropTop,
  int cropWidth,
  int cropHeight,
  Pointer<Char> formats,
  int flags,
  int binarizer,
  int maxSymbols,
  int minLineCount,
);

@Native<
  Int Function(
    Pointer<FzxContext>,
    Pointer<Uint8>,
    Int,
    Pointer<Char>,
    Uint32,
    Int,
    Int,
    Int,
  )
>(symbol: 'fzx_read_file')
external int fzxReadFile(
  Pointer<FzxContext> ctx,
  Pointer<Uint8> data,
  int size,
  Pointer<Char> formats,
  int flags,
  int binarizer,
  int maxSymbols,
  int minLineCount,
);

@Native<
  Int Function(
    Pointer<FzxContext>,
    Pointer<Uint8>,
    Int,
    Int,
    Pointer<Char>,
    Pointer<Char>,
  )
>(symbol: 'fzx_write')
external int fzxWrite(
  Pointer<FzxContext> ctx,
  Pointer<Uint8> data,
  int size,
  int binary,
  Pointer<Char> format,
  Pointer<Char> options,
);

@Native<Pointer<Uint8> Function(Pointer<FzxContext>)>(
  symbol: 'fzx_result',
  isLeaf: true,
)
external Pointer<Uint8> fzxResult(Pointer<FzxContext> ctx);

@Native<Int Function(Pointer<FzxContext>)>(
  symbol: 'fzx_result_size',
  isLeaf: true,
)
external int fzxResultSize(Pointer<FzxContext> ctx);

@Native<Pointer<Char> Function(Pointer<FzxContext>)>(
  symbol: 'fzx_error',
  isLeaf: true,
)
external Pointer<Char> fzxError(Pointer<FzxContext> ctx);
