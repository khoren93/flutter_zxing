// A sheet of labels: 1000 numbered codes, AA000001 to AA001000, on A4
// pages, shared as one PDF to print at 100 %. Android, iOS, macOS, the web.
// Also needs share_plus. The full sheet editor (a list or a CSV column,
// paper, code size, SVG and ZIP) is in the demo's Create → Many codes.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:share_plus/share_plus.dart';

class LabelSheetPage extends StatefulWidget {
  const LabelSheetPage({super.key});

  @override
  State<LabelSheetPage> createState() => _LabelSheetPageState();
}

class _LabelSheetPageState extends State<LabelSheetPage> {
  // Your codes: made one when asked for, so 1000 or 100 000 cost nothing.
  final SerialItems _items = SerialItems('AA{n:6}', count: 1000);

  // Match your label paper: page size, labels across and down, margins.
  static const BarcodeLabelSheet _sheet = BarcodeLabelSheet(
    paper: PaperSize.a4,
    columns: 3,
    rows: 8,
    codeSize: 25, // millimetres
    style: BarcodeStyle.soft,
  );

  int _page = 0;
  double? _progress; // while making the PDF

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _progress = 0);
    try {
      // Encoded a page at a time, off the UI thread.
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
      // It names the item that cannot be encoded.
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
          Row(
            children: [
              IconButton(
                onPressed: _page > 0 ? () => setState(() => _page--) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  'Page ${_page + 1} of $pages',
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
