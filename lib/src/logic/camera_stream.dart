part of 'zxing.dart';

IsolateUtils? isolateUtils;

/// Number of callers that have started camera processing without stopping it
/// again. The decoding isolate is shared, so it may only be torn down once the
/// last caller is done with it — otherwise disposing one `ReaderWidget` would
/// break every other one still on screen.
int _cameraProcessingRefCount = 0;

/// Starts reading barcode from the camera
Future<void> zxingStartCameraProcessing() async {
  _cameraProcessingRefCount++;
  final IsolateUtils utils = isolateUtils ??= IsolateUtils();
  try {
    await utils.startReadingBarcode();
  } catch (_) {
    _cameraProcessingRefCount = _cameraProcessingRefCount > 0
        ? _cameraProcessingRefCount - 1
        : 0;
    if (_cameraProcessingRefCount == 0) {
      isolateUtils = null;
    }
    rethrow;
  }
}

/// Stops reading barcode from the camera
void zxingStopCameraProcessing() {
  if (_cameraProcessingRefCount > 0) {
    _cameraProcessingRefCount--;
  }
  if (_cameraProcessingRefCount > 0) {
    return;
  }
  isolateUtils?.stopReadingBarcode();
  isolateUtils = null;
}

Future<dynamic> zxingProcessCameraImage(
  CameraImage image,
  DecodeParams params,
) => _inference(IsolateData(image, params));

/// Runs inference in another isolate
Future<dynamic> _inference(IsolateData isolateData) async {
  final IsolateUtils? utils = isolateUtils;
  if (utils == null || !utils.isRunning) {
    throw StateError(
      'Camera processing is not running. '
      'Call `zx.startCameraProcessing()` before processing camera images.',
    );
  }
  return utils.process(isolateData);
}
