// Create → Many codes: numbered codes, a list or a CSV column, drawn with
// the format and style of One code, laid out on label sheets and shared as
// a PDF, SVG pages or a ZIP of the codes.
part of 'create_page.dart';

/// Where Many codes takes its items from.
enum _Source { numbered, list, csv }

/// The paper sizes offered, by name.
const Map<String, PaperSize> _papers = <String, PaperSize>{
  'A4': PaperSize.a4,
  'A5': PaperSize.a5,
  'A3': PaperSize.a3,
  'Letter': PaperSize.letter,
  'Legal': PaperSize.legal,
};

/// The list a new List starts with.
const String _sampleList = 'SKU-0001\nSKU-0002\nSKU-0003\nSKU-0004\nSKU-0005';

/// Thrown from a progress callback to stop an export.
final class _Cancelled implements Exception {
  const _Cancelled();
}

/// 1000 → `1,000`.
String _count(int n) {
  final String s = n.abs().toString();
  final StringBuffer b = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) {
      b.write(',');
    }
    b.write(s[i]);
  }
  return b.toString();
}

/// `1 code`, `1,000 codes`.
/// Millimetres to a half: `3`, `2.5`.
String _mm(double v) {
  final double half = (v * 2).round() / 2;
  return half == half.roundToDouble()
      ? '${half.round()}'
      : half.toStringAsFixed(1);
}

String _plural(int n, String one) => '${_count(n)} ${n == 1 ? one : '${one}s'}';

/// What a separator is called.
String _separatorName(String s) => switch (s) {
  ';' => 'semicolon',
  '\t' => 'tab',
  _ => 'comma',
};

/// The one of `,`, `;` and tab the first row of [csv] has most of, outside
/// quotes, as `BarcodeItems.csv` picks it; `,` if it has none.
String _separatorOf(String csv) {
  final Map<String, int> counts = <String, int>{',': 0, ';': 0, '\t': 0};
  bool quoted = false;
  for (int i = 0; i < csv.length; i++) {
    final String c = csv[i];
    if (c == '"') {
      quoted = !quoted;
    } else if (!quoted && (c == '\n' || c == '\r')) {
      break;
    } else if (!quoted && counts.containsKey(c)) {
      counts[c] = counts[c]! + 1;
    }
  }
  String best = ',';
  for (final MapEntry<String, int> e in counts.entries) {
    if (e.value > counts[best]!) {
      best = e.key;
    }
  }
  return best;
}

/// [item] as a part of a file name.
String _fileSafe(String item) {
  final String safe = item.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return safe.length > 40 ? safe.substring(0, 40) : safe;
}

/// [png] with its resolution written in a `pHYs` chunk, right after the
/// header (any `pHYs` it had is dropped): printed at [dpi], each pixel is
/// 1/[dpi] inch, so the code comes out at the size it was made for.
Uint8List pngWithDpi(Uint8List png, int dpi) {
  final ByteData data = ByteData.sublistView(png);
  final int perMetre = (dpi / 0.0254).round();
  final BytesBuilder out = BytesBuilder(copy: false)
    ..add(Uint8List.sublistView(png, 0, 8));
  int at = 8;
  while (at + 12 <= png.length) {
    final int length = data.getUint32(at);
    final String type = String.fromCharCodes(png, at + 4, at + 8);
    final int end = at + 12 + length;
    if (type != 'pHYs') {
      out.add(Uint8List.sublistView(png, at, end));
    }
    if (type == 'IHDR') {
      final ByteData chunk = ByteData(21)
        ..setUint32(0, 9)
        ..setUint32(8, perMetre)
        ..setUint32(12, perMetre)
        ..setUint8(16, 1); // the unit: the metre
      final Uint8List bytes = chunk.buffer.asUint8List();
      bytes.setRange(4, 8, 'pHYs'.codeUnits);
      chunk.setUint32(17, getCrc32(Uint8List.sublistView(bytes, 4, 17)));
      out.add(bytes);
    }
    at = end;
  }
  return out.takeBytes();
}

/// Many codes: the items, their check, the sheet and the exports. Kept by
/// the page while it lives, so switching modes keeps everything.
class _Batch {
  _Batch(this.page) {
    for (final TextEditingController c in <TextEditingController>[
      pattern,
      start,
      step,
      count,
      list,
      csvText,
    ]) {
      c.addListener(_edited);
    }
    // Made while the page builds: nothing to tell it yet.
    _rebuild(notify: false);
  }

  final _CreatePageState page;

  _Source source = _Source.numbered;
  final TextEditingController pattern = TextEditingController(text: 'AA{n:6}');
  final TextEditingController start = TextEditingController(text: '1');
  final TextEditingController step = TextEditingController(text: '1');
  final TextEditingController count = TextEditingController(text: '1000');
  CheckDigit? checkDigit;
  final TextEditingController list = TextEditingController(text: _sampleList);

  /// CSV typed or pasted.
  final TextEditingController csvText = TextEditingController();

  /// The CSV file opened, by name; its text stays out of the field, where a
  /// long file would be slow.
  String? csvFile;
  String _fileText = '';
  int column = 0;
  bool header = true;

  /// What the CSV shows: the first row's cells, rows, a few for the table.
  List<String> csvHeaders = const <String>[];
  List<List<String>> csvPreview = const <List<String>>[];
  int csvRows = 0;
  String separator = ',';

  /// Every item the source gives, before skipping.
  List<String> _all = const <String>[];

  /// Why the source gives none, and the field it is about.
  (String field, String message)? sourceError;

  /// The positions in [_all] skipped as they do not fit.
  Set<int> skipped = const <int>{};

  /// The items on the sheet.
  List<String> items = const <String>[];

  /// The first item that does not fit, by the writer's quick check.
  BarcodeItemIssue? issue;
  bool checking = false;
  bool skipping = false;
  BarcodeWriter? _checkedWriter;
  int _run = 0;
  Timer? _debounce;
  String _inputs = '';

  // The sheet.
  String paper = 'A4';
  bool landscape = false;
  int columns = 3;
  int rows = 8;

