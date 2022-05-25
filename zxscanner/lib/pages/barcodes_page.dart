import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zxscanner/models/models.dart';
import 'package:zxscanner/utils/db_service.dart';
import 'package:zxscanner/utils/router.dart';
import 'package:zxscanner/widgets/common_widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

class BarcodesPage extends StatefulWidget {
  const BarcodesPage({
    Key? key,
  }) : super(key: key);

  @override
  State<BarcodesPage> createState() => _BarcodesPageState();
}

class _BarcodesPageState extends State<BarcodesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcodes'),
      ),
      body: _buildResultList(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(FontAwesomeIcons.plus),
        onPressed: () {
          Navigator.of(context).pushNamed(AppRoutes.creator);
        },
      ),
    );
  }

  _buildResultList() {
    return ValueListenableBuilder<Box<Encode>>(
        valueListenable: DbService.instance.getEncodes().listenable(),
        builder: (context, box, _) {
          final results = box.values.toList().cast<Encode>();
          return results.isEmpty
              ? const Center(
                  child: Text(
                  'Tap + to create a Barcode',
                  style: TextStyle(fontSize: 24),
                ))
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return ContainerX(
                      child: Card(
                        child: ListTile(
                          leading: Image.memory(
                            result.data ?? Uint8List(0),
                            width: 60,
                          ),
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
                                  DbService.instance.deleteEncode(result);
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
