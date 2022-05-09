import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    Key? key,
  }) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _resultQueue = <CodeResult>[];

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
                title: Text(result.textString ?? ''),
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
