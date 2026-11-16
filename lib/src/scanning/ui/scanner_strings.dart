import 'package:flutter/widgets.dart';

import '../../content/barcode_content.dart';
import 'scanner_theme.dart';

/// The texts of the scanner widgets: button labels for screen readers,
/// states, result sheets. English by default; pass your translations to
/// `BarcodeScanner(strings: ...)`:
///
/// ```dart
/// BarcodeScanner(
///   strings: ScannerStrings(
///     close: 'Scanner schließen',
///     starting: 'Kamera wird gestartet…',
///     itemCount: (n) => n == 1 ? '1 Artikel' : '$n Artikel',
///   ),
/// )
/// ```
@immutable
final class ScannerStrings {
  /// Creates the texts; every one has an English default.
  const ScannerStrings({
    this.close = 'Close the scanner',
    this.torchOn = 'Turn on the torch',
    this.torchOff = 'Turn off the torch',
    this.switchCamera = 'Switch camera',
    this.pickImage = 'Read a code from a photo',
    this.zoom = 'Zoom',
    this.autoZoom = 'Auto',
    this.autoZoomOn = 'Turn on automatic zoom',
    this.autoZoomOff = 'Turn off automatic zoom',
    this.starting = 'Starting the camera…',
    this.permissionTitle = 'Camera access is off',
    this.permissionMessage =
        'Turn on camera access for this app in Settings to scan codes.',
    this.unavailableTitle = "The camera isn't available",
    this.unavailableMessage =
        'Another app may be using it, or this device has none.',
    this.photoFallback = 'You can still read a code from a photo.',
    this.openSettings = 'Open Settings',
    this.tryAgain = 'Try again',
    this.choosePhoto = 'Choose a photo',
    this.noCodeInPhoto = 'No code found in this photo',
    this.copy = 'Copy',
    this.copied = 'Copied',
    this.scanAgain = 'Scan again',
    this.done = 'Done',
    this.scanned = 'Scanned',
    this.emptyList = 'Codes you scan appear here',
    this.itemCount = _itemCount,
    this.byteCount = _byteCount,
    this.link = 'Link',
    this.wifi = 'Wi‑Fi network',
    this.wifiOpen = 'Open network',
    this.wifiPassword = 'password in the code',
    this.contact = 'Contact',
    this.event = 'Event',
    this.email = 'Email',
    this.phone = 'Phone',
    this.sms = 'Text message',
    this.location = 'Location',
    this.gs1 = 'GS1',
    this.binary = 'Binary data',
    this.text = 'Text',
  });

  /// The strings of the nearest [ScannerScope], or the English defaults.
  static ScannerStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScannerScope>()?.strings ??
      const ScannerStrings();

  /// Label of the close button.
  final String close;

  /// Label of the torch button while the torch is off.
  final String torchOn;

  /// Label of the torch button while the torch is on.
  final String torchOff;

  /// Label of the switch camera button.
  final String switchCamera;

  /// Label of the photo button.
  final String pickImage;

  /// Label of the zoom buttons.
  final String zoom;

  /// Text of the automatic zoom button, before the zoom presets.
  final String autoZoom;

  /// Label of the automatic zoom button while it is off.
  final String autoZoomOn;

  /// Label of the automatic zoom button while it is on.
  final String autoZoomOff;

  /// Shown while the camera starts.
  final String starting;

  /// Title of the "no camera permission" card.
  final String permissionTitle;

  /// Text of the "no camera permission" card.
  final String permissionMessage;

  /// Title of the "camera not available" card.
  final String unavailableTitle;

  /// Text of the "camera not available" card.
  final String unavailableMessage;

  /// Added to the error cards when a photo can be read instead.
  final String photoFallback;

  /// The button that opens the app's settings.
  final String openSettings;

  /// The button that opens the camera again.
  final String tryAgain;

  /// The button that reads a photo instead of the camera.
  final String choosePhoto;

  /// Shown when a photo has no code.
  final String noCodeInPhoto;

  /// The button that copies a code's text.
  final String copy;

  /// The copy button after copying.
  final String copied;

  /// The button that hides a result and scans the next code.
  final String scanAgain;

