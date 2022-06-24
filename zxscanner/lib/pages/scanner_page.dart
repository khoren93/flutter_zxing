import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../utils/db_service.dart';
import '../utils/extensions.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    super.key,
  });

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
        onScan: (CodeResult result) async {
          addCode(result);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: pickImage,
        child: const Icon(FontAwesomeIcons.image),
      ),
    );
  }

  // ignore: always_declare_return_types
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

  Future<void> readCodeFromImage(XFile file) async {
    final CodeResult? result = await readBarcodeImagePath(file);
    if (result != null && result.isValidBool) {
      addCode(result);
    } else {
      if (!mounted) {
        return;
      }
      context.showToast('No code found');
    }
  }

  void addCode(CodeResult result) {
    final Code code = Code.fromCodeResult(result);
    DbService.instance.addCode(code);
    context.showToast('Code added:\n${code.text ?? ''}');
  }
}
