import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

import 'flutter_zxing.dart';

class ZxingWriterWidget extends StatefulWidget {
  const ZxingWriterWidget({
    Key? key,
    this.onSuccess,
    this.onError,
  }) : super(key: key);

  final Function(EncodeResult, Uint8List)? onSuccess;
  final Function(String)? onError;

  @override
  State<ZxingWriterWidget> createState() => _ZxingWriterWidgetState();
}

class _ZxingWriterWidgetState extends State<ZxingWriterWidget>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _widthController =
      TextEditingController(text: "300");
  final TextEditingController _heightController =
      TextEditingController(text: "300");
  final TextEditingController _marginController =
      TextEditingController(text: "10");
  final TextEditingController _eccController = TextEditingController(text: "0");

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  final _maxTextLength = 2000;
  final _supportedFormats = CodeFormat.writerFormats;
  var _codeFormat = Format.QRCode;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(height: 20),
              // Input multiline text
              TextFormField(
                controller: _textController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                maxLength: _maxTextLength,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  labelText: 'Enter barcode text here',
                  counterText:
                      '${_textController.value.text.length} / $_maxTextLength',
                ),
                validator: (value) {
                  if (value?.isEmpty == true) {
                    return 'Please enter some text';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Format DropDown button
              DropdownButtonFormField<int>(
                value: _codeFormat,
                items: _supportedFormats
                    .map((format) => DropdownMenuItem(
                          value: format,
                          child: Text(FlutterZxing.formatName(format)),
                        ))
                    .toList(),
                onChanged: (format) {
                  setState(() {
                    _codeFormat = format ?? Format.QRCode;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Flexible(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Width',
                      ),
                      validator: (value) {
                        final width = int.tryParse(value ?? '');
                        if (width == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Height',
                      ),
                      validator: (value) {
                        final width = int.tryParse(value ?? '');
                        if (width == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Flexible(
                    child: TextFormField(
                      controller: _marginController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Margin',
                      ),
                      validator: (value) {
                        final width = int.tryParse(value ?? '');
                        if (width == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: TextFormField(
                      controller: _eccController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ECC Level',
                      ),
                      validator: (value) {
                        final width = int.tryParse(value ?? '');
                        if (width == null) {
                          return 'Invalid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Write button
              ElevatedButton(
                onPressed: createBarcode,
                child: const Text('Create'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void createBarcode() {
    if (_formKey.currentState?.validate() ?? false) {
      _formKey.currentState?.save();
      FocusScope.of(context).unfocus();
      final text = _textController.value.text;
      final width = int.parse(_widthController.value.text);
      final height = int.parse(_heightController.value.text);
      final margin = int.parse(_marginController.value.text);
      final ecc = int.parse(_eccController.value.text);
      var result = FlutterZxing.encodeBarcode(
          text, width, height, _codeFormat, margin, ecc);
      String? error;
      if (result.isValidBool) {
        try {
          final img = imglib.Image.fromBytes(width, height, result.bytes);
          final encodedBytes = Uint8List.fromList(imglib.encodeJpg(img));
          widget.onSuccess?.call(result, encodedBytes);
        } on Exception catch (e) {
          error = e.toString();
        }
      } else {
        error = result.errorMessage;
      }
      if (error != null) {
        debugPrint(error);
        widget.onError?.call(error);
      }
    }
  }
}
