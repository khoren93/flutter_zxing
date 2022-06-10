part of 'zxing.dart';

IsolateUtils? isolateUtils;

/// Starts reading barcode from the camera
Future<void> startCameraProcessing() async {
  isolateUtils = IsolateUtils();
  await isolateUtils?.startReadingBarcode();
}

/// Stops reading barcode from the camera
void stopCameraProcessing() => isolateUtils?.stopReadingBarcode();

Future<CodeResult> processCameraImage(CameraImage image,
    {int format = Format.Any, double cropPercent = 0.5}) async {
  final IsolateData isolateData = IsolateData(image, format, cropPercent);
  final CodeResult result = await _inference(isolateData);
  return result;
}

/// Runs inference in another isolate
Future<CodeResult> _inference(IsolateData isolateData) async {
  final ReceivePort responsePort = ReceivePort();
  isolateUtils?.sendPort
      ?.send(isolateData..responsePort = responsePort.sendPort);
  final dynamic results = await responsePort.first;
  return results;
}
