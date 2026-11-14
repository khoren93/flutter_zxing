// The engine on native platforms: one fzx context on a long-lived isolate.
//
// Input bytes are copied once, on the calling isolate, into native memory
// that the engine isolate reads in place; the calling isolate frees it when
// the reply arrives (or when the engine isolate dies). Results are parsed on
// the engine isolate, so the calling isolate only receives Dart objects.
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:ui' show Rect;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../errors.dart';
import '../reading/pixel_buffer.dart';
import 'engine.dart';
import 'engine_protocol.dart';
import 'fzx_bindings.dart';
import 'result_codec.dart';

/// Starts the engine isolate.
Future<EngineBackend> spawnBackend(String name) => NativeBackend.spawn(name);

/// The engine on a long-lived isolate of this isolate group.
final class NativeBackend implements EngineBackend {
  NativeBackend._(this._isolate, this._requests, this._replies) {
    _replies.handler = (Object? message) {
      final _Reply reply = message! as _Reply;
      _pending.remove(reply.id)?.complete(reply);
    };
  }

  /// Spawns the isolate and waits until its fzx context is ready.
  static Future<NativeBackend> spawn(String name) async {
    final RawReceivePort replies = RawReceivePort(null, '$name replies');
    final Completer<SendPort> ready = Completer<SendPort>();
    NativeBackend? backend;
    // The handshake, uncaught errors and the exit notification share one
    // port, so that a failure while loading the native library fails the
    // caller instead of leaving it waiting forever.
    final RawReceivePort control = RawReceivePort(null, '$name control');
    control.handler = (Object? message) {
      if (message is SendPort) {
        ready.complete(message);
        return;
      }
      final EngineException error = switch (message) {
        [final Object? error, _] => EngineException(
          'The barcode engine failed: $error',
        ),
        final String startupError => EngineException(startupError),
        _ => const EngineException('The barcode engine stopped'),
      };
      if (message is! List<Object?>) {
        control.close(); // exit: nothing more will arrive
      }
      if (!ready.isCompleted) {
        ready.completeError(error);
      } else {
        backend?._stopped(error);
      }
    };
    try {
      final Isolate isolate = await Isolate.spawn(
        _engineMain,
        (control.sendPort, replies.sendPort),
        debugName: name,
        onError: control.sendPort,
        onExit: control.sendPort,
      );
      backend = NativeBackend._(isolate, await ready.future, replies);
      return backend;
    } on Object {
      replies.close();
      control.close();
      rethrow;
    }
  }

  final Isolate _isolate;
  final SendPort _requests;
  final RawReceivePort _replies;
  final Map<int, Completer<_Reply>> _pending = <int, Completer<_Reply>>{};
  final Completer<void> _done = Completer<void>();
  int _nextId = 0;

  @override
  Future<void> get done => _done.future;

  void _stopped(EngineException error) {
    if (_done.isCompleted) {
      return;
    }
    _done.complete();
    _replies.close();
    final List<Completer<_Reply>> pending = _pending.values.toList();
    _pending.clear();
    for (final Completer<_Reply> c in pending) {
      c.completeError(error);
    }
  }

  /// Sends a request; [input] (native memory owned by this call) is freed
  /// once the engine isolate is done with it.
  Future<_Reply> _call(
    _Request Function(int id) request, [
    Pointer<Uint8>? input,
  ]) async {
    if (_done.isCompleted) {
      if (input != null) {
        malloc.free(input);
      }
      throw const EngineException('The barcode engine stopped');
    }
    final int id = _nextId++;
    final Completer<_Reply> completer = Completer<_Reply>();
    _pending[id] = completer;
    _requests.send(request(id));
    try {
      final _Reply reply = await completer.future;
      if (reply.code < 0) {
        throwFzxError(reply.code, reply.error);
      }
      return reply;
    } finally {
      if (input != null) {
        malloc.free(input);
      }
    }
  }

  static Pointer<Uint8> _copy(Uint8List bytes) {
    final Pointer<Uint8> p = malloc<Uint8>(bytes.isEmpty ? 1 : bytes.length);
    p.asTypedList(bytes.length).setAll(0, bytes);
    return p;
  }

  @override
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  ) async {
    final Pointer<Uint8> input = _copy(encodedImage);
    final _Reply reply = await _call(
      (int id) => _ReadImage(id, input.address, encodedImage.length, options),
      input,
    );
    return reply.read!;
  }

  @override
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options,
  ) async {
    final Pointer<Uint8> input = _copy(image.bytes);
    final Rect? crop = image.crop;
    final _Reply reply = await _call(
      (int id) => _ReadPixels(
        id,
        input.address,
        image.width,
        image.height,
        image.rowStride ?? 0,
        image.layout.index,
        crop == null
            ? null
            : <int>[
                crop.left.round(),
                crop.top.round(),
                crop.width.round(),
                crop.height.round(),
              ],
        options,
      ),
      input,
    );
    return reply.read!;
  }

  @override
  Future<EngineSymbol> write(
    Uint8List data, {
    required bool binary,
    required String format,
    required String options,
  }) async {
    final Pointer<Uint8> input = _copy(data);
    final _Reply reply = await _call(
      (int id) =>
          _Write(id, input.address, data.length, binary, format, options),
      input,
    );
    return reply.symbol!;
  }

  @override
  Future<String> version() async => (await _call(_Version.new)).text!;

  @override
  void dispose() {
    if (_done.isCompleted) {
      return;
    }
    // Lets the isolate free its context and exit after the current call.
    _requests.send(null);
    _stopped(const EngineException('The barcode engine was shut down'));
    // Safety net if the isolate is stuck in a long call: kill it once that
    // call returns to Dart.
    _isolate.kill();
  }
}

