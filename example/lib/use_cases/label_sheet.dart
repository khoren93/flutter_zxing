// A sheet of labels: item codes on A4 pages, 3 × 8 to a page, each a QR
// code or a Code 128 barcode with its text, shared as one PDF to print at
// 100 %. Android, iOS, macOS, the web. Also needs share_plus.
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
