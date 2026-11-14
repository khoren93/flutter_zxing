// Where a camera frame ends up on screen, and back: the frame is rotated
// and mirrored into the orientation it is shown in, then fitted into the
// scanner widget. Pure geometry, no platform code; not exported.
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:flutter/widgets.dart' show Orientation;

import '../barcode/barcode.dart';

/// How a camera frame is shown: rotated clockwise by [rotation] degrees,
/// then mirrored left to right if [mirrored].
///
/// Frames come in the orientation the camera delivers them (on Android the
/// sensor's, usually landscape); the result is the frame as the user sees it
/// in the preview, called the display frame here.
@immutable
final class FrameTransform {
  /// Creates a transform. [rotation] is 0, 90, 180 or 270.
  const FrameTransform(
    this.frameSize, {
    this.rotation = 0,
    this.mirrored = false,
  }) : assert(
         rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270,
         'rotation is a multiple of 90 degrees',
       );

  /// Size of the frame as delivered.
  final Size frameSize;

  /// Clockwise rotation from the delivered frame to the display frame.
  final int rotation;

  /// Whether the display frame is mirrored left to right (front camera).
  final bool mirrored;

  /// Size of the display frame.
  Size get displaySize => rotation % 180 == 0 ? frameSize : frameSize.flipped;

  /// A point of the delivered frame in the display frame.
  Offset toDisplay(Offset p) {
    final double w = frameSize.width;
    final double h = frameSize.height;
    final Offset r = switch (rotation) {
      90 => Offset(h - p.dy, p.dx),
      180 => Offset(w - p.dx, h - p.dy),
      270 => Offset(p.dy, w - p.dx),
      _ => p,
    };
    return mirrored ? Offset(displaySize.width - r.dx, r.dy) : r;
  }

  /// A point of the display frame in the delivered frame.
  Offset toFrame(Offset d) {
    final double w = frameSize.width;
    final double h = frameSize.height;
    final Offset m = mirrored ? Offset(displaySize.width - d.dx, d.dy) : d;
    return switch (rotation) {
      90 => Offset(m.dy, h - m.dx),
      180 => Offset(w - m.dx, h - m.dy),
      270 => Offset(w - m.dy, m.dx),
      _ => m,
    };
  }

  /// A rectangle of the display frame in the delivered frame.
  Rect rectToFrame(Rect r) =>
      Rect.fromPoints(toFrame(r.topLeft), toFrame(r.bottomRight));

  /// [barcode] with its corners moved from the delivered frame into the
  /// display frame. The corners keep their meaning (the symbol's top-left
  /// stays `topLeft`).
  Barcode barcodeToDisplay(Barcode barcode) =>
      mapBarcodePosition(barcode, toDisplay);

  @override
  bool operator ==(Object other) =>
      other is FrameTransform &&
      other.frameSize == frameSize &&
      other.rotation == rotation &&
      other.mirrored == mirrored;

  @override
  int get hashCode => Object.hash(frameSize, rotation, mirrored);

  @override
  String toString() =>
      'FrameTransform($frameSize, rotation: $rotation, mirrored: $mirrored)';
}

/// How the display frame is fitted into the scanner widget, exactly as a
/// centred `FittedBox` with [fit] lays it out.
@immutable
final class PreviewFit {
  /// Fits a display frame of [frameSize] into a widget of [viewSize].
  factory PreviewFit(Size frameSize, Size viewSize, BoxFit fit) {
    final FittedSizes sizes = applyBoxFit(fit, frameSize, viewSize);
    return PreviewFit._(
      frameSize,
      viewSize,
      Alignment.center.inscribe(sizes.source, Offset.zero & frameSize),
      Alignment.center.inscribe(sizes.destination, Offset.zero & viewSize),
    );
  }

  const PreviewFit._(this.frameSize, this.viewSize, this.source, this.target);

  /// Size of the display frame.
  final Size frameSize;

  /// Size of the widget.
  final Size viewSize;

  /// The part of the display frame that is shown.
  final Rect source;

  /// Where that part is drawn in the widget.
  final Rect target;

  /// A point of the display frame in the widget.
  Offset toView(Offset p) => Offset(
    target.left + (p.dx - source.left) * target.width / source.width,
    target.top + (p.dy - source.top) * target.height / source.height,
  );

  /// A point of the widget in the display frame.
  Offset toFrame(Offset v) => Offset(
    source.left + (v.dx - target.left) * source.width / target.width,
    source.top + (v.dy - target.top) * source.height / target.height,
  );

  /// The visible part of [viewRect] (widget coordinates) in the display
  /// frame, or `null` if none of it shows the frame.
  Rect? rectToFrame(Rect viewRect) {
    final Rect visible = viewRect.intersect(target);
    if (visible.width <= 0 || visible.height <= 0) {
      return null;
    }
    return Rect.fromPoints(
      toFrame(visible.topLeft),
      toFrame(visible.bottomRight),
    );
  }
}

