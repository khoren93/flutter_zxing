import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:flutter_zxing/generated_bindings.dart';
import 'package:flutter_zxing/zxing_reader_widget.dart';
import 'package:flutter_zxing/zxing_writer_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

late Directory tempDir;
String get tempPath => '${tempDir.path}/zxing.jpg';

class ZxingPage extends StatefulWidget {
  const ZxingPage({
    Key? key,
  }) : super(key: key);

  @override
  State<ZxingPage> createState() => _ZxingPageState();
}

class _ZxingPageState extends State<ZxingPage> with TickerProviderStateMixin {
  CameraController? controller;
  TabController? _tabController;

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  // Scan result queue
  final _resultQueue = <CodeResult>[];

  // Write result
  Uint8List? writeResult;

  // true when the camera is active
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();

    initStateAsync();
  }

  void initStateAsync() async {
    _tabController = TabController(length: 3, vsync: this);
    _tabController?.addListener(() {
      _isScanning = _tabController?.index == 0;
      if (_isScanning) {
        controller?.resumePreview();
      } else {
        controller?.pausePreview();
      }
    });
    getTemporaryDirectory().then((value) {
      tempDir = value;
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller?.dispose();
  }

  void showInSnackBar(String message) {}

  void logError(String code, String? message) {
    if (message != null) {
      debugPrint('Error: $code\nError Message: $message');
    } else {
      debugPrint('Error: $code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Scanner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scanner'),
            Tab(text: 'Result'),
            Tab(text: 'Writer'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Scanner
          ZxingReaderWidget(onScan: (result) async {
            _resultQueue.insert(0, result);
            _tabController?.index = 1;
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() {});
          }),
          // Result
          _buildResultList(),
          // Writer
          SingleChildScrollView(
            child: Column(
              children: [
                ZxingWriterWidget(
                  onSuccess: (result) {
                    setState(() {
                      writeResult = result;
                    });
                  },
                  onError: (error) {
                    setState(() {
                      writeResult = null;
                    });
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
                if (writeResult != null) buildWriteResult(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Column buildWriteResult() {
    return Column(
      children: [
        // Barcode image
        Image.memory(writeResult ?? Uint8List(0)),
        // Share button
        ElevatedButton(
          onPressed: () {
            // Save image to device
            final file = File(tempPath);
            file.writeAsBytesSync(writeResult ?? Uint8List(0));
            final path = file.path;
            // Share image
            Share.shareFiles([path]);
          },
          child: const Text('Share'),
        ),
      ],
    );
  }

  _buildResultList() {
    return _resultQueue.isEmpty
        ? const Center(
            child: Text(
            'No Results',
            style: TextStyle(fontSize: 24),
          ))
        : ListView.builder(
            itemCount: _resultQueue.length,
            itemBuilder: (context, index) {
              final result = _resultQueue[index];
              return ListTile(
                title: Text(result.textString),
                subtitle: Text(result.formatString),
                trailing: ButtonBar(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Copy button
                    TextButton(
                      child: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: result.textString));
                      },
                    ),
                    // Remove button
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _resultQueue.removeAt(index);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          );
  }
}
