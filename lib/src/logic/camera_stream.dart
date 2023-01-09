part of 'zxing.dart';

IsolateUtils? isolateUtils;

/// Starts reading barcode from the camera
Future<void> zxingStartCameraProcessing() async {
  isolateUtils = IsolateUtils();
  await isolateUtils?.startReadingBarcode();
}

/// Stops reading barcode from the camera
void zxingStopCameraProcessing() => isolateUtils?.stopReadingBarcode();

Future<dynamic> zxingProcessCameraImage(
  CameraImage image, {
  DecodeParams? params,
}) async {
  final IsolateData isolateData = IsolateData(image, params ?? DecodeParams());
  final dynamic result = await _inference(isolateData);
  return result;
}

/// Runs inference in another isolate
Future<dynamic> _inference(IsolateData isolateData) async {
  final ReceivePort responsePort = ReceivePort();
  isolateUtils?.sendPort
      ?.send(isolateData..responsePort = responsePort.sendPort);
  final dynamic results = await responsePort.first;
  return results;
}