/// The whole pixels of [frame] covered by [rect], clamped into a frame of
/// [frameSize]; `null` if nothing is left.
///
/// Rounded outwards, so the decoded area never misses an edge of the
/// window.
Rect? pixelCrop(Rect rect, Size frameSize) {
  final double left = rect.left.floorToDouble().clamp(0, frameSize.width);
  final double top = rect.top.floorToDouble().clamp(0, frameSize.height);
  final double right = rect.right.ceilToDouble().clamp(0, frameSize.width);
  final double bottom = rect.bottom.ceilToDouble().clamp(0, frameSize.height);
  if (right - left < 1 || bottom - top < 1) {
    return null;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// [barcode] with every corner moved by [map].
Barcode mapBarcodePosition(Barcode barcode, Offset Function(Offset) map) {
  final BarcodePosition p = barcode.position;
  return Barcode(
    format: barcode.format,
    text: barcode.text,
    bytes: barcode.bytes,
    position: BarcodePosition(
      topLeft: map(p.topLeft),
      topRight: map(p.topRight),
      bottomRight: map(p.bottomRight),
      bottomLeft: map(p.bottomLeft),
    ),
    contentType: barcode.contentType,
    orientation: barcode.orientation,
    isMirrored: barcode.isMirrored,
    isInverted: barcode.isInverted,
    ecLevel: barcode.ecLevel,
    version: barcode.version,
    symbologyIdentifier: barcode.symbologyIdentifier,
    sequence: barcode.sequence,
    error: barcode.error,
  );
}

/// Clockwise degrees of [orientation] from the natural portrait orientation,
/// as the camera plugin's preview turns it (`CameraPreview`: portraitUp 0,
/// landscapeRight 1, portraitDown 2, landscapeLeft 3 quarter turns).
int orientationDegrees(DeviceOrientation orientation) => switch (orientation) {
  DeviceOrientation.portraitUp => 0,
  DeviceOrientation.landscapeRight => 90,
  DeviceOrientation.portraitDown => 180,
  DeviceOrientation.landscapeLeft => 270,
};

/// The orientation of [degrees] (see [orientationDegrees]).
DeviceOrientation orientationOfDegrees(int degrees) => switch (degrees % 360) {
  90 => DeviceOrientation.landscapeRight,
  180 => DeviceOrientation.portraitDown,
  270 => DeviceOrientation.landscapeLeft,
  _ => DeviceOrientation.portraitUp,
};

/// The orientation the app's UI is drawn in, from the physical [device]
/// orientation the camera reports and the shape of the [ui].
///
/// Flutter does not expose the UI rotation itself. When the UI follows the
/// device, the two agree; when they do not, the app is locked to the other
/// shape and its UI stays in its natural orientation (portrait up; for an
/// app locked to landscape, landscape right).
DeviceOrientation uiOrientation(DeviceOrientation device, Orientation ui) {
  final bool deviceLandscape = orientationDegrees(device) % 180 != 0;
  if (deviceLandscape == (ui == Orientation.landscape)) {
    return device;
  }
  return ui == Orientation.portrait
      ? DeviceOrientation.portraitUp
      : DeviceOrientation.landscapeRight;
}

/// Clockwise rotation from an Android camera frame, which comes in the
/// sensor's orientation, to the UI: the rotation camera_android_camerax
/// applies to its preview (Android's camera orientation formula). The
/// front camera's preview is also mirrored.
int androidFrameRotation({
  required int sensorOrientation,
  required DeviceOrientation ui,
  required bool front,
}) {
  final int degrees = orientationDegrees(ui);
  return front
      ? (sensorOrientation - degrees + 360) % 360
      : (sensorOrientation + degrees) % 360;
}

/// Clockwise rotation from an iOS camera frame to the UI.
///
/// iOS turns frames to the capture orientation itself, so a frame of the
/// UI's shape needs nothing. The front camera of an iPhone 17 Pro Max turns
/// them the wrong way: asked for a rotation of a degrees it applies 90 - a,
/// so its frames come in the other shape (landscape in portrait, portrait in
/// landscape), and the rest of the turn is a quarter turn clockwise in a
/// portrait UI and three quarters in a landscape one (found on the device).
int iosFrameRotation(Size frame, DeviceOrientation ui) {
  final bool frameLandscape = frame.width > frame.height;
  final bool uiLandscape = orientationDegrees(ui) % 180 != 0;
  if (frameLandscape == uiLandscape) {
    return 0;
  }
  return uiLandscape ? 270 : 90;
}
