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

  final Function(Uint8List)? onSuccess;
  final Function(String)? onError;

  @override
  State<ZxingWriterWidget> createState() => _ZxingWriterWidgetState();
}

class _ZxingWriterWidgetState extends State<ZxingWriterWidget>
    with TickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _textController = TextEditingController();

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
              // Format DropDown button
              DropdownButtonFormField<int>(
                value: _codeFormat,
                items: _supportedFormats
                    .map((format) => DropdownMenuItem(
                          value: format,
                          child: Text(CodeFormat.formatName(format)),
                        ))
                    .toList(),
                onChanged: (format) {
                  setState(() {
                    _codeFormat = format ?? Format.QRCode;
                  });
                },
              ),
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
                  hintText: 'Enter text to create a barcode',
                  counterText:
                      '${_textController.value.text.length} / $_maxTextLength',
                ),
              ),
              // Write button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _formKey.currentState?.save();
                    FocusScope.of(context).unfocus();
                    final text = _textController.value.text;
                    const width = 300;
                    const height = 300;
                    final result = FlutterZxing.encodeBarcode(
                        text, width, height, _codeFormat, 5, 0);
                    String? error;
                    if (result.isValidBool) {
                      try {
                        final img =
                            imglib.Image.fromBytes(width, height, result.bytes);
                        final resultBytes =
                            Uint8List.fromList(imglib.encodeJpg(img));
                        widget.onSuccess?.call(resultBytes);
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
                },
                child: const Text('Create'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
