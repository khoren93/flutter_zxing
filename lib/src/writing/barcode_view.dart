import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../barcode/barcode_format.dart';
import '../errors.dart';
import 'barcode_painter.dart';
import 'barcode_writer.dart';
import 'symbol_layout.dart';

/// Shows a barcode. Drawn as vectors from the module matrix, so it is sharp
/// at any size and pixel density.
///
/// ```dart
/// BarcodeView('https://pub.dev', format: BarcodeFormat.qrCode, width: 200)
/// BarcodeView('4006381333931', format: BarcodeFormat.ean13, showText: true, width: 240)
/// BarcodeView.bytes(payload, format: BarcodeFormat.dataMatrix, width: 120)
/// ```
///
/// Without [width] and [height] it fills the incoming constraints, keeping
/// the symbol's aspect ratio.
class BarcodeView extends StatefulWidget {
  /// Creates a barcode view for the text [data].
  const BarcodeView(
    String this.data, {
    super.key,
    this.format = BarcodeFormat.qrCode,
    this.errorCorrection,
    this.showText = false,
    this.style = const BarcodeStyle(),
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  }) : bytes = null;

  /// Creates a barcode view for binary [bytes] (formats with a byte mode:
  /// QR, Data Matrix, Aztec, PDF417).
  const BarcodeView.bytes(
    Uint8List this.bytes, {
    super.key,
    this.format = BarcodeFormat.qrCode,
    this.errorCorrection,
    this.style = const BarcodeStyle(),
    this.width,
    this.height,
    this.semanticLabel,
    this.errorBuilder,
  }) : data = null,
       showText = false;

  /// The text to encode, or `null` for [BarcodeView.bytes].
  final String? data;

  /// The binary data to encode, or `null` for text.
  final Uint8List? bytes;

  /// The symbology; must be writable ([BarcodeFormat.canWrite]).
  final BarcodeFormat format;

  /// Error correction; `null` uses the format's default, or
  /// [ErrorCorrection.high] when [BarcodeStyle.logo] is set.
  final ErrorCorrection? errorCorrection;

  /// Show the human readable text under linear barcodes.
  final bool showText;

  /// Colors and shapes.
  final BarcodeStyle style;

  /// Width in logical pixels.
  final double? width;

  /// Height in logical pixels.
  final double? height;

