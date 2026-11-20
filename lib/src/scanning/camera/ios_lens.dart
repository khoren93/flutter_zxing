// The focus of an iPhone camera, read straight from AVFoundation through the
// Objective-C runtime: the camera plugin does not report it, and this needs
// no native code of the package. The camera plugin names its cameras by
// AVCaptureDevice.uniqueID, so the device is looked up by that name.
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'camera_source.dart';

typedef _Id = Pointer<Void>;

final DynamicLibrary _process = DynamicLibrary.process();

final _Id Function(Pointer<Utf8>) _getClass = _process
    .lookupFunction<_Id Function(Pointer<Utf8>), _Id Function(Pointer<Utf8>)>(
      'objc_getClass',
    );
final _Id Function(Pointer<Utf8>) _registerName = _process
    .lookupFunction<_Id Function(Pointer<Utf8>), _Id Function(Pointer<Utf8>)>(
      'sel_registerName',
    );

// objc_msgSend, typed for each kind of call.
final _Id Function(_Id, _Id) _send = _process
    .lookupFunction<_Id Function(_Id, _Id), _Id Function(_Id, _Id)>(
      'objc_msgSend',
    );
final _Id Function(_Id, _Id, Pointer<Void>) _sendPointer = _process
    .lookupFunction<
      _Id Function(_Id, _Id, Pointer<Void>),
      _Id Function(_Id, _Id, Pointer<Void>)
    >('objc_msgSend');
final bool Function(_Id, _Id, _Id) _sendBool = _process
    .lookupFunction<Bool Function(_Id, _Id, _Id), bool Function(_Id, _Id, _Id)>(
      'objc_msgSend',
    );
final _Id Function(_Id, _Id, _Id, _Id, int) _sendDefaultDevice = _process
    .lookupFunction<
      _Id Function(_Id, _Id, _Id, _Id, Long),
      _Id Function(_Id, _Id, _Id, _Id, int)
    >('objc_msgSend');
final int Function(_Id, _Id) _sendInt = _process
    .lookupFunction<UnsignedLong Function(_Id, _Id), int Function(_Id, _Id)>(
      'objc_msgSend',
    );
final _Id Function(_Id, _Id, int) _sendIndex = _process
    .lookupFunction<
      _Id Function(_Id, _Id, UnsignedLong),
      _Id Function(_Id, _Id, int)
    >('objc_msgSend');
final double Function(_Id, _Id) _sendDouble = _process
    .lookupFunction<Double Function(_Id, _Id), double Function(_Id, _Id)>(
      'objc_msgSend',
    );
final bool Function(_Id, _Id) _sendFlag = _process
    .lookupFunction<Bool Function(_Id, _Id), bool Function(_Id, _Id)>(
      'objc_msgSend',
    );
final int Function(_Id, _Id) _sendLong = _process
    .lookupFunction<Long Function(_Id, _Id), int Function(_Id, _Id)>(
      'objc_msgSend',
    );
final double Function(_Id, _Id) _sendFloat = _process
    .lookupFunction<Float Function(_Id, _Id), double Function(_Id, _Id)>(
      'objc_msgSend',
    );

_Id _selector(String name) {
  final Pointer<Utf8> chars = name.toNativeUtf8();
  try {
    return _registerName(chars);
  } finally {
    malloc.free(chars);
  }
}

_Id _class(String name) {
  final Pointer<Utf8> chars = name.toNativeUtf8();
  try {
    return _getClass(chars);
  } finally {
    malloc.free(chars);
  }
}

final _Id _alloc = _selector('alloc');
final _Id _initWithUtf8 = _selector('initWithUTF8String:');
final _Id _retain = _selector('retain');
final _Id _release = _selector('release');
final _Id _respondsTo = _selector('respondsToSelector:');
final _Id _deviceWithUniqueId = _selector('deviceWithUniqueID:');
final _Id _lensPosition = _selector('lensPosition');
final _Id _isAdjustingFocus = _selector('isAdjustingFocus');
final _Id _minimumFocusDistance = _selector('minimumFocusDistance');
final _Id _defaultDevice = _selector(
  'defaultDeviceWithDeviceType:mediaType:position:',
);
final _Id _switchOverFactors = _selector(
  'virtualDeviceSwitchOverVideoZoomFactors',
);
final _Id _count = _selector('count');
final _Id _objectAtIndex = _selector('objectAtIndex:');
final _Id _doubleValue = _selector('doubleValue');
final _Id _currentDevice = _selector('currentDevice');
final _Id _orientation = _selector('orientation');

/// The NSString constant [name] of AVFoundation (a device or media type).
_Id _constant(String name) => _process.lookup<_Id>(name).value;

