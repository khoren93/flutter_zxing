// The engine on the web: fzx compiled to WebAssembly, running in a module
// Web Worker (assets/web/fzx_worker.js). Input buffers are transferred to the
// worker, results come back as the raw fzx result buffer.
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show Rect;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import '../errors.dart';
import '../reading/pixel_buffer.dart';
import 'engine.dart';
import 'engine_protocol.dart';
import 'result_codec.dart';

/// Starts the engine worker.
Future<EngineBackend> spawnBackend(String name) => WebBackend.spawn(name);

/// URL of a file in this package's `assets/web/`.
String engineAssetUrl(String file) =>
    ui_web.assetManager.getAssetUrl('packages/flutter_zxing/assets/web/$file');

extension type _Message._(JSObject _) implements JSObject {
  external String? get type;
  external int? get id;
  external int? get code;
  external String? get error;
  external JSArrayBuffer? get buffer;
  external double? get ms;
  external int? get abi;
  external String? get version;
}

/// The engine in a Web Worker.
final class WebBackend implements EngineBackend {
  WebBackend._(this._worker);

  /// Starts the worker and waits until its WebAssembly module is ready.
  static Future<WebBackend> spawn(String name) async {
    final web.Worker worker = web.Worker(
      engineAssetUrl('fzx_worker.js').toJS,
      web.WorkerOptions(type: 'module', name: name),
    );
    final WebBackend backend = WebBackend._(worker);
    worker
      ..onmessage = backend._handleMessage.toJS
      ..onerror = backend._handleError.toJS;
    try {
      await backend._ready.future;
    } on Object {
      worker.terminate();
      rethrow;
    }
    return backend;
  }

  final web.Worker _worker;
  final Completer<String> _ready = Completer<String>();
  final Map<int, Completer<_Message>> _pending = <int, Completer<_Message>>{};
  final Completer<void> _done = Completer<void>();
  int _nextId = 0;
  String? _version;

  void _handleMessage(web.MessageEvent event) {
    final _Message message = event.data! as _Message;
    switch (message.type) {
      case 'ready':
        final int abi = message.abi ?? -1;
        if (abi != fzxExpectedAbiVersion) {
          _ready.completeError(
            EngineException(
              'The barcode engine WebAssembly module has ABI version $abi, '
              'this version of flutter_zxing needs $fzxExpectedAbiVersion. '
              'The browser may have cached an old module.',
            ),
          );
        } else {
          _version = message.version;
          _ready.complete(message.version ?? '');
        }
      case 'failed':
        _fail(
          EngineException(
            'The barcode engine failed to start: ${message.error}',
          ),
        );
      default:
        _pending.remove(message.id)?.complete(message);
    }
  }

  void _handleError(web.Event event) {
    final String detail = event.isA<web.ErrorEvent>()
        ? (event as web.ErrorEvent).message
        : 'the worker script could not be loaded';
    _fail(EngineException('The barcode engine failed: $detail'));
  }

  void _fail(EngineException error) {
    if (!_ready.isCompleted) {
      _ready.completeError(error);
    }
    _stopped(error);
  }

  void _stopped(EngineException error) {
    if (_done.isCompleted) {
      return;
    }
    _done.complete();
    _worker
      ..onmessage = null
      ..onerror = null;
    final List<Completer<_Message>> pending = _pending.values.toList();
    _pending.clear();
    for (final Completer<_Message> c in pending) {
      c.completeError(error);
    }
  }

  @override
  Future<void> get done => _done.future;

  Future<_Message> _call(
    JSObject request, [
    List<JSObject> transfer = const <JSObject>[],
  ]) async {
    if (_done.isCompleted) {
      throw const EngineException('The barcode engine stopped');
    }
    final int id = _nextId++;
    final Completer<_Message> completer = Completer<_Message>();
    _pending[id] = completer;
    request.setProperty('id'.toJS, id.toJS);
    _worker.postMessage(request, transfer.toJS);
    final _Message reply = await completer.future;
    final int code = reply.code ?? -5;
    if (code < 0) {
      throwFzxError(code, reply.error ?? 'Unknown error');
    }
    return reply;
  }

