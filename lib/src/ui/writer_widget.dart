import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

import '../../flutter_zxing.dart';

class WriterWidget extends StatefulWidget {
  const WriterWidget({
    super.key,
    this.text = '',
    this.format = Format.QRCode,
    this.width = 120,
    this.height = 120,
    this.margin = 0,
    this.eccLevel = 0,
    this.messages = const Messages(),
    this.onSuccess,
    this.onError,
  });

  final String text;
  final int format;
  final int width;
  final int height;
  final int margin;
  final int eccLevel;
  final Messages messages;
  final Function(EncodeResult result, Uint8List? bytes)? onSuccess;
  final Function(String error)? onError;

  @override
  State<WriterWidget> createState() => _WriterWidgetState();
}

class _WriterWidgetState extends State<WriterWidget>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _marginController = TextEditingController();
  final TextEditingController _eccController = TextEditingController();

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  final int _maxTextLength = 2000;
  final List<int> _supportedFormats = CodeFormat.writerFormats;
  int _codeFormat = Format.QRCode;

  @override
  void initState() {
    _textController.text = widget.text;
    _widthController.text = widget.width.toString();
    _heightController.text = widget.height.toString();
    _marginController.text = widget.margin.toString();
    _eccController.text = widget.eccLevel.toString();
    _codeFormat = widget.format;
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _marginController.dispose();
    _eccController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Messages m = widget.messages;
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
                  labelText: m.textLabel,
                  counterText:
                      '${_textController.value.text.length} / $_maxTextLength',
                ),
                validator: (String? value) {
                  if (value?.isEmpty ?? false) {
                    return m.invalidText;
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
                      decoration: InputDecoration(
                        labelText: m.widthLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return m.invalidWidth;
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
                      decoration: InputDecoration(
                        labelText: m.heightLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return m.invalidHeight;
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
                      decoration: InputDecoration(
                        labelText: m.marginLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return m.invalidMargin;
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
                      decoration: InputDecoration(
                        labelText: m.eccLevelLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return m.invalidEccLevel;
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
                child: Text(m.createButton),
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
      final EncodeResult result = encodeBarcode(
        text,
        format: _codeFormat,
        width: width,
        height: height,
        margin: margin,
        eccLevel: ecc,
      );
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