/// An iPhone camera (`AVCaptureDevice`), held while it is open.
final class IosLens {
  IosLens._(this._device, this.minimumFocusDistance);

  /// The camera named [uniqueId], or `null` when there is none or it cannot
  /// be read.
  static IosLens? open(String uniqueId) {
    try {
      final _Id deviceClass = _class('AVCaptureDevice');
      if (deviceClass == nullptr) {
        return null;
      }
      final Pointer<Utf8> chars = uniqueId.toNativeUtf8();
      final _Id name = _sendPointer(
        _send(_class('NSString'), _alloc),
        _initWithUtf8,
        chars.cast(),
      );
      malloc.free(chars);
      final _Id device = _sendPointer(deviceClass, _deviceWithUniqueId, name);
      _send(name, _release);
      if (device == nullptr || !_sendBool(device, _respondsTo, _lensPosition)) {
        return null;
      }
      _send(device, _retain);
      // iOS 15 and later.
      final int? minimum = _sendBool(device, _respondsTo, _minimumFocusDistance)
          ? _sendLong(device, _minimumFocusDistance)
          : null;
      return IosLens._(device, minimum != null && minimum > 0 ? minimum : null);
    } on Object {
      return null; // no Objective-C runtime here
    }
  }

  /// The zoom of the telephoto camera in the main camera's terms (3, 4, 5…),
  /// on the [back] or the front side, or `null` without one. Taken from the
  /// zoom factors at which the system's multi-camera device switches lenses.
  static double? telephotoZoom({bool back = true}) {
    try {
      final _Id deviceClass = _class('AVCaptureDevice');
      final _Id video = _constant('AVMediaTypeVideo');
      // Ultra-wide, wide and telephoto: switches at the wide and the
      // telephoto camera. Wide and telephoto: switches at the telephoto.
      for (final (String type, bool hasUltraWide) in <(String, bool)>[
        ('AVCaptureDeviceTypeBuiltInTripleCamera', true),
        ('AVCaptureDeviceTypeBuiltInDualCamera', false),
      ]) {
        final _Id device = _sendDefaultDevice(
          deviceClass,
          _defaultDevice,
          _constant(type),
          video,
          back ? 1 : 2, // AVCaptureDevicePositionBack, …Front
        );
        if (device == nullptr) {
          continue;
        }
        final _Id factors = _send(device, _switchOverFactors);
        final int count = factors == nullptr ? 0 : _sendInt(factors, _count);
        if (count < (hasUltraWide ? 2 : 1)) {
          continue;
        }
        double factor(int i) =>
            _sendDouble(_sendIndex(factors, _objectAtIndex, i), _doubleValue);
        final double zoom = hasUltraWide
            ? factor(count - 1) / factor(0)
            : factor(count - 1);
        return zoom > 1 ? zoom : null;
      }
      return null;
    } on Object {
      return null; // not AVFoundation, or an older one
    }
  }

  /// The device's physical orientation as UIKit reports it
  /// (`UIDeviceOrientation`: 1 portrait, 2 upside down, 3 landscape left,
  /// 4 landscape right, 5 face up, 6 face down, 0 unknown); `null` where it
  /// cannot be read. The camera plugin turns focus points by it.
  static int? deviceOrientation() {
    try {
      final _Id deviceClass = _class('UIDevice');
      if (deviceClass == nullptr) {
        return null;
      }
      final _Id device = _send(deviceClass, _currentDevice);
      return device == nullptr ? null : _sendLong(device, _orientation);
    } on Object {
      return null; // no UIKit here
    }
  }

  /// The nearest the camera named [uniqueId] can focus, in millimeters;
  /// `null` for a fixed focus, before iOS 15 and where unknown.
  static int? minimumFocusDistanceOf(String uniqueId) {
    final IosLens? lens = open(uniqueId);
    lens?.release();
    return lens?.minimumFocusDistance;
  }

  _Id? _device;

  /// The nearest the camera can focus, in millimeters; `null` where iOS
  /// does not say (before iOS 15, fixed focus).
  final int? minimumFocusDistance;

  /// Where the lens is focused now; `null` once released.
  LensFocus? get focus {
    final _Id? device = _device;
    if (device == null) {
      return null;
    }
    return LensFocus(
      _sendFloat(device, _lensPosition),
      adjusting: _sendFlag(device, _isAdjustingFocus),
      minimumDistance: minimumFocusDistance,
    );
  }

  /// Lets the camera go.
  void release() {
    final _Id? device = _device;
    _device = null;
    if (device != null) {
      _send(device, _release);
    }
  }
}