  /// Millimetres; `null`: as large as the labels allow.
  double? codeSize;
  LabelOrder order = LabelOrder.rows;
  bool? _caption;

  /// The caption's height, in millimetres.
  double captionSize = 3;
  int _page = 0;

  // An export or a skip in progress.
  String? busy;
  double? progress;
  bool _cancel = false;

  final GlobalKey<PopupMenuButtonState<BarcodeFormat>> formatMenu =
      GlobalKey<PopupMenuButtonState<BarcodeFormat>>();
  final GlobalKey<PopupMenuButtonState<String>> moreMenu =
      GlobalKey<PopupMenuButtonState<String>>();

  void dispose() {
    _debounce?.cancel();
    _cancel = true;
    _run++;
    for (final TextEditingController c in <TextEditingController>[
      pattern,
      start,
      step,
      count,
      list,
      csvText,
    ]) {
      c.dispose();
    }
  }

  void _changed() {
    if (page.mounted) {
      page._update(() {});
    }
  }

  /// A field changed: the items are made again once typing pauses, so a
  /// keystroke never makes thousands of codes.
  void _edited() {
    if (_signature == _inputs) {
      return; // only the cursor moved
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _rebuild);
  }

  String get _signature => switch (source) {
    _Source.numbered =>
      'n|${pattern.text}|${start.text}|${step.text}|${count.text}|$checkDigit',
    _Source.list => 'l|${list.text}',
    _Source.csv => 'c|$csvFile|${csvText.text}|$column|$header',
  };

  void setSource(_Source s) {
    source = s;
    _rebuild();
  }

  void setCheckDigit(CheckDigit? c) {
    checkDigit = c;
    _rebuild();
  }

  void setColumn(int c) {
    column = c;
    _rebuild();
  }

  void setHeader(bool h) {
    header = h;
    _rebuild();
  }

