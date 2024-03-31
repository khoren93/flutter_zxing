import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:receive_intent/receive_intent.dart';

import '../configs/app_store.dart';
import '../models/models.dart' as model;
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
      ),
      body: ReaderWidget(
        actionButtonsAlignment: Alignment.topCenter,
        onScan: (Code result) async {
          addCode(result);
        },
      ),
    );
  }

  void addCode(Code result) {
    final model.Code code = model.Code.fromCodeResult(result);
    DbService.instance.addCode(code);
    context.showToast('Barcode saved:\n${code.text ?? ''}');
    if (Platform.isAndroid) {
      if(AppStoreBase.isExternCall) {
        ReceiveIntent.setResult(kActivityResultOk, data: {"SCAN_RESULT": "${code.text ?? ''}"}, shouldFinish:true);
      }
    }
  }
}
