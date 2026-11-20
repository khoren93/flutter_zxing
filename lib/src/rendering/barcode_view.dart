import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../barcode/barcode_format.dart';
import '../errors.dart';
import '../writing/barcode_writer.dart';
import '../writing/symbol_layout.dart';
import 'barcode_painter.dart';
import 'barcode_style.dart';
import 'frame_layout.dart';
import 'logo_symbol.dart';
import 'symbol_shapes.dart';

/// Shows a barcode. Drawn as vectors from the module matrix, so it is sharp
/// at any size and pixel density.
///
/// The [writer] encodes the data, exactly as `writer.encode` and the
/// exports do; the [style] draws it.
///
/// ```dart
/// BarcodeView('https://pub.dev', width: 200)
/// BarcodeView(
///   '4006381333931',
///   writer: const BarcodeWriter(BarcodeFormat.ean13),
///   width: 240,
/// )
/// BarcodeView.bytes(
///   payload,
///   writer: const BarcodeWriter(BarcodeFormat.dataMatrix),
///   width: 120,
/// )
/// ```
///
/// Without [width] and [height] it fills the incoming constraints, keeping
/// the symbol's aspect ratio.
class BarcodeView extends StatefulWidget {
  /// Creates a barcode view for the text [data], encoded with [writer] (a
  /// QR code by default).
  const BarcodeView(
    String this.data, {
    super.key,
    BarcodeWriter this.writer = const BarcodeWriter(BarcodeFormat.qrCode),
    this.style = BarcodeStyle.classic,
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  }) : bytes = null,
       symbol = null;

  /// Draws a [BarcodeSymbol] as it is: the modules a reader sampled from a
  /// code (`Barcode.symbol`), or a symbol from `BarcodeWriter.encode` or
  /// `BarcodeStyle.encode`. Nothing is encoded, so the code shown is
  /// exactly the one read.
  ///
  /// ```dart
  /// final BarcodeSymbol? symbol = capture.barcode.symbol;
  /// if (symbol != null) BarcodeView.symbol(symbol, width: 56);
  /// ```
  ///
  /// In debug mode, asserts that a QR code under a [BarcodeStyle.logo] has
  /// the error correction the logo needs; encode it with
  /// `BarcodeStyle.encode` to get it.
  BarcodeView.symbol(
    BarcodeSymbol this.symbol, {
    super.key,
    this.style = BarcodeStyle.classic,
    this.width,
    this.height,
    this.semanticLabel,
  }) : data = symbol.text,
       bytes = null,
       writer = null,
       errorBuilder = null;

  /// Creates a barcode view for binary [bytes], encoded with [writer]
  /// (formats with a byte mode: QR, Data Matrix, Aztec, PDF417).
  const BarcodeView.bytes(
    Uint8List this.bytes, {
    super.key,
    BarcodeWriter this.writer = const BarcodeWriter(BarcodeFormat.qrCode),
    this.style = BarcodeStyle.classic,
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  }) : data = null,
       symbol = null;

  /// The text to encode, or `null` for [BarcodeView.bytes].
  final String? data;

  /// The binary data to encode, or `null` for text.
  final Uint8List? bytes;

  /// The symbol to draw as it is, from [BarcodeView.symbol].
  final BarcodeSymbol? symbol;

  /// Encodes [data] or [bytes]: the format, error correction, GS1, version
  /// and the text under linear barcodes ([BarcodeWriter.showText]); `null`
  /// for [BarcodeView.symbol], which encodes nothing.
  ///
  /// Under a [BarcodeStyle.logo], a QR code gets the error correction the
  /// logo needs ([BarcodeLogo.neededErrorCorrection]) unless the writer
  /// sets its own.
  final BarcodeWriter? writer;

  /// Colors, shapes, logo, title, caption and quiet zone.
  final BarcodeStyle style;

  /// Width in logical pixels.
  final double? width;

  /// Height in logical pixels.
  final double? height;