// --- messages -----------------------------------------------------------------

sealed class _Request {
  const _Request(this.id);
  final int id;
}

final class _ReadImage extends _Request {
  const _ReadImage(super.id, this.address, this.size, this.options);
  final int address;
  final int size;
  final EngineReadOptions options;
}

final class _ReadPixels extends _Request {
  const _ReadPixels(
    super.id,
    this.address,
    this.width,
    this.height,
    this.rowStride,
    this.layout,
    this.crop,
    this.options,
  );
  final int address;
  final int width;
  final int height;
  final int rowStride;
  final int layout;
  final List<int>? crop;
  final EngineReadOptions options;
}

final class _Write extends _Request {
  const _Write(
    super.id,
    this.address,
    this.size,
    this.binary,
    this.format,
    this.options,
  );
  final int address;
  final int size;
  final bool binary;
  final String format;
  final String options;
}

final class _Version extends _Request {
  const _Version(super.id);
}

final class _Reply {
  const _Reply(
    this.id, {
    this.code = 0,
    this.error = '',
    this.read,
    this.symbol,
    this.text,
  });
  final int id;
  final int code;
  final String error;
  final EngineReadResult? read;
  final EngineSymbol? symbol;
  final String? text;
}

// --- engine isolate ---------------------------------------------------------------

void _engineMain((SendPort, SendPort) ports) {
  final (SendPort control, SendPort replies) = ports;
  final int abi = fzxAbiVersion();
  if (abi != fzxExpectedAbiVersion) {
    control.send(
      'The barcode engine library has ABI version $abi, this version of '
      'flutter_zxing needs $fzxExpectedAbiVersion. Run `flutter clean`.',
    );
    return;
  }
  final Pointer<FzxContext> ctx = fzxNew();
  if (ctx == nullptr) {
    control.send('The barcode engine is out of memory');
    return;
  }
  final _Engine engine = _Engine(ctx);
  final RawReceivePort requests = RawReceivePort(null, 'requests');
  requests.handler = (Object? message) {
    if (message == null) {
      requests.close();
      engine.dispose();
      return;
    }
    replies.send(engine.handle(message as _Request));
  };
  control.send(requests.sendPort);
}

final class _Engine {
  _Engine(this._ctx);

  final Pointer<FzxContext> _ctx;
  final Stopwatch _stopwatch = Stopwatch();
  // Native copies of the format filters seen so far; a handful at most.
  final Map<String, Pointer<Char>> _formats = <String, Pointer<Char>>{};

  Pointer<Char> _formatsPointer(String formats) {
    if (_formats.length > 32) {
      _formats.values.forEach(malloc.free);
      _formats.clear();
    }
    return _formats[formats] ??= formats.toNativeUtf8().cast<Char>();
  }

  String _error() => fzxError(_ctx).cast<Utf8>().toDartString();

  Uint8List _result() => fzxResult(_ctx).asTypedList(fzxResultSize(_ctx));

  _Reply handle(_Request request) {
    _stopwatch
      ..reset()
      ..start();
    try {
      return switch (request) {
        final _ReadImage r => _read(
          r.id,
          fzxReadFile(
            _ctx,
            Pointer<Uint8>.fromAddress(r.address),
            r.size,
            _formatsPointer(r.options.formats),
            r.options.flags,
            r.options.binarizer,
            r.options.maxSymbols,
            r.options.minLineCount,
          ),
        ),
        final _ReadPixels r => _read(
          r.id,
          fzxRead(
            _ctx,
            Pointer<Uint8>.fromAddress(r.address),
            r.width,
            r.height,
            r.rowStride,
            r.layout,
            r.crop?[0] ?? 0,
            r.crop?[1] ?? 0,
            r.crop?[2] ?? 0,
            r.crop?[3] ?? 0,
            _formatsPointer(r.options.formats),
            r.options.flags,
            r.options.binarizer,
            r.options.maxSymbols,
            r.options.minLineCount,
          ),
        ),
        final _Write r => _write(r),
        final _Version r => _Reply(
          r.id,
          text: fzxVersion().cast<Utf8>().toDartString(),
        ),
      };
    } on Object catch (e) {
      return _Reply(request.id, code: FzxError.internal, error: '$e');
    }
  }

  _Reply _read(int id, int code) {
    if (code < 0) {
      return _Reply(id, code: code, error: _error());
    }
    final int micros = _stopwatch.elapsedMicroseconds;
    return _Reply(id, read: decodeBarcodes(_result()).withEngineMicros(micros));
  }

  _Reply _write(_Write r) {
    final Pointer<Utf8> format = r.format.toNativeUtf8();
    final Pointer<Utf8> options = r.options.toNativeUtf8();
    try {
      final int code = fzxWrite(
        _ctx,
        Pointer<Uint8>.fromAddress(r.address),
        r.size,
        r.binary ? 1 : 0,
        format.cast<Char>(),
        options.cast<Char>(),
      );
      if (code < 0) {
        return _Reply(r.id, code: code, error: _error());
      }
      return _Reply(r.id, symbol: decodeSymbol(_result()));
    } finally {
      malloc
        ..free(format)
        ..free(options);
    }
  }

  void dispose() {
    _formats.values.forEach(malloc.free);
    _formats.clear();
    fzxFree(_ctx);
  }
}
