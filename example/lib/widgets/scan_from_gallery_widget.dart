import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image_picker/image_picker.dart';

class ScanFromGalleryWidget extends StatelessWidget {
  const ScanFromGalleryWidget({
    Key? key,
    this.onScan,
    this.onScanFailure,
  }) : super(key: key);

  final Function(Code)? onScan;
  final Function(Code?)? onScanFailure;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: _onFromGalleryButtonTapped,
        child: const Icon(Icons.image),
      ),
    );
  }

  void _onFromGalleryButtonTapped() async {
    final XFile? file =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      final Code? result = await zx.readBarcodeImagePath(
        file,
        params: DecodeParams(tryInverted: true),
      );
      if (result != null && result.isValid) {
        onScan?.call(result);
      } else {
        result?.error = 'No barcode found';
        onScanFailure?.call(result);
      }
    }
  }
}