  /// Opens a CSV file; its text never goes through a field.
  Future<void> openCsv() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[
        XTypeGroup(
          label: 'CSV',
          extensions: <String>['csv', 'tsv', 'txt'],
          mimeTypes: <String>[
            'text/csv',
            'text/comma-separated-values',
            'text/tab-separated-values',
            'text/plain',
          ],
          uniformTypeIdentifiers: <String>[
            'public.comma-separated-values-text',
            'public.tab-separated-values-text',
            'public.plain-text',
          ],
        ),
      ],
    );
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    loadCsv(utf8.decode(bytes, allowMalformed: true), name: file.name);
  }

  void loadCsv(String text, {required String name}) {
    csvFile = name;
    _fileText = text;
    column = 0;
    _rebuild();
  }

  void closeCsv() {
    csvFile = null;
    _fileText = '';
    column = 0;
    _rebuild();
  }

  /// Makes the items from the source and checks them.
  void _rebuild({bool notify = true}) {
    _debounce?.cancel();
    _inputs = _signature;
    sourceError = null;
    List<String> all;
    try {
      all = switch (source) {
        _Source.numbered => _serial(),
        _Source.list => BarcodeItems.lines(list.text),
        _Source.csv => _readCsv(),
      };
    } on ArgumentError catch (e) {
      all = const <String>[];
      sourceError = (
        switch (e.name) {
          'start' || 'step' => e.name!,
          'count' || null => 'count',
          _ => 'pattern',
        },
        '${e.message}',
      );
    }
    _all = all;
    skipped = const <int>{};
    items = all;
    _check(notify: notify);
  }

  /// Numbered items: made one when asked for, so 10 000 cost nothing here.
  SerialItems _serial() {
    int number(TextEditingController c, String name) =>
        int.tryParse(c.text.trim()) ??
        (throw ArgumentError.value(c.text, name, 'Give a whole number'));
    return SerialItems(
      pattern.text,
      count: number(count, 'count'),
      start: number(start, 'start'),
      step: number(step, 'step'),
      checkDigit: checkDigit,
    );
  }

  List<String> _readCsv() {
    final String text = csvFile != null ? _fileText : csvText.text;
    if (text.trim().isEmpty) {
      csvHeaders = const <String>[];
      csvPreview = const <List<String>>[];
      csvRows = 0;
      return const <String>[];
    }
    separator = _separatorOf(text);
    csvHeaders = BarcodeItems.csvHeaders(text, separator: separator);
    final List<List<String>> first = <List<String>>[];
    int n = 0;
    for (final List<String> row in BarcodeItems.csvRows(
      text,
      separator: separator,
    )) {
      if (first.length < 4) {
        first.add(row);
      }
      n++;
    }
    csvRows = n;
    csvPreview = first;
    if (column >= csvHeaders.length) {
      column = 0;
    }
    return BarcodeItems.csv(
      text,
      column: column,
      header: header,
      separator: separator,
    );
  }

  /// The writer's quick check of every item: its rules for each (digits
  /// only, length, check digit) and an encode of the first, longest and
  /// last. A run started before is dropped, and stops early.
  void _check({bool notify = true}) {
    final int run = ++_run;
    final BarcodeWriter writer = page._batchWriter;
    _checkedWriter = writer;
    issue = null;
    checking = items.isNotEmpty;
    _page = 0;
    if (notify) {
      _changed();
    }
    if (items.isEmpty) {
      return;
    }
    final List<String> checked = items;
    Iterable<String> current() sync* {
      for (final String item in checked) {
        if (run != _run) {
          return;
        }
        yield item;
      }
    }

    writer
        .checkItems(current())
        .then(
          (BarcodeItemIssue? found) {
            if (run == _run) {
              issue = found;
              checking = false;
              _changed();
            }
          },
          onError: (Object _) {
            if (run == _run) {
              checking = false;
              _changed();
            }
          },
        );
  }

  /// The format, its options or the style changed. The items are checked
  /// again only if the writer changed: a new color needs no check.
  void lookChanged() {
    if (page._batchWriter == _checkedWriter) {
      return;
    }
    skipped = const <int>{};
    items = _all;
    _check();
  }

  /// Leaves out every item that does not fit.
  ///
  /// `checkItems` gives the first problem only, so it runs again after
  /// each one, on what comes after it: every item is looked at once by the
  /// quick rules, however many are skipped (10 000 items, a few ms). Once
  /// the rules pass to the end, `checkItems` encodes the first, longest and
  /// last item; if the engine refuses one, the same rest is checked again
  /// without it. A last pass over all that is left confirms.
  Future<void> skipUnfit() async {
    final BarcodeWriter writer = page._batchWriter;
    final List<String> all = _all;
    final Set<int> bad = <int>{...skipped};
    final int run = ++_run;
    skipping = true;
    progress = 0;
    _cancel = false;
    issue = null;
    checking = false;
    _changed();
    int from = 0;
    while (!_cancel && run == _run) {
      final List<int> at = <int>[];
      bool exhausted = false;
      Iterable<String> rest() sync* {
        for (int i = from; i < all.length; i++) {
          if (!bad.contains(i)) {
            at.add(i);
            yield all[i];
          }
        }
        exhausted = true;
      }

      final BarcodeItemIssue? found = await writer.checkItems(rest());
      if (found == null) {
        if (from == 0) {
          break;
        }
        from = 0; // the last pass, over everything left
        continue;
      }
      final int index = at[found.index];
      bad.add(index);
      // A rule broken: everything before it passed. An encode refused (the
      // rules passed to the end): check the same rest without it.
      if (!exhausted) {
        from = index + 1;
      }
      progress = from / all.length;
      _changed();
    }
    skipping = false;
    progress = null;
    if (run != _run) {
      return; // the source changed meanwhile
    }
    if (!_cancel) {
      skipped = bad;
      items = <String>[
        for (int i = 0; i < all.length; i++)
          if (!bad.contains(i)) all[i],
      ];
    }
    _check();
  }

  void undoSkip() {
    skipped = const <int>{};
    items = _all;
    _check();
  }

  /// Scrolls to the format menu and opens it.
  void changeFormat() {
    final BuildContext? context = formatMenu.currentContext;
    if (context == null) {
      return;
    }
    unawaited(
      Scrollable.ensureVisible(
        context,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
      ).then((_) => formatMenu.currentState?.showButtonMenu()),
    );
  }

  // The sheet.

  /// Whether the bars print their own text (EAN, UPC and the linear codes
  /// with digits under the bars): then the caption is off unless asked for.
  bool get _printsDigits =>
      page._format.isLinear &&
      page._textUnderBars &&
      page._format != BarcodeFormat.dxFilmEdge;

  bool get caption => _caption ?? !_printsDigits;

  PaperSize get _paper {
    final PaperSize p = _papers[paper]!;
    return landscape ? p.landscape : p;
  }

  BarcodeLabelSheet get _layout => BarcodeLabelSheet(
    paper: _paper,
    columns: columns,
    rows: rows,
    order: order,
    caption: caption,
    captionSize: captionSize,
    style: page._style,
    writer: page._batchWriter,
  );

  /// The longer side of the largest code the labels hold, in millimetres;
  /// 0 when there is no room. A linear code is taken as twice as wide as
  /// tall, as the preview shows it.
  double get maxCodeSize {
    final BarcodeLabelSheet l = _layout;
    final Size label = l.labelSize;
    final double w = label.width - 2 * l.padding;
    final double h =
        label.height -
        2 * l.padding -
        (l.caption ? l.captionSize * (1 + 0.25) : 0);
    if (w <= 0 || h <= 0) {
      return 0;
    }
    return page._square ? math.min(w, h) : math.min(w, h * 2);
  }

  /// The size a code is drawn at, in millimetres.
  double get drawnCodeSize =>
      math.min(codeSize ?? double.infinity, maxCodeSize);

  BarcodeLabelSheet get sheet {
    final double? size = codeSize;
    return size == null || maxCodeSize <= 0
        ? _layout
        : _layout.copyWith(codeSize: () => drawnCodeSize);
  }

  int get pageCount => items.isEmpty ? 0 : sheet.pageCount(items.length);

  int get pageShown => _page.clamp(0, math.max(0, pageCount - 1));

  bool get canExport =>
      items.isNotEmpty &&
      issue == null &&
      !checking &&
      !skipping &&
      busy == null &&
      maxCodeSize > 0;

  void change(VoidCallback edit) {
    edit();
    _changed();
  }

  void setCaption(bool on) => change(() => _caption = on);

  void goTo(int page) => change(() => _page = page);

  // The exports.

  void cancel() => change(() => _cancel = true);

  void _tick(int done, int total) {
    if (_cancel) {
      throw const _Cancelled();
    }
    progress = total == 0 ? null : done / total;
    _changed();
  }

  Future<void> _work(String label, Future<void> Function() work) async {
    if (busy != null) {
      return;
    }
    busy = label;
    progress = 0;
    _cancel = false;
    _changed();
    try {
      await work();
    } on _Cancelled {
      // Stopped: nothing to share.
    } on BarcodeWriteException catch (e) {
      page._toast(e.message);
    } on UnsupportedError catch (e) {
      page._toast(e.message ?? 'Not supported here');
    } on ArgumentError catch (e) {
      page._toast('${e.message}');
    } finally {
      busy = null;
      progress = null;
      _changed();
    }
  }

  /// One PDF of every page, made a page at a time: the codes are encoded
  /// off the UI thread, and the progress can stop it between pages.
  Future<void> sharePdf() => _work('Making the PDF', () async {
    final Uint8List pdf = await sheet.pdf(items, onProgress: _tick);
    await _share(
      <XFile>[XFile.fromData(pdf, mimeType: 'application/pdf')],
      <String>['flutter_zxing_labels.pdf'],
    );
  });

  /// One SVG a page.
  Future<void> shareSvgPages() => _work('Making the SVG pages', () async {
    final int total = pageCount;
    final int width = '$total'.length;
    final List<XFile> files = <XFile>[];
    final List<String> names = <String>[];
    await for (final String svg in sheet.svgPages(items)) {
      if (_cancel) {
        throw const _Cancelled();
      }
      files.add(XFile.fromData(utf8.encode(svg), mimeType: 'image/svg+xml'));
      names.add(
        'flutter_zxing_labels_${'${files.length}'.padLeft(width, '0')}.svg',
      );
      _tick(files.length, total);
    }
    await _share(files, names, zipName: 'flutter_zxing_labels_svg.zip');
  });

  /// Every page as a PNG at [dpi], in one ZIP: the sheet as the PDF
  /// prints it, as images.
  Future<void> sharePngPages(int dpi) =>
      _work('Making the PNG pages', () async {
        final int total = pageCount;
        final int width = '$total'.length;
        final Archive zip = Archive();
        int n = 0;
        await for (final Uint8List png in sheet.pngPages(items, dpi: dpi)) {
          if (_cancel) {
            throw const _Cancelled();
          }
          n++;
          zip.addFile(
            ArchiveFile.bytes(
              'flutter_zxing_labels_${'$n'.padLeft(width, '0')}.png',
              png,
            ),
          );
          _tick(n, total);
        }
        await _share(
          <XFile>[
            XFile.fromData(
              ZipEncoder().encodeBytes(zip),
              mimeType: 'application/zip',
            ),
          ],
          <String>['flutter_zxing_labels_${dpi}dpi.zip'],
        );
      });

  /// Every code on its own as an SVG and a PNG, in one ZIP, for a layout
  /// made elsewhere; with the sheet's text under each code when the sheet
  /// has it. The PNG has a whole number of pixels a module, as close to
  /// the sheet's code size at [dpi] as that allows, and says its dpi in a
  /// `pHYs` chunk.
  Future<void> shareZip(int dpi) => _work('Making the ZIP', () async {
    final BarcodeWriter writer = page._batchWriter;
    final BarcodeStyle plain = page._style.copyWith(
      title: () => null,
      caption: () => null,
      card: () => null,
    );
    final double mm = drawnCodeSize;
    final bool text = caption;
    // The sheet's text size, as a fraction of the code's width.
    final double textSize = (captionSize / mm).clamp(0.04, 0.3);
    final Archive zip = Archive();
    final int width = '${items.length}'.length;
    for (int i = 0; i < items.length; i++) {
      final String item = items[i];
      final BarcodeStyle style = text
          ? plain.copyWith(
              caption: () => BarcodeCaption(
                item,
                size: textSize,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFF000000),
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Courier',
                  fontFamilyFallback: <String>[
                    'Courier New',
                    'Menlo',
                    'monospace',
                  ],
                ),
              ),
            )
          : plain;
      final BarcodeSymbol symbol = await style.encode(item, writer: writer);
      final int quiet = style.quietZone ? 2 * symbol.quietZone : 0;
      final int modules = math.max(symbol.width, symbol.height) + quiet;
      final int moduleSize = math.max(1, (mm / modules * dpi / 25.4).round());
      final String name =
          '${'${i + 1}'.padLeft(width, '0')}_${_fileSafe(item)}';
      zip
        ..addFile(
          ArchiveFile.bytes(
            'png/$name.png',
            pngWithDpi(await style.toPng(symbol, moduleSize: moduleSize), dpi),
          ),
        )
        ..addFile(
          ArchiveFile.bytes(
            'svg/$name.svg',
            utf8.encode(await style.toSvg(symbol)),
          ),
        );
      if (i % 10 == 9 || i == items.length - 1) {
        _tick(i + 1, items.length);
      }
    }
    await _share(
      <XFile>[
        XFile.fromData(
          ZipEncoder().encodeBytes(zip),
          mimeType: 'application/zip',
        ),
      ],
      <String>['flutter_zxing_codes_${dpi}dpi.zip'],
    );
  });

  Future<void> _share(
    List<XFile> files,
    List<String> names, {
    String? zipName,
  }) async {
    if (!page.mounted) {
      return;
    }
    final String? saved = await saveOrShare(
      page.context,
      files,
      names,
      zipName: zipName ?? 'flutter_zxing_files.zip',
    );
    if (saved != null && saved.isNotEmpty) {
      page._toast('Saved $saved');
    }
  }
}

