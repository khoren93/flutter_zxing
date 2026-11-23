// Buttons of your own under the scan window, placed with foregroundBuilder,
// while the built-in zoom and camera switch move with controlsLayout.
// Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

class OwnButtonsPage extends StatefulWidget {
  const OwnButtonsPage({super.key});

  @override
  State<OwnButtonsPage> createState() => _OwnButtonsPageState();
}

class _OwnButtonsPageState extends State<OwnButtonsPage> {
  ScannerControlsLayout _controls = ScannerControlsLayout.adaptive;

  void _help() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Hold the code flat, about a hand away')),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Buttons of your own'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<ScannerControlsLayout>(
            segments: const [
              ButtonSegment(
                value: ScannerControlsLayout.adaptive,
                label: Text('Bottom'),
              ),
              ButtonSegment(
                value: ScannerControlsLayout.sideColumn,
                label: Text('Side'),
              ),
              ButtonSegment(
                value: ScannerControlsLayout.topBar,
                label: Text('Top'),
              ),
            ],
            selected: {_controls},
            onSelectionChanged: (s) => setState(() => _controls = s.first),
          ),
        ),
      ),
    ),
    body: BarcodeScanner(
      // The built-in torch and photo buttons off: yours replace them. The
      // zoom and the camera switch stay, where controlsLayout puts them
      // (a side column needs room beside the window, as on a tablet).
      template: ScannerTemplate.minimal(
        torchButton: false,
        photoButton: false,
        controlsLayout: _controls,
      ),
      foregroundBuilder: (context, layout) {
        // Hidden while a result shows: the scanner pauses then.
        if (layout.state.status != ScannerStatus.running) {
          return const SizedBox.shrink();
        }
        final Rect window = layout.scanWindow;
        final buttons = <Widget>[
          TorchButton(layout.controller),
          PickImageButton(layout.controller),
          ScannerButton(
            icon: const ScannerIconData.fromIconData(Icons.help_outline),
            label: 'Help',
            onPressed: _help,
          ),
        ];
        // Under the window and its hint; at its left in landscape, where
        // there is no room below it.
        if (layout.size.width > layout.size.height) {
          return Positioned(
            right: layout.size.width - window.left + 24,
            top: window.top,
            bottom: layout.size.height - window.bottom,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: buttons,
            ),
          );
        }
        return Positioned(
          left: 0,
          right: 0,
          top: window.bottom + 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 24,
            children: buttons,
          ),
        );
      },
    ),
  );
}