  /// Accessibility label. By default the format's name, the
  /// [BarcodeStyle.title] and [BarcodeStyle.caption], and the text under a
  /// linear barcode when it is shown; never the encoded data, which may be
  /// a password or bank details.
  final String? semanticLabel;

  /// Shown instead of the barcode if [data] cannot be encoded. Without it,
  /// an empty box is shown and the error is reported to `FlutterError`.
  final Widget Function(BuildContext context, BarcodeWriteException error)?
  errorBuilder;

  @override
  State<BarcodeView> createState() => _BarcodeViewState();
}

class _BarcodeViewState extends State<BarcodeView> {
  _Request? _request;

  /// The symbol as encoded or given, before the style's quiet zone.
  BarcodeSymbol? _encoded;

  /// The request [_encoded] answers; `null` for a given symbol.
  _Request? _encodedFor;
  BarcodeSymbol? _symbol;
  SymbolLayout? _layout;
  Object? _error;

  /// Fires when what moves the view (a scrollable, a route transition) has
  /// come to rest, to snap it to the pixel grid again.
  final _Settled _settled = _Settled();
  List<ScrollPosition> _positions = const <ScrollPosition>[];
  ModalRoute<Object?>? _route;

  ImageStream? _logoStream;
  ImageInfo? _logoInfo;
  late final ImageStreamListener _logoListener = ImageStreamListener(
    _onLogo,
    onError: (Object error, StackTrace? stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'flutter_zxing',
          context: ErrorDescription('while loading the logo of a BarcodeView'),
        ),
      );
    },
  );

  @override
  void initState() {
    super.initState();
    _encode(initial: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveLogo();
    _watchMovement();
  }

  @override
  void didUpdateWidget(BarcodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.symbol != oldWidget.symbol ||
        (widget.symbol == null && _Request.of(widget) != _request)) {
      _encode(initial: false);
    } else if (widget.style.quietZone != oldWidget.style.quietZone) {
      // The same symbol with or without its quiet zone: nothing to encode.
      // One still being encoded gets the new style when it arrives.
      final BarcodeSymbol? encoded = _encoded;
      if (encoded != null && _encodedFor == _request) {
        setState(() => _show(encoded, _encodedFor));
      }
    }
    if (widget.style.logo?.image != oldWidget.style.logo?.image) {
      _resolveLogo();
    }
  }

  @override
  void dispose() {
    _logoStream?.removeListener(_logoListener);
    _logoInfo?.dispose();
    _unwatchMovement();
    _settled.dispose();
    super.dispose();
  }

  /// Listens to the scrollables around the view and to its route's
  /// transitions: a layer they move is not painted again, so the snap to
  /// the pixel grid is redone once they stop.
  void _watchMovement() {
    final List<ScrollPosition> positions = <ScrollPosition>[
      for (
        ScrollableState? s = Scrollable.maybeOf(context);
        s != null;
        s = Scrollable.maybeOf(s.context)
      )
        s.position,
    ];
    final ModalRoute<Object?>? route = ModalRoute.of(context);
    if (listEquals(positions, _positions) && route == _route) {
      return;
    }
    _unwatchMovement();
    _positions = positions;
    _route = route;
    for (final ScrollPosition p in positions) {
      p.addListener(_onScroll);
      p.isScrollingNotifier.addListener(_onScroll);
    }
    route?.animation?.addStatusListener(_onRouteStatus);
    route?.secondaryAnimation?.addStatusListener(_onRouteStatus);
  }

  void _unwatchMovement() {
    for (final ScrollPosition p in _positions) {
      p.removeListener(_onScroll);
      p.isScrollingNotifier.removeListener(_onScroll);
    }
    _route?.animation?.removeStatusListener(_onRouteStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteStatus);
    _positions = const <ScrollPosition>[];
    _route = null;
  }

  void _onScroll() {
    // Not on every frame of a fling: once it stops, or after a jump.
    if (!_positions.any((ScrollPosition p) => p.isScrollingNotifier.value)) {
      _settled.ping();
    }
  }

  void _onRouteStatus(AnimationStatus status) {
    if (!status.isAnimating) {
      _settled.ping();
    }
  }

  /// Shows [encoded], the answer to [request], in the current style.
  void _show(BarcodeSymbol encoded, _Request? request) {
    final BarcodeSymbol shown = styledSymbol(encoded, widget.style);
    _encoded = encoded;
    _encodedFor = request;
    _symbol = shown;
    _layout = SymbolLayout(shown);
    _error = null;
  }

  /// Encodes the current request. Until the result arrives the previous
  /// symbol stays on screen, so changing the data does not flash.
  void _encode({required bool initial}) {
    final BarcodeSymbol? given = widget.symbol;
    final _Request? request = given == null ? _Request.of(widget) : null;
    _request = request;
    final BarcodeSymbol? ready = given ?? _symbolCache.get(request!);
    if (ready != null) {
      initial ? _show(ready, request) : setState(() => _show(ready, request));
      return;
    }
    request!.encode().then(
      (BarcodeSymbol symbol) {
        _symbolCache.put(request, symbol);
        if (!mounted || _request != request) {
          return;
        }
        setState(() => _show(symbol, request));
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || _request != request) {
          return;
        }
        if (error is! BarcodeWriteException || widget.errorBuilder == null) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'flutter_zxing',
              context: ErrorDescription('while encoding a BarcodeView'),
            ),
          );
        }
        setState(() {
          _encoded = null;
          _encodedFor = null;
          _symbol = null;
          _layout = null;
          _error = error;
        });
      },
    );
  }

  void _resolveLogo() {
    final BarcodeLogo? logo = widget.style.logo;
    final ImageStream? stream = logo?.image.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream != null &&
        _logoStream != null &&
        stream.key == _logoStream!.key) {
      return;
    }
    _logoStream?.removeListener(_logoListener);
    _logoStream = stream;
    if (_logoInfo != null) {
      _logoInfo!.dispose();
      _logoInfo = null;
    }
    stream?.addListener(_logoListener);
  }

  void _onLogo(ImageInfo info, bool synchronousCall) {
    void apply() {
      _logoInfo?.dispose();
      _logoInfo = info;
    }

    synchronousCall ? apply() : setState(apply);
  }

  /// The frame of the last build, kept while its inputs stay the same: its
  /// text is measured.
  FrameLayout? _frame;
  (SymbolLayout, BarcodeStyle, TextStyle)? _frameKey;

  FrameLayout _frameOf(SymbolLayout layout, TextStyle base) {
    final (SymbolLayout, BarcodeStyle, TextStyle)? key = _frameKey;
    if (_frame == null ||
        key == null ||
        !identical(key.$1, layout) ||
        key.$2 != widget.style ||
        key.$3 != base) {
      _frame = FrameLayout(layout, widget.style, base: base);
      _frameKey = (layout, widget.style, base);
    }
    return _frame!;
  }

  /// The symbology of the code shown.
  BarcodeFormat get _format => widget.symbol?.format ?? widget.writer!.format;

  String get _semanticLabel {
    // The text printed under the bars is on screen; the data may not be.
    final String? shown = _symbol?.text;
    final String name = _format.displayName;
    final String code = shown == null || shown.isEmpty ? name : '$name: $shown';
    return widget.semanticLabel ??
        <String>[
          ?widget.style.title?.text,
          code,
          ?widget.style.caption?.text,
        ].where((String s) => s.isNotEmpty).join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final Object? error = _error;
    if (error != null) {
      final BarcodeWriteException? writeError = error is BarcodeWriteException
          ? error
          : null;
      if (writeError != null && widget.errorBuilder != null) {
        return widget.errorBuilder!(context, writeError);
      }
      return SizedBox(width: widget.width, height: widget.height);
    }
    final BarcodeSymbol? symbol = _symbol;
    final SymbolLayout? layout = _layout;
    // A symbol of an earlier style stays on screen while the one for this
    // style is encoded: only that one has to fit the logo.
    assert(
      symbol == null ||
          _encodedFor != _request ||
          logoFits(symbol, widget.style.logo),
      logoFitsMessage(symbol, widget.style.logo!),
    );
    if (symbol == null || layout == null) {
      // First show, still encoding: hold the space the symbol will most
      // likely take, so that it appears without moving anything.
      final bool square = hasModuleShapes(_format);
      return SizedBox(
        width: widget.width ?? (square ? widget.height : null),
        height: widget.height ?? (square ? widget.width : null),
      );
    }

    final double devicePixelRatio =
        MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    // Only the app's font: no decoration (outside a Material the default
    // style is the yellow-underlined error style), color and size are set
    // by the painter.
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final TextStyle textStyle = TextStyle(
      fontFamily: ambient.fontFamily,
      fontFamilyFallback: ambient.fontFamilyFallback,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final FrameLayout frame = _frameOf(
      layout,
      TextStyle(
        fontFamily: ambient.fontFamily,
        fontFamilyFallback: ambient.fontFamilyFallback,
      ),
    );
    return Semantics(
      container: true,
      image: true,
      label: _semanticLabel,
      child: _BarcodeBox(
        width: widget.width,
        height: widget.height,
        frameSize: Size(frame.width, frame.height),
        devicePixelRatio: devicePixelRatio,
        settled: _settled,
        child: CustomPaint(
          painter: BarcodePainter(
            symbol: symbol,
            layout: layout,
            frame: frame,
            style: widget.style,
            devicePixelRatio: devicePixelRatio,
            textStyle: textStyle,
            textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
            logo: _logoInfo?.image,
          ),
        ),
      ),
    );
  }
}

