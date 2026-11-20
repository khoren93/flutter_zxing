import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../barcode/barcode_format.dart';
import '../scan_window.dart';
import '../scanner_controller.dart';
import 'result_sheet.dart';
import 'scan_verdict.dart';
import 'scanner_icons.dart';
import 'scanner_strings.dart';
import 'scanner_theme.dart';

/// Builds the sheet shown for a code the scanner found: see
/// [ScannerResult].
typedef ScannerResultBuilder =
    Widget Function(BuildContext context, ScannerResult result);

/// Builds the buttons of the default result sheet, such as
/// `[...result.defaultActions, ScannerAction(label: 'Open', ...)]`.
typedef ScannerActionsBuilder =
    List<ScannerAction> Function(BuildContext context, ScannerResult result);

/// A code the scanner found and shows, for a [ScannerResultBuilder] and a
/// [ScannerActionsBuilder].
@immutable
final class ScannerResult {
  /// Creates a result.
  const ScannerResult({
    required this.barcode,
    required this.capture,
    required this.scanAgain,
    this.cutOut,
    this.close,
    this.defaultActions = const <ScannerAction>[],
  });

  /// The code.
  final Barcode barcode;

  /// The capture the code came from: the other codes found with it, where
  /// it came from (camera or photo), and its picture with
  /// `capture.snapshot(barcode)`.
  final BarcodeCapture capture;

  /// The camera's cut-out of the code, for a [BarcodeThumbnail]; `null`
  /// until it is cut out, or where it cannot be. Owned by the scanner and
  /// valid while the result shows: `clone()` it to keep it.
  final ui.Image? cutOut;

  /// Hides the result and scans the next code with the camera.
  final VoidCallback scanAgain;

  /// Hides the result without scanning again: back to the codes to pick
  /// from in [ScannerMode.pick] (`BarcodeResultSheet.onClose`). `null` in
  /// the other modes, where the result hides by scanning again.
  final VoidCallback? close;

  /// The buttons of the default sheet: a copy of what matters, such as
  /// "Copy IBAN" with the IBAN alone for a payment (none for a code with a
  /// secret), then "Scan again".
  final List<ScannerAction> defaultActions;
}

/// Called with the [barcode] the user picked in [ScannerMode.pick] and the
/// [capture] it came from, which also holds the other codes found with it
/// and gives its picture with `capture.snapshot(barcode)`.
typedef ScannerPickCallback =
    void Function(Barcode barcode, BarcodeCapture capture);

/// What a [ScannerTemplate] does with the codes it finds.
enum ScannerMode {
  /// One code at a time: the brackets lock onto it, scanning pauses and a
  /// result sheet slides up (or the screen closes, with
  /// [ScannerTemplate.closeOnResult]).
  single,

  /// Every code goes into a [BarcodeListSheet], with counts; scanning goes
  /// on.
  collect,

  /// Scanning goes on: each code gets a short verdict that hides by itself
  /// ([ScannerTemplate.resumeAfter]), such as tickets at a door.
  continuous,

  /// Every code in view gets a label; a tap on one picks it, then as
  /// [single].
  pick,
}

/// A ready-made scanner screen: which buttons it has, where the scan window
/// is, what happens when a code is found, and its default [theme].
///
/// ```dart
/// BarcodeScanner(template: ScannerTemplate.minimal())
/// BarcodeScanner(
///   template: ScannerTemplate.retail(onDone: (items) => save(items)),
///   theme: ScannerTheme(accent: Color(0xFFFF6A1A)),
/// )
/// ```
///
/// The named constructors are presets for common screens; every field can
/// be changed with [copyWith]. The [mode] decides what happens with a
/// code: one result at a time with a [BarcodeResultSheet] (or
/// [resultBuilder]'s sheet), a list with counts, short verdicts while
/// scanning goes on, or a pick among the codes in view. A [check] accepts,
/// flags or refuses each code before that.
///
/// [scanWindow], [formats], [facing], [initialZoom] and the detection the
/// template needs apply to the controller `BarcodeScanner` creates. A
/// controller you pass keeps its own settings: make it with
/// `ScannerController.fromTemplate` to take the template's.
@immutable
final class ScannerTemplate {
  /// Creates a template; prefer a preset and [copyWith].
  const ScannerTemplate({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(),
    this.formats,
    this.title,
    this.hint,
    this.hintIcon,
    this.largeHint = false,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = false,
    this.zoomButtons = false,
    this.switchCameraButton = false,
    this.mode = ScannerMode.single,
    this.onDone,
    this.onPick,
    this.check,
    this.counter = false,
    this.showResult = true,
    this.resultHeader = ResultHeader.picture,
    this.resultBuilder,
    this.actionsBuilder,
    this.closeOnResult = false,
    this.resumeAfter,
    this.initialZoom,
    this.facing,
    this.haptics = true,
    this.sound = false,
  }) : _titleOf = null,
       _hintOf = null;

