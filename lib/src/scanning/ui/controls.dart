import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

import '../../errors.dart';
import '../l10n/scanner_localizations.dart';
import '../scanner_controller.dart';
import 'glass.dart';
import 'pressable.dart';
import 'scanner_icons.dart';
import 'scanner_theme.dart';

/// A glass button that turns the torch on and off; hidden when the camera
/// has no torch. Its icons are the theme's `icons.torchOn` and
/// `icons.torchOff`.
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
      final ScannerLocalizations texts = ScannerLocalizations.of(context);
      final ScannerIconSet icons = ScannerTheme.of(context).icons;
      final bool on = state.torch == TorchState.on;
      return ScannerButton(
        icon: on ? icons.torchOn : icons.torchOff,
        label: on ? texts.torchOff : texts.torchOn,
        selected: on,
        isToggle: true,
        onPressed: () => unawaited(controller.toggleTorch()),
      );
    },
  );
}

/// A glass button that switches between the back and the front camera;
/// hidden when there is no camera to switch to
/// ([ScannerState.canSwitchCamera]).
class SwitchCameraButton extends StatelessWidget {
  /// Creates the button.
  const SwitchCameraButton(this.controller, {super.key});

  /// The controller whose camera to switch.
  final ScannerController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ScannerState>(
    valueListenable: controller,
    builder: (BuildContext context, ScannerState state, Widget? _) {
      if (!state.canSwitchCamera) {
        return const SizedBox.shrink();
      }
      return ScannerButton(
        icon: ScannerTheme.of(context).icons.switchCamera,
        label: ScannerLocalizations.of(context).switchCamera,
        onPressed: () => unawaited(controller.switchCamera()),
      );
    },
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
    icon: ScannerTheme.of(context).icons.close,
    label: ScannerLocalizations.of(context).close,
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

  /// Called after a photo was read, with its capture or `null` when no
  /// code could be read in it. Not called when the user cancels, or when
  /// the picker cannot open.
  final ValueChanged<BarcodeCapture?>? onResult;

  @override
  Widget build(BuildContext context) => ScannerButton(
    icon: ScannerTheme.of(context).icons.photo,
    label: ScannerLocalizations.of(context).pickImage,
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

/// Whether the photo picker is open: a second tap meanwhile is ignored.
bool _picking = false;

/// Lets the user pick a photo and reads it with [controller]. Returns
/// whether a photo was picked and its capture (`null` without a code, for
/// a file that is not an image, or when the engine failed on it). Nothing
/// is picked while the picker is already open, or when it cannot open,
/// such as without access to the photos.
Future<(bool, BarcodeCapture?)> pickAndReadImage(
  ScannerController controller,
) async {
  if (_picking) {
    return (false, null);
  }
  _picking = true;
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: ImageSource.gallery);
  } on PlatformException {
    return (false, null);
  } finally {
    _picking = false;
  }
  if (file == null) {
    return (false, null);
  }
  try {
    return (true, await controller.readImage(await file.readAsBytes()));
  } on ImageDecodeException {
    return (true, null);
  } on EngineException {
    // The next read starts the engine again.
    return (true, null);
  }
}

/// Glass zoom presets; hidden when there are fewer than two. On an iPhone
/// with several cameras on the back they are its cameras: "0.5×" (the
/// ultra-wide camera, [ScannerState.minZoom]), "1×" and the telephoto camera
/// ([ScannerState.telephotoZoom], "4×" on an iPhone 17 Pro). Elsewhere "1×",
/// "2×" and "4×", as far as the camera zooms, after [ScannerState.minZoom]
/// when it is below 1 (an Android camera that zooms out).
/// A preset selected after pinching shows the actual zoom ("1.6×").
///
/// Where the camera can zoom by itself ([ScannerState.autoZoom]), an "Auto"
/// button comes first. While it is selected, the scanner picks the zoom, and
/// the preset it picked is lit faintly; a tap on a preset zooms by hand.
class ZoomButtons extends StatelessWidget {
  /// Creates the buttons.
  const ZoomButtons(
    this.controller, {
    super.key,
    this.levels,
    this.direction = Axis.horizontal,
  });

  /// The controller to zoom.
  final ScannerController controller;

  /// Zoom factors to offer instead, in ascending order; those above
  /// [ScannerState.maxZoom] are left out. [ScannerState.minZoom] is added in
  /// front when it is below 1.
  final List<double>? levels;

  /// A row, or a column (beside the window in landscape).
  final Axis direction;

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
      // The cameras themselves where automatic zoom knows them (an iPhone
      // with more than one on the back); elsewhere digital zoom levels.
      final double? telephoto = state.telephotoZoom;
      final bool cameras =
          state.autoZoom != AutoZoomState.unavailable &&
          (state.minZoom < 0.95 || telephoto != null);
      final List<double> available = <double>[
        if (state.minZoom < 0.95) state.minZoom,
        for (final double level
            in levels ??
                (cameras ? <double>[1, ?telephoto] : const <double>[1, 2, 4]))
          if (level >= 1 && level <= state.maxZoom + 0.01) level,
      ];
      if (available.length < 2) {
        return const SizedBox.shrink();
      }
      final ScannerLocalizations texts = ScannerLocalizations.of(context);
      final ScannerTheme theme = ScannerTheme.of(context);
      final Color pressedText = theme.isDark
          ? const Color(0xFF161A21)
          : const Color(0xFFFFFFFF);

      Widget button({
        required String text,
        required String label,
        required bool selected,
        required VoidCallback onPressed,
        bool toggle = false,
        bool lit = false,
      }) => Semantics(
        container: true,
        button: true,
        selected: toggle ? null : selected,
        toggled: toggle ? selected : null,
        label: label,
        child: Pressable(
          onPressed: onPressed,
          shape: theme.pillBorder,
          // A 48 × 48 target around the 44 × 36 pill.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: ExcludeSemantics(
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
                    color: selected
                        ? theme.inkColor
                        : lit
                        ? theme.inkColor.withValues(alpha: 0.22)
                        : const Color(0x00000000),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    style: theme.labelStyle.copyWith(
                      fontSize: 13,
                      height: 18 / 13,
                      color: selected ? pressedText : theme.inkColor,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final bool auto = state.autoZoom == AutoZoomState.on;
      int current = 0;
      for (int i = 0; i < available.length; i++) {
        if (state.zoom >= available[i] - 0.05) {
          current = i;
        }
      }
      final List<Widget> buttons = <Widget>[
        if (state.autoZoom != AutoZoomState.unavailable)
          button(
            text: texts.autoZoom,
            label: auto ? texts.autoZoomOff : texts.autoZoomOn,
            selected: auto,
            toggle: true,
            onPressed: () => unawaited(controller.setAutoZoom(!auto)),
          ),
        for (int i = 0; i < available.length; i++)
          button(
            text: i == current && (state.zoom - available[i]).abs() > 0.05
                ? _format(state.zoom)
                : _format(available[i]),
            label: _format(available[i]),
            selected: !auto && i == current,
            lit: auto && i == current,
            onPressed: () => unawaited(controller.setZoom(available[i])),
          ),
      ];
      return Semantics(
        container: true,
        label: texts.zoom,
        // The targets reach the glass's edge; the pills keep their inset.
        child: ScannerGlass(
          padding: direction == Axis.horizontal
              ? const EdgeInsets.symmetric(horizontal: 2)
              : const EdgeInsets.symmetric(vertical: 2),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Flex(
              direction: direction,
              mainAxisSize: MainAxisSize.min,
              children: buttons,
            ),
          ),
        ),
      );
    },
  );
}
