// The demo's history of scanned and created codes, kept with
// shared_preferences. A scan keeps its module grid (drawn exactly again) or,
// for codes that need it, the camera's cut-out as a small PNG.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where a history item came from.
enum HistoryOrigin { scanned, created }

/// One scanned or created code.
@immutable
final class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.barcode,
    required this.origin,
    required this.time,
    this.source = 'camera',
    this.preset,
    this.cutOutPng,
    this.decodeMillis,
  });

  final String id;

  /// The code, rebuilt from what was stored: text, bytes, format and, for
  /// matrix codes, the modules as read.
  final Barcode barcode;
  final HistoryOrigin origin;
  final DateTime time;

  /// "camera" or "photo" for scans.
  final String source;

  /// The style preset of a created code.
  final String? preset;

  /// The camera's cut-out of a scan whose picture cannot be drawn again.
  final Uint8List? cutOutPng;

  /// How long reading took, when known.
  final int? decodeMillis;

  BarcodeContent get content => barcode.content;

  Map<String, Object?> toJson() {
    final BarcodeSymbol? symbol = barcode.symbol;
    return <String, Object?>{
      'id': id,
      'format': barcode.format.name,
      'text': barcode.text,
      'bytes': base64Encode(barcode.bytes),
      'contentType': barcode.contentType.name,
      'sid': barcode.symbologyIdentifier,
      'origin': origin.name,
      'time': time.millisecondsSinceEpoch,
      'source': source,
      'preset': preset,
      if (symbol != null)
        'symbol': <String, Object?>{
          'w': symbol.width,
          'h': symbol.height,
          'q': symbol.quietZone,
          'm': base64Encode(symbol.modules),
        },
      if (cutOutPng != null) 'cut': base64Encode(cutOutPng!),
      'ms': decodeMillis,
    };
  }

  static HistoryItem? fromJson(Map<String, Object?> json) {
    final BarcodeFormat? format = BarcodeFormat.values
        .where((BarcodeFormat f) => f.name == json['format'])
        .firstOrNull;
    if (format == null) {
      return null;
    }
    final Map<String, Object?>? s = (json['symbol'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>();
    return HistoryItem(
      id: json['id']! as String,
      barcode: Barcode(
        format: format,
        text: json['text']! as String,
        bytes: base64Decode(json['bytes']! as String),
        position: _noPosition,
        contentType: BarcodeContentType.values.firstWhere(
          (BarcodeContentType t) => t.name == json['contentType'],
          orElse: () => BarcodeContentType.text,
        ),
        symbologyIdentifier: json['sid'] as String? ?? '',
        symbol: s == null
            ? null
            : BarcodeSymbol(
                format: format,
                width: s['w']! as int,
                height: s['h']! as int,
                quietZone: s['q']! as int,
                modules: base64Decode(s['m']! as String),
              ),
      ),
      origin: HistoryOrigin.values.byName(json['origin']! as String),
      time: DateTime.fromMillisecondsSinceEpoch(json['time']! as int),
      source: json['source'] as String? ?? 'camera',
      preset: json['preset'] as String?,
      cutOutPng: json['cut'] == null
          ? null
          : base64Decode(json['cut']! as String),
      decodeMillis: json['ms'] as int?,
    );
  }
}

const BarcodePosition _noPosition = BarcodePosition(
  topLeft: ui.Offset.zero,
  topRight: ui.Offset.zero,
  bottomRight: ui.Offset.zero,
  bottomLeft: ui.Offset.zero,
);

/// A code created in the demo, as a [Barcode] for thumbnails and results.
Barcode createdBarcode(String text, BarcodeFormat format) => Barcode(
  format: format,
  text: text,
  bytes: Uint8List.fromList(utf8.encode(text)),
  position: _noPosition,
);

/// The history, newest first.
final class HistoryStore extends ChangeNotifier {
  HistoryStore._();

  /// The app's history.
  static final HistoryStore instance = HistoryStore._();

  static const String _key = 'demo.history.v1';
  static const int _limit = 200;

  final List<HistoryItem> _items = <HistoryItem>[];
  bool _loaded = false;

  List<HistoryItem> get items => List<HistoryItem>.unmodifiable(_items);

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw != null) {
        for (final Object? e in jsonDecode(raw) as List<Object?>) {
          final HistoryItem? item = HistoryItem.fromJson(
            (e! as Map<Object?, Object?>).cast<String, Object?>(),
          );
          if (item != null) {
            _items.add(item);
          }
        }
      }
    } on Object catch (e) {
      debugPrint('History not loaded: $e');
    }
    notifyListeners();
  }

  /// Adds a scan. The same code scanned again within a minute is not added
  /// twice.
  Future<HistoryItem?> addScan(
    Barcode barcode, {
    String source = 'camera',
    ui.Image? cutOut,
  }) async {
    final DateTime now = DateTime.now();
    final HistoryItem? last = _items.firstOrNull;
    if (last != null &&
        last.origin == HistoryOrigin.scanned &&
        last.barcode.text == barcode.text &&
        last.barcode.format == barcode.format &&
        now.difference(last.time) < const Duration(minutes: 1)) {
      return null;
    }
    Uint8List? png;
    if (cutOut != null && BarcodeThumbnail.needsCutOut(barcode)) {
      final ByteData? data = await cutOut.toByteData(
        format: ui.ImageByteFormat.png,
      );
      png = data?.buffer.asUint8List();
    }
    final HistoryItem item = HistoryItem(
      id: '${now.microsecondsSinceEpoch}',
      barcode: barcode,
      origin: HistoryOrigin.scanned,
      time: now,
      source: source,
      cutOutPng: png,
    );
    _insert(item);
    return item;
  }

  /// Adds a created code.
  HistoryItem addCreated(String text, BarcodeFormat format, String preset) {
    final DateTime now = DateTime.now();
    final HistoryItem item = HistoryItem(
      id: '${now.microsecondsSinceEpoch}',
      barcode: createdBarcode(text, format),
      origin: HistoryOrigin.created,
      time: now,
      preset: preset,
    );
    _insert(item);
    return item;
  }

  void remove(HistoryItem item) {
    _items.removeWhere((HistoryItem i) => i.id == item.id);
    notifyListeners();
    unawaited(_save());
  }

  void clear() {
    _items.clear();
    notifyListeners();
    unawaited(_save());
  }

  void _insert(HistoryItem item) {
    _items.insert(0, item);
    if (_items.length > _limit) {
      _items.removeRange(_limit, _items.length);
    }
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(<Object?>[for (final HistoryItem i in _items) i.toJson()]),
      );
    } on Object catch (e) {
      debugPrint('History not saved: $e');
    }
  }
}