  /// Accessibility label; defaults to "`format` barcode: `data`".
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
  BarcodeSymbol? _symbol;
  SymbolLayout? _layout;
  Object? _error;

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
  }

  @override
  void didUpdateWidget(BarcodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_Request.of(widget) != _request) {
      _encode(initial: false);
    }
    if (widget.style.logo?.image != oldWidget.style.logo?.image) {
      _resolveLogo();
    }
  }

  @override
  void dispose() {
    _logoStream?.removeListener(_logoListener);
    _logoInfo?.dispose();
    super.dispose();
  }

  /// Encodes the current request. Until the result arrives the previous
  /// symbol stays on screen, so changing the data does not flash.
  void _encode({required bool initial}) {
    final _Request request = _Request.of(widget);
    _request = request;
    final BarcodeSymbol? cached = _symbolCache.get(request);
    if (cached != null) {
      void apply() {
        _symbol = cached;
        _layout = SymbolLayout(cached);
        _error = null;
      }

      initial ? apply() : setState(apply);
      return;
    }
    request.encode().then(
      (BarcodeSymbol symbol) {
        _symbolCache.put(request, symbol);
        if (!mounted || _request != request) {
          return;
        }
        setState(() {
          _symbol = symbol;
          _layout = SymbolLayout(symbol);
          _error = null;
        });
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

  String get _semanticLabel {
    final String? data = widget.data;
    return widget.semanticLabel ??
        (data == null
            ? '${widget.format.displayName} barcode'
            : '${widget.format.displayName} barcode: $data');
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
    if (symbol == null || layout == null) {
      // First show, still encoding: hold the space the symbol will most
      // likely take, so that it appears without moving anything.
      final bool square = hasModuleShapes(widget.format);
      return SizedBox(
        width: widget.width ?? (square ? widget.height : null),
        height: widget.height ?? (square ? widget.width : null),
      );
    }

    final double ratio = layout.width / layout.height;
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
    return Semantics(
      container: true,
      image: true,
      label: _semanticLabel,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double? w = widget.width;
          double? h = widget.height;
          if (w == null && h == null) {
            // Fill the constraints, keeping the aspect ratio; unbounded
            // both ways, 4 pixels per module.
            final double maxW = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : layout.width * 4.0;
            final double maxH = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : layout.height * 4.0;
            w = maxW < maxH * ratio ? maxW : maxH * ratio;
            h = w / ratio;
          }
          w ??= h! * ratio;
          h ??= w / ratio;
          return SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: BarcodePainter(
                symbol: symbol,
                layout: layout,
                style: widget.style,
                devicePixelRatio: devicePixelRatio,
                textStyle: textStyle,
                logo: _logoInfo?.image,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// What a [BarcodeView] asks the writer for.
@immutable
final class _Request {
  _Request.of(BarcodeView view)
    : data = view.data,
      bytes = view.bytes,
      format = view.format,
      showText = view.showText,
      quietZone = view.style.quietZone,
      // A logo covers modules: QR codes then get the most error correction.
      errorCorrection =
          view.errorCorrection ??
          (view.style.logo != null &&
                  view.format.symbology == BarcodeFormat.qrCode
              ? ErrorCorrection.high
              : null);

  final String? data;
  final Uint8List? bytes;
  final BarcodeFormat format;
  final bool showText;
  final bool quietZone;
  final ErrorCorrection? errorCorrection;

  Future<BarcodeSymbol> encode() {
    final BarcodeWriter writer = BarcodeWriter(
      format,
      errorCorrection: errorCorrection,
      quietZone: quietZone,
      showText: showText,
    );
    final Uint8List? b = bytes;
    return b != null ? writer.encodeBytes(b) : writer.encode(data!);
  }

  @override
  bool operator ==(Object other) =>
      other is _Request &&
      other.data == data &&
      listEquals(other.bytes, bytes) &&
      other.format == format &&
      other.showText == showText &&
      other.quietZone == quietZone &&
      other.errorCorrection == errorCorrection;

  @override
  int get hashCode => Object.hash(
    data,
    bytes == null ? null : Object.hashAll(bytes!),
    format,
    showText,
    quietZone,
    errorCorrection,
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

/// How a [BarcodeView] is drawn.
@immutable
final class BarcodeStyle {
  /// Creates a style. The defaults are black on white with square modules.
  const BarcodeStyle({
    this.color = const Color(0xFF000000),
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.gradient,
    this.moduleShape = ModuleShape.square,
    this.finderShape = FinderShape.square,
    this.quietZone = true,
    this.logo,
  });

  /// Color of the dark modules.
  final Color color;

  /// Background color. Keep enough contrast with [color].
  final Color backgroundColor;

  /// Paints the dark modules with a gradient instead of [color].
  final Gradient? gradient;

  /// Shape of the data modules (2D formats).
  final ModuleShape moduleShape;

  /// Shape of the finder patterns ("eyes") of QR codes.
  final FinderShape finderShape;

  /// Keep the quiet zone (blank margin) around the symbol.
  final bool quietZone;

  /// An image in the middle of a QR code.
  final BarcodeLogo? logo;

  /// Creates a copy with the given fields replaced.
  BarcodeStyle copyWith({
    Color? color,
    Color? backgroundColor,
    Gradient? gradient,
    ModuleShape? moduleShape,
    FinderShape? finderShape,
    bool? quietZone,
    BarcodeLogo? logo,
  }) => BarcodeStyle(
    color: color ?? this.color,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    gradient: gradient ?? this.gradient,
    moduleShape: moduleShape ?? this.moduleShape,
    finderShape: finderShape ?? this.finderShape,
    quietZone: quietZone ?? this.quietZone,
    logo: logo ?? this.logo,
  );

  @override
  bool operator ==(Object other) =>
      other is BarcodeStyle &&
      other.color == color &&
      other.backgroundColor == backgroundColor &&
      other.gradient == gradient &&
      other.moduleShape == moduleShape &&
      other.finderShape == finderShape &&
      other.quietZone == quietZone &&
      other.logo == logo;

  @override
  int get hashCode => Object.hash(
    color,
    backgroundColor,
    gradient,
    moduleShape,
    finderShape,
    quietZone,
    logo,
  );
}

/// Shape of the data modules of QR, Aztec and Data Matrix codes. Linear
/// barcodes and PDF417 always use plain bars and rows.
enum ModuleShape {
  /// Classic squares.
  square,

  /// Neighbouring modules flow into one shape; corners with no neighbour on
  /// either side are rounded.
  rounded,

  /// Dots.
  circle,
}

/// Shape of the finder patterns ("eyes") of a QR code.
enum FinderShape {
  /// Classic squares.
  square,

  /// Rounded squares.
  rounded,

  /// Circles.
  circle,
}

/// An image placed in the middle of a QR code.
@immutable
final class BarcodeLogo {
  /// Creates a logo. [size] is the fraction of the symbol width it covers.
  const BarcodeLogo(
    this.image, {
    this.size = 0.22,
    this.clearBackground = true,
  });

  /// The image.
  final ImageProvider image;

  /// Fraction of the symbol width, 0–0.3. Larger logos may not scan.
  final double size;

  /// Clear the modules behind the logo instead of drawing over them.
  final bool clearBackground;

  @override
  bool operator ==(Object other) =>
      other is BarcodeLogo &&
      other.image == image &&
      other.size == size &&
      other.clearBackground == clearBackground;

  @override
  int get hashCode => Object.hash(image, size, clearBackground);
}
