import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  setZxingLogEnabled(kDebugMode);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Zxing Example',
      home: DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({Key? key}) : super(key: key);

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  Uint8List? createdCodeBytes;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Zxing Example'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Scan Code'),
              Tab(text: 'Create Code'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ReaderWidget(
              onScan: (value) {
                showMessage(context, 'Scanned: ${value.textString ?? ''}');
              },
            ),
            ListView(
              children: [
                WriterWidget(
                  onSuccess: (result, bytes) {
                    setState(() {
                      createdCodeBytes = bytes;
                    });
                  },
                  onError: (error) {
                    showMessage(context, 'Error: $error');
                  },
                ),
                if (createdCodeBytes != null)
                  Image.memory(createdCodeBytes ?? Uint8List(0), height: 200),
              ],
            ),
          ],
        ),
      ),
    );
  }

  showMessage(BuildContext context, String message) {
    debugPrint(message);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
