import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../flutter_zxing.dart';

/// Widget to create a code from a text and barcode format
class WriterWidget extends StatefulWidget {
  const WriterWidget({
    super.key,
    this.text,
    this.format = Format.qrCode,
    this.height = 120, // Width is calculated from height and format ratio
    this.margin = 0,
    this.eccLevel = EccLevel.low,
    this.messages = const Messages(),
    this.onSuccess,
    this.onError,
  });

  final String? text;
  final int format;
  final int height;
  final int margin;
  final EccLevel eccLevel;
  final Messages messages;
  final Function(Encode result, Uint8List? bytes)? onSuccess;
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

  bool isAndroid() => Theme.of(context).platform == TargetPlatform.android;

  final List<int> _supportedFormats = CodeFormat.supportedEncodeFormats;

  int _codeFormat = Format.qrCode;
  EccLevel _eccLevel = EccLevel.low;

  Messages get messages => widget.messages;
  Map<EccLevel, String> get _eccTitlesMap => <EccLevel, String>{
        EccLevel.low: messages.lowEccLevel,
        EccLevel.medium: messages.mediumEccLevel,
        EccLevel.quartile: messages.quartileEccLevel,
        EccLevel.high: messages.highEccLevel,
      };

  @override
  void initState() {
    _codeFormat = widget.format;
    _eccLevel = widget.eccLevel;
    _textController.text = widget.text ?? _codeFormat.demoText;
    _widthController.text =
        (widget.height * _codeFormat.ratio).round().toString();
    _heightController.text = widget.height.toString();
    _marginController.text = widget.margin.toString();
    super.initState();
  }

  @override
  void dispose() {
    _textController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _marginController.dispose();
    super.dispose();
  }

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
                maxLength: _codeFormat.maxTextLength,
                onChanged: (String value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  filled: true,
                  labelText: messages.textLabel,
                  counterText:
                      '${_textController.value.text.length} / ${_codeFormat.maxTextLength}',
                ),
                validator: (String? value) {
                  if (value?.isEmpty ?? false) {
                    return messages.invalidText;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Format DropDown button
              Row(
                children: <Widget>[
                  Flexible(
                    child: DropdownButtonFormField<int>(
                      value: _codeFormat,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        filled: true,
                        labelText: messages.formatLabel,
                      ),
                      items: _supportedFormats
                          .map((int format) => DropdownMenuItem<int>(
                                value: format,
                                child: Text(zx.barcodeFormatName(format)),
                              ))
                          .toList(),
                      onChanged: (int? format) {
                        setState(() {
                          _codeFormat = format ?? Format.qrCode;
                          _textController.text = _codeFormat.demoText;
                          _heightController.text = widget.height.toString();
                          _widthController.text =
                              (widget.height * _codeFormat.ratio)
                                  .round()
                                  .toString();
                        });
                      },
                    ),
                  ),
                  if (_codeFormat.isSupportedEccLevel) ...<Widget>[
                    const SizedBox(width: 6),
                    Flexible(
                      child: DropdownButtonFormField<EccLevel>(
                        value: _eccLevel,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          filled: true,
                          labelText: messages.eccLevelLabel,
                        ),
                        items: _eccTitlesMap.entries
                            .map((MapEntry<EccLevel, String> entry) =>
                                DropdownMenuItem<EccLevel>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: (EccLevel? ecc) {
                          setState(() {
                            _eccLevel = ecc ?? EccLevel.low;
                          });
                        },
                      ),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: <Widget>[
                  Flexible(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: messages.widthLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return messages.invalidWidth;
                        }
                        return null;
                      },
                      onChanged: (String value) {
                        // use format ratio to calculate height
                        final int? width = int.tryParse(value);
                        if (width != null) {
                          final int height =
                              (width / _codeFormat.ratio).round();
                          _heightController.text = height.toString();
                        }
                      },
                    ),
                  ),
                  // const SizedBox(width: 8),
                  Flexible(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: messages.heightLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return messages.invalidHeight;
                        }
                        return null;
                      },
                      onChanged: (String value) {
                        // use format ratio to calculate width
                        final int? height = int.tryParse(value);
                        if (height != null) {
                          final int width =
                              (height * _codeFormat.ratio).round();
                          _widthController.text = width.toString();
                        }
                      },
                    ),
                  ),
                  Flexible(
                    child: TextFormField(
                      controller: _marginController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: messages.marginLabel,
                      ),
                      validator: (String? value) {
                        final int? width = int.tryParse(value ?? '');
                        if (width == null) {
                          return messages.invalidMargin;
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
                child: Text(messages.createButton),
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
      final EccLevel ecc = _eccLevel;
      final Encode result = zx.encodeBarcode(
        contents: text,
        params: EncodeParams(
          format: _codeFormat,
          width: width,
          height: height,
          margin: margin,
          eccLevel: ecc,
        ),
      );
      String? error;
      if (result.isValid && result.data != null) {
        try {
          final Uint8List encodedBytes =
              pngFromBytes(result.data!, width, height);
          widget.onSuccess?.call(result, encodedBytes);
        } catch (e) {
          error = e.toString();
        }
      } else {
        error = result.error;
      }
      if (error != null) {
        widget.onError?.call(error);
      }
    }
  }
}