  EngineReadResult _readResult(_Message reply) => decodeBarcodes(
    reply.buffer!.toDart.asUint8List(),
  ).withEngineMicros(((reply.ms ?? 0) * 1000).round());

  static JSObject _options(EngineReadOptions o) =>
      <String, Object>{
            'formats': o.formats,
            'flags': o.flags,
            'binarizer': o.binarizer,
            'maxSymbols': o.maxSymbols,
            'minLineCount': o.minLineCount,
          }.jsify()!
          as JSObject;

  /// A copy of [bytes] the worker can take ownership of.
  static JSArrayBuffer _transferable(Uint8List bytes) =>
      Uint8List.fromList(bytes).buffer.toJS;

  @override
  Future<EngineReadResult> readImage(
    Uint8List encodedImage,
    EngineReadOptions options,
  ) async {
    final JSArrayBuffer buffer = _transferable(encodedImage);
    final JSObject request = JSObject()
      ..setProperty('type'.toJS, 'readImage'.toJS)
      ..setProperty('buffer'.toJS, buffer)
      ..setProperty('options'.toJS, _options(options));
    return _readResult(await _call(request, <JSObject>[buffer]));
  }

  @override
  Future<EngineReadResult> readPixels(
    PixelBuffer image,
    EngineReadOptions options,
  ) async {
    final JSArrayBuffer buffer = _transferable(image.bytes);
    final Rect? crop = image.crop;
    final JSObject request = JSObject()
      ..setProperty('type'.toJS, 'readPixels'.toJS)
      ..setProperty('buffer'.toJS, buffer)
      ..setProperty('width'.toJS, image.width.toJS)
      ..setProperty('height'.toJS, image.height.toJS)
      ..setProperty('rowStride'.toJS, (image.rowStride ?? 0).toJS)
      ..setProperty('layout'.toJS, image.layout.index.toJS)
      ..setProperty('options'.toJS, _options(options));
    if (crop != null) {
      request.setProperty(
        'crop'.toJS,
        <int>[
          crop.left.round(),
          crop.top.round(),
          crop.width.round(),
          crop.height.round(),
        ].jsify(),
      );
    }
    return _readResult(await _call(request, <JSObject>[buffer]));
  }

  /// Reads a camera frame captured as an `ImageBitmap`. The bitmap is
  /// transferred to the worker: the caller must not use it afterwards.
  Future<EngineReadResult> readBitmap(
    web.ImageBitmap bitmap,
    EngineReadOptions options, {
    Rect? crop,
  }) async {
    final JSObject request = JSObject()
      ..setProperty('type'.toJS, 'readBitmap'.toJS)
      ..setProperty('bitmap'.toJS, bitmap)
      ..setProperty('options'.toJS, _options(options));
    if (crop != null) {
      request.setProperty(
        'crop'.toJS,
        <int>[
          crop.left.round(),
          crop.top.round(),
          crop.width.round(),
          crop.height.round(),
        ].jsify(),
      );
    }
    return _readResult(await _call(request, <JSObject>[bitmap]));
  }

  @override
  Future<EngineSymbol> write(
    Uint8List data, {
    required bool binary,
    required String format,
    required String options,
  }) async {
    final JSArrayBuffer buffer = _transferable(data);
    final JSObject request = JSObject()
      ..setProperty('type'.toJS, 'write'.toJS)
      ..setProperty('buffer'.toJS, buffer)
      ..setProperty('binary'.toJS, binary.toJS)
      ..setProperty('format'.toJS, format.toJS)
      ..setProperty('options'.toJS, options.toJS);
    final _Message reply = await _call(request, <JSObject>[buffer]);
    return decodeSymbol(reply.buffer!.toDart.asUint8List());
  }

  @override
  Future<String> version() async => _version ?? await _ready.future;

  @override
  void dispose() {
    _worker.terminate();
    _stopped(const EngineException('The barcode engine was shut down'));
  }
}
