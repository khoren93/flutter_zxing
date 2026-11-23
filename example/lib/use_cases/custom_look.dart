// Your brand's look: the scanner in your colors, shapes and icons, with a
// scan window sized and placed for your codes, your own texts and a widget
// of your own over the camera. Three looks to switch between: a bank, a
// grocery till and a club door. Android, iOS, macOS, the web.
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

/// A text of the scanner in your words: subclass the built-in translation
/// of your app's language and override what you need.
class _TillTexts extends ScannerLocalizationsEn {
  @override
  String get scanAgain => 'Next item';
}

/// One look: a template with its window, a theme and texts.
typedef _Look = ({
  String name,
  ScannerTemplate template,
  ScannerTheme theme,
  ScannerLocalizations? texts,
});

final List<_Look> _looks = [
  (
    name: 'Bank',
    // A card-shaped window for payment QR codes, buttons and panels in the
    // bank's pale blue, a plain white sheet, square corners, bolder texts
    // and the app's Material icons on the buttons.
    template: const ScannerTemplate.minimal(
      title: 'Pay by QR code',
      hint: 'Fit the payment code in the frame',
      scanWindow: ScanWindow.centered(width: 0.85, aspectRatio: 1.6),
      formats: {BarcodeFormat.qrCode},
      zoomButtons: false,
    ),
    theme: const ScannerTheme(
      accent: Color(0xFF1D4ED8),
      brightness: Brightness.light,
      buttonShape: ScannerButtonShape.roundedSquare,
      windowRadius: 6,
      glass: Color(0xFFEAF0FF), // opaque: no blur behind it
      sheet: Color(0xFFFFFFFF),
      sheetRadius: 16,
      textStyles: ScannerTextStyles(
        title: TextStyle(fontWeight: FontWeight.w700),
        hint: TextStyle(fontWeight: FontWeight.w600),
      ),
      icons: ScannerIconSet(
        close: ScannerIconData.fromIconData(Icons.arrow_back),
        torchOn: ScannerIconData.fromIconData(Icons.flashlight_on_outlined),
        torchOff: ScannerIconData.fromIconData(Icons.flashlight_off_outlined),
        photo: ScannerIconData.fromIconData(Icons.photo_library_outlined),
        switchCamera: ScannerIconData.fromIconData(Icons.cameraswitch_outlined),
      ),
    ),
    texts: null, // the app's language
  ),
  (
    name: 'Grocery',
    // A wide, low window for product barcodes with a till's red laser and
    // still brackets without dimming, the torch for dark shelves, and "Next
    // item" instead of "Scan again".
    template: ScannerTemplate.minimal(
      hint: 'Barcode on the product',
      scanWindow: const ScanWindow.centered(
        width: 0.9,
        aspectRatio: 3,
        alignment: Alignment(0, 0.2),
      ),
      formats: BarcodeFormat.retail,
      photoButton: false,
    ),
    theme: const ScannerTheme(
      accent: Color(0xFFFF6A1A),
      brightness: Brightness.dark,
      windowRadius: 4,
      windowShape: ScannerWindowShape.bracketsOnly,
      breathing: false,
      scanLine: ScanLine(color: Color(0xFFFF1A1A)), // costs some energy
    ),
    texts: _TillTexts(),
  ),
  (
    name: 'Club',
    // A small round window high up, pink on dark glass with pink arcs over
    // a deep violet scrim, and its own colors for a ticket that was used or
    // is not valid.
    template: const ScannerTemplate.minimal(
      title: 'Door',
      hint: 'Ticket QR code',
      scanWindow: ScanWindow.centered(
        width: 0.55,
        alignment: Alignment(0, -0.35),
      ),
      formats: {BarcodeFormat.qrCode},
    ),
    theme: const ScannerTheme(
      accent: Color(0xFFFF3FA4),
      brightness: Brightness.dark,
      windowShape: ScannerWindowShape.circle,
      window: Color(0xFFFF8CC6),
      scrim: Color(0xC21A0B2E),
      bracketWidth: 4,
      bracketLength: 28,
      warning: Color(0xFFFFD60A),
      danger: Color(0xFFFF453A),
      // fontFamily: 'YourBrandFont', // a font your app bundles
    ),
    texts: null,
  ),
];

class CustomLookPage extends StatefulWidget {
  const CustomLookPage({super.key});

  @override
  State<CustomLookPage> createState() => _CustomLookPageState();
}

class _CustomLookPageState extends State<CustomLookPage> {
  _Look _look = _looks.first;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your brand’s look'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SegmentedButton<_Look>(
            segments: [
              for (final look in _looks)
                ButtonSegment(value: look, label: Text(look.name)),
            ],
            selected: {_look},
            onSelectionChanged: (s) => setState(() => _look = s.first),
          ),
        ),
      ),
    ),
    body: BarcodeScanner(
      template: _look.template,
      theme: _look.theme,
      texts: _look.texts,
      // Your own widget over the camera, in the look's glass.
      // Under the template's top bar, clear of the result sheet below.
      foregroundBuilder: (context, layout) => Positioned(
        left: 0,
        right: 0,
        top: MediaQuery.paddingOf(context).top + 72,
        child: Center(
          child: ScannerGlass(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              '${_look.name} · a widget of yours',
              style: ScannerTheme.of(context).labelStyle,
            ),
          ),
        ),
      ),
    ),
  );
}
