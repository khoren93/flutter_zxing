import 'dart:math' as math;

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
/// const ScanWindow.centered(alignment: Alignment(0, -0.5)) // higher up
/// const ScanWindow.full()
/// ScanWindow.fromRect(const Rect.fromLTWH(0.1, 0.2, 0.8, 0.3))
/// ```
@immutable
final class ScanWindow {
  /// The whole visible preview.
  const ScanWindow.full()
    : this._(const Rect.fromLTRB(0, 0, 1, 1), 0, 0, Alignment.center);

  /// A window in the centre: [width] as a fraction of the preview width,
  /// height from [aspectRatio] (width / height). On a preview too low for
  /// that, such as a phone in landscape, the window is shrunk to take the
  /// same fraction of the height.
  ///
  /// [alignment] moves it from the centre, e.g. `Alignment(0, -0.5)`
  /// halfway to the top, to leave room for a result sheet below.
  ///
  /// [width] and [aspectRatio] must be above 0: a window of no size would
  /// decode nothing.
  const ScanWindow.centered({
    double width = 0.7,
    double aspectRatio = 1,
    Alignment alignment = Alignment.center,
  }) : this._(null, width, aspectRatio, alignment);

  /// A window given as fractions of the preview (0–1 on both axes).
  const ScanWindow.fromRect(Rect fractions)
    : this._(fractions, 0, 0, Alignment.center);

  const ScanWindow._(
    this._rect,
    this._width,
    this._aspectRatio,
    this._alignment,
  ) : assert(
        _rect != null || (_width > 0 && _aspectRatio > 0),
        'width and aspectRatio must be above 0',
      );

  final Rect? _rect;
  final double _width;
  final double _aspectRatio;
  final Alignment _alignment;

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
    final double maxHeight = viewSize.height * math.min(_width, 1);
    if (h > maxHeight) {
      h = maxHeight;
      w = h * _aspectRatio;
    }
    return _alignment.inscribe(Size(w, h), Offset.zero & viewSize);
  }

  @override
  bool operator ==(Object other) =>
      other is ScanWindow &&
      other._rect == _rect &&
      other._width == _width &&
      other._aspectRatio == _aspectRatio &&
      other._alignment == _alignment;

  @override
  int get hashCode => Object.hash(_rect, _width, _aspectRatio, _alignment);
}
