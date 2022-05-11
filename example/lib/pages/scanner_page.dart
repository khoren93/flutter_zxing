import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing_example/models/models.dart';
import 'package:flutter_zxing_example/utils/db_service.dart';
import 'package:flutter_zxing_example/utils/extensions.dart';
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
      body: ReaderWidget(
        onScan: (result) async {
          addCode(result);
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(FontAwesomeIcons.image),
        onPressed: pickImage,
      ),
    );
  }

  pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file != null) {
        readCodeFromImage(file);
      }
    } catch (e) {
      debugPrint(e.toString());
      context.showToast(e.toString());
    }
  }

  readCodeFromImage(XFile file) async {
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
        addCode(result);
      } else {
        context.showToast('No code found');
      }
    }
  }

  void addCode(CodeResult result) {
    Code code = Code.fromCodeResult(result);
    DbService.instance.addCode(code);
    context.showToast('Code added:\n${code.text ?? ''}');
  }
}
