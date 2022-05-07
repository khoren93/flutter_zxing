import 'package:flutter/material.dart';
import 'package:flutter_zxing/zxing_reader_widget.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({
    Key? key,
  }) : super(key: key);

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();

    initStateAsync();
  }

  void initStateAsync() async {
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    super.dispose();
    _tabController?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Single code'),
            Tab(text: 'Multi code'),
            Tab(text: 'Image'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Single code scanner
          ZxingReaderWidget(onScan: (result) async {
            // _resultQueue.insert(0, result);
            // await Future.delayed(const Duration(milliseconds: 500));
            // setState(() {});
          }),
          // Multi code scanner
          Container(),
          // ZxingReaderWidget(onScan: (result) async {
          //   // _resultQueue.insert(0, result);
          //   // await Future.delayed(const Duration(milliseconds: 500));
          //   // setState(() {});
          // }),
          // Image scanner
          Container(),
        ],
      ),
    );
  }
}