/// The picture of a history item: the exact modules, the code drawn again,
/// the camera's cut-out, or (created codes) the code in its style.
class HistoryPicture extends StatelessWidget {
  const HistoryPicture(this.item, {super.key, this.size = 56});

  final HistoryItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (item.origin == HistoryOrigin.created) {
      final BarcodeStyle style =
          BarcodeStyle.presets[item.preset] ?? BarcodeStyle.classic;
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.21),
        child: ColoredBox(
          color: style.backgroundColor,
          child: SizedBox.square(
            dimension: size,
            child: Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: BarcodeView(
                item.barcode.text,
                format: item.barcode.format,
                style: style.copyWith(quietZone: false),
                semanticLabel: '',
              ),
            ),
          ),
        ),
      );
    }
    final Uint8List? png = item.cutOutPng;
    if (png != null) {
      return _CutOut(png: png, barcode: item.barcode, size: size);
    }
    return BarcodeThumbnail(item.barcode, size: size);
  }
}

/// A thumbnail with the stored cut-out decoded.
class _CutOut extends StatefulWidget {
  const _CutOut({required this.png, required this.barcode, required this.size});

  final Uint8List png;
  final Barcode barcode;
  final double size;

  @override
  State<_CutOut> createState() => _CutOutState();
}

class _CutOutState extends State<_CutOut> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    unawaited(_decode());
  }

  Future<void> _decode() async {
    final ui.Codec codec = await ui.instantiateImageCodec(widget.png);
    final ui.FrameInfo frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BarcodeThumbnail(widget.barcode, cutOut: _image, size: widget.size);
}
