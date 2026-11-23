// The automatic zoom (ScannerController.setAutoZoom, iPhones): the scanner
// moves between the physical cameras by where the open camera's lens is
// focused, so that it does not stay on blurry frames. To the ultra-wide
// (macro) camera when the main camera cannot focus any closer, back when the
// code moves away, to the telephoto camera when the code is far, back when it
// comes closer than the telephoto camera can focus.
//
// All its numbers are in AutoLensTuning. The lens position is
// AVCaptureDevice.lensPosition: 0.0 is the nearest the lens can focus, 1.0
// far. It is not a distance, and the same distance reads differently on
// different cameras (and iPhones).
import 'package:flutter/foundation.dart';

import 'camera/camera_source.dart';

/// One step of the automatic zoom: a camera at a zoom of its own, and when
/// to leave it.
@immutable
final class AutoLensStep {
  /// Creates a step.
  const AutoLensStep(this.lens, {this.zoom = 1, this.down, this.up});

  /// The camera.
  final CameraLens lens;

  /// The camera's own zoom: 1, or more for a digital zoom of it (the main
  /// camera at 2 is 2×).
  final double zoom;

  /// Go to the previous (wider) step once the lens position is at or below
  /// this (the code came closer); `null`: never.
  final double? down;

  /// Go to the next (longer) step once the lens position is above this (the
  /// code moved away); `null`: never.
  final double? up;
}

/// The numbers of the automatic zoom, in one place.
abstract final class AutoLensTuning {
  /// The steps, from the widest. Those on a camera the phone does not have
  /// are skipped.
  static const List<AutoLensStep> steps = <AutoLensStep>[
    // The ultra-wide camera zoomed to 0.9× (its own 1.8): at its own 0.5× a
    // close code is half as big in the frame. On an iPhone 17 Pro Max at
    // 10 cm this reads 30 of 34 codes at hd instead of 15 (R3-08). Not 1×:
    // that zoom belongs to the main camera, and a step at the same zoom
    // gives way to the longer camera. Back to the main camera once it
    // focuses farther than the main camera can (it reads about 0.75 where the
    // main camera reaches 0).
    AutoLensStep(CameraLens.ultraWide, zoom: 1.8, up: 0.77),
    // The main camera (1×): at its nearest focus → the ultra-wide camera;
    // farther → its own 2×.
    AutoLensStep(CameraLens.main, down: 0.02, up: 0.5),
    // The main camera zoomed to 2× (the same lens, so the same lens
    // position): far → the telephoto camera; closer again → 1×.
    AutoLensStep(CameraLens.main, zoom: 2, down: 0.3, up: 0.7),
    // The telephoto camera (3×–5×, 4× on an iPhone 17 Pro): at its nearest
    // focus → the main camera at 2×.
    AutoLensStep(CameraLens.telephoto, down: 0.02),
  ];

  /// No camera change while codes are being read: none for this long first.
  static const Duration idle = Duration(milliseconds: 400);

  /// How long the lens position must stay past a threshold before moving to
  /// a wider camera (the code came closer: the frames are blurry now).
  static const Duration holdNear = Duration(milliseconds: 400);

  /// The same before moving to a longer camera (the code moved away: the
  /// frames are still sharp, so there is no hurry).
  static const Duration holdFar = Duration(milliseconds: 1000);

  /// After a change, the new camera is left alone this long: it focuses
  /// first.
  static const Duration settle = Duration(milliseconds: 1500);
}

/// The zoom of each camera the phone has, in the main camera's terms.
typedef AutoLensZooms = Map<CameraLens, double>;

/// The zooms of the cameras: the main one at 1, the [ultraWide] and
/// [telephoto] ones where there are.
AutoLensZooms autoLensZooms({double? ultraWide, double? telephoto}) =>
    <CameraLens, double>{
      CameraLens.ultraWide: ?ultraWide,
      CameraLens.main: 1,
      CameraLens.telephoto: ?telephoto,
    };

/// The zooms of the [steps] on the cameras in [zooms] (in the main
/// camera's terms), with their steps, from the widest. A step that does not
/// zoom in further than the one before is skipped (the main camera's 2× on
/// a phone whose telephoto camera is 2×).
List<(double, AutoLensStep)> _usable(
  AutoLensZooms zooms,
  List<AutoLensStep> steps,
) {
  final List<(double, AutoLensStep)> usable = <(double, AutoLensStep)>[];
  for (final AutoLensStep s in steps) {
    final double? z = zooms[s.lens];
    if (z == null) {
      continue;
    }
    if (usable.isNotEmpty && z * s.zoom <= usable.last.$1 + 1e-3) {
      // A longer camera at the same zoom wins: it is sharper.
      if (s.zoom == 1) {
        usable.removeLast();
      } else {
        continue;
      }
    }
    usable.add((z * s.zoom, s));
  }
  return usable;
}

/// Whether [zoom] is the zoom of one of the steps on the cameras in
/// [zooms].
bool isAutoLensZoom(
  double zoom,
  AutoLensZooms zooms, {
  List<AutoLensStep> steps = AutoLensTuning.steps,
}) => _usable(
  zooms,
  steps,
).any(((double, AutoLensStep) s) => (s.$1 - zoom).abs() < 1e-3);

/// The zoom to go to from [zoom] with the lens at [lensPosition], or `null`
/// to stay: also when [zoom] is not the zoom of a step (zoomed by hand).
/// Only steps on the cameras in [zooms] are used.
double? autoLensTarget(
  double zoom,
  double lensPosition,
  AutoLensZooms zooms, {
  List<AutoLensStep> steps = AutoLensTuning.steps,
}) {
  final List<(double, AutoLensStep)> usable = _usable(zooms, steps);
  final int i = usable.indexWhere(
    ((double, AutoLensStep) s) => (s.$1 - zoom).abs() < 1e-3,
  );
  if (i < 0) {
    return null;
  }
  final AutoLensStep step = usable[i].$2;
  final double? down = step.down;
  final double? up = step.up;
  if (down != null && i > 0 && lensPosition <= down) {
    return usable[i - 1].$1;
  }
  if (up != null && i < usable.length - 1 && lensPosition > up) {
    return usable[i + 1].$1;
  }
  return null;
}
