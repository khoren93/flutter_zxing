import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The part of the camera preview that is decoded, relative to what the
/// user sees on screen. The default overlay draws exactly this area.
///
/// A smaller window decodes faster and avoids reading neighbouring codes.
///
/// ```dart
/// const ScanWindow.centered()                          // 70% wide square
/// const ScanWindow.centered(width: 0.9, aspectRatio: 3) // wide, for 1D codes
/// const ScanWindow.full()
/// ScanWindow.fromRect(const Rect.fromLTWH(0.1, 0.2, 0.8, 0.3))
/// ```
@immutable
final class ScanWindow {
  /// The whole visible preview.
  const ScanWindow.full() : this._(null, 1, 1);

  /// A window in the centre: [width] as a fraction of the preview width,
  /// height from [aspectRatio] (width / height), shrunk to fit if needed.
  const ScanWindow.centered({double width = 0.7, double aspectRatio = 1})
    : this._(null, width, aspectRatio);

  /// A window given as fractions of the preview (0–1 on both axes).
  const ScanWindow.fromRect(Rect fractions) : this._(fractions, 0, 0);

  const ScanWindow._(this._rect, this._width, this._aspectRatio);

  final Rect? _rect;
  final double _width;
  final double _aspectRatio;

  /// The window in the coordinates of a preview of [viewSize].
  Rect resolve(Size viewSize) {
    final Rect? rect = _rect;
    if (rect != null) {
      return Rect.fromLTRB(
        rect.left * viewSize.width,
        rect.top * viewSize.height,
        rect.right * viewSize.width,
        rect.bottom * viewSize.height,
      );
    }
    double w = viewSize.width * _width;
    double h = w / _aspectRatio;
    if (h > viewSize.height) {
      h = viewSize.height;
      w = h * _aspectRatio;
    }
    return Rect.fromCenter(
      center: viewSize.center(Offset.zero),
      width: w,
      height: h,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ScanWindow &&
      other._rect == _rect &&
      other._width == _width &&
      other._aspectRatio == _aspectRatio;

  @override
  int get hashCode => Object.hash(_rect, _width, _aspectRatio);
}
