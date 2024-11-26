part of 'zxing.dart';

final GeneratedBindings bindings = GeneratedBindings(dylib);

// Getting a library that holds needed symbols
DynamicLibrary _openDynamicLibrary() {
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libflutter_zxing.so');
  } else if (Platform.isWindows) {
    return DynamicLibrary.open('flutter_zxing.dll');
  }
  return DynamicLibrary.process();
}

DynamicLibrary dylib = _openDynamicLibrary();
