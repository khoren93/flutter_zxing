import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../errors.dart';
import '../scanner_controller.dart';
import 'glass.dart';
import 'scanner_icons.dart';
import 'scanner_strings.dart';
import 'scanner_theme.dart';

/// A glass button that turns the torch on and off; hidden when the camera
/// has no torch.
class TorchButton extends StatelessWidget {
  /// Creates the button.
  const TorchButton(this.controller, {super.key});

  /// The controller whose torch to toggle.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ScannerState>(
    valueListenable: controller,
    builder: (BuildContext context, ScannerState state, Widget? _) {
      if (state.torch == TorchState.unavailable) {
        return const SizedBox.shrink();
      }
      final ScannerStrings strings = ScannerStrings.of(context);
      final bool on = state.torch == TorchState.on;
      return ScannerButton(
        icon: on ? ScannerIcons.torchOn : ScannerIcons.torchOff,
        label: on ? strings.torchOff : strings.torchOn,
        selected: on,
        isToggle: true,
        onPressed: () => unawaited(controller.toggleTorch()),
      );
    },
  );
}

/// A glass button that switches between the back and the front camera.
class SwitchCameraButton extends StatelessWidget {
  /// Creates the button.
  const SwitchCameraButton(this.controller, {super.key});

  /// The controller whose camera to switch.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => ScannerButton(
    icon: ScannerIcons.switchCamera,
    label: ScannerStrings.of(context).switchCamera,
    onPressed: () => unawaited(controller.switchCamera()),
  );
}

/// A glass button that closes the scanner: by default it pops the current
/// route.
class ScannerCloseButton extends StatelessWidget {
  /// Creates the button.
  const ScannerCloseButton({super.key, this.onPressed});

  /// Called on tap; default `Navigator.maybePop`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ScannerButton(
    icon: ScannerIcons.close,
    label: ScannerStrings.of(context).close,
    onPressed: onPressed ?? () => unawaited(Navigator.maybePop(context)),
  );
}

/// A glass button that lets the user pick a photo and reads the codes in
/// it with [ScannerController.readImage]: they are reported like the
/// camera's.
///
/// Uses `image_picker`; on iOS and Android the system photo picker needs
/// no permission.
class PickImageButton extends StatelessWidget {
  /// Creates the button.
  const PickImageButton(this.controller, {super.key, this.onResult});

  /// The controller that reads the photo.
  final ScannerController controller;

  /// Called after a photo was read, with its capture or `null` when it has
  /// no code. Not called when the user cancels.
  final ValueChanged<BarcodeCapture?>? onResult;

  @override
  Widget build(BuildContext context) => ScannerButton(
    icon: ScannerIcons.photo,
    label: ScannerStrings.of(context).pickImage,
    onPressed: () => unawaited(_pick()),
  );

  Future<void> _pick() async {
    final (bool picked, BarcodeCapture? capture) = await pickAndReadImage(
      controller,
    );
    if (picked) {
      onResult?.call(capture);
    }
  }
}

/// Lets the user pick a photo and reads it with [controller]. Returns
/// whether a photo was picked and its capture (`null` without a code, or
/// for a file that is not an image).
Future<(bool, BarcodeCapture?)> pickAndReadImage(
  ScannerController controller,
) async {
  final XFile? file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
  );
  if (file == null) {
    return (false, null);
  }
  try {
    return (true, await controller.readImage(await file.readAsBytes()));
  } on ImageDecodeException {
    return (true, null);
  }
}

/// Glass zoom presets ("1×", "2×", "4×") for the levels the camera
/// supports; hidden when it supports fewer than two. A level selected
/// after pinching shows the actual zoom ("1.6×").
class ZoomButtons extends StatelessWidget {
  /// Creates the buttons.
  const ZoomButtons(
    this.controller, {
    super.key,
    this.levels = const <double>[1, 2, 4],
  });

  /// The controller to zoom.
  final ScannerController controller;

  /// Zoom factors to offer, in ascending order; those above
  /// [ScannerState.maxZoom] are left out.
  final List<double> levels;

  static String _format(double zoom) {
    final double rounded = (zoom * 10).roundToDouble() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}×'
        : '${rounded.toStringAsFixed(1)}×';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ScannerState>(
    valueListenable: controller,
    builder: (BuildContext context, ScannerState state, Widget? _) {
      final List<double> available = <double>[
        for (final double level in levels)
          if (level >= 1 && level <= state.maxZoom + 0.01) level,
      ];
      if (available.length < 2) {
        return const SizedBox.shrink();
      }
      int selected = 0;
      for (int i = 0; i < available.length; i++) {
        if (state.zoom >= available[i] - 0.05) {
          selected = i;
        }
      }
      final ScannerTheme theme = ScannerTheme.of(context);
      final Color pressedText = theme.isDark
          ? const Color(0xFF161A21)
          : const Color(0xFFFFFFFF);
      return Semantics(
        container: true,
        label: ScannerStrings.of(context).zoom,
        child: ScannerGlass(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < available.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 4),
                Semantics(
                  button: true,
                  selected: i == selected,
                  excludeSemantics: true,
                  label: _format(available[i]),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(controller.setZoom(available[i])),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 36,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: ShapeDecoration(
                        shape: theme.pillBorder,
                        color: i == selected
                            ? theme.inkColor
                            : const Color(0x00000000),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        i == selected &&
                                (state.zoom - available[i]).abs() > 0.05
                            ? _format(state.zoom)
                            : _format(available[i]),
                        style: theme.labelStyle.copyWith(
                          fontSize: 13,
                          height: 18 / 13,
                          color: i == selected ? pressedText : theme.inkColor,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