/// Many codes' layouts and the writer they share.
extension on _CreatePageState {
  /// One code's format and options; GS1 is a property of a form's data,
  /// not of a list.
  BarcodeWriter get _batchWriter =>
      BarcodeWriter(_format, errorCorrection: _level, showText: _showText);

  /// A section's title, with what it holds on the right.
  Widget _sectionHeader(String title, String trailing) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: <Widget>[
        Expanded(child: FzLabel(title)),
        Text(
          trailing,
          style: TextStyle(fontSize: 12, color: Fz.of(context).inkMuted),
        ),
      ],
    ),
  );

  /// The settings: the codes, their look and the sheet.
  List<Widget> _batchSettings(BuildContext context) {
    final _Batch b = _batch;
    return <Widget>[
      _sectionHeader(
        'Codes',
        b.items.isEmpty ? 'none' : _plural(b.items.length, 'code'),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _CodesForm(this),
      ),
      ..._look(context),
      const SizedBox(height: 24),
      _sectionHeader(
        'Sheet',
        b.pageCount == 0 ? '' : _plural(b.pageCount, 'page'),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SheetSettings(this),
      ),
    ];
  }

  /// One column: the first code, the settings, the page and the export.
  Widget _buildBatchPhone(BuildContext context) => ListView(
    padding: EdgeInsets.only(
      top: MediaQuery.paddingOf(context).top + 12,
      bottom: 120,
    ),
    children: <Widget>[
      _title(context),
      const SizedBox(height: 14),
      _modeSwitch(),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _FirstCode(this, size: 176),
      ),
      const SizedBox(height: 22),
      ..._batchSettings(context),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _SheetPreview(this),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _BatchExport(this),
      ),
    ],
  );

  /// The settings on the left, scrolling; on the right the first code, the
  /// page under it filling the height, and the export.
  Widget _buildBatchWide(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Expanded(
        child: SafeArea(
          right: false,
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 120),
            children: <Widget>[
              _title(context),
              const SizedBox(height: 14),
              _modeSwitch(),
              const SizedBox(height: 18),
              ..._batchSettings(context),
            ],
          ),
        ),
      ),
      Expanded(
        child: SafeArea(
          left: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              // A phone in landscape has no height for the page beside
              // the code: the column scrolls instead.
              if (c.maxHeight < 640) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: <Widget>[
                    _FirstCode(this, size: 140),
                    const SizedBox(height: 12),
                    _SheetPreview(this),
                    const SizedBox(height: 12),
                    _BatchExport(this),
                  ],
                );
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _FirstCode(this, size: 150),
                    const SizedBox(height: 12),
                    Expanded(child: _SheetPreview(this, fill: true)),
                    const SizedBox(height: 12),
                    _BatchExport(this),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}

