import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  zx.setLogEnabled(kDebugMode);
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
            if (kIsWeb)
              Center(
                child: Text(
                  'Web is not supported yet.',
                  style: Theme.of(context).textTheme.headline6,
                ),
              )
            else
              ReaderWidget(
                onScan: (value) {
                  showMessage(context, 'Scanned: ${value.text ?? ''}');
                },
                tryInverted: true,
              ),
            if (kIsWeb)
              Center(
                child: Text(
                  'Web is not supported yet.',
                  style: Theme.of(context).textTheme.headline6,
                ),
              )
            else
              ListView(
                children: [
                  WriterWidget(
                    messages: const Messages(
                      createButton: 'Create Code',
                    ),
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