  const ScannerTemplate._copy({
    required this.theme,
    required this.scanWindow,
    required this.formats,
    required this.title,
    required this.hint,
    required this.hintIcon,
    required this.largeHint,
    required this.closeButton,
    required this.onClose,
    required this.onOpenSettings,
    required this.torchButton,
    required this.photoButton,
    required this.zoomButtons,
    required this.switchCameraButton,
    required this.mode,
    required this.onDone,
    required this.onPick,
    required this.check,
    required this.counter,
    required this.showResult,
    required this.resultHeader,
    required this.resultBuilder,
    required this.actionsBuilder,
    required this.closeOnResult,
    required this.resumeAfter,
    required this.initialZoom,
    required this.facing,
    required this.haptics,
    required this.sound,
    required String Function(ScannerStrings strings)? titleOf,
    required String Function(ScannerStrings strings)? hintOf,
  }) : _titleOf = titleOf,
       _hintOf = hintOf;

  /// The default screen: close and torch buttons, a hint under the window,
  /// a photo button, zoom presets and a camera switch; a result sheet with
  /// the parsed content.
  const ScannerTemplate.minimal({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(alignment: Alignment(0, -0.1)),
    this.formats,
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = true,
    this.zoomButtons = true,
    this.switchCameraButton = true,
    this.check,
    this.showResult = true,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       onDone = null,
       onPick = null,
       counter = false,
       resultHeader = ResultHeader.picture,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintCode;

  /// Paying with a QR code: a title pill, the window high up and a sheet
  /// for the payment below it.
  const ScannerTemplate.payment({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.6,
      alignment: Alignment(0, -0.5),
    ),
    this.formats = const <BarcodeFormat>{BarcodeFormat.qrCode},
    this.title,
    this.hint,
    this.hintIcon,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = false,
    this.photoButton = false,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.picture,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = _titlePayment,
       _hintOf = null;

  /// Retail and warehouse: dark glass, a wide window for product and
  /// shipping barcodes, the torch, and a list of everything scanned with
  /// counts; [onDone] receives the list. A [check] keeps codes out of it.
  const ScannerTemplate.retail({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.88,
      aspectRatio: 3,
      alignment: Alignment(0, -0.6),
    ),
    this.formats = const <BarcodeFormat>{
      ...BarcodeFormat.retail,
      ...BarcodeFormat.industrial,
    },
    this.title,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.onDone,
    this.check,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.collect,
       onPick = null,
       hint = null,
       hintIcon = null,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.picture,
       resultBuilder = null,
       actionsBuilder = null,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = null;

  /// Tickets and documents: a wide window for boarding passes, tickets and
  /// IDs (PDF417, Aztec, QR, Data Matrix), a title pill and a sheet for the
  /// fields.
  const ScannerTemplate.ticket({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.87,
      aspectRatio: 2.2,
      alignment: Alignment(0, -0.35),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.pdf417,
      BarcodeFormat.aztec,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    },
    this.title,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       hint = null,
       hintIcon = null,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.picture,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = _titleTicket,
       _hintOf = null;

  /// Everyday QR codes: links, Wi‑Fi networks, contacts, events. Dark
  /// glass and a sheet with an icon of the content's kind; add buttons such
  /// as "Open" or "Connect" with [actionsBuilder].
  const ScannerTemplate.content({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.62,
      alignment: Alignment(0, -0.62),
    ),
    this.formats = const <BarcodeFormat>{BarcodeFormat.qrCode},
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.icon,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintQrCode;

  /// Products and books: a wide window for EAN and UPC barcodes and a
  /// sheet with the GTIN, or the ISBN of a book ([ProductContent]).
  const ScannerTemplate.product({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.88,
      aspectRatio: 3,
      alignment: Alignment(0, -0.45),
    ),
    this.formats = BarcodeFormat.retail,
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.barcode,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.icon,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintBarcode;

  /// Small codes on parts, boards and labels: a small window, the camera
  /// zoomed to 2× from the start, zoom presets, and 2D formats that are
  /// printed small (Data Matrix, QR, Micro QR, rMQR).
  const ScannerTemplate.small({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.45,
      alignment: Alignment(0, -0.15),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
      BarcodeFormat.microQrCode,
      BarcodeFormat.rmqrCode,
    },
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.closer,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.zoomButtons = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.initialZoom = 2,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       photoButton = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.icon,
       closeOnResult = false,
       resumeAfter = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintCloser;

  /// Signing in or pairing a device with a QR code shown on another
  /// screen: a title pill, QR codes only, and the screen closes with the
  /// code once it is accepted. A [check] refuses codes that are not yours.
  /// Read the code from `Navigator.push`'s result or from `onDetect`.
  const ScannerTemplate.signIn({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.6,
      alignment: Alignment(0, -0.2),
    ),
    this.formats = const <BarcodeFormat>{BarcodeFormat.qrCode},
    this.title,
    this.hint,
    this.hintIcon,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = false,
    this.check,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = false,
       resultHeader = ResultHeader.picture,
       resultBuilder = null,
       actionsBuilder = null,
       closeOnResult = true,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = _titleSignIn,
       _hintOf = null;

  /// Tickets at the door: scanning never stops, [check] judges each code
  /// and the window flashes in the verdict's color with a sound and a
  /// haptic of its own; a counter at the top counts the accepted codes.
  const ScannerTemplate.checkIn({
    required ScannerCheck this.check,
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.6,
      alignment: Alignment(0, -0.35),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.qrCode,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
      BarcodeFormat.dataMatrix,
    },
    this.hint,
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.counter = true,
    this.resumeAfter = const Duration(seconds: 2),
    this.haptics = true,
    this.sound = true,
  }) : mode = ScannerMode.continuous,
       title = null,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       showResult = true,
       resultHeader = ResultHeader.picture,
       resultBuilder = null,
       actionsBuilder = null,
       closeOnResult = false,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintTicket;

  /// Medicine packs: GS1 Data Matrix, and a sheet with the GTIN, batch,
  /// serial number and expiry date, marked when it has passed.
  const ScannerTemplate.pharma({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.45,
      alignment: Alignment(0, -0.5),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
    },
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.icon,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintDataMatrix;

  /// Several codes in view, such as on a box or a poster: no window, a
  /// label on every code, and a tap on one picks it: [onPick] is told, and
  /// its result sheet opens. The camera stops on that frame, so that closing
  /// the sheet with its close button or a tap around it goes back to the same
  /// codes (on the web, to the codes then in view); "Scan again" goes to the
  /// camera. A photo with several codes opens with the same labels and stays
  /// until the user leaves it.
  const ScannerTemplate.pick({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.formats,
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.qrCode,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = true,
    this.onPick,
    this.check,
    this.showResult = true,
    this.resultBuilder,
    this.actionsBuilder,
    this.closeOnResult = false,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.pick,
       scanWindow = const ScanWindow.full(),
       largeHint = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       counter = false,
       resultHeader = ResultHeader.icon,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintPick;

  /// Logistics labels: GS1-128 and GS1 2D codes with SSCC, GTIN, batch
  /// and quantity in a list with counts; [onDone] receives the list.
  const ScannerTemplate.logistics({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.9,
      aspectRatio: 3,
      alignment: Alignment(0, -0.6),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.code128,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
      BarcodeFormat.itf,
    },
    this.title,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.onDone,
    this.check,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.collect,
       onPick = null,
       hint = null,
       hintIcon = null,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.picture,
       resultBuilder = null,
       actionsBuilder = null,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = null;

  /// A self-service kiosk: the front camera, no buttons, the [title] and
  /// [hint] large in a panel (at the side in landscape), and a verdict for
  /// each code that hides by itself. Pass a [check] to accept or refuse
  /// codes.
  const ScannerTemplate.kiosk({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(width: 0.6),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.qrCode,
      BarcodeFormat.aztec,
      BarcodeFormat.pdf417,
      BarcodeFormat.dataMatrix,
    },
    this.title,
    this.hint,
    this.check,
    this.onOpenSettings,
    this.counter = false,
    this.resumeAfter = const Duration(seconds: 3),
    this.facing = CameraFacing.front,
    this.haptics = false,
    this.sound = true,
  }) : mode = ScannerMode.continuous,
       hintIcon = null,
       largeHint = true,
       closeButton = false,
       onClose = null,
       torchButton = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       showResult = true,
       resultHeader = ResultHeader.picture,
       resultBuilder = null,
       actionsBuilder = null,
       closeOnResult = false,
       initialZoom = null,
       _titleOf = _titleTicket,
       _hintOf = _hintKiosk;

  /// The whole camera, without a window or dimming: the brackets appear
  /// on the code found. Photo, zoom and camera buttons at the bottom.
  const ScannerTemplate.fullscreen({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.formats,
    this.title,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = true,
    this.zoomButtons = true,
    this.switchCameraButton = true,
    this.check,
    this.showResult = true,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       scanWindow = const ScanWindow.full(),
       hint = null,
       hintIcon = null,
       largeHint = false,
       onDone = null,
       onPick = null,
       counter = false,
       resultHeader = ResultHeader.icon,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = null;

  /// Vehicle identification numbers on the windshield or the door pillar:
  /// a long, low window, Code 39 and 2D codes, and a sheet with the VIN
  /// ([VinContent]).
  const ScannerTemplate.vin({
    this.theme = const ScannerTheme(brightness: Brightness.dark),
    this.scanWindow = const ScanWindow.centered(
      width: 0.9,
      aspectRatio: 4,
      alignment: Alignment(0, -0.35),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.code39,
      BarcodeFormat.code128,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
    },
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.vehicle,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       photoButton = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.icon,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintVin;

  /// Loyalty and membership cards: the barcodes they carry (Code 128,
  /// PDF417, QR, EAN-13, Aztec, Code 39) and a sheet with the card number
  /// large. Add a button such as "Add card" with [actionsBuilder].
  const ScannerTemplate.loyalty({
    this.theme = const ScannerTheme(),
    this.scanWindow = const ScanWindow.centered(
      width: 0.85,
      aspectRatio: 2.2,
      alignment: Alignment(0, -0.45),
    ),
    this.formats = const <BarcodeFormat>{
      BarcodeFormat.code128,
      BarcodeFormat.pdf417,
      BarcodeFormat.qrCode,
      BarcodeFormat.ean13,
      BarcodeFormat.aztec,
      BarcodeFormat.code39,
    },
    this.title,
    this.hint,
    this.hintIcon = ScannerIcons.card,
    this.closeButton = true,
    this.onClose,
    this.onOpenSettings,
    this.torchButton = true,
    this.photoButton = true,
    this.check,
    this.resultBuilder,
    this.actionsBuilder,
    this.haptics = true,
    this.sound = false,
  }) : mode = ScannerMode.single,
       largeHint = false,
       zoomButtons = false,
       switchCameraButton = false,
       onDone = null,
       onPick = null,
       counter = false,
       showResult = true,
       resultHeader = ResultHeader.card,
       closeOnResult = false,
       resumeAfter = null,
       initialZoom = null,
       facing = null,
       _titleOf = null,
       _hintOf = _hintCard;

  /// The template's theme; `BarcodeScanner.theme` is merged on top.
  final ScannerTheme theme;

  /// The scan window of the scanner's own controller. With
  /// [ScanWindow.full] there is no window: no dimming, and the brackets
  /// show only on a code.
  final ScanWindow scanWindow;

  /// Formats of the scanner's own controller; `null` reads all.
  final Set<BarcodeFormat>? formats;

  /// A title pill at the top, e.g. "Pay with QR"; an empty string for
  /// none. `null` is the preset's title from [ScannerStrings], such as
  /// [ScannerStrings.titlePayment], or none. See [resolveTitle].
  final String? title;

  /// A hint under the window while searching; an empty string for none.
  /// `null` is the preset's hint from [ScannerStrings], such as
  /// [ScannerStrings.hintCode], or none. See [resolveHint].
  final String? hint;

  /// The preset's title and hint, from the strings of the scanner.
  final String Function(ScannerStrings strings)? _titleOf;
  final String Function(ScannerStrings strings)? _hintOf;

  /// The title shown with [strings]: [title], or the preset's; `null` for
  /// none.
  String? resolveTitle(ScannerStrings strings) =>
      _shown(title ?? _titleOf?.call(strings));

  /// The hint shown with [strings]: [hint], or the preset's; `null` for
  /// none.
  String? resolveHint(ScannerStrings strings) =>
      _shown(hint ?? _hintOf?.call(strings));

  static String? _shown(String? text) =>
      text == null || text.isEmpty ? null : text;

  static String _hintCode(ScannerStrings s) => s.hintCode;
  static String _hintQrCode(ScannerStrings s) => s.hintQrCode;
  static String _hintBarcode(ScannerStrings s) => s.hintBarcode;
  static String _hintCloser(ScannerStrings s) => s.hintCloser;
  static String _hintTicket(ScannerStrings s) => s.hintTicket;
  static String _hintDataMatrix(ScannerStrings s) => s.hintDataMatrix;
  static String _hintPick(ScannerStrings s) => s.hintPick;
  static String _hintKiosk(ScannerStrings s) => s.hintKiosk;
  static String _hintVin(ScannerStrings s) => s.hintVin;
  static String _hintCard(ScannerStrings s) => s.hintCard;
  static String _titlePayment(ScannerStrings s) => s.titlePayment;
  static String _titleTicket(ScannerStrings s) => s.titleTicket;
  static String _titleSignIn(ScannerStrings s) => s.titleSignIn;

  /// An icon before [hint].
  final ScannerIconData? hintIcon;

  /// Shows [title] and [hint] large in a panel at the bottom (at the side
  /// in landscape) instead of the pills, for a screen read from a step
  /// away, such as a kiosk.
  final bool largeHint;

  /// A close button at the top left, shown when [onClose] is set or the
  /// scanner's route can be popped.
  final bool closeButton;

  /// Called by the close button; default `Navigator.maybePop`.
  final VoidCallback? onClose;

  /// Opens the app's settings, where the user allows the camera: the
  /// error card then offers "Open Settings" when camera access is off.
  /// Opening the settings needs a plugin such as `app_settings`;
  /// `BarcodeScanner.onOpenSettings` takes precedence.
  final VoidCallback? onOpenSettings;

  /// A torch button at the top right, when the camera has a torch.
  final bool torchButton;

  /// A button that reads a code from a photo, at the bottom left.
  final bool photoButton;

  /// Zoom presets at the bottom.
  final bool zoomButtons;

  /// A camera switch at the bottom right.
  final bool switchCameraButton;

  /// What happens with the codes found.
  final ScannerMode mode;

  /// With [ScannerMode.collect]: called by the list's "Done" button with
  /// the collected codes.
  final ValueChanged<List<CollectedBarcode>>? onDone;

  /// With [ScannerMode.pick]: called each time the user picks a code that
  /// [check] did not refuse. `BarcodeScanner.onDetect` reports every code
  /// found instead, picked or not.
  final ScannerPickCallback? onPick;

  /// Accepts, flags or refuses each code before anything else happens.
  /// With [ScannerMode.single] and [ScannerMode.pick], a refused code
  /// flashes the window in [ScannerTheme.dangerColor] with the verdict's
  /// text, and scanning goes on; a flagged one is taken like an accepted
  /// one, after a flash in [ScannerTheme.warningColor] with the verdict's
  /// text; with [ScannerMode.collect], a refused code
  /// stays out of the list and a flagged one goes in, each with the
  /// verdict's text; with [ScannerMode.continuous], every verdict shows for
  /// [resumeAfter]. `null` accepts every code.
  final ScannerCheck? check;

  /// With [ScannerMode.continuous]: a counter of the accepted codes at the
  /// top ([ScannerStrings.checkedIn]).
  final bool counter;

  /// With one result at a time: pause and show a result sheet. Without it,
  /// the brackets lock onto the code and the app handles `onDetect`.
  final bool showResult;

  /// What the default result sheet shows next to its title
  /// ([BarcodeResultSheet.header]): the picture of the code, an icon of its
  /// kind, the text as a card number, or nothing.
  final ResultHeader resultHeader;

  /// Builds the result sheet; default [BarcodeResultSheet]. A tap on the
  /// camera around it scans again.
  final ScannerResultBuilder? resultBuilder;

  /// The buttons of the default result sheet; default
  /// [ScannerResult.defaultActions]. Buttons that do not scan again get a
  /// close in the sheet's corner; a tap on the camera around the sheet
  /// scans again too.
  final ScannerActionsBuilder? actionsBuilder;

  /// Once a code is accepted, the brackets lock onto it and the scanner's
  /// route is popped with the [Barcode] as its result, instead of showing
  /// a result sheet.
  final bool closeOnResult;

  /// How long a result shows before scanning goes on by itself: the
  /// verdict of [ScannerMode.continuous] (default 2 seconds), or the
  /// result sheet of [ScannerMode.single]. `null` waits for the user in
  /// [ScannerMode.single].
  final Duration? resumeAfter;

  /// The zoom the camera starts with, such as 2 for small codes; `null`
  /// keeps 1×.
  final double? initialZoom;

  /// The camera of the scanner's own controller; `null` is the back
  /// camera.
  final CameraFacing? facing;

  /// A haptic when a code is found; with a [check], a stronger one for a
  /// code that needs a look and a vibration for a refused one.
  final bool haptics;

  /// The system click sound when a code is found, the alert sound when one
  /// is refused or flagged (Android and iOS; the system's sound settings
  /// apply). For a sound of your own, play it in `BarcodeScanner.onDetect`.
  final bool sound;

  /// How the scanner's own controller reports codes for this template.
  DetectionMode get detection => switch (mode) {
    // A refused code stays in view: reported once, not on every frame.
    ScannerMode.single when check != null => DetectionMode.distinct,
    ScannerMode.single => DetectionMode.once,
    _ => DetectionMode.distinct,
  };

  /// How many codes the scanner's own controller looks for in a frame.
  int? get maxBarcodes => switch (mode) {
    ScannerMode.collect || ScannerMode.pick => null,
    _ => 1,
  };

  /// A copy with the given fields replaced.
  ///
  /// Fields that may be `null` take a function, so that they can be
  /// cleared as well as set:
  ///
  /// ```dart
  /// template.copyWith(hint: () => 'Scan the label', check: () => null)
  /// ```
  ScannerTemplate copyWith({
    ScannerTheme? theme,
    ScanWindow? scanWindow,
    ValueGetter<Set<BarcodeFormat>?>? formats,
    ValueGetter<String?>? title,
    ValueGetter<String?>? hint,
    ValueGetter<ScannerIconData?>? hintIcon,
    bool? largeHint,
    bool? closeButton,
    ValueGetter<VoidCallback?>? onClose,
    ValueGetter<VoidCallback?>? onOpenSettings,
    bool? torchButton,
    bool? photoButton,
    bool? zoomButtons,
    bool? switchCameraButton,
    ScannerMode? mode,
    ValueGetter<ValueChanged<List<CollectedBarcode>>?>? onDone,
    ValueGetter<ScannerPickCallback?>? onPick,
    ValueGetter<ScannerCheck?>? check,
    bool? counter,
    bool? showResult,
    ResultHeader? resultHeader,
    ValueGetter<ScannerResultBuilder?>? resultBuilder,
    ValueGetter<ScannerActionsBuilder?>? actionsBuilder,
    bool? closeOnResult,
    ValueGetter<Duration?>? resumeAfter,
    ValueGetter<double?>? initialZoom,
    ValueGetter<CameraFacing?>? facing,
    bool? haptics,
    bool? sound,
  }) => ScannerTemplate._copy(
    theme: theme ?? this.theme,
    scanWindow: scanWindow ?? this.scanWindow,
    formats: formats == null ? this.formats : formats(),
    title: title == null ? this.title : title(),
    hint: hint == null ? this.hint : hint(),
    hintIcon: hintIcon == null ? this.hintIcon : hintIcon(),
    largeHint: largeHint ?? this.largeHint,
    closeButton: closeButton ?? this.closeButton,
    onClose: onClose == null ? this.onClose : onClose(),
    onOpenSettings: onOpenSettings == null
        ? this.onOpenSettings
        : onOpenSettings(),
    torchButton: torchButton ?? this.torchButton,
    photoButton: photoButton ?? this.photoButton,
    zoomButtons: zoomButtons ?? this.zoomButtons,
    switchCameraButton: switchCameraButton ?? this.switchCameraButton,
    mode: mode ?? this.mode,
    onDone: onDone == null ? this.onDone : onDone(),
    onPick: onPick == null ? this.onPick : onPick(),
    check: check == null ? this.check : check(),
    counter: counter ?? this.counter,
    showResult: showResult ?? this.showResult,
    resultHeader: resultHeader ?? this.resultHeader,
    resultBuilder: resultBuilder == null ? this.resultBuilder : resultBuilder(),
    actionsBuilder: actionsBuilder == null
        ? this.actionsBuilder
        : actionsBuilder(),
    closeOnResult: closeOnResult ?? this.closeOnResult,
    resumeAfter: resumeAfter == null ? this.resumeAfter : resumeAfter(),
    initialZoom: initialZoom == null ? this.initialZoom : initialZoom(),
    facing: facing == null ? this.facing : facing(),
    haptics: haptics ?? this.haptics,
    sound: sound ?? this.sound,
    titleOf: _titleOf,
    hintOf: _hintOf,
  );
}
