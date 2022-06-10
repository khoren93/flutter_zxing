import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

import '../../flutter_zxing.dart';

class WriterWidget extends StatefulWidget {
  const WriterWidget({
    super.key,
    this.onSuccess,
    this.onError,
  });

  final Function(EncodeResult, Uint8List?)? onSuccess;
  final Function(String)? onError;

  @override
  State<WriterWidget> createState() => _WriterWidgetState();
}

class _WriterWidgetState extends State<WriterWidget>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _widthController =
      TextEditingController(text: '300');
  final TextEditingController _heightController =
      TextEditingController(text: '300');
  final TextEditingController _marginController =
      TextEditingController(text: '10');
  final TextEditingController _eccController = TextEditingController(text: '0');

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  final int _maxTextLength = 2000;
  final List<int> _supportedFormats = CodeFormat.writerFormats;
  int _codeFormat = Format.QRCode;

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
            children: <Widget>[
              const SizedBox(height: 20),
              // Input multiline text
              TextFormField(
                controller: _textController,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                maxLength: _maxTextLength,
                onChanged: (String value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  labelText: 'Enter barcode text here',
                  counterText:
                      '${_textController.value.text.length} / $_maxTextLength',
                ),
                validator: (String? value) {
                  if (value?.isEmpty ?? false) {
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
                    .map((int format) => DropdownMenuItem<int>(
                          value: format,
                          child: Text(barcodeFormatName(format)),
                        ))
                    .toList(),
                onChanged: (int? format) {
                  setState(() {
                    _codeFormat = format ?? Format.QRCode;
                  });
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Flexible(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Width',
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
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
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
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
                children: <Widget>[
                  Flexible(
                    child: TextFormField(
                      controller: _marginController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Margin',
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
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
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
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
              const SizedBox(height: 10),
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
      final String text = _textController.value.text;
      final int width = int.parse(_widthController.value.text);
      final int height = int.parse(_heightController.value.text);
      final int margin = int.parse(_marginController.value.text);
      final int ecc = int.parse(_eccController.value.text);
      final EncodeResult result =
          encodeBarcode(text, width, height, _codeFormat, margin, ecc);
      String? error;
      if (result.isValidBool) {
        try {
          final imglib.Image img = imglib.Image.fromBytes(
            width,
            height,
            result.bytes,
          );
          final Uint8List encodedBytes = Uint8List.fromList(
            imglib.encodeJpg(img),
          );
          widget.onSuccess?.call(result, encodedBytes);
        } catch (e) {
          error = e.toString();
        }
      } else {
        error = result.errorMessage;
      }
      if (error != null) {
        widget.onError?.call(error);
      }
    }
  }
}
