// A sheet of labels: item codes on pages of the paper you choose, so many
// across and down, each a QR code or a Code 128 barcode of the size you set
// with its text, shared as one PDF to print at 100 %. Android, iOS, macOS,
// the web. Also needs share_plus.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

class LabelSheetPage extends StatefulWidget {
  const LabelSheetPage({super.key});

  @override
  State<LabelSheetPage> createState() => _LabelSheetPageState();
}

class _LabelSheetPageState extends State<LabelSheetPage> {
  // Your code: the item codes from your inventory.
  final List<String> _items = [
    for (int i = 1; i <= 120; i++) 'SKU-${i.toString().padLeft(4, '0')}',
  ];
  // Match your label paper: page size, labels across and down, margins.
  BarcodeLabelSheet _sheet = const BarcodeLabelSheet(columns: 3, rows: 8);
  int _page = 0;
  double? _progress; // while making the PDF

  static const Map<String, PaperSize> _papers = {
    'A4': PaperSize.a4,
    'A5': PaperSize.a5,
    'A3': PaperSize.a3,
    'Letter': PaperSize.letter,
    'Legal': PaperSize.legal,
  };
  String _paper = 'A4';
  bool _landscape = false;

  void _update(BarcodeLabelSheet sheet) => setState(() {
    _sheet = sheet;
    // Fewer pages now: stay on the last one.
    _page = _page.clamp(0, sheet.pageCount(_items.length) - 1);
  });

  void _setPaper(String name, bool landscape) {
    _paper = name;
    _landscape = landscape;
    final PaperSize paper = _papers[name]!;
    _update(_sheet.copyWith(paper: landscape ? paper.landscape : paper));
  }

  Widget _stepper(String label, int value, int max, ValueChanged<int> set) =>
      Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value > 1 ? () => set(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center),
          ),
          IconButton(
            onPressed: value < max ? () => set(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      );

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _progress = 0);
    try {
      // Encoded a page at a time: 10 000 QR codes take about 1.5 s on a
      // laptop and make a PDF of about 1 MB.
      final pdf = await _sheet.pdf(
        _items,
        onProgress: (done, total) {
          if (mounted) setState(() => _progress = done / total);
        },
      );
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(pdf, mimeType: 'application/pdf')],
          fileNameOverrides: ['labels.pdf'],
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } on BarcodeWriteException catch (e) {
      // It names the item, such as one with a character Code 128 cannot hold.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int pages = _sheet.pageCount(_items.length);
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
            selected: {_sheet.writer.format},
            onSelectionChanged: (s) => setState(
              () => _sheet = _sheet.copyWith(writer: BarcodeWriter(s.first)),
            ),
          ),
          const SizedBox(height: 8),
          // The paper and the layout: match your label paper.
          Row(
            children: [
              const Expanded(child: Text('Paper')),
              DropdownButton<String>(
                value: _paper,
                items: [
                  for (final name in _papers.keys)
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (name) => _setPaper(name!, _landscape),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: _landscape ? 'Portrait' : 'Landscape',
                onPressed: () => _setPaper(_paper, !_landscape),
                icon: Icon(
                  _landscape
                      ? Icons.crop_landscape_outlined
                      : Icons.crop_portrait_outlined,
                ),
              ),
            ],
          ),
          _stepper(
            'Codes across',
            _sheet.columns,
            10,
            (n) => _update(_sheet.copyWith(columns: n)),
          ),
          _stepper(
            'Rows on a page',
            _sheet.rows,
            20,
            (n) => _update(_sheet.copyWith(rows: n)),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _sheet.codeSize == null
                      ? 'Code size: as large as fits'
                      : 'Code size: ${_sheet.codeSize!.round()} mm',
                ),
              ),
              Switch(
                value: _sheet.codeSize != null,
                onChanged: (fixed) =>
                    _update(_sheet.copyWith(codeSize: () => fixed ? 20 : null)),
              ),
            ],
          ),
          if (_sheet.codeSize case final double size)
            Slider(
              value: size,
              min: 8,
              max: 80,
              divisions: 72,
              label: '${size.round()} mm',
              onChanged: (v) => _update(_sheet.copyWith(codeSize: () => v)),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Flexible(
                child: Text(
                  'Page ${_page + 1} of $pages, ${_items.length} labels',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: _page < pages - 1
                    ? () => setState(() => _page++)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          // The page as the PDF prints it.
          DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
            child: BarcodeLabelSheetView(
              sheet: _sheet,
              items: _items,
              page: _page,
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: _progress != null ? null : () => _share(context),
              icon: const Icon(Icons.print_outlined),
              label: Text(
                _progress == null
                    ? 'Share as PDF'
                    : 'Making the pages… ${(_progress! * 100).round()} %',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
