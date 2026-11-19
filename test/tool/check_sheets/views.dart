// Part of check_sheets_test.dart: how tiles are drawn, fonts and the logo.
part of '../check_sheets_test.dart';

/// A tile of the overview: the id, the name and as much code as fits.
Widget _overviewTile(
  String id,
  _Tile tile,
  Map<String, ui.Image> images,
  GlobalKey key,
) => DecoratedBox(
  decoration: BoxDecoration(
    color: const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '$id  ',
                style: const TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: tile.title),
              if (tile.note != null)
                TextSpan(
                  text: '  ${tile.note}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _text.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: KeyedSubtree(
            key: key,
            child: tile.sample == null
                ? Center(child: _code(tile, images))
                : SizedBox.expand(child: _code(tile, images)),
          ),
        ),
      ],
    ),
  ),
);

/// Gives every BarcodeView real time to encode and paint.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 200; i++) {
    final bool waiting = find
        .byType(BarcodeView)
        .evaluate()
        .any(
          (Element e) => find
              .descendant(
                of: find.byWidget(e.widget),
                matching: find.byType(CustomPaint),
              )
              .evaluate()
              .isEmpty,
        );
    if (!waiting && i > 10) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump();
}

/// [text] with control characters made visible.
String _visible(String text) => text
    .replaceAll('\r', '‹CR›')
    .replaceAll('\n', '⏎')
    .replaceAll('\x1d', '‹GS›')
    .replaceAll('\x1e', '‹RS›');

String _kindName(Type? kind) => kind?.toString() ?? '—';

Future<void> _loadFonts() async {
  final String? root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final FontLoader roboto = FontLoader('Roboto');
    for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
      final File file = File(
        '$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf',
      );
      if (file.existsSync()) {
        roboto.addFont(
          Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
    }
    await roboto.load();
  }
  final File menlo = File('/System/Library/Fonts/Menlo.ttc');
  if (menlo.existsSync()) {
    await (FontLoader('Menlo')..addFont(
          Future<ByteData>.value(ByteData.sublistView(menlo.readAsBytesSync())),
        ))
        .load();
  }
}

/// A 96 × 96 logo: a rounded square with a white Z, like an app icon.
Future<Uint8List> _logoPng() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 96, 96),
      const Radius.circular(22),
    ),
    Paint()..color = const Color(0xFF0B3D91),
  );
  canvas.drawPath(
    Path()
      ..moveTo(26, 26)
      ..lineTo(70, 26)
      ..lineTo(26, 70)
      ..lineTo(70, 70),
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round,
  );
  final ui.Image image = await recorder.endRecording().toImage(96, 96);
  final ByteData png = (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  image.dispose();
  return png.buffer.asUint8List();
}

// Menlo has the arrows and symbols Roboto from the SDK lacks.
const TextStyle _text = TextStyle(
  fontFamily: 'Roboto',
  fontFamilyFallback: <String>['Menlo'],
  color: _ink,
);
const TextStyle _mono = TextStyle(
  fontFamily: 'Menlo',
  fontSize: 11,
  height: 1.35,
  color: _muted,
);

/// The code of [tile], sized to the space it has.
Widget _code(_Tile tile, Map<String, ui.Image> images) {
  Widget view(String data, {double? width}) => BarcodeView(
    data,
    format: tile.format,
    gs1: tile.gs1,
    errorCorrection: tile.ecc,
    style: tile.style,
    showText: tile.format.isLinear,
    width: width,
  );
  final Widget code;
  if (tile.sample case final String path) {
    final ui.Image image = images[path]!;
    code = RawImage(
      image: image,
      fit: BoxFit.contain,
      filterQuality: image.width < 250
          ? FilterQuality.none
          : FilterQuality.medium,
    );
  } else if (tile.codes case final List<String> codes) {
    code = Wrap(
      spacing: 22,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: <Widget>[
        for (final String c in codes)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              view(c, width: 100),
              Text(
                c.substring(0, 1),
                style: _text.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  } else if (tile.bytes case final Uint8List bytes) {
    code = BarcodeView.bytes(bytes, format: tile.format);
  } else {
    code = view(tile.data, width: tile.look == _Look.tiny ? 34 : null);
  }
  return switch (tile.look) {
    _Look.rotated => Transform.rotate(
      angle: 0.5236,
      child: SizedBox.square(dimension: 130, child: code),
    ),
    _Look.mirrored => Transform.flip(flipX: true, child: code),
    _ => code,
  };
}

Widget _tile(
  String id,
  _Tile tile,
  Map<String, ui.Image> images,
  GlobalKey key,
) {
  final String? note = tile.note;
  final String data = tile.bytes != null
      ? tile.bytes!
            .map((int b) => b.toRadixString(16).padLeft(2, '0'))
            .join(' ')
      : tile.codes?.join(' · ') ?? _visible(tile.data);
  return DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  child: Text(
                    id,
                    style: _text.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tile.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                tile.format.displayName,
                style: _text.copyWith(fontSize: 12, color: _muted),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: KeyedSubtree(
                key: key,
                child: Center(child: _code(tile, images)),
              ),
            ),
          ),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(
                  text: '→ ${_kindName(tile.kind)}',
                  style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note != null)
                  TextSpan(
                    text: '  $note',
                    style: TextStyle(color: tile.warning ? _warn : _muted),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _text.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            data.isEmpty ? '(see sample)' : data,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _mono,
          ),
        ],
      ),
    ),
  );
}

/// What reading a tile back found.
final class _Check {
  const _Check(this.id, this.tile, this.found);

  final String id;
  final _Tile tile;
  final List<Barcode> found;

  Barcode? get first => found.isEmpty ? null : found.first;

  bool get formatOk =>
      first != null && first!.format.symbology == tile.format.symbology;

  bool get kindOk =>
      tile.kind == null || first?.content.runtimeType == tile.kind;

  /// An EAN with an add-on also reads without it: any of the reads counts.
  bool get textOk =>
      !tile.exact ||
      found.any((Barcode b) => b.text.trim() == tile.expectedText.trim());

  bool get countOk => tile.codes == null || found.length == tile.codes!.length;

  /// Not read, or read as something else: the sheet itself is wrong.
  bool get failed => first == null || !formatOk || !kindOk || !countOk;

  String get status => failed ? '✗' : (textOk ? '✓' : '≈');
}
