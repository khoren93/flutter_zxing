// What an iPhone camera does on its own, read from AVFoundation through the
// Objective-C runtime: exposure, ISO, frame duration, focus. For the spike
// watch (R4-03): a spike next to a change of these points at the camera.
import 'dart:ffi';
import 'dart:io';

typedef _Id = Pointer<Void>;

/// CMTime: a value over a timescale.
final class _CMTime extends Struct {
  @Int64()
  external int value;
  @Int32()
  external int timescale;
  @Uint32()
  external int flags;
  @Int64()
  external int epoch;
}

/// One reading of the camera.
typedef CameraNumbers = ({
  double iso,
  double exposureMs,
  double maxFps,
  double lensPosition,
  bool adjustingFocus,
  bool adjustingExposure,
  bool adjustingWhiteBalance,
});

/// Reads one camera, an AVCaptureDevice named by its uniqueID (the camera
/// plugin's CameraDescription.name on iOS).
final class IosCameraNumbers {
  IosCameraNumbers._(this._device);

  static final DynamicLibrary _lib = DynamicLibrary.process();
  static final _Id Function(Pointer<Uint8>) _getClass = _lib
      .lookupFunction<
        _Id Function(Pointer<Uint8>),
        _Id Function(Pointer<Uint8>)
      >('objc_getClass');
  static final _Id Function(Pointer<Uint8>) _sel = _lib
      .lookupFunction<
        _Id Function(Pointer<Uint8>),
        _Id Function(Pointer<Uint8>)
      >('sel_registerName');
  static final Pointer<Uint8> Function(int) _malloc = _lib
      .lookupFunction<
        Pointer<Uint8> Function(IntPtr),
        Pointer<Uint8> Function(int)
      >('malloc');
  static final Pointer<Void> _msgSend = _lib.lookup<Void>('objc_msgSend');
  static final _Id Function(_Id, _Id) _send = _msgSend
      .cast<NativeFunction<_Id Function(_Id, _Id)>>()
      .asFunction();
  static final _Id Function(_Id, _Id, _Id) _sendId = _msgSend
      .cast<NativeFunction<_Id Function(_Id, _Id, _Id)>>()
      .asFunction();
  static final _Id Function(_Id, _Id, Pointer<Uint8>) _sendChars = _msgSend
      .cast<NativeFunction<_Id Function(_Id, _Id, Pointer<Uint8>)>>()
      .asFunction();
  static final double Function(_Id, _Id) _sendFloat = _msgSend
      .cast<NativeFunction<Float Function(_Id, _Id)>>()
      .asFunction();
  static final bool Function(_Id, _Id) _sendBool = _msgSend
      .cast<NativeFunction<Bool Function(_Id, _Id)>>()
      .asFunction();
  static final _CMTime Function(_Id, _Id) _sendTime = _msgSend
      .cast<NativeFunction<_CMTime Function(_Id, _Id)>>()
      .asFunction();

  static Pointer<Uint8> _c(String s) {
    final Pointer<Uint8> p = _malloc(s.length + 1);
    for (int i = 0; i < s.length; i++) {
      p[i] = s.codeUnitAt(i);
    }
    p[s.length] = 0;
    return p;
  }

  // Selectors live as long as the app: looked up once.
  static final _Id _iso = _sel(_c('ISO'));
  static final _Id _exposure = _sel(_c('exposureDuration'));
  static final _Id _frame = _sel(_c('activeVideoMinFrameDuration'));
  static final _Id _lens = _sel(_c('lensPosition'));
  static final _Id _focusing = _sel(_c('isAdjustingFocus'));
  static final _Id _exposing = _sel(_c('isAdjustingExposure'));
  static final _Id _balancing = _sel(_c('isAdjustingWhiteBalance'));

  final _Id _device;

  /// The camera named [uniqueId]; `null` off iOS or if it is not there.
  static IosCameraNumbers? open(String uniqueId) {
    if (!Platform.isIOS) {
      return null;
    }
    try {
      final _Id string = _sendChars(
        _getClass(_c('NSString')),
        _sel(_c('stringWithUTF8String:')),
        _c(uniqueId),
      );
      final _Id device = _sendId(
        _getClass(_c('AVCaptureDevice')),
        _sel(_c('deviceWithUniqueID:')),
        string,
      );
      if (device == nullptr) {
        return null;
      }
      _send(device, _sel(_c('retain')));
      return IosCameraNumbers._(device);
    } on Object {
      return null;
    }
  }

  /// The camera now.
  CameraNumbers read() {
    final _CMTime e = _sendTime(_device, _exposure);
    final _CMTime f = _sendTime(_device, _frame);
    return (
      iso: _sendFloat(_device, _iso),
      exposureMs: e.timescale == 0 ? 0 : e.value / e.timescale * 1000,
      maxFps: f.value == 0 ? 0 : f.timescale / f.value,
      lensPosition: _sendFloat(_device, _lens),
      adjustingFocus: _sendBool(_device, _focusing),
      adjustingExposure: _sendBool(_device, _exposing),
      adjustingWhiteBalance: _sendBool(_device, _balancing),
    );
  }
}
