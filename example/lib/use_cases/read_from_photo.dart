// Read from a photo: the user picks a screenshot or a picture from the
// gallery and the app lists every code in it, without a camera. Android,
// iOS, macOS, the web. Also needs image_picker.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

class ReadFromPhotoPage extends StatefulWidget {
  const ReadFromPhotoPage({super.key});

  @override
  State<ReadFromPhotoPage> createState() => _ReadFromPhotoPageState();
}

class _ReadFromPhotoPageState extends State<ReadFromPhotoPage> {
  List<Barcode>? _barcodes; // null until a photo is read
  String? _error;
  bool _reading = false;

  Future<void> _pick() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file == null || !mounted) return; // cancelled
    setState(() => _reading = true);
    List<Barcode>? barcodes;
    String? error;
    try {
      // Reads on a background isolate (a Web Worker on the web).
      barcodes = await const BarcodeReader().readAll(await file.readAsBytes());
    } on ImageDecodeException {
      error = 'This file is not an image';
    }
    if (!mounted) return;
    setState(() {
      _reading = false;
      _barcodes = barcodes;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Barcode>? barcodes = _barcodes;
    return Scaffold(
      appBar: AppBar(title: const Text('Read from a photo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _reading ? null : _pick,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Pick a photo'),
      ),
      body: switch ((_reading, _error, barcodes)) {
        (true, _, _) => const Center(child: CircularProgressIndicator()),
        (_, final String error, _) => Center(child: Text(error)),
        (_, _, null) => const Center(child: Text('Pick a photo with a code')),
        // "Not found" is an empty list, not an exception.
        (_, _, []) => const Center(child: Text('No code found in this photo')),
        (_, _, final List<Barcode> found) => ListView.separated(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: found.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => ListTile(
            leading: const Icon(Icons.qr_code_2),
            title: SelectableText(found[i].text),
            subtitle: Text(found[i].format.displayName),
          ),
        ),
      },
    );
  }
}
