part of 'zxing.dart';

IsolateUtils? isolateUtils;

/// Starts reading barcode from the camera
Future<void> zxingStartCameraProcessing() async {
  if (isolateUtils != null) {
    return;
  }
  isolateUtils = IsolateUtils();
  await isolateUtils?.startReadingBarcode();
}

/// Stops reading barcode from the camera
void zxingStopCameraProcessing() {
  isolateUtils?.stopReadingBarcode();
  isolateUtils = null;
}

Future<dynamic> zxingProcessCameraImage(
        CameraImage image, DecodeParams params) =>
    _inference(IsolateData(image, params));

/// Runs inference in another isolate
Future<dynamic> _inference(IsolateData isolateData) async {
  final ReceivePort responsePort = ReceivePort();
  isolateUtils?.sendPort
      ?.send(isolateData..responsePort = responsePort.sendPort);
  final dynamic results = await responsePort.first;
  return results;
}