final class _Settled extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// What a [BarcodeView] asks the writer for.
@immutable
final class _Request {
  _Request.of(BarcodeView view)
    : data = view.data,
      // A copy: the caller may reuse its buffer, and the cache keeps this.
      bytes = view.bytes == null ? null : Uint8List.fromList(view.bytes!),
      // A logo covers modules: QR codes then get the error correction it
      // needs.
      writer = writerUnderLogo(view.writer!, view.style.logo),
      logoSize = view.style.logo?.size;

  final String? data;
  final Uint8List? bytes;
  final BarcodeWriter writer;
  final double? logoSize;

  Future<BarcodeSymbol> encode() {
    final Uint8List? b = bytes;
    return encodeUnderLogo(
      writer,
      logoSize,
      (BarcodeWriter w) => b != null ? w.encodeBytes(b) : w.encode(data!),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Request &&
      other.data == data &&
      listEquals(other.bytes, bytes) &&
      other.writer == writer &&
      other.logoSize == logoSize;

  @override
  int get hashCode => Object.hash(
    data,
    bytes == null ? null : Object.hashAll(bytes!),
    writer,
    logoSize,
  );
}

/// Recently encoded symbols, so that a [BarcodeView] shown again (a list
/// scrolled back, a page revisited) paints in its first frame.
final _SymbolCache _symbolCache = _SymbolCache();

final class _SymbolCache {
  static const int _capacity = 64;
  final LinkedHashMap<_Request, BarcodeSymbol> _symbols =
      LinkedHashMap<_Request, BarcodeSymbol>();

  BarcodeSymbol? get(_Request request) {
    final BarcodeSymbol? symbol = _symbols.remove(request);
    if (symbol != null) {
      _symbols[request] = symbol;
    }
    return symbol;
  }

  void put(_Request request, BarcodeSymbol symbol) {
    _symbols
      ..remove(request)
      ..[request] = symbol;
    if (_symbols.length > _capacity) {
      _symbols.remove(_symbols.keys.first);
    }
  }
}

/// Sizes the symbol and paints it on the device pixel grid.
///
/// Size: [width] and [height]; one of them and the aspect ratio of
/// [frameSize]; or, with neither, the incoming constraints at that ratio
/// (the bounded axis decides: a Column or a ListView bounds only one), and
/// 4 pixels per module when nothing is bounded. Unlike a LayoutBuilder it
/// has intrinsic sizes, so it works in an `AlertDialog`, an
/// `IntrinsicWidth` or a `Table`.
///
/// Paint: its child moved by less than a device pixel so that the child's
/// origin lies on the device pixel grid. Without it, a symbol whose modules
/// are a whole number of pixels is still blurred at every edge when its
/// place on screen falls between two pixels (a fractional device pixel
/// ratio, a centred widget), and thin bars stop reading. A layer an
/// ancestor moves is not painted again, so [settled] repaints it once a
/// scrollable or a route transition around it comes to rest.
class _BarcodeBox extends SingleChildRenderObjectWidget {
  const _BarcodeBox({
    required this.width,
    required this.height,
    required this.frameSize,
    required this.devicePixelRatio,
    required this.settled,
    super.child,
  });

  final double? width;
  final double? height;
  final Size frameSize;
  final double devicePixelRatio;
  final Listenable settled;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarcodeBox(
    width: width,
    height: height,
    frameSize: frameSize,
    devicePixelRatio: devicePixelRatio,
    settled: settled,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBarcodeBox renderObject,
  ) => renderObject
    ..width = width
    ..height = height
    ..frameSize = frameSize
    ..devicePixelRatio = devicePixelRatio
    ..settled = settled;
}

class _RenderBarcodeBox extends RenderProxyBox {
  _RenderBarcodeBox({
    required double? width,
    required double? height,
    required Size frameSize,
    required double devicePixelRatio,
    required Listenable settled,
  }) : _width = width,
       _height = height,
       _frameSize = frameSize,
       _devicePixelRatio = devicePixelRatio,
       _settled = settled;

  double? _width;
  double? get width => _width;
  set width(double? value) {
    if (value != _width) {
      _width = value;
      markNeedsLayout();
    }
  }

  double? _height;
  double? get height => _height;
  set height(double? value) {
    if (value != _height) {
      _height = value;
      markNeedsLayout();
    }
  }

  Size _frameSize;
  Size get frameSize => _frameSize;
  set frameSize(Size value) {
    if (value != _frameSize) {
      _frameSize = value;
      markNeedsLayout();
    }
  }

  double _devicePixelRatio;
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value != _devicePixelRatio) {
      _devicePixelRatio = value;
      markNeedsPaint();
    }
  }

