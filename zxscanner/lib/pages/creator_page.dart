import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:zxscanner/configs/constants.dart';
import 'package:zxscanner/models/encode.dart';
import 'package:zxscanner/utils/db_service.dart';
import 'package:zxscanner/utils/extensions.dart';
import 'package:zxscanner/widgets/common_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

late Directory tempDir;
String get tempPath => '${tempDir.path}/zxing.jpg';

class CreatorPage extends StatefulWidget {
  const CreatorPage({
    Key? key,
  }) : super(key: key);

  @override
  State<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends State<CreatorPage> {
  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  // Write result
  Encode? encode;

  @override
  void initState() {
    super.initState();

    initStateAsync();
  }

  void initStateAsync() async {
    getTemporaryDirectory().then((value) {
      tempDir = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator'),
      ),
      body: SingleChildScrollView(
        child: ContainerX(
          child: Column(
            children: [
              WriterWidget(
                onSuccess: (result, bytes) {
                  setState(() {
                    encode = Encode.fromEncodeResult(result, bytes);
                  });
                },
                onError: (error) {
                  setState(() {
                    encode = null;
                  });
                  context.showToast(error);
                },
              ),
              if (encode != null) buildWriteResult(),
            ],
          ),
        ),
      ),
    );
  }

  Column buildWriteResult() {
    return Column(
      children: [
        // Barcode image
        if (encode?.data != null) Image.memory(encode?.data ?? Uint8List(0)),
        const SizedBox(height: spaceLarge),
        // Share button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Save image to device
                final file = File(tempPath);
                file.writeAsBytesSync(encode?.data ?? Uint8List(0));
                final path = file.path;
                // Share image
                Share.shareFiles([path]);
              },
              child: const Text('Share'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (encode != null) {
                  await DbService.instance.addEncode(encode!);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: spaceLarge),
      ],
    );
  }
}
