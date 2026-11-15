import 'package:flutter/widgets.dart';

import 'scanner_theme.dart';

/// A tap target of the scanner widgets that shrinks while pressed and shows a focus ring for the
/// keyboard; reacts to Enter and Space.
class Pressable extends StatefulWidget {
  /// Creates the target.
  const Pressable({
    super.key,
    required this.onPressed,
    required this.shape,
    required this.child,
  });

  /// Called on tap, Enter or Space; `null` disables the target.
  final VoidCallback? onPressed;

  /// The outline of the focus ring.
  final ShapeBorder shape;

  /// The content.
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  void _press(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = widget.onPressed;
    final ScannerTheme theme = ScannerTheme.of(context);
    final ShapeBorder? ring = _focused
        ? switch (widget.shape) {
            final OutlinedBorder outlined => outlined.copyWith(
              side: BorderSide(
                color: theme.focusColor,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            _ => null,
          }
        : null;
    return FocusableActionDetector(
      enabled: onPressed != null,
      mouseCursor: onPressed != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowFocusHighlight: (bool value) => setState(() => _focused = value),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent _) {
            onPressed?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onPressed == null
            ? null
            : (TapDownDetails _) => _press(true),
        onTapUp: onPressed == null ? null : (TapUpDetails _) => _press(false),
        onTapCancel: onPressed == null ? null : () => _press(false),
        onTap: onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: ring == null
              ? widget.child
              : DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: ShapeDecoration(shape: ring),
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}
