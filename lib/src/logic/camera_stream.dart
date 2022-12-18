part of 'zxing.dart';

IsolateUtils? isolateUtils;

/// Starts reading barcode from the camera
Future<void> zxingStartCameraProcessing() async {
  isolateUtils = IsolateUtils();
  await isolateUtils?.startReadingBarcode();
}

/// Stops reading barcode from the camera
void zxingStopCameraProcessing() => isolateUtils?.stopReadingBarcode();

Future<Code> zxingProcessCameraImage(
  CameraImage image, {
  Params? params,
}) async {
  final IsolateData isolateData = IsolateData(image, params ?? Params());
  final Code result = await _inference(isolateData);
  return result;
}

/// Runs inference in another isolate
Future<Code> _inference(IsolateData isolateData) async {
  final ReceivePort responsePort = ReceivePort();
  isolateUtils?.sendPort
      ?.send(isolateData..responsePort = responsePort.sendPort);
  final dynamic results = await responsePort.first;
  return results;
}
