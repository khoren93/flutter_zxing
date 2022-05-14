import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
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
    FlutterZxing.setLogEnabled(true);
    return MaterialApp(
      title: 'Flutter Zxing Example',
      home: DefaultTabController(
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
                  debugPrint(value.textString ?? '');
                },
              ),
              WriterWidget(
                onSuccess: (result, bytes) {},
                onError: (error) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
