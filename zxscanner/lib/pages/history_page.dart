import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/code.dart';
import '../utils/db_service.dart';
import '../widgets/common_widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
  });

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

  ValueListenableBuilder<Box<Code>> _buildResultList() {
    return ValueListenableBuilder<Box<Code>>(
        valueListenable: DbService.instance.getCodes().listenable(),
        builder: (BuildContext context, Box<Code> box, _) {
          final List<Code> results = box.values.toList().cast<Code>();
          return results.isEmpty
              ? const Center(
                  child: Text(
                  'No Results',
                  style: TextStyle(fontSize: 24),
                ))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Code result = results[index];
                    return ContainerX(
                      child: Card(
                        child: ListTile(
                          title: Text(result.text ?? ''),
                          subtitle: Text(result.formatName),
                          trailing: OverflowBar(
                            children: <Widget>[
                              // Copy button
                              IconButton(
                                icon: const Icon(FontAwesomeIcons.copy),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: result.text ?? ''));
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
