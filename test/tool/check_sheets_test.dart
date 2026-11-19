// Check sheets: every code flutter_zxing makes or reads, drawn into PNG
// files at many sizes and read back from those files. Skipped unless SHEETS
// names an output folder (build/ is ignored by git):
//
//   SHEETS=build/check_sheets flutter test test/tool/check_sheets_test.dart
//
// The folders:
//   1-formats/   every supported format: all-grid (square sheets),
//                all-column (one code per row), linear-grid and 2d-grid
//   2-single/    each code alone, by pixels per module (density)
//   3-content/, 4-templates/, 5-styles/, 6-hard/: real content, scanner
//                templates, styles and hard cases
// Every file is drawn at its size, not scaled, and read whole, once, as a
// file. Next to every X.png is X_read.png: each tile framed by what reading
// gave and labelled with its pixels per module. Each folder has report.md;
// index.html shows every file next to its read; tiles.md lists every tile
// with what it holds, to scan with a phone. The sizes are the lists below.
// Text uses Roboto from the Flutter SDK when FLUTTER_ROOT is set.
@Tags(<String>['native'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/src/rendering/barcode_painter.dart';

// The codes the field test of the diagnostics page knows.
// ignore: avoid_relative_lib_imports
import '../../example/lib/diagnostics/field_codes.dart';

part 'check_sheets/tiles.dart';
part 'check_sheets/views.dart';

final String? _out = Platform.environment['SHEETS'];
const String _samples = 'third_party/zxing-cpp/test/samples';

// The sizes the sheets are drawn at: edit these lists.

/// 1-formats grids: the side of the square, in pixels.
const List<int> _gridSides = <int>[
  1000,
  1500,
  2000,
  3000,
  4000,
  5000,
  7000,
  10000,
];

/// 1-formats columns: the width in pixels; the height follows the codes.
const List<int> _columnWidths = <int>[400, 720, 1080, 1440];

/// 2-single: pixels per module, from [_densityFrom] to [_densityTo] by
/// [_densityStep]. Each file is the code scaled exactly, not snapped to
/// whole pixels, so 2.5 is really 2.5 (on a screen BarcodeView draws only
/// whole pixels from 2 up).
const double _densityFrom = 0.5;
const double _densityTo = 5.0;
const double _densityStep = 0.1;
final List<double> _modulePixels = <double>[
  for (int i = 0; _densityFrom + i * _densityStep <= _densityTo + 1e-9; i++)
    ((_densityFrom + i * _densityStep) * 100).roundToDouble() / 100,
];

/// 3-content to 6-hard: the page width in pixels.
const List<int> _pageWidths = <int>[2000, 4000];

/// The sizes at which every tile is also read on its own, to make sure the
/// sheet itself is right, and the ones index.html shows first.
const int _checkGrid = 4000;
const int _checkColumn = 1080;
const int _checkPage = 4000;

// Geometry, in logical pixels.
const Size _page = Size(1600, 1000);
const double _margin = 28;
const double _header = 64;
const double _gap = 14;
const int _columns = 4;
const int _rows = 3;
const double _gridSide = 2400;
const double _gridHeader = 92;
const double _gridHeading = 58;
const double _columnWidth = 480;

/// A single code: logical pixels per module (BarcodeView with no size) and
/// the white around it.
const double _singleModule = 4;
const double _singlePad = 40;

// Colours.
const Color _ink = Color(0xFF0E1218);
const Color _muted = Color(0xFF5B6472);
const Color _paper = Color(0xFFEEF0F3);
const Color _accent = Color(0xFF00735D);
const Color _warn = Color(0xFFB45309);

/// How every file is read: whole, once, with the options for files.
const BarcodeReader _fileReader = BarcodeReader(
  options: ReaderOptions(eanAddOn: EanAddOn.read),
);

/// What reading gave for a tile.
enum _Outcome {
  read('✓', 'read', Color(0xFF16A34A)),
  offTile('↗', 'outline off its tile', Color(0xFF9333EA)),
  wrong('✗', 'read wrong', Color(0xFFDC2626)),
  missing('—', 'not found', Color(0xFFEA580C));

  const _Outcome(this.mark, this.label, this.color);
  final String mark;
  final String label;
  final Color color;

  String get css =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/// A code on a sheet and where it is, in logical pixels.
final class _Placed {
  _Placed(this.id, this.tile, this.rect);

  final String id;
  final _Tile tile;
  final Rect rect;

  /// Around the code itself: its module size is measured there.
  final GlobalKey key = GlobalKey();

  int get count => tile.codes?.length ?? 1;
}

/// A sheet, drawn once per variant.
final class _Sheet {
  _Sheet(
    this.name,
    this.title,
    this.size,
    this.placed,
    this.page,
    this.variants, {
    this.check,
    this.snap = true,
  });

  /// The file name before the size, and the sub-folder if the folder has
  /// them.
  final String name;
  final String title;
  final Size size;
  final List<_Placed> placed;
  final Widget page;

  /// The label in each file name and its device pixel ratio.
  final List<(String, double)> variants;

  /// The variant whose tiles are also read one by one.
  final String? check;

  /// Whether BarcodeView snaps modules to the file's pixels, as on a
  /// screen. If not, the sheet is laid out at a ratio of 1 and scaled.
  final bool snap;
}

/// A folder of sheets.
final class _Folder {
  _Folder(
    this.name,
    this.title,
    this.about,
    this.sheets, {
    this.subfolders = false,
    this.single = false,
  });

  final String name;
  final String title;
  final String about;
  final List<_Sheet> sheets;

  /// Each sheet in a folder of its own.
  final bool subfolders;

  /// 2-single: one table of every code by size, not one per sheet.
  final bool single;
  final List<_FileResult> results = <_FileResult>[];

  String pathOf(_Sheet sheet, String file) =>
      subfolders ? '${sheet.name}/$file' : file;
}

/// One tile of one file.
final class _TileResult {
  const _TileResult(this.placed, this.modulePx, this.outcome, this.detail);

  final _Placed placed;

  /// Pixels per module of the code as drawn, or null for a sample image.
  final double? modulePx;
  final _Outcome outcome;
  final String? detail;

  String get cell => '${outcome.mark} ${_pxText(modulePx)}'.trim();
}

/// One file and what reading it gave.
final class _FileResult {
  const _FileResult(
    this.sheet,
    this.label,
    this.width,
    this.height,
    this.ms,
    this.tiles,
    this.stray,
  );

  final _Sheet sheet;
  final String label;
  final int width;
  final int height;

  /// Time to read the file, decoding it included.
  final int ms;
  final List<_TileResult> tiles;

  /// Reads that belong to no tile.
  final List<String> stray;

  String get file => '${sheet.name}_$label.png';
  String get readFile => '${sheet.name}_${label}_read.png';
  int count(_Outcome o) =>
      tiles.where((_TileResult t) => t.outcome == o).length;
  _TileResult tile(String id) =>
      tiles.firstWhere((_TileResult t) => t.placed.id == id);

  Map<String, Object> toJson() => <String, Object>{
    'width': width,
    'height': height,
    'total': tiles.length,
    for (final _Outcome o in _Outcome.values) o.name: count(o),
    'other': stray.length,
    'ms': ms,
    'tiles': <String, String>{
      for (final _TileResult t in tiles) t.placed.id: t.outcome.name,
    },
  };
}

String _pxText(double? px) => px == null ? '' : '${px.toStringAsFixed(1)} px';

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

Rect _px(Rect r, double dpr) =>
    Rect.fromLTRB(r.left * dpr, r.top * dpr, r.right * dpr, r.bottom * dpr);

String _describe(Barcode b) {
  final String text = _visible(b.text);
  return '${b.format.displayName} “${text.length > 40 ? '${text.substring(0, 39)}…' : text}”';
}

/// Tiles under a heading.
typedef _Group = (String heading, String about, List<(String, _Tile)> tiles);

/// Places [tiles] in rows of [columns] from [top]; gives their places and
/// the bottom. A tile in [tall] takes two rows: a code keeps its proportions,
/// so only height lets its bars grow. A tile in [rowStarts] starts a row.
(List<Rect>, double) _gridRects(
  List<_Tile> tiles,
  double top, {
  required int columns,
  required double row,
  Set<BarcodeFormat> tall = const <BarcodeFormat>{},
  Set<BarcodeFormat> rowStarts = const <BarcodeFormat>{},
}) {
  final double cell =
      (_gridSide - 2 * _margin - (columns - 1) * _gap) / columns;
  final List<Rect> rects = <Rect>[];
  int column = 0;
  double rowTop = top;
  double rowHeight = 0;
  for (final _Tile tile in tiles) {
    if (column + tile.span > columns ||
        (column > 0 && rowStarts.contains(tile.format))) {
      column = 0;
      rowTop += rowHeight + _gap;
      rowHeight = 0;
    }
    final double height = tall.contains(tile.format) ? 2 * row + _gap : row;
    rects.add(
      Rect.fromLTWH(
        _margin + column * (cell + _gap),
        rowTop,
        tile.span * cell + (tile.span - 1) * _gap,
        height,
      ),
    );
    rowHeight = math.max(rowHeight, height);
    column += tile.span;
  }
  return (rects, rowTop + rowHeight + _gap);
}

Widget _heading(String title, String about, double size) => Text.rich(
  TextSpan(
    children: <InlineSpan>[
      TextSpan(
        text: title,
        style: _text.copyWith(fontSize: size, fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: '   $about',
        style: _text.copyWith(fontSize: size * 0.62, color: _muted),
      ),
    ],
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);

/// A square sheet of [groups], the rows as high as makes it square.
_Sheet _gridSheet(
  String name,
  String title,
  List<_Group> groups,
  Map<String, ui.Image> images, {
  required int columns,
  Set<BarcodeFormat> tall = const <BarcodeFormat>{},
  Set<BarcodeFormat> rowStarts = const <BarcodeFormat>{},
}) {
  (List<List<Rect>>, List<double>, double) layout(double row) {
    double y = _gridHeader;
    final List<List<Rect>> rects = <List<Rect>>[];
    final List<double> tops = <double>[];
    for (final _Group g in groups) {
      y += _gridHeading;
      tops.add(y);
      final (List<Rect> r, double end) = _gridRects(
        <_Tile>[for (final (String _, _Tile t) in g.$3) t],
        y,
        columns: columns,
        row: row,
        tall: tall,
        rowStarts: rowStarts,
      );
      rects.add(r);
      y = end;
    }
    return (rects, tops, y - _gap + _margin);
  }

  // The height grows linearly with the row: solve for a square.
  final double h1 = layout(100).$3;
  final double h2 = layout(200).$3;
  final double row = 100 + (_gridSide - h1) * 100 / (h2 - h1);
  final (List<List<Rect>> rects, List<double> tops, double height) = layout(
    row,
  );
  final List<_Placed> placed = <_Placed>[
    for (int g = 0; g < groups.length; g++)
      for (int i = 0; i < groups[g].$3.length; i++)
        _Placed(groups[g].$3[i].$1, groups[g].$3[i].$2, rects[g][i]),
  ];
  final Widget page = ColoredBox(
    color: _paper,
    child: Stack(
      children: <Widget>[
        Positioned(
          left: _margin,
          right: _margin,
          top: 20,
          child: Text(
            'flutter_zxing 4.0 · $title',
            style: _text.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
        for (int g = 0; g < groups.length; g++)
          Positioned(
            left: _margin,
            right: _margin,
            top: tops[g] - _gridHeading + 12,
            child: _heading(groups[g].$1, groups[g].$2, 24),
          ),
        for (final _Placed p in placed)
          Positioned.fromRect(
            rect: p.rect,
            child: _overviewTile(p.id, p.tile, images, p.key),
          ),
      ],
    ),
  );
  return _Sheet(
    name,
    title,
    Size(_gridSide, height),
    placed,
    page,
    <(String, double)>[
      for (final int side in _gridSides)
        (side.toString().padLeft(5, '0'), side / _gridSide),
    ],
    check: _checkGrid.toString().padLeft(5, '0'),
  );
}

/// One code per row, as a phone screen shows a list.
_Sheet _columnSheet(
  String name,
  String title,
  List<_Group> groups,
  Map<String, ui.Image> images,
) {
  const double side = 16;
  const double top = 56;
  const double heading = 40;
  const double between = 10;
  double y = top;
  final List<double> tops = <double>[];
  final List<_Placed> placed = <_Placed>[];
  for (final _Group g in groups) {
    tops.add(y);
    y += heading;
    for (final (String id, _Tile t) in g.$3) {
      final double h = t.format.isLinear ? 150 : 240;
      placed.add(
        _Placed(id, t, Rect.fromLTWH(side, y, _columnWidth - 2 * side, h)),
      );
      y += h + between;
    }
  }
  final Size size = Size(_columnWidth, y - between + side);
  final Widget page = ColoredBox(
    color: _paper,
    child: Stack(
      children: <Widget>[
        Positioned(
          left: side,
          right: side,
          top: 14,
          child: Text(
            'flutter_zxing 4.0 · $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        for (int g = 0; g < groups.length; g++)
          Positioned(
            left: side,
            right: side,
            top: tops[g] + 8,
            child: _heading(groups[g].$1, groups[g].$2, 16),
          ),
        for (final _Placed p in placed)
          Positioned.fromRect(
            rect: p.rect,
            child: _overviewTile(p.id, p.tile, images, p.key),
          ),
      ],
    ),
  );
  return _Sheet(name, title, size, placed, page, <(String, double)>[
    for (final int w in _columnWidths)
      ('w${w.toString().padLeft(4, '0')}', w / _columnWidth),
  ], check: 'w${_checkColumn.toString().padLeft(4, '0')}');
}

/// The pages of a section, as they always were.
List<_Sheet> _sectionSheets(_Section section, Map<String, ui.Image> images) {
  final (String letter, String title, String about, List<_Tile> tiles) =
      section;
  final List<(int, List<_Tile>, List<Rect>)> parts = _paginate(tiles);
  return <_Sheet>[
    for (int part = 0; part < parts.length; part++)
      () {
        final (int first, List<_Tile> pageTiles, List<Rect> rects) =
            parts[part];
        final String heading = parts.length > 1
            ? '$title (${part + 1}/${parts.length})'
            : title;
        final List<_Placed> placed = <_Placed>[
          for (int i = 0; i < pageTiles.length; i++)
            _Placed('$letter${first + i + 1}', pageTiles[i], rects[i]),
        ];
        final Widget page = ColoredBox(
          color: _paper,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: _margin,
                right: _margin,
                top: 18,
                height: _header,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$letter  ',
                      style: _text.copyWith(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: _accent,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            heading,
                            style: _text.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            about,
                            style: _text.copyWith(fontSize: 14, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'flutter_zxing 4.0 · check sheet',
                      style: _text.copyWith(fontSize: 13, color: _muted),
                    ),
                  ],
                ),
              ),
              for (final _Placed p in placed)
                Positioned.fromRect(
                  rect: p.rect,
                  child: _tile(p.id, p.tile, images, p.key),
                ),
            ],
          ),
        );
        return _Sheet(
          '$letter-${_slug(title)}${parts.length > 1 ? '-${part + 1}' : ''}',
          '$letter · $heading',
          _page,
          placed,
          page,
          <(String, double)>[
            for (final int w in _pageWidths)
              (w.toString().padLeft(5, '0'), w / _page.width),
          ],
          check: _checkPage.toString().padLeft(5, '0'),
        );
      }(),
  ];
}

/// A code alone on white; [codeSize] is its size at [_singleModule].
_Sheet _singleSheet(
  String id,
  _Tile tile,
  Size codeSize,
  Map<String, ui.Image> images,
) {
  final Size size = Size(
    codeSize.width + 2 * _singlePad,
    codeSize.height + 2 * _singlePad,
  );
  final _Placed placed = _Placed(id, tile, Offset.zero & size);
  return _Sheet(
    '$id-${_slug(tile.title)}',
    '$id ${tile.title}',
    size,
    <_Placed>[placed],
    ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: Center(child: _singleCode(tile, images, placed.key)),
    ),
    <(String, double)>[
      for (final double m in _modulePixels)
        ('m${m.toStringAsFixed(1)}', m / _singleModule),
    ],
    snap: false,
  );
}

/// The code at [_singleModule] logical pixels per module.
Widget _singleCode(_Tile tile, Map<String, ui.Image> images, Key key) =>
    UnconstrainedBox(
      child: KeyedSubtree(key: key, child: _code(tile, images)),
    );

/// The smallest pixels per module of the codes under [key].
double? _moduleOf(GlobalKey key, double dpr) {
  double? least;
  for (final Element e
      in find
          .descendant(of: find.byKey(key), matching: find.byType(CustomPaint))
          .evaluate()) {
    final CustomPainter? painter = (e.widget as CustomPaint).painter;
    if (painter is BarcodePainter) {
      final Size size = (e.renderObject! as RenderBox).size;
      final double m = painter.moduleSize(size) * dpr;
      least = least == null ? m : math.min(least, m);
    }
  }
  return least;
}

/// Shows [page] at [dpr] and gives every BarcodeView time to paint. With
/// [snap] off, BarcodeView sees a ratio of 1 and does not snap to [dpr].
Future<GlobalKey> _show(
  WidgetTester tester,
  Widget page,
  Size size,
  double dpr, {
  bool snap = true,
}) async {
  tester.view
    ..devicePixelRatio = dpr
    ..physicalSize = size * dpr;
  final GlobalKey boundary = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, devicePixelRatio: snap ? dpr : 1),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: _text,
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox.fromSize(size: size, child: page),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return boundary;
}

/// Which tile each read belongs to, and how each tile went. A read counts
/// for the tile it lies in; one with the right text lying elsewhere counts
/// for its tile as off its tile (zxing-cpp gives some codes a wrong
/// outline); anything else is wrong.
(List<_TileResult>, List<(Barcode, _Outcome)>, List<String>) _classify(
  List<_Placed> placed,
  double dpr,
  List<Barcode> found,
  Map<String, double?> modules,
) {
  bool fits(_Tile t, Barcode b) =>
      b.format.symbology == t.format.symbology &&
      (!t.exact || b.text.trim() == t.expectedText.trim());
  final Map<String, List<Barcode>> hits = <String, List<Barcode>>{
    for (final _Placed p in placed) p.id: <Barcode>[],
  };
  final Map<String, List<Barcode>> off = <String, List<Barcode>>{
    for (final _Placed p in placed) p.id: <Barcode>[],
  };
  final Map<String, List<Barcode>> wrong = <String, List<Barcode>>{
    for (final _Placed p in placed) p.id: <Barcode>[],
  };
  final List<(Barcode, _Outcome)> marks = <(Barcode, _Outcome)>[];
  final List<(Barcode, _Placed?)> loose = <(Barcode, _Placed?)>[];
  for (final Barcode b in found) {
    final List<Offset> c = b.position.corners;
    final Offset middle = (c[0] + c[1] + c[2] + c[3]) / 4;
    final _Placed? t = placed
        .where((_Placed p) => _px(p.rect, dpr).contains(middle))
        .firstOrNull;
    if (t != null && fits(t.tile, b)) {
      // A second read of a code already found adds nothing.
      if (hits[t.id]!.length < t.count) {
        hits[t.id]!.add(b);
        marks.add((b, _Outcome.read));
      }
      continue;
    }
    loose.add((b, t));
  }
  final List<String> stray = <String>[];
  for (final (Barcode b, _Placed? t) in loose) {
    final List<_Placed> owners =
        placed
            .where(
              (_Placed u) =>
                  fits(u.tile, b) &&
                  hits[u.id]!.length + off[u.id]!.length < u.count,
            )
            .toList()
          ..sort(
            (_Placed u, _Placed v) => (u.tile.format == b.format ? 0 : 1)
                .compareTo(v.tile.format == b.format ? 0 : 1),
          );
    if (owners.isNotEmpty) {
      off[owners.first.id]!.add(b);
      marks.add((b, _Outcome.offTile));
    } else if (placed.any((_Placed u) => fits(u.tile, b))) {
      // Another read of a code already found.
    } else if (t != null) {
      wrong[t.id]!.add(b);
      marks.add((b, _Outcome.wrong));
    } else {
      stray.add(_describe(b));
      marks.add((b, _Outcome.wrong));
    }
  }
  final List<_TileResult> tiles = <_TileResult>[
    for (final _Placed p in placed)
      () {
        final int h = hits[p.id]!.length;
        final int o = off[p.id]!.length;
        final (_Outcome outcome, String? detail) = h >= p.count
            ? (_Outcome.read, null)
            : h + o >= p.count
            ? (_Outcome.offTile, 'outline off its tile')
            : wrong[p.id]!.isNotEmpty
            ? (
                _Outcome.wrong,
                'read as ${wrong[p.id]!.map(_describe).join('; ')}',
              )
            : (
                _Outcome.missing,
                h + o > 0 ? 'found ${h + o}/${p.count}' : null,
              );
        return _TileResult(p, modules[p.id], outcome, detail);
      }(),
  ];
  return (tiles, marks, stray);
}

/// [image] with every tile framed by its outcome and labelled, and every
/// read outlined.
Future<Uint8List> _annotate(
  ui.Image image,
  double dpr,
  List<_TileResult> tiles,
  List<(Barcode, _Outcome)> marks,
) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder)
    ..drawImage(image, Offset.zero, Paint());
  for (final _TileResult t in tiles) {
    final Rect rect = _px(t.placed.rect, dpr);
    final double font = math
        .min(rect.shortestSide / 9, image.width / 110)
        .clamp(9, 44);
    final double stroke = (font / 5).clamp(1.5, 8);
    canvas.drawRect(
      rect.deflate(stroke / 2),
      Paint()
        ..color = t.outcome.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final ui.Paragraph label =
        (ui.ParagraphBuilder(
                ui.ParagraphStyle(fontFamily: 'Roboto', fontSize: font),
              )
              ..pushStyle(
                ui.TextStyle(
                  color: const Color(0xFFFFFFFF),
                  background: Paint()..color = t.outcome.color,
                  fontWeight: FontWeight.bold,
                ),
              )
              ..addText(
                ' ${t.placed.id} ${_pxText(t.modulePx)}'
                '${t.outcome == _Outcome.read ? '' : ' · ${t.outcome.label}'} ',
              ))
            .build()
          ..layout(ui.ParagraphConstraints(width: math.max(rect.width, 160)));
    canvas.drawParagraph(
      label,
      Offset(rect.left + stroke, rect.bottom - stroke - label.height),
    );
  }
  for (final (Barcode b, _Outcome o) in marks) {
    final double stroke = math.max(2, image.width / 800);
    canvas.drawPath(
      Path()..addPolygon(b.position.corners, true),
      Paint()
        ..color = o.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
  }
  final ui.Image drawn = await recorder.endRecording().toImage(
    image.width,
    image.height,
  );
  final ByteData png = (await drawn.toByteData(
    format: ui.ImageByteFormat.png,
  ))!;
  drawn.dispose();
  return png.buffer.asUint8List();
}

/// Draws [sheet] at one variant, writes the file, reads it and writes what
/// reading gave next to it. At the sheet's check variant, every tile is also
/// read on its own into [checks].
Future<_FileResult> _drawAndRead(
  WidgetTester tester,
  Directory dir,
  _Sheet sheet,
  String label,
  double dpr,
  List<_Check> checks,
) async {
  final GlobalKey boundary = await _show(
    tester,
    sheet.page,
    sheet.size,
    dpr,
    snap: sheet.snap,
  );
  final Map<String, double?> modules = <String, double?>{
    for (final _Placed p in sheet.placed) p.id: _moduleOf(p.key, dpr),
  };
  final Map<String, Rect> areas = <String, Rect>{
    if (label == sheet.check)
      for (final _Placed p in sheet.placed)
        p.id: _px(tester.getRect(find.byKey(p.key)), dpr),
  };
  final RenderRepaintBoundary render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final String stem = '${dir.path}/${sheet.name}_$label';
  return (await tester.runAsync<_FileResult>(() async {
    final ui.Image image = await render.toImage(pixelRatio: dpr);
    final Uint8List png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    File('$stem.png').writeAsBytesSync(png);
    if (areas.isNotEmpty) {
      final ByteData rgba = (await image.toByteData())!;
      for (final _Placed p in sheet.placed) {
        final List<Barcode> found = await _fileReader.readAllPixels(
          PixelBuffer(
            rgba.buffer.asUint8List(),
            width: image.width,
            height: image.height,
            layout: PixelLayout.rgba,
            crop: areas[p.id],
          ),
        );
        checks.add(_Check(p.id, p.tile, found));
      }
    }
    final Stopwatch watch = Stopwatch()..start();
    final List<Barcode> found = await _fileReader.readAll(png);
    watch.stop();
    final (
      List<_TileResult> tiles,
      List<(Barcode, _Outcome)> marks,
      List<String> stray,
    ) = _classify(
      sheet.placed,
      dpr,
      found,
      modules,
    );
    File(
      '${stem}_read.png',
    ).writeAsBytesSync(await _annotate(image, dpr, tiles, marks));
    final _FileResult result = _FileResult(
      sheet,
      label,
      image.width,
      image.height,
      watch.elapsedMilliseconds,
      tiles,
      stray,
    );
    image.dispose();
    return result;
  }))!;
}

/// How many variants [id] was read at, as "6/8".
String _readCount(List<_FileResult> results, String id) {
  final int read = results
      .where((_FileResult r) => r.tile(id).outcome == _Outcome.read)
      .length;
  return '$read/${results.length}';
}

/// The first variant from which [id] reads at every larger one.
String _readsFrom(List<_FileResult> results, String id) {
  String from = '—';
  for (final _FileResult r in results.reversed) {
    if (r.tile(id).outcome != _Outcome.read) {
      break;
    }
    from = r.label;
  }
  return from;
}

/// "m1.5" as "1.5".
String _density(String label) =>
    label.startsWith('m') ? label.substring(1) : label;

String _md(String s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ');

String _secondsText(int ms) => '${(ms / 1000).toStringAsFixed(2)} s';

const String _legend =
    '✓ read · ↗ read, but zxing-cpp gives an outline off its tile · '
    '✗ read wrong · — not found. The number is pixels per module as drawn.';

/// report.md of [folder].
String _folderReport(_Folder folder, Map<String, dynamic>? baseline) {
  final StringBuffer md = StringBuffer()
    ..writeln('# ${folder.title}')
    ..writeln()
    ..writeln(folder.about)
    ..writeln()
    ..writeln(
      'Every file is read whole, once, as a file, with '
      '`ReaderOptions(eanAddOn: EanAddOn.read)`. $_legend',
    )
    ..writeln();
  if (folder.single) {
    final List<String> labels = <String>[
      for (final (String l, double _) in folder.sheets.first.variants) l,
    ];
    md
      ..writeln(
        '| code | ${labels.map(_density).join(' | ')} | read | reads from |',
      )
      ..writeln('|---|${'---|' * labels.length}---|---|');
    for (final _Sheet s in folder.sheets) {
      final List<_FileResult> rs = folder.results
          .where((_FileResult r) => r.sheet == s)
          .toList();
      final String id = s.placed.single.id;
      md.writeln(
        '| **$id** ${_md(s.placed.single.tile.title)} '
        '| ${rs.map((_FileResult r) => r.tile(id).outcome.mark).join(' | ')} '
        '| ${_readCount(rs, id)} | ${_density(_readsFrom(rs, id))} |',
      );
    }
    return md.toString();
  }
  for (final _Sheet s in folder.sheets) {
    final List<_FileResult> rs = folder.results
        .where((_FileResult r) => r.sheet == s)
        .toList();
    md
      ..writeln('## ${s.title}')
      ..writeln()
      ..writeln(
        '| file | pixels | read | outline off | wrong | not found | other reads | time${baseline == null ? '' : ' | baseline read'} |',
      )
      ..writeln(
        '|---|---|---|---|---|---|---|---|${baseline == null ? '' : '---|'}',
      );
    for (final _FileResult r in rs) {
      final Object? b =
          ((baseline?[folder.name] as Map<String, dynamic>?)?[s.name]
                  as Map<String, dynamic>?)?[r.label]
              is Map<String, dynamic>
          ? (((baseline![folder.name] as Map<String, dynamic>)[s.name]
                    as Map<String, dynamic>)[r.label]
                as Map<String, dynamic>)['read']
          : null;
      md.writeln(
        '| [${r.label}](${folder.pathOf(s, r.readFile)}) | ${r.width} × ${r.height} '
        '| ${r.count(_Outcome.read)}/${r.tiles.length} | ${r.count(_Outcome.offTile)} '
        '| ${r.count(_Outcome.wrong)} | ${r.count(_Outcome.missing)} | ${r.stray.length} '
        '| ${_secondsText(r.ms)}${baseline == null ? '' : ' | ${b ?? '—'}'} |',
      );
    }
    md
      ..writeln()
      ..writeln(
        '| tile | format | ${rs.map((_FileResult r) => r.label).join(' | ')} | read |',
      )
      ..writeln('|---|---|${'---|' * rs.length}---|');
    for (final _Placed p in s.placed) {
      md.writeln(
        '| **${p.id}** ${_md(p.tile.title)} | ${p.tile.format.displayName} '
        '| ${rs.map((_FileResult r) => r.tile(p.id).cell).join(' | ')} '
        '| ${_readCount(rs, p.id)} |',
      );
    }
    final List<String> notes = <String>[
      for (final _FileResult r in rs) ...<String>[
        for (final _TileResult t in r.tiles)
          if (t.detail != null)
            '${r.label} **${t.placed.id}**: ${_md(t.detail!)}',
        for (final String x in r.stray)
          '${r.label}: outside the tiles, ${_md(x)}',
      ],
    ];
    if (notes.isNotEmpty) {
      md.writeln();
      for (final String n in notes) {
        md.writeln('- $n');
      }
    }
    md.writeln();
  }
  return md.toString();
}

/// index.html: every file next to its read, and per code how many sizes it
/// was read at.
String _index(List<_Folder> folders) {
  const HtmlEscape esc = HtmlEscape();
  String e(String s) => esc.convert(s);
  String mark(_TileResult t) =>
      '<td class="c" style="background:${t.outcome.css}" title="${e(t.outcome.label)}${t.detail == null ? '' : ': ${e(t.detail!)}'}">${e(t.cell)}</td>';
  String image(String src) =>
      '<a href="${e(src)}"><img loading="lazy" src="${e(src)}" alt=""></a>';
  String figure(String caption, String file, String read) =>
      '<figure><figcaption>${e(caption)}</figcaption>'
      '<div class="two">${image(file)}${image(read)}</div></figure>';
  final StringBuffer h = StringBuffer()
    ..writeln('''
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Check sheets</title>
<style>
  body { margin: 0; background: #1b1f24; color: #e8eaed; font: 14px -apple-system, system-ui, sans-serif; }
  nav { position: sticky; top: 0; z-index: 1; display: flex; flex-wrap: wrap; gap: 6px; padding: 10px 16px; background: #1b1f24ee; }
  nav a, a { color: #9cc7ff; }
  nav a { text-decoration: none; padding: 4px 10px; border-radius: 6px; background: #2c323a; color: #e8eaed; }
  section { padding: 8px 16px 24px; }
  h2 { margin: 18px 0 4px; font-size: 20px; }
  h3 { margin: 18px 0 6px; font-size: 16px; }
  p { color: #aab2bd; margin: 4px 0 10px; }
  .wrap { overflow-x: auto; }
  table { border-collapse: collapse; margin: 6px 0 12px; font-size: 12px; }
  th, td { border: 1px solid #333a43; padding: 3px 6px; text-align: left; white-space: nowrap; }
  td.c { color: #fff; font-weight: 600; text-align: center; }
  table.dense td.c, table.dense th { padding: 3px 2px; min-width: 18px; text-align: center; }
  .pairs { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 640px), 1fr)); gap: 12px; }
  figure { margin: 0; background: #23282f; border-radius: 8px; padding: 8px; }
  figcaption { margin-bottom: 6px; }
  .two { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
  .two img { width: 100%; height: auto; background: #fff; border-radius: 4px; }
</style></head><body>''')
    ..writeln(
      '<nav>${folders.map((_Folder f) => '<a href="#${e(f.name)}">${e(f.name)}</a>').join()}<a href="tiles.md">tiles.md</a></nav>',
    )
    ..writeln(
      '<section><p>${e(_legend)} Each pair: the file, then what reading it found. Click an image for full size.</p></section>',
    );
  for (final _Folder f in folders) {
    h.writeln(
      '<section id="${e(f.name)}"><h2>${e(f.title)}</h2><p>${e(f.about)} <a href="${e(f.name)}/report.md">report.md</a></p>',
    );
    if (f.single) {
      final List<String> labels = <String>[
        for (final (String l, double _) in f.sheets.first.variants) l,
      ];
      h
        ..writeln(
          '<p>Pixels per module across, each code down. Click a cell for what reading that file found.</p>',
        )
        ..writeln(
          '<div class="wrap"><table class="dense"><tr><th>code</th>${labels.map((String l) => '<th>${e(_density(l))}</th>').join()}<th>read</th><th>reads from</th></tr>',
        );
      for (final _Sheet s in f.sheets) {
        final List<_FileResult> rs = f.results
            .where((_FileResult r) => r.sheet == s)
            .toList();
        final String id = s.placed.single.id;
        String cell(_FileResult r) {
          final _TileResult t = r.tile(id);
          final String title =
              '${_density(r.label)} px · ${t.outcome.label}'
              '${t.detail == null ? '' : ': ${t.detail!}'}';
          final String href = '${f.name}/${f.pathOf(s, r.readFile)}';
          final String link =
              '<a style="color:#fff;text-decoration:none" href="${e(href)}">${e(t.outcome.mark)}</a>';
          return '<td class="c" style="background:${t.outcome.css}" title="${e(title)}">$link</td>';
        }

        h.writeln(
          '<tr><td><b>${e(id)}</b> ${e(s.placed.single.tile.title)}</td>'
          '${rs.map(cell).join()}'
          '<td>${_readCount(rs, id)}</td><td>${e(_density(_readsFrom(rs, id)))}</td></tr>',
        );
      }
      h.writeln('</table></div></section>');
      continue;
    }
    for (final _Sheet s in f.sheets) {
      final List<_FileResult> rs = f.results
          .where((_FileResult r) => r.sheet == s)
          .toList();
      h
        ..writeln('<h3>${e(s.title)}</h3><div class="wrap"><table>')
        ..writeln(
          '<tr><th>code</th><th>format</th>${rs.map((_FileResult r) => '<th>${e(r.label)}<br><small>${r.count(_Outcome.read)}/${r.tiles.length} · ${_secondsText(r.ms)}</small></th>').join()}<th>read</th></tr>',
        );
      for (final _Placed p in s.placed) {
        h.writeln(
          '<tr><td><b>${e(p.id)}</b> ${e(p.tile.title)}</td><td>${e(p.tile.format.displayName)}</td>'
          '${rs.map((_FileResult r) => mark(r.tile(p.id))).join()}<td>${_readCount(rs, p.id)}</td></tr>',
        );
      }
      h
        ..writeln('</table></div>')
        ..writeln('<div class="pairs">');
      for (final _FileResult r in rs) {
        final String file = '${f.name}/${f.pathOf(s, r.file)}';
        final String read = '${f.name}/${f.pathOf(s, r.readFile)}';
        h.writeln(
          figure(
            '${r.label} · ${r.width} × ${r.height} · read '
            '${r.count(_Outcome.read)}/${r.tiles.length}'
            '${r.stray.isEmpty ? '' : ' · ${r.stray.length} other reads'}',
            file,
            read,
          ),
        );
      }
      h.writeln('</div>');
    }
    h.writeln('</section>');
  }
  h.writeln('</body></html>');
  return h.toString();
}

/// tiles.md: every tile once, what it holds and what reading it alone gave.
String _tilesReport(List<(_Folder, _Sheet, List<_Check>)> checked) {
  final StringBuffer md = StringBuffer()
    ..writeln('# flutter_zxing 4.0 · check sheet tiles')
    ..writeln()
    ..writeln(
      '✓ read back as drawn · ≈ read, text differs (expected for some formats) · ✗ broken tile. '
      'Each tile read on its own from the file named. Scan each tile with the demo and tick the last column.',
    )
    ..writeln();
  for (final (_Folder f, _Sheet s, List<_Check> checks) in checked) {
    md
      ..writeln(
        '## ${s.title} (${f.name}/${f.pathOf(s, '${s.name}_${s.check}.png')})',
      )
      ..writeln()
      ..writeln('| | Tile | Format | Expect | Read back | Data | Phone |')
      ..writeln('|---|---|---|---|---|---|---|');
    for (final _Check c in checks) {
      final Barcode? b = c.first;
      final String read = b == null
          ? 'not read'
          : '${c.status} ${b.format.displayName} · ${b.content.runtimeType}'
                '${c.tile.codes != null ? ' · ${c.found.length} codes' : ''}'
                '${b.ecLevel != null && b.ecLevel!.isNotEmpty ? ' · ECC ${b.ecLevel}' : ''}'
                '${b.isMirrored ? ' · mirrored' : ''}${b.isInverted ? ' · inverted' : ''}';
      final String data = c.tile.bytes != null
          ? '(binary)'
          : _visible(c.tile.data);
      md.writeln(
        '| **${c.id}** | ${_md(c.tile.title)}${c.tile.note != null ? '<br><sub>${_md(c.tile.note!)}</sub>' : ''} '
        '| ${c.tile.format.displayName} | ${_kindName(c.tile.kind)} | ${_md(read)} '
        '| `${_md(data.length > 60 ? '${data.substring(0, 60)}…' : data)}` | ☐ |',
      );
    }
    md.writeln();
  }
  return md.toString();
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await warmUpBarcodeEngine();
  });

  testWidgets(
    'check sheets',
    (WidgetTester tester) async {
      final Directory root = Directory(_out!)..createSync(recursive: true);
      // Start clean, keeping only the baseline to compare with.
      for (final FileSystemEntity e in root.listSync()) {
        if (e.uri.pathSegments.where((String s) => s.isNotEmpty).last !=
            'baseline.json') {
          e.deleteSync(recursive: true);
        }
      }
      addTearDown(tester.view.reset);

      final Uint8List logo = (await tester.runAsync(_logoPng))!;
      final List<_Section> sections = _sections(logo);

      // Every format the writer makes is on a sheet.
      expect(
        BarcodeFormat.writable.difference(<BarcodeFormat>{
          for (final _Section s in sections)
            for (final _Tile t in s.$4)
              if (t.sample == null) t.format,
        }),
        isEmpty,
        reason: 'a writable format has no tile',
      );
      final List<_Tile> written = _writtenTiles(sections);
      final List<(BarcodeFormat, _Tile)> readOnly = _readOnlyTiles();
      expect(
        <BarcodeFormat>{
          for (final BarcodeFormat f in BarcodeFormat.values)
            if (f.canRead && !f.canWrite) f,
        }.difference(<BarcodeFormat>{
          for (final (BarcodeFormat f, _Tile _) in readOnly) f,
        }),
        isEmpty,
        reason: 'a format the scanner only reads has no tile',
      );
      final List<_Tile> others = <_Tile>[
        for (final (BarcodeFormat _, _Tile t) in readOnly) t,
      ];

      final Map<String, ui.Image> images = <String, ui.Image>{};
      await tester.runAsync(() async {
        for (final _Tile t in <_Tile>[
          ...others,
          for (final _Section s in sections) ...s.$4,
        ]) {
          if (t.sample case final String path) {
            images[path] ??= await decodeImageFromList(
              File(path).readAsBytesSync(),
            );
          }
        }
      });

      List<_Group> groups(bool Function(_Tile) keep) => <_Group>[
        (
          'Made by flutter_zxing',
          'drawn by BarcodeWriter',
          <(String, _Tile)>[
            for (final (int i, _Tile t) in written.indexed)
              if (keep(t)) ('W${i + 1}', t),
          ],
        ),
        (
          'Read only',
          'the scanner reads these, the writer has no such format',
          <(String, _Tile)>[
            for (final (int i, _Tile t) in others.indexed)
              if (keep(t)) ('R${i + 1}', t),
          ],
        ),
      ];
      bool all(_Tile t) => true;

      // 2-single: the size of each drawn code at _singleModule.
      final List<(String, _Tile)> singles = <(String, _Tile)>[
        for (final _Group g in groups((_Tile t) => t.sample == null)) ...g.$3,
      ];
      final Map<String, Size> singleSizes = <String, Size>{};
      for (final (String id, _Tile t) in singles) {
        final GlobalKey key = GlobalKey();
        await _show(
          tester,
          Center(child: _singleCode(t, images, key)),
          const Size(8000, 4000),
          1,
        );
        singleSizes[id] = tester.getSize(find.byKey(key));
      }

      const Set<BarcodeFormat> tall = <BarcodeFormat>{
        BarcodeFormat.code39Extended,
        BarcodeFormat.code93,
      };
      final List<_Folder> folders = <_Folder>[
        _Folder(
          '1-formats',
          'Every supported format',
          'Codes the writer makes (W) and the scanner only reads (R). '
              'Square sheets from ${_gridSides.first} to ${_gridSides.last} px, '
              'one code per row from ${_columnWidths.first} to ${_columnWidths.last} px wide, '
              'and the linear and 2D codes apart.',
          <_Sheet>[
            _gridSheet(
              'all-grid',
              'all formats',
              groups(all),
              images,
              columns: 7,
              tall: tall,
              rowStarts: const <BarcodeFormat>{
                BarcodeFormat.code39Extended,
                BarcodeFormat.codabar,
                BarcodeFormat.itf,
              },
            ),
            _columnSheet(
              'all-column',
              'all formats, one per row',
              groups(all),
              images,
            ),
            _gridSheet(
              'linear-grid',
              'linear formats',
              groups((_Tile t) => t.format.isLinear),
              images,
              columns: 4,
            ),
            _gridSheet(
              '2d-grid',
              '2D formats',
              groups((_Tile t) => !t.format.isLinear),
              images,
              columns: 4,
            ),
          ],
          subfolders: true,
        ),
        _Folder(
          '2-single',
          'Each code alone',
          'One code per file, from $_densityFrom to $_densityTo pixels per module '
              'by $_densityStep. Each file is the code scaled exactly, not '
              'snapped to whole pixels. Sample images (MaxiCode, QR Model 1, '
              'EAN-5) are not drawn, so they are not here.',
          <_Sheet>[
            for (final (String id, _Tile t) in singles)
              _singleSheet(id, t, singleSizes[id]!, images),
          ],
          subfolders: true,
          single: true,
        ),
        for (final (String name, String title, String about, String letters)
            in const <(String, String, String, String)>[
              (
                '3-content',
                'Content',
                'Real data: links, contacts, payments, documents.',
                'EFGH',
              ),
              (
                '4-templates',
                'Scanner templates',
                'Codes the scanner templates are made for.',
                'IJ',
              ),
              (
                '5-styles',
                'Styles',
                'BarcodeView styles, logos, captions and cards.',
                'K',
              ),
              ('6-hard', 'Hard cases', 'Limits of the reader.', 'L'),
            ])
          _Folder(
            name,
            title,
            '$about Pages ${_pageWidths.join(' and ')} px wide.',
            <_Sheet>[
              for (final _Section s in sections)
                if (letters.contains(s.$1)) ..._sectionSheets(s, images),
            ],
          ),
      ];

      final List<(_Folder, _Sheet, List<_Check>)> checked =
          <(_Folder, _Sheet, List<_Check>)>[];
      for (final _Folder f in folders) {
        for (final _Sheet s in f.sheets) {
          final Directory dir = Directory(
            '${root.path}/${f.name}/${f.pathOf(s, '')}'.replaceAll(
              RegExp(r'/$'),
              '',
            ),
          )..createSync(recursive: true);
          final List<_Check> checks = <_Check>[];
          for (final (String label, double dpr) in s.variants) {
            f.results.add(
              await _drawAndRead(tester, dir, s, label, dpr, checks),
            );
          }
          if (checks.isNotEmpty) {
            checked.add((f, s, checks));
          }
          if (!f.single) {
            // ignore: avoid_print
            print(
              '${f.name}/${s.name}: ${f.results.where((_FileResult r) => r.sheet == s).map((_FileResult r) => '${r.label} ${r.count(_Outcome.read)}/${r.tiles.length}').join(' · ')}',
            );
          }
        }
        if (f.single) {
          // ignore: avoid_print
          print(
            '${f.name}: ${f.sheets.map((_Sheet s) => '${s.placed.single.id} from ${_readsFrom(f.results.where((_FileResult r) => r.sheet == s).toList(), s.placed.single.id)}').join(' · ')}',
          );
        }
      }
      for (final ui.Image image in images.values) {
        image.dispose();
      }

      final File baselineFile = File('${root.path}/baseline.json');
      final Map<String, dynamic>? baseline = baselineFile.existsSync()
          ? jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>
          : null;
      for (final _Folder f in folders) {
        File(
          '${root.path}/${f.name}/report.md',
        ).writeAsStringSync(_folderReport(f, baseline));
      }
      File('${root.path}/summary.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(<String, Object>{
          for (final _Folder f in folders)
            f.name: <String, Object>{
              for (final _Sheet s in f.sheets)
                s.name: <String, Object>{
                  for (final _FileResult r in f.results.where(
                    (_FileResult r) => r.sheet == s,
                  ))
                    r.label: r.toJson(),
                },
            },
        }),
      );
      File('${root.path}/index.html').writeAsStringSync(_index(folders));
      File('${root.path}/tiles.md').writeAsStringSync(_tilesReport(checked));

      // The field test recognises the codes of all-grid by what they read as.
      final List<_Check> grid = checked
          .firstWhere(
            ((_Folder, _Sheet, List<_Check>) c) => c.$2.name == 'all-grid',
          )
          .$3;
      expect(
        <String>[for (final FieldCode c in fieldCodes) c.id],
        <String>[for (final _Check c in grid) c.id],
        reason: 'example/lib/diagnostics/field_codes.dart is out of date',
      );
      for (final (int i, _Check c) in grid.indexed) {
        expect(
          c.found.any(
            (Barcode b) => fieldCodes[i].matches(b.format.name, b.text),
          ),
          isTrue,
          reason: '${c.id} is not what field_codes.dart expects',
        );
      }
      final List<String> failed = <String>[
        for (final (_Folder f, _Sheet s, List<_Check> checks) in checked)
          for (final _Check c in checks)
            if (c.failed) '${f.name}/${s.name} ${c.id} ${c.tile.title}',
      ];
      expect(failed, isEmpty, reason: 'tiles that do not read on their own');
    },
    skip: _out == null,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
