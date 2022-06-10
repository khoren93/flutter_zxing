import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:zxscanner/models/models.dart';
import 'package:zxscanner/utils/db_service.dart';
import 'package:zxscanner/utils/extensions.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

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
        onPressed: pickImage,
        child: const Icon(FontAwesomeIcons.image),
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
    final CodeResult? result = await readBarcodeImagePath(file);
    if (result != null && result.isValidBool) {
      addCode(result);
    } else {
      if (!mounted) return;
      context.showToast('No code found');
    }
  }

  void addCode(CodeResult result) {
    Code code = Code.fromCodeResult(result);
    DbService.instance.addCode(code);
    context.showToast('Code added:\n${code.text ?? ''}');
  }
}
