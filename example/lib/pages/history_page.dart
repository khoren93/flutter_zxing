import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing_example/models/code.dart';
import 'package:flutter_zxing_example/utils/db_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    Key? key,
  }) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
      ),
      body: _buildResultList(),
    );
  }

  _buildResultList() {
    return ValueListenableBuilder<Box<Code>>(
        valueListenable: DbService.instance.getCodes().listenable(),
        builder: (context, box, _) {
          final results = box.values.toList().cast<Code>();
          return results.isEmpty
              ? const Center(
                  child: Text(
                  'No Results',
                  style: TextStyle(fontSize: 24),
                ))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ListTile(
                      title: Text(result.text ?? ''),
                      subtitle: Text(result.format.toString()),
                      trailing: ButtonBar(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Copy button
                          TextButton(
                            child: const Text('Copy'),
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: result.text));
                            },
                          ),
                          // Remove button
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // DbService.instance.deleteCode(result);
                              // setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
        });
  }
}
