// The Settings tab of the diagnostics page: every setting of the engine, the
// camera and the scanner, applied at once.
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import 'diag_settings.dart';

/// The settings of one side of the run.
class DiagSettingsTab extends StatelessWidget {
  /// Creates the tab.
  const DiagSettingsTab({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.controller,
    this.side,
    this.onSide,
  });

  /// What is set now.
  final DiagSettings settings;
  final ValueChanged<DiagSettings> onChanged;

  /// For the zoom slider.
  final ScannerController controller;

  /// The side being edited in an A/B run, `null` outside one.
  final String? side;
  final ValueChanged<String>? onSide;

  @override
  Widget build(BuildContext context) {
    final DiagSettings s = settings;
    final String? editing = side;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        if (editing != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'A', label: Text('Edit A')),
                ButtonSegment<String>(value: 'B', label: Text('Edit B')),
              ],
              selected: <String>{editing},
              onSelectionChanged: (Set<String> v) => onSide?.call(v.first),
            ),
          ),
        const _Header('Search'),
        _flag('tryHarder', s.tryHarder, (bool v) => s.copyWith(tryHarder: v)),
        _flag('tryRotate', s.tryRotate, (bool v) => s.copyWith(tryRotate: v)),
        _flag('tryInvert', s.tryInvert, (bool v) => s.copyWith(tryInvert: v)),
        _flag(
          'tryDownscale',
          s.tryDownscale,
          (bool v) => s.copyWith(tryDownscale: v),
        ),
        _flag('isPure', s.isPure, (bool v) => s.copyWith(isPure: v)),
        _flag(
          'returnErrors',
          s.returnErrors,
          (bool v) => s.copyWith(returnErrors: v),
          note: 'Counts codes found but not decoded',
        ),
        _flag(
          'validateOptionalChecksum',
          s.validateChecksum,
          (bool v) => s.copyWith(validateChecksum: v),
        ),
        const _Header('Processing'),
        _choice<Binarizer>(
          'Binarizer',
          s.binarizer,
          Binarizer.values,
          (Binarizer v) => v.name,
          (Binarizer v) => s.copyWith(binarizer: v),
        ),
        _choice<int>(
          'minLineCount',
          s.minLineCount,
          const <int>[1, 2, 3, 4, 6, 8],
          (int v) => '$v',
          (int v) => s.copyWith(minLineCount: v),
        ),
        _choice<int>(
          'downscaleThreshold',
          s.downscaleThreshold,
          const <int>[0, 240, 360, 500, 720, 1000],
          (int v) => v == 0 ? 'Default' : '$v px',
          (int v) => s.copyWith(downscaleThreshold: v),
        ),
        _choice<int>(
          'downscaleFactor',
          s.downscaleFactor,
          const <int>[0, 2, 3, 4],
          (int v) => v == 0 ? 'Default' : '×$v',
          (int v) => s.copyWith(downscaleFactor: v),
        ),
        _choice<EanAddOn>(
          'EAN add-on',
          s.eanAddOn,
          EanAddOn.values,
          (EanAddOn v) => v.name,
          (EanAddOn v) => s.copyWith(eanAddOn: v),
        ),
        _choice<String>(
          'Character set',
          s.characterSet,
          <String>[
            '',
            for (final CharacterSet c in CharacterSet.values) c.name,
          ],
          (String v) => v.isEmpty ? 'Guess' : v,
          (String v) => s.copyWith(characterSet: v),
        ),
        const _Header('Formats'),
        _choice<DiagFormats>(
          'Formats',
          s.formats,
          DiagFormats.values,
          (DiagFormats v) => v.label,
          (DiagFormats v) => s.copyWith(formats: v),
        ),
        const _Header('Camera'),
        _choice<CameraResolution>(
          'Resolution',
          s.resolution,
          CameraResolution.values,
          (CameraResolution v) => v.name,
          (CameraResolution v) => s.copyWith(resolution: v),
        ),
        _flag(
          'Automatic zoom',
          s.autoZoom,
          (bool v) => s.copyWith(autoZoom: v),
        ),
        ValueListenableBuilder<ScannerState>(
          valueListenable: controller,
          builder: (BuildContext context, ScannerState state, _) => ListTile(
            dense: true,
            title: Text('Zoom ${state.zoom.toStringAsFixed(1)}×'),
            subtitle: state.maxZoom > state.minZoom
                ? Slider(
                    value: state.zoom.clamp(state.minZoom, state.maxZoom),
                    min: state.minZoom,
                    max: state.maxZoom,
                    onChanged: controller.setZoom,
                  )
                : null,
          ),
        ),
        const _Header('Scanner'),
        _choice<DiagWindow>(
          'Scan window',
          s.window,
          DiagWindow.values,
          (DiagWindow v) => v.label,
          (DiagWindow v) => s.copyWith(window: v),
        ),
        _choice<int>(
          'Codes per frame',
          s.maxBarcodes,
          const <int>[1, 2, 5, 0],
          (int v) => v == 0 ? 'All' : '$v',
          (int v) => s.copyWith(maxBarcodes: v),
        ),
        _choice<int>(
          'Read at most every',
          s.readIntervalMs,
          const <int>[0, 33, 66, 100, 200, 500],
          (int v) => v == 0 ? 'Every frame' : '$v ms',
          (int v) => s.copyWith(readIntervalMs: v),
        ),
        _choice<DetectionMode>(
          'Report',
          s.detection,
          const <DetectionMode>[
            DetectionMode.distinct,
            DetectionMode.continuous,
          ],
          (DetectionMode v) => v.name,
          (DetectionMode v) => s.copyWith(detection: v),
        ),
        _flag('Glass blur', s.blur, (bool v) => s.copyWith(blur: v)),
      ],
    );
  }

  Widget _flag(
    String title,
    bool value,
    DiagSettings Function(bool) change, {
    String? note,
  }) => SwitchListTile(
    dense: true,
    title: Text(title),
    subtitle: note == null ? null : Text(note),
    value: value,
    onChanged: (bool v) => onChanged(change(v)),
  );

  Widget _choice<T>(
    String title,
    T value,
    List<T> values,
    String Function(T) label,
    DiagSettings Function(T) change,
  ) => ListTile(
    dense: true,
    title: Text(title),
    trailing: DropdownButton<T>(
      value: value,
      underline: const SizedBox.shrink(),
      items: <DropdownMenuItem<T>>[
        for (final T v in values)
          DropdownMenuItem<T>(value: v, child: Text(label(v))),
      ],
      onChanged: (T? v) => onChanged(change(v as T)),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
