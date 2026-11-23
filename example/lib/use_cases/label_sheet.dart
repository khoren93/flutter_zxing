// A sheet of labels: item codes on A4 pages in columns, each a QR code or
// a Code 128 barcode with its text, shared as one SVG per page in mm to
// print at 100 %. Android, iOS, macOS, the web. Also needs share_plus.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

class LabelSheetPage extends StatefulWidget {
  const LabelSheetPage({super.key});

  @override
  State<LabelSheetPage> createState() => _LabelSheetPageState();
}

// The sheet, in millimetres: A4, 4 × 8 labels. Match your label paper.
const double _pageW = 210, _pageH = 297, _margin = 10, _gap = 4;
const int _columns = 4, _rows = 8, _perPage = _columns * _rows;
const double _labelW =
    (_pageW - 2 * _margin - (_columns - 1) * _gap) / _columns;
const double _labelH = (_pageH - 2 * _margin - (_rows - 1) * _gap) / _rows;
const double _pad = 2, _textSize = 3.5; // inside a label
const double _codeW = _labelW - 2 * _pad;
const double _codeH = _labelH - 2 * _pad - _textSize - 1.5;

const String _pageStart =
    '<svg xmlns="http://www.w3.org/2000/svg" width="${_pageW}mm" '
    'height="${_pageH}mm" viewBox="0 0 $_pageW $_pageH" '
    'shape-rendering="crispEdges">'
    '<rect width="100%" height="100%" fill="#fff"/>';

// The top left corner of the label at [i] on its page.
Offset _labelAt(int i) => Offset(
  _margin + (i % _columns) * (_labelW + _gap),
  _margin + (i ~/ _columns) * (_labelH + _gap),
);

class _LabelSheetPageState extends State<LabelSheetPage> {
  // Your code: the item codes from your inventory.
  final List<String> _items = [
    for (int i = 1; i <= 120; i++) 'SKU-${i.toString().padLeft(4, '0')}',
  ];
  BarcodeFormat _format = BarcodeFormat.qrCode;
  bool _busy = false;

  // One SVG per page, each code encoded once on the engine's background
  // isolate: about 0.1 ms a code on a laptop. For tens of thousands, write
  // each page to a file as it is made instead of keeping them in memory.
  Future<List<String>> _buildPages() async {
    final BarcodeWriter writer = BarcodeWriter(_format);
    final List<StringBuffer> pages = [];
    for (final (n, item) in _items.indexed) {
      if (n % _perPage == 0) pages.add(StringBuffer(_pageStart));
      final BarcodeSymbol symbol = await writer.encode(item);
      final Offset at = _labelAt(n % _perPage);
      // The box holds the quiet zone too; a linear code needs it only on
      // its left and right.
      final int q = symbol.quietZone, qy = _format.isLinear ? 0 : q;
      pages.last
        ..write('<svg x="${at.dx + _pad}" y="${at.dy + _pad}" ')
        ..write('width="$_codeW" height="$_codeH" viewBox="${-q} ${-qy} ')
        ..write('${symbol.width + 2 * q} ${symbol.height + 2 * qy}">')
        ..write('<path d="${_modules(symbol)}"/></svg>')
        ..write('<text x="${at.dx + _labelW / 2}" ')
        ..write('y="${at.dy + _labelH - _pad}" font-size="$_textSize" ')
        ..write('font-family="monospace" ')
        ..write('text-anchor="middle">${_xml.convert(item)}</text>');
    }
    return [for (final StringBuffer page in pages) '$page</svg>'];
  }

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final List<String> pages = await _buildPages();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            for (final String page in pages)
              XFile.fromData(utf8.encode(page), mimeType: 'image/svg+xml'),
          ],
          fileNameOverrides: [
            for (int i = 1; i <= pages.length; i++) 'labels-$i.svg',
          ],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on BarcodeWriteException catch (e) {
      // Such as a character Code 128 cannot hold.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // A label of the preview at [mm] logical pixels a millimetre.
  Widget _label(int i, String item, BarcodeWriter writer, double mm) =>
      Positioned(
        left: (_labelAt(i).dx + _pad) * mm,
        top: (_labelAt(i).dy + _pad) * mm,
        child: Column(
          children: [
            BarcodeView(
              item,
              writer: writer,
              width: _codeW * mm,
              height: _codeH * mm,
            ),
            Text(
              item,
              style: TextStyle(fontSize: _textSize * mm, color: Colors.black),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final BarcodeWriter writer = BarcodeWriter(_format);
    return Scaffold(
      appBar: AppBar(title: const Text('A sheet of labels')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<BarcodeFormat>(
            segments: const [
              ButtonSegment(value: BarcodeFormat.qrCode, label: Text('QR')),
              ButtonSegment(
                value: BarcodeFormat.code128,
                label: Text('Code 128'),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            '${_items.length} labels on '
            '${(_items.length / _perPage).ceil()} A4 pages',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // The first page, laid out like the SVG: millimetres × scale.
          AspectRatio(
            aspectRatio: _pageW / _pageH,
            child: LayoutBuilder(
              builder: (context, box) => ColoredBox(
                color: Colors.white,
                child: Stack(
                  children: [
                    for (final (i, item) in _items.take(_perPage).indexed)
                      _label(i, item, writer, box.maxWidth / _pageW),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: _busy ? null : () => _share(context),
              icon: const Icon(Icons.print_outlined),
              label: Text(_busy ? 'Making the pages…' : 'Share as SVG'),
            ),
          ),
        ],
      ),
    );
  }
}

// The dark modules as one path in module units, a rectangle per run of
// dark modules in a row. The rows of a Code 128 barcode are all the same:
// its first row is drawn as tall as the symbol.
String _modules(BarcodeSymbol s) {
  final bool linear = s.format.isLinear;
  final int band = linear ? s.height : 1;
  final StringBuffer path = StringBuffer();
  for (int y = 0; y < (linear ? 1 : s.height); y++) {
    for (int x = 0; x < s.width; x++) {
      if (!s.isDark(x, y)) continue;
      final int start = x;
      while (x + 1 < s.width && s.isDark(x + 1, y)) {
        x++;
      }
      path.write('M$start ${y}h${x + 1 - start}v${band}h${start - x - 1}z');
    }
  }
  return path.toString();
}

const HtmlEscape _xml = HtmlEscape(HtmlEscapeMode.element);