/// The first code with the look of every code, its format menus, and the
/// check of all of them: the card One code has, for many.
class _FirstCode extends StatelessWidget {
  const _FirstCode(this.page, {required this.size});

  final _CreatePageState page;
  final double size;

  @override
  Widget build(BuildContext context) {
    final _Batch b = page._batch;
    final Fz fz = Fz.of(context);
    final String? first = b.items.firstOrNull;
    final int n = b.items.length;
    return FzCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: _Preview(
              page,
              size: size,
              data: first ?? '',
              writer: page._batchWriter,
              trouble: first == null
                  ? ('No codes', b.sourceError?.$2 ?? 'Add codes below')
                  : null,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _FormatMenu(page, menuKey: b.formatMenu),
              if (page._format.hasErrorCorrection) ...<Widget>[
                const SizedBox(width: 8),
                _EccMenu(page),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  first ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                n == 0 ? 'No codes yet' : 'The first of ${_plural(n, 'code')}',
                style: TextStyle(fontSize: 12, color: fz.inkMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The check of all the codes, in the title as One code's check is.
Widget _batchCheck(_CreatePageState page) {
  final _Batch b = page._batch;
  final int n = b.items.length;
  final BarcodeItemIssue? issue = b.issue;
  final bool busy = b.checking || b.skipping;
  return ReadCheck(
    reads: busy ? null : n > 0 && issue == null,
    invalid: n == 0,
    text: busy
        ? null
        : n == 0
        ? 'No codes'
        : issue != null
        ? 'Row ${_count(issue.index + 1)} does not fit'
        : 'All ${_count(n)} fit · ${page._format.displayName}',
  );
}

/// Where the codes come from: numbered, a list or a CSV column, and the
/// first that does not fit.
class _CodesForm extends StatelessWidget {
  const _CodesForm(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final _Batch b = page._batch;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<_Source>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<_Source>>[
            ButtonSegment<_Source>(
              value: _Source.numbered,
              label: Text('Numbered'),
            ),
            ButtonSegment<_Source>(value: _Source.list, label: Text('List')),
            ButtonSegment<_Source>(value: _Source.csv, label: Text('CSV')),
          ],
          selected: <_Source>{b.source},
          onSelectionChanged: (Set<_Source> s) => b.setSource(s.first),
        ),
        const SizedBox(height: 18),
        ...switch (b.source) {
          _Source.numbered => _numbered(context, b),
          _Source.list => _list(context, b),
          _Source.csv => _csv(context, b),
        },
        _Issue(page),
        const SizedBox(height: 12),
      ],
    );
  }

  String? _error(_Batch b, String field) =>
      b.sourceError?.$1 == field ? b.sourceError!.$2 : null;

  List<Widget> _numbered(BuildContext context, _Batch b) {
    final List<String> items = b.items;
    final String range = switch (b.skipped.isEmpty ? items.length : -1) {
      -1 || 0 => '',
      1 => items.first,
      2 => '${items[0]} · ${items[1]}',
      final int n => '${items[0]} · ${items[1]} … ${items[n - 1]}',
    };
    const TextInputType whole = TextInputType.numberWithOptions(signed: true);
    return <Widget>[
      TextField(
        controller: b.pattern,
        decoration: InputDecoration(
          labelText: 'Pattern',
          helperText: '{n} is the number; {n:6} pads it with zeros to 6 digits',
          helperMaxLines: 2,
          errorText: _error(b, 'pattern'),
          errorMaxLines: 3,
        ),
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (String label, TextEditingController c, String field)
              in <(String, TextEditingController, String)>[
                ('Start', b.start, 'start'),
                ('Step', b.step, 'step'),
                ('How many', b.count, 'count'),
              ]) ...<Widget>[
            if (field != 'start') const SizedBox(width: 10),
            Expanded(
              flex: field == 'count' ? 4 : 3,
              child: TextField(
                controller: c,
                keyboardType: whole,
                decoration: InputDecoration(
                  labelText: label,
                  errorText: _error(b, field),
                  errorMaxLines: 4,
                ),
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 14),
      const FzLabel('Check digit'),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<int>>[
          ButtonSegment<int>(value: -1, label: Text('None')),
          ButtonSegment<int>(value: 0, label: Text('GS1')),
          ButtonSegment<int>(value: 1, label: Text('Luhn')),
        ],
        selected: <int>{
          switch (b.checkDigit) {
            null => -1,
            CheckDigit.gs1 => 0,
            _ => 1,
          },
        },
        onSelectionChanged: (Set<int> s) => b.setCheckDigit(switch (s.first) {
          0 => CheckDigit.gs1,
          1 => CheckDigit.luhn,
          _ => null,
        }),
      ),
      if (range.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        Text(
          range,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Fz.of(context).inkMuted,
          ),
        ),
      ],
    ];
  }

  List<Widget> _list(BuildContext context, _Batch b) => <Widget>[
    TextField(
      controller: b.list,
      minLines: 5,
      maxLines: 10,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        labelText: 'Codes',
        alignLabelWithHint: true,
        helperText: 'One code a line · ${_plural(b._all.length, 'code')}',
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
    ),
    const SizedBox(height: 12),
  ];

  List<Widget> _csv(BuildContext context, _Batch b) {
    final Fz fz = Fz.of(context);
    final String about =
        '${_plural(b.csvRows, 'row')} · separator ${_separatorName(b.separator)}';
    final bool any = b.csvHeaders.isNotEmpty;
    return <Widget>[
      if (b.csvFile case final String name)
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          decoration: BoxDecoration(
            color: fz.raised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: fz.line),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fz.lockSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 22,
                  color: fz.lockInk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      about,
                      style: TextStyle(fontSize: 12, color: fz.inkMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close the file',
                icon: const Icon(Icons.close_rounded),
                onPressed: b.closeCsv,
              ),
            ],
          ),
        )
      else
        TextField(
          controller: b.csvText,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'CSV',
            alignLabelWithHint: true,
            hintText: 'Paste the rows here, or open a file',
            helperText: any ? about : null,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => unawaited(b.openCsv()),
          icon: const Icon(Icons.file_open_outlined, size: 20),
          label: Text(b.csvFile == null ? 'Open a file' : 'Open another'),
        ),
      ),
      if (any) ...<Widget>[
        const SizedBox(height: 16),
        const FzLabel('Column'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (int i = 0; i < b.csvHeaders.length; i++)
              ChoiceChip(
                label: Text(
                  b.header && b.csvHeaders[i].isNotEmpty
                      ? b.csvHeaders[i]
                      : 'Column ${i + 1}',
                ),
                selected: b.column == i,
                onSelected: (_) => b.setColumn(i),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'First row is a header',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Its cells name the columns; it is not a code',
            style: TextStyle(color: fz.inkMuted),
          ),
          value: b.header,
          onChanged: b.setHeader,
        ),
        const SizedBox(height: 4),
        _CsvTable(b),
      ],
      const SizedBox(height: 12),
    ];
  }
}

