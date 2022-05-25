import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zxscanner/models/code.dart';
import 'package:zxscanner/utils/db_service.dart';
import 'package:zxscanner/widgets/common_widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
                    return ContainerX(
                      child: Card(
                        child: ListTile(
                          title: Text(result.text ?? ''),
                          subtitle: Text(result.formatName),
                          trailing: ButtonBar(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Copy button
                              IconButton(
                                icon: const Icon(FontAwesomeIcons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: result.text));
                                },
                              ),
                              // Remove button
                              IconButton(
                                icon: const Icon(FontAwesomeIcons.trash,
                                    color: Colors.red),
                                onPressed: () {
                                  DbService.instance.deleteCode(result);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
        });
  }
}
