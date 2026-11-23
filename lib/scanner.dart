/// The camera scanner: [BarcodeScanner] with templates and themes, its
/// [ScannerController], and the glass widgets to build your own scanner UI.
///
/// A layer on top of `core.dart`, `content.dart` and `rendering.dart`,
/// which it exports too.
library;

export 'content.dart';
export 'rendering.dart';
export 'src/scanning/l10n/scanner_localizations.dart'
    hide lookupScannerLocalizations;
export 'src/scanning/l10n/scanner_localizations_de.dart';
export 'src/scanning/l10n/scanner_localizations_en.dart';
export 'src/scanning/l10n/scanner_localizations_es.dart';
export 'src/scanning/l10n/scanner_localizations_fr.dart';
export 'src/scanning/l10n/scanner_localizations_lookup.dart'
    show ScannerLocalizationsContent;
export 'src/scanning/l10n/scanner_localizations_ru.dart';
export 'src/scanning/l10n/scanner_localizations_zh.dart';
export 'src/scanning/scan_window.dart';
export 'src/scanning/scanner_controller.dart'
    hide
        BarcodeCapturePhoto,
        ScannerControllerDebug,
        ScannerControllerGlimpse,
        ScannerFrameSample;
export 'src/scanning/style_content.dart';
export 'src/scanning/ui/controls.dart' hide pickAndReadImage;
export 'src/scanning/ui/glass.dart';
export 'src/scanning/ui/result_sheet.dart' hide defaultResultActions;
export 'src/scanning/ui/scan_field_button.dart';
export 'src/scanning/ui/scan_verdict.dart';
export 'src/scanning/ui/scanner_icons.dart' hide svgPath;
export 'src/scanning/ui/scanner_template.dart';
export 'src/scanning/ui/scanner_theme.dart' hide resolvedScannerScope;
export 'src/scanning/ui/states.dart';
export 'src/scanning/ui/thumbnail.dart'
    hide BarcodeThumbnailKind, barcodeThumbnailKindOf, exactBarcodePicture;
export 'src/scanning/ui/window_overlay.dart'
    hide BracketsPainter, OutlinePainter, ScanLinePainter, WindowScrim;