/// The first rows of the CSV, the column read highlighted.
class _CsvTable extends StatelessWidget {
  const _CsvTable(this.b);

  final _Batch b;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final int columns = b.csvPreview.fold<int>(
      0,
      (int n, List<String> row) => math.max(n, row.length),
    );
    final List<List<String>> rows = b.csvPreview
        .skip(b.header ? 1 : 0)
        .take(3)
        .toList();
    Widget cell(String text, int column, {bool head = false}) {
      final bool picked = column == b.column;
      return Container(
        color: picked ? fz.lockSoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: head
              ? TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: picked ? fz.lockInk : fz.inkMuted,
                )
              : TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: picked ? fz.lockInk : fz.ink,
                  fontWeight: picked ? FontWeight.w600 : FontWeight.w400,
                ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fz.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fz.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(horizontalInside: BorderSide(color: fz.line)),
          children: <TableRow>[
            if (b.header && b.csvPreview.isNotEmpty)
              TableRow(
                children: <Widget>[
                  for (int c = 0; c < columns; c++)
                    cell(
                      (c < b.csvPreview.first.length
                              ? b.csvPreview.first[c]
                              : '')
                          .toUpperCase(),
                      c,
                      head: true,
                    ),
                ],
              ),
            for (final List<String> row in rows)
              TableRow(
                children: <Widget>[
                  for (int c = 0; c < columns; c++)
                    cell(c < row.length ? row[c] : '', c),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The first item that does not fit, in the demo's error style, with what
/// to do about it; or the items skipped.
class _Issue extends StatelessWidget {
  const _Issue(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final _Batch b = page._batch;
    final Fz fz = Fz.of(context);
    final Color bad = Theme.of(context).colorScheme.error;
    if (b.skipping) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Finding the codes that do not fit…',
                    style: TextStyle(fontSize: 13, color: fz.inkMuted),
                  ),
                  const SizedBox(height: 6),
                  _Progress(b.progress),
                ],
              ),
            ),
            TextButton(onPressed: b.cancel, child: const Text('Cancel')),
          ],
        ),
      );
    }
    final BarcodeItemIssue? issue = b.issue;
    if (issue != null) {
      final String item = issue.item.length > 40
          ? '${issue.item.substring(0, 37)}…'
          : issue.item;
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
        decoration: BoxDecoration(
          color: bad.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 22, color: bad),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Row ${_count(issue.index + 1)}, “$item”',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: fz.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        issue.message,
                        style: TextStyle(fontSize: 13, color: fz.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              children: <Widget>[
                TextButton(
                  onPressed: () => unawaited(b.skipUnfit()),
                  child: const Text('Skip rows that do not fit'),
                ),
                TextButton(
                  onPressed: b.changeFormat,
                  child: const Text('Change format'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (b.skipped.isNotEmpty) {
      return Row(
        children: <Widget>[
          Icon(Icons.filter_alt_outlined, size: 18, color: fz.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_count(b.skipped.length)} skipped: '
              '${b.skipped.length == 1 ? 'it does' : 'they do'} not fit '
              '${page._format.displayName}',
              style: TextStyle(fontSize: 13, color: fz.inkMuted),
            ),
          ),
          TextButton(onPressed: b.undoSkip, child: const Text('Undo')),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// A thin progress bar in the accent.
class _Progress extends StatelessWidget {
  const _Progress(this.value);

  final double? value;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: 6,
    borderRadius: BorderRadius.circular(999),
    color: Fz.lock,
    backgroundColor: Fz.of(context).line,
  );
}

/// A number with − and + buttons, in a field's frame.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final ButtonStyle small = IconButton.styleFrom(
      minimumSize: const Size(40, 40),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: fz.raised,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fz.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: '$label: fewer',
                  style: small,
                  icon: const Icon(Icons.remove_rounded, size: 20),
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '$label: more',
                  style: small,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The paper, the labels on it, the code size, the order and the caption.
class _SheetSettings extends StatelessWidget {
  const _SheetSettings(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final _Batch b = page._batch;
    final Fz fz = Fz.of(context);
    final double max = b.maxCodeSize;
    final int maxMm = max.floor();
    final double? size = b.codeSize;
    const ButtonStyle compact = ButtonStyle(
      visualDensity: VisualDensity.compact,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(child: FzLabel('Paper')),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: compact,
              segments: const <ButtonSegment<bool>>[
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.crop_portrait_rounded),
                  tooltip: 'Portrait',
                ),
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.crop_landscape_rounded),
                  tooltip: 'Landscape',
                ),
              ],
              selected: <bool>{b.landscape},
              onSelectionChanged: (Set<bool> s) =>
                  b.change(() => b.landscape = s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: <ButtonSegment<String>>[
            for (final String name in _papers.keys)
              ButtonSegment<String>(value: name, label: Text(name)),
          ],
          selected: <String>{b.paper},
          onSelectionChanged: (Set<String> s) =>
              b.change(() => b.paper = s.first),
        ),
        const SizedBox(height: 14),
        _Stepper(
          label: 'Codes across',
          value: b.columns,
          min: 1,
          max: 10,
          onChanged: (int n) => b.change(() => b.columns = n),
        ),
        _Stepper(
          label: 'Rows on a page',
          value: b.rows,
          min: 1,
          max: 20,
          onChanged: (int n) => b.change(() => b.rows = n),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Fixed code size',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            max <= 0
                ? 'No room for a code: fewer labels or a larger paper'
                : size == null
                ? 'As large as each label allows: $maxMm mm'
                : '${b.drawnCodeSize.round()} mm, up to $maxMm mm',
            style: TextStyle(color: fz.inkMuted),
          ),
          value: size != null,
          onChanged: maxMm < 6
              ? null
              : (bool on) => b.change(
                  () => b.codeSize = on ? math.min(20, maxMm).toDouble() : null,
                ),
        ),
        if (size != null && maxMm >= 6)
          Slider(
            value: b.drawnCodeSize.roundToDouble().clamp(5, maxMm.toDouble()),
            min: 5,
            max: maxMm.toDouble(),
            divisions: maxMm - 5,
            label: '${b.drawnCodeSize.round()} mm',
            onChanged: (double v) => b.change(() => b.codeSize = v),
          ),
        const SizedBox(height: 8),
        const FzLabel('Order'),
        const SizedBox(height: 8),
        SegmentedButton<LabelOrder>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<LabelOrder>>[
            ButtonSegment<LabelOrder>(
              value: LabelOrder.rows,
              label: Text('Rows'),
            ),
            ButtonSegment<LabelOrder>(
              value: LabelOrder.columns,
              label: Text('Columns'),
            ),
            ButtonSegment<LabelOrder>(
              value: LabelOrder.rowStrips,
              label: Text('Row strips'),
            ),
            ButtonSegment<LabelOrder>(
              value: LabelOrder.columnStrips,
              label: Text('Column strips'),
            ),
          ],
          selected: <LabelOrder>{b.order},
          onSelectionChanged: (Set<LabelOrder> s) =>
              b.change(() => b.order = s.first),
        ),
        const SizedBox(height: 6),
        Text(switch (b.order) {
          LabelOrder.rows => 'Left to right, then the next row',
          LabelOrder.columns => 'Top to bottom, then the next column',
          LabelOrder.rowStrips =>
            'Each row runs on through every page: '
                'cut a stack of sheets into strips',
          LabelOrder.columnStrips =>
            'Each column runs on through every page: '
                'cut a stack of sheets into strips',
        }, style: TextStyle(fontSize: 13, color: fz.inkMuted)),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Text under each code',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            b._printsDigits
                ? 'The bars print their own digits'
                : 'The code itself, as a line of text',
            style: TextStyle(color: fz.inkMuted),
          ),
          value: b.caption,
          onChanged: b.setCaption,
        ),
        if (b.caption) ...<Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: FzLabel('Text size')),
              Text(
                '${_mm(b.captionSize)} mm',
                style: TextStyle(fontSize: 13, color: fz.inkMuted),
              ),
            ],
          ),
          Slider(
            value: b.captionSize,
            min: 2,
            max: 6,
            divisions: 8,
            label: '${_mm(b.captionSize)} mm',
            semanticFormatterCallback: (double v) => '${_mm(v)} millimetres',
            onChanged: (double v) => b.change(() => b.captionSize = v),
          ),
        ],
      ],
    );
  }
}