  Listenable _settled;
  Listenable get settled => _settled;
  set settled(Listenable value) {
    if (value != _settled) {
      if (attached) {
        _settled.removeListener(markNeedsPaint);
        value.addListener(markNeedsPaint);
      }
      _settled = value;
    }
  }

  /// The size it takes within [maxWidth] x [maxHeight], before the
  /// constraints' minimums; either may be infinite.
  Size _wanted(double maxWidth, double maxHeight) {
    final double ratio = _frameSize.width / _frameSize.height;
    double? w = _width;
    double? h = _height;
    if (w == null && h == null) {
      final bool wide = maxWidth.isFinite;
      final bool tall = maxHeight.isFinite;
      if (wide && tall) {
        w = maxWidth < maxHeight * ratio ? maxWidth : maxHeight * ratio;
      } else if (wide) {
        w = maxWidth;
      } else if (tall) {
        w = maxHeight * ratio;
      } else {
        w = _frameSize.width * 4.0;
      }
      h = w / ratio;
    }
    w ??= h! * ratio;
    h ??= w / ratio;
    return Size(w, h);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _settled.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _settled.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _wanted(double.infinity, height).width;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _wanted(double.infinity, height).width;

  @override
  double computeMinIntrinsicHeight(double width) =>
      _wanted(width, double.infinity).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _wanted(width, double.infinity).height;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(
    _wanted(constraints.maxWidth, constraints.maxHeight),
  );

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
    child?.layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child == null) {
      return;
    }
    final Offset global = localToGlobal(Offset.zero);
    double snap(double v) =>
        (v * _devicePixelRatio).roundToDouble() / _devicePixelRatio;
    final Offset shift = Offset(snap(global.dx), snap(global.dy)) - global;
    context.paintChild(child, offset + shift);
  }
}
