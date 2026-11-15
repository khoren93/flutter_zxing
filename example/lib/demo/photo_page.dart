// Every code in a photo: outlined and numbered on the picture, listed below.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

import 'content.dart';
import 'history.dart';
import 'tokens.dart';

/// Picks a photo and opens it on a [PhotoPage]; nothing if the person
/// cancels.
Future<void> pickAndReadPhoto(BuildContext context) async {
  final NavigatorState navigator = Navigator.of(context);
  final XFile? file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
  );
  if (file == null) {
    return;
  }
  final Uint8List bytes = await file.readAsBytes();
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => PhotoPage(bytes),
    ),
  );
}

class PhotoPage extends StatefulWidget {
  const PhotoPage(this.bytes, {super.key});

  final Uint8List bytes;

  @override
  State<PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<PhotoPage> {
  ui.Image? _image;
  List<Barcode>? _barcodes;
  int? _millis;
  String? _error;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _read() async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(widget.bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      codec.dispose();
      final Stopwatch watch = Stopwatch()..start();
      final List<Barcode> found = await const BarcodeReader().readAll(
        widget.bytes,
      );
      watch.stop();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _barcodes = found.where((Barcode b) => b.isValid).toList();
        _millis = watch.elapsedMilliseconds;
      });
    } on ImageDecodeException catch (e) {
      if (mounted) {
        setState(
          () => _error = 'This file is not a picture we can read. ${e.message}',
        );
      }
    }
  }

  void _saveAll() {
    for (final Barcode b in _barcodes ?? const <Barcode>[]) {
      unawaited(HistoryStore.instance.addScan(b, source: 'photo'));
    }
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final List<Barcode>? barcodes = _barcodes;
    final ui.Image? image = _image;
    final int count = barcodes?.length ?? 0;
    return Theme(
      data: demoTheme(Brightness.dark),
      child: Builder(
        builder: (BuildContext context) {
          final Fz dark = Fz.of(context);
          return Scaffold(
            appBar: AppBar(
              backgroundColor: dark.surface,
              surfaceTintColor: Colors.transparent,
              title: Text(
                barcodes == null
                    ? 'Photo'
                    : count == 1
                    ? 'Photo · 1 code'
                    : 'Photo · $count codes',
              ),
              centerTitle: true,
              actions: <Widget>[
                IconButton(
                  tooltip: 'Choose another photo',
                  icon: const Icon(Icons.photo_library_outlined),
                  onPressed: () => unawaited(() async {
                    final NavigatorState nav = Navigator.of(context);
                    nav.pop();
                    await pickAndReadPhoto(nav.context);
                  }()),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  )
                : barcodes == null || image == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final bool wide = c.maxWidth > 840;
                      final Widget picture = Padding(
                        padding: const EdgeInsets.all(16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: AspectRatio(
                            aspectRatio: image.width / image.height,
                            child: CustomPaint(
                              foregroundPainter: _Outlines(
                                barcodes,
                                Size(
                                  image.width.toDouble(),
                                  image.height.toDouble(),
                                ),
                              ),
                              child: RawImage(image: image, fit: BoxFit.fill),
                            ),
                          ),
                        ),
                      );
                      final Widget list = _List(
                        barcodes: barcodes,
                        millis: _millis ?? 0,
                        saved: _saved,
                        onSave: _saveAll,
                      );
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(flex: 3, child: Center(child: picture)),
                            SizedBox(
                              width: 400,
                              child: SingleChildScrollView(child: list),
                            ),
                          ],
                        );
                      }
                      return ListView(
                        children: <Widget>[
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: c.maxHeight * 0.5,
                            ),
                            child: Center(child: picture),
                          ),
                          list,
                        ],
                      );
                    },
                  ),
            backgroundColor: fz == dark ? null : dark.surface,
          );
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.barcodes,
    required this.millis,
    required this.saved,
    required this.onSave,
  });

  final List<Barcode> barcodes;
  final int millis;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    if (barcodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No code found in this photo. Try one where the code is sharp and fills more of the picture.',
          textAlign: TextAlign.center,
          style: TextStyle(color: fz.inkMuted, fontSize: 16),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: FzCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      barcodes.length == 1
                          ? '1 code'
                          : '${barcodes.length} codes',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    'read in $millis ms',
                    style: TextStyle(color: fz.inkMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            for (final (int i, Barcode b) in barcodes.indexed)
              _Row(index: i + 1, barcode: b),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: barcodes.map((Barcode b) => b.text).join('\n'),
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All codes copied')),
                        );
                      }
                    },
                    child: const Text('Copy all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Fz.lock,
                      foregroundColor: Fz.onLock,
                    ),
                    onPressed: saved ? null : onSave,
                    child: Text(saved ? 'Saved' : 'Save to history'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.index, required this.barcode});

  final int index;
  final Barcode barcode;

  @override
  Widget build(BuildContext context) {
    final Fz fz = Fz.of(context);
    final Described d = describe(barcode);
    final Uri? open = d.open;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: <Widget>[
          _Number(index),
          const SizedBox(width: 12),
          BarcodeThumbnail(barcode, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${d.kind} · ${barcode.format.displayName}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: fz.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (open != null)
            IconButton(
              tooltip: d.openLabel,
              icon: Icon(d.openIcon),
              onPressed: () => unawaited(openUri(context, open)),
            )
          else
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () => unawaited(
                Clipboard.setData(ClipboardData(text: barcode.text)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  const _Number(this.n);

  final int n;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: Fz.lock, shape: BoxShape.circle),
    child: Text(
      '$n',
      style: const TextStyle(
        color: Fz.onLock,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    ),
  );
}

/// The found codes' outlines and numbers over the photo.
class _Outlines extends CustomPainter {
  _Outlines(this.barcodes, this.imageSize);

  final List<Barcode> barcodes;
  final Size imageSize;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / imageSize.width;
    final double sy = size.height / imageSize.height;
    Offset map(Offset p) => Offset(p.dx * sx, p.dy * sy);
    final Paint fill = Paint()..color = const Color(0x332EE6B5);
    final Paint line = Paint()
      ..color = Fz.lock
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    for (final (int i, Barcode b) in barcodes.indexed) {
      final BarcodePosition p = b.position;
      final List<Offset> corners = <Offset>[
        map(p.topLeft),
        map(p.topRight),
        map(p.bottomRight),
        map(p.bottomLeft),
      ];
      final Path path = Path()..addPolygon(corners, true);
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, line);
      final Offset at = corners.reduce(
        (Offset a, Offset c) => a.dy + a.dx < c.dy + c.dx ? a : c,
      );
      canvas.drawCircle(at, 13, Paint()..color = Fz.lock);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Fz.onLock,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(_Outlines old) =>
      old.barcodes != barcodes || old.imageSize != imageSize;
}