  /// The button that ends a list of scanned codes.
  final String done;

  /// Above the number of scanned codes.
  final String scanned;

  /// An empty list of scanned codes.
  final String emptyList;

  /// The number of scanned codes ("3 items").
  final String Function(int count) itemCount;

  /// The size of binary data ("120 bytes").
  final String Function(int count) byteCount;

  /// The kind of a [UrlContent].
  final String link;

  /// The kind of a [WifiContent].
  final String wifi;

  /// A Wi‑Fi network without a password.
  final String wifiOpen;

  /// A Wi‑Fi network whose password is in the code.
  final String wifiPassword;

  /// The kind of a [ContactContent].
  final String contact;

  /// The kind of an [EventContent].
  final String event;

  /// The kind of an [EmailContent].
  final String email;

  /// The kind of a [PhoneContent].
  final String phone;

  /// The kind of an [SmsContent].
  final String sms;

  /// The kind of a [GeoContent].
  final String location;

  /// The kind of a [Gs1Content].
  final String gs1;

  /// The kind of a [BinaryContent].
  final String binary;

  /// The kind of a [TextContent].
  final String text;

  /// The kind of [content], as shown above a result's title.
  String kindOf(BarcodeContent content) => switch (content) {
    UrlContent() => link,
    WifiContent() => wifi,
    ContactContent() => contact,
    EventContent() => event,
    EmailContent() => email,
    PhoneContent() => phone,
    SmsContent() => sms,
    GeoContent() => location,
    Gs1Content() => gs1,
    BinaryContent() => binary,
    TextContent() => text,
  };

  @override
  bool operator ==(Object other) =>
      other is ScannerStrings &&
      other.close == close &&
      other.torchOn == torchOn &&
      other.torchOff == torchOff &&
      other.switchCamera == switchCamera &&
      other.pickImage == pickImage &&
      other.zoom == zoom &&
      other.autoZoom == autoZoom &&
      other.autoZoomOn == autoZoomOn &&
      other.autoZoomOff == autoZoomOff &&
      other.starting == starting &&
      other.permissionTitle == permissionTitle &&
      other.permissionMessage == permissionMessage &&
      other.unavailableTitle == unavailableTitle &&
      other.unavailableMessage == unavailableMessage &&
      other.photoFallback == photoFallback &&
      other.openSettings == openSettings &&
      other.tryAgain == tryAgain &&
      other.choosePhoto == choosePhoto &&
      other.noCodeInPhoto == noCodeInPhoto &&
      other.copy == copy &&
      other.copied == copied &&
      other.scanAgain == scanAgain &&
      other.done == done &&
      other.scanned == scanned &&
      other.emptyList == emptyList &&
      other.itemCount == itemCount &&
      other.byteCount == byteCount &&
      other.link == link &&
      other.wifi == wifi &&
      other.wifiOpen == wifiOpen &&
      other.wifiPassword == wifiPassword &&
      other.contact == contact &&
      other.event == event &&
      other.email == email &&
      other.phone == phone &&
      other.sms == sms &&
      other.location == location &&
      other.gs1 == gs1 &&
      other.binary == binary &&
      other.text == text;

  @override
  int get hashCode => Object.hashAll(<Object>[
    close,
    torchOn,
    torchOff,
    switchCamera,
    pickImage,
    zoom,
    autoZoom,
    autoZoomOn,
    autoZoomOff,
    starting,
    permissionTitle,
    permissionMessage,
    unavailableTitle,
    unavailableMessage,
    photoFallback,
    openSettings,
    tryAgain,
    choosePhoto,
    noCodeInPhoto,
    copy,
    copied,
    scanAgain,
    done,
    scanned,
    emptyList,
    itemCount,
    byteCount,
    link,
    wifi,
    wifiOpen,
    wifiPassword,
    contact,
    event,
    email,
    phone,
    sms,
    location,
    gs1,
    binary,
    text,
  ]);

  static String _itemCount(int count) => count == 1 ? '1 item' : '$count items';

  static String _byteCount(int count) => count == 1 ? '1 byte' : '$count bytes';
}
