
import 'dart:async';

import 'package:flutter/services.dart';

class FlutterZxing {
  static const MethodChannel _channel = MethodChannel('flutter_zxing');

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
