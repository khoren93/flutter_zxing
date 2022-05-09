import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as imglib;

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    Key? key,
  }) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
      ),
      body: ZxingReaderWidget(
        onScan: (result) async {
          // _resultQueue.insert(0, result);
          // await Future.delayed(const Duration(milliseconds: 500));
          // setState(() {});
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(FontAwesomeIcons.image),
        onPressed: () async {
          final XFile? file =
              await _picker.pickImage(source: ImageSource.gallery);
          if (file != null) {
            final Uint8List bytes = await file.readAsBytes();
            imglib.Image? image = imglib.decodeImage(bytes);
            if (image != null) {
              final CodeResult result = FlutterZxing.readBarcode(
                image.getBytes(format: imglib.Format.luminance),
                Format.Any,
                image.width,
                image.height,
                0,
                0,
              );
              if (result.isValidBool) {
                debugPrint(result.textString);
              }
            }
          }
        },
      ),
    );
  }
}