/// A page of the sheet as it prints, with paging, pinch and double-tap to
/// zoom, and a button to open it full screen. In the wide layout it fills
/// the height it is given.
class _SheetPreview extends StatelessWidget {
  const _SheetPreview(this.page, {this.fill = false});

  final _CreatePageState page;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final _Batch b = page._batch;
    final Fz fz = Fz.of(context);
    final BarcodeLabelSheet sheet = b.sheet;
    final int pages = b.pageCount;
    final int shown = b.pageShown;
    final bool room = b.maxCodeSize > 0;
    final Widget frame = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fz.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _Zoom(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _Paper(sheet: sheet, items: b.items, page: shown, room: room),
        ),
      ),
    );
    return FzCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  pages == 0
                      ? 'No pages'
                      : 'Page ${_count(shown + 1)} of ${_count(pages)} · '
                            '${_plural(sheet.labelsPerPage, 'label')} a page',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Full screen',
                icon: const Icon(Icons.open_in_full_rounded, size: 20),
                onPressed: pages == 0 || !room
                    ? null
                    : () => unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (BuildContext context) => _FullPage(
                              sheet: sheet,
                              items: b.items,
                              pages: pages,
                              initial: shown,
                              onPage: b.goTo,
                            ),
                          ),
                        ),
                      ),
              ),
              IconButton(
                tooltip: 'Previous page',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: shown > 0 ? () => b.goTo(shown - 1) : null,
              ),
              IconButton(
                tooltip: 'Next page',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: shown < pages - 1 ? () => b.goTo(shown + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: fill ? null : frame,
          ),
          if (fill)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: frame,
              ),
            ),
        ],
      ),
    );
  }
}

/// A page of [sheet] on white paper with a shadow, as large as the box
/// allows at the paper's proportions; a line instead when the labels have
/// no room for a code.
class _Paper extends StatelessWidget {
  const _Paper({
    required this.sheet,
    required this.items,
    required this.page,
    required this.room,
  });

  final BarcodeLabelSheet sheet;
  final List<String> items;
  final int page;
  final bool room;

