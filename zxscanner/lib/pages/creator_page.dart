import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../configs/constants.dart';
import '../models/encode.dart';
import '../utils/db_service.dart';
import '../utils/extensions.dart';
import '../widgets/common_widgets.dart';

late Directory tempDir;
String get tempPath => '${tempDir.path}/zxing.jpg';

class CreatorPage extends StatefulWidget {
  const CreatorPage({
    super.key,
  });

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

  Future<void> initStateAsync() async {
    getTemporaryDirectory().then((Directory value) {
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
            children: <Widget>[
              WriterWidget(
                onSuccess: (EncodeResult result, Uint8List? bytes) {
                  setState(() {
                    encode = Encode.fromEncodeResult(result, bytes);
                  });
                },
                onError: (String error) {
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
      children: <Widget>[
        // Barcode image
        if (encode?.data != null) Image.memory(encode?.data ?? Uint8List(0)),
        const SizedBox(height: spaceLarge),
        // Share button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Builder(builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  // Save image to device
                  final File file = File(tempPath);
                  file.writeAsBytesSync(encode?.data ?? Uint8List(0));
                  final String path = file.path;

                  // Share image
                  final RenderBox? box =
                      context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    Share.shareFiles(
                      <String>[path],
                      sharePositionOrigin:
                          box.localToGlobal(Offset.zero) & box.size,
                    );
                  }
                },
                child: const Text('Share'),
              );
            }),
            ElevatedButton(
              onPressed: () async {
                if (encode != null) {
                  await DbService.instance.addEncode(encode!);
                  if (!mounted) {
                    return;
                  }
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