  @override
  Widget build(BuildContext context) {
    final PaperSize paper = sheet.paper;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double aspect = paper.width / paper.height;
        final double width = math.max(
          0,
          math.min(c.maxWidth, c.maxHeight * aspect),
        );
        return Center(
          child: SizedBox(
            width: width,
            height: width / aspect,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.all(Radius.circular(2)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A0E1218),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: room
                  ? BarcodeLabelSheetView(
                      sheet: sheet,
                      items: items,
                      page: page,
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No room for a code on these labels',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Pinch to zoom [child] up to 6×; a double tap zooms to 3× where it
/// lands, or back out.
///
/// The codes stay sharp: the page is vectors and text, drawn again at the
/// zoomed scale. Once a zoom comes to rest the child sees a device pixel
/// ratio multiplied by it, so a [BarcodeView] snaps its modules to the
/// zoomed pixels rather than to those of the page at 1×.
class _Zoom extends StatefulWidget {
  const _Zoom({required this.child});

  final Widget child;

  @override
  State<_Zoom> createState() => _ZoomState();
}

class _ZoomState extends State<_Zoom> with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(_step);
  Animation<Matrix4>? _tween;
  Offset _tap = Offset.zero;

  /// The scale the child is drawn for, set once a zoom comes to rest.
  double _scale = 1;

  /// Whether a drag pans the page: only zoomed in, so that at 1× it
  /// scrolls the list around it.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  void _onTransform() {
    final bool zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() => _zoomed = zoomed);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _step() {
    final Animation<Matrix4>? tween = _tween;
    if (tween != null) {
      _controller.value = tween.value;
    }
    if (_animation.isCompleted) {
      _rest();
    }
  }

  void _rest() {
    final double scale =
        (_controller.value.getMaxScaleOnAxis() * 100).round() / 100;
    if (scale != _scale) {
      setState(() => _scale = scale);
    }
  }

  void _toggle() {
    final Matrix4 from = _controller.value.clone();
    final Matrix4 to;
    if (from.getMaxScaleOnAxis() > 1.01) {
      to = Matrix4.identity();
    } else {
      const double zoom = 3;
      final Offset scene = _controller.toScene(_tap);
      to = Matrix4.identity()
        ..translateByDouble(_tap.dx, _tap.dy, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1)
        ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
    }
    _tween = Matrix4Tween(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutCubic));
    unawaited(_animation.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return GestureDetector(
      onDoubleTapDown: (TapDownDetails d) => _tap = d.localPosition,
      onDoubleTap: _toggle,
      child: InteractiveViewer(
        transformationController: _controller,
        maxScale: 6,
        panEnabled: _zoomed,
        onInteractionStart: (_) => _animation.stop(),
        onInteractionEnd: (_) => _rest(),
        child: MediaQuery(
          data: media.copyWith(
            devicePixelRatio: media.devicePixelRatio * _scale,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A page full screen: zoom as in the preview, and paging that the
/// preview follows.
class _FullPage extends StatefulWidget {
  const _FullPage({
    required this.sheet,
    required this.items,
    required this.pages,
    required this.initial,
    required this.onPage,
  });

  final BarcodeLabelSheet sheet;
  final List<String> items;
  final int pages;
  final int initial;
  final ValueChanged<int> onPage;

  @override
  State<_FullPage> createState() => _FullPageState();
}

class _FullPageState extends State<_FullPage> {
  late int _page = widget.initial;

  void _goTo(int page) {
    setState(() => _page = page);
    widget.onPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    return Scaffold(
      backgroundColor: fz.surface,
      appBar: AppBar(
        backgroundColor: fz.surface,
        title: Text(
          'Page ${_count(_page + 1)} of ${_count(widget.pages)}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Previous page',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _page > 0 ? () => _goTo(_page - 1) : null,
          ),
          IconButton(
            tooltip: 'Next page',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _page < widget.pages - 1 ? () => _goTo(_page + 1) : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _Zoom(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _Paper(
              sheet: widget.sheet,
              items: widget.items,
              page: _page,
              room: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// Share the PDF, or more: SVG pages or every code in a ZIP. While one is
/// made, its progress and a way to stop it.
class _BatchExport extends StatelessWidget {
  const _BatchExport(this.page);

  final _CreatePageState page;

  @override
  Widget build(BuildContext context) {
    final _Batch b = page._batch;
    final String? busy = b.busy;
    if (busy != null) {
      final double? p = b.progress;
      return FzCard(
        radius: 18,
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    p == null ? '$busy…' : '$busy… ${(p * 100).round()} %',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(onPressed: b.cancel, child: const Text('Cancel')),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _Progress(p),
            ),
          ],
        ),
      );
    }
    final bool can = b.canExport;
    final int pages = b.pageCount;
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: can ? () => unawaited(b.sharePdf()) : null,
            icon: Icon(
              savesToDisk ? Icons.download_rounded : Icons.ios_share_rounded,
              size: 20,
            ),
            label: Text(
              '${savesToDisk ? 'Save' : 'Share'} PDF'
              '${pages == 0 ? '' : ' · ${_plural(pages, 'page')}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          key: b.moreMenu,
          tooltip: 'More',
          enabled: can,
          onSelected: (String v) => unawaited(switch (v) {
            'svg' => b.shareSvgPages(),
            'png300' => b.sharePngPages(300),
            'png600' => b.sharePngPages(600),
            'zip600' => b.shareZip(600),
            _ => b.shareZip(300),
          }),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'svg',
              child: Text('SVG pages · ${_plural(pages, 'file')}'),
            ),
            const PopupMenuItem<String>(
              value: 'png300',
              child: Text('PNG pages · 300 dpi'),
            ),
            const PopupMenuItem<String>(
              value: 'png600',
              child: Text('PNG pages · 600 dpi'),
            ),
            const PopupMenuDivider(),
            for (final int dpi in const <int>[300, 600])
              PopupMenuItem<String>(
                value: 'zip$dpi',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('Separate codes as ZIP · $dpi dpi'),
                  subtitle: Text(
                    b.caption
                        ? 'Each code on its own, its text under it'
                        : 'Each code on its own, no text',
                  ),
                ),
              ),
          ],
          // The menu button takes the taps; the button only shows.
          child: IgnorePointer(
            child: OutlinedButton.icon(
              onPressed: can ? () {} : null,
              icon: const Icon(Icons.more_horiz_rounded, size: 20),
              label: const Text('More'),
            ),
          ),
        ),
      ],
    );
  }
}
