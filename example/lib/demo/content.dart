// What a code holds, in words: the kind, a title, the fields, and what can
// be done with it. Also the text the generator encodes for each kind, and a
// style written as Dart.
import 'package:flutter/foundation.dart';
// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:url_launcher/url_launcher.dart';

/// A code's content, described for a list row or a result page.
@immutable
final class Described {
  const Described({
    required this.kind,
    required this.icon,
    required this.title,
    this.fields = const <(String, String)>[],
    this.open,
    this.openLabel,
    this.openIcon,
    this.secret,
  });

  /// "Wi‑Fi", "Link", "Product"...
  final String kind;
  final IconData icon;
  final String title;

  /// Label and value pairs.
  final List<(String, String)> fields;

  /// What the primary action opens, if anything.
  final Uri? open;
  final String? openLabel;
  final IconData? openIcon;

  /// A value worth its own copy button (a Wi‑Fi password).
  final String? secret;
}

/// Describes [barcode]'s content.
Described describe(Barcode barcode) {
  final BarcodeContent content = BarcodeContent.parse(barcode);
  String or(String? s, String fallback) =>
      s == null || s.isEmpty ? fallback : s;
  return switch (content) {
    UrlContent(:final Uri url, :final String? title) => Described(
      kind: content.service?.displayName ?? 'Link',
      icon: Icons.link_rounded,
      title: or(title, url.host.isEmpty ? url.toString() : url.host),
      fields: <(String, String)>[('Address', url.toString())],
      open: url,
      openLabel: 'Open',
      openIcon: Icons.open_in_new_rounded,
    ),
    WifiContent(
      :final String ssid,
      :final String? password,
      :final WifiSecurity security,
      :final bool hidden,
    ) =>
      Described(
        kind: 'Wi‑Fi',
        icon: Icons.wifi_rounded,
        title: ssid,
        fields: <(String, String)>[
          ('Network', ssid),
          if (password != null && password.isNotEmpty) ('Password', password),
          ('Security', _security(security)),
          ('Hidden', hidden ? 'Yes' : 'No'),
        ],
        secret: password,
      ),
    EmailContent(:final String address, :final String? subject) => Described(
      kind: 'Email',
      icon: Icons.mail_outline_rounded,
      title: address,
      fields: <(String, String)>[
        ('To', address),
        if (subject != null) ('Subject', subject),
      ],
      open: Uri(scheme: 'mailto', path: address),
      openLabel: 'Write',
      openIcon: Icons.edit_outlined,
    ),
    PhoneContent(:final String number) => Described(
      kind: 'Phone',
      icon: Icons.call_outlined,
      title: number,
      open: Uri(scheme: 'tel', path: number),
      openLabel: 'Call',
      openIcon: Icons.call_outlined,
    ),
    SmsContent(:final String number, :final String? message) => Described(
      kind: 'Message',
      icon: Icons.sms_outlined,
      title: number,
      fields: <(String, String)>[
        ('To', number),
        if (message != null) ('Message', message),
      ],
      open: Uri(scheme: 'sms', path: number),
      openLabel: 'Message',
      openIcon: Icons.sms_outlined,
    ),
    GeoContent(:final double latitude, :final double longitude) => Described(
      kind: 'Location',
      icon: Icons.place_outlined,
      title: '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      open: Uri.parse('geo:$latitude,$longitude'),
      openLabel: 'Map',
      openIcon: Icons.map_outlined,
    ),
    ContactContent(
      :final String? name,
      :final String? organization,
      :final List<String> phones,
      :final List<String> emails,
    ) =>
      Described(
        kind: 'Contact',
        icon: Icons.person_outline_rounded,
        title: or(name, or(organization, 'Contact')),
        fields: <(String, String)>[
          if (organization != null) ('Company', organization),
          for (final String p in phones) ('Phone', p),
          for (final String e in emails) ('Email', e),
        ],
        open: phones.isEmpty ? null : Uri(scheme: 'tel', path: phones.first),
        openLabel: 'Call',
        openIcon: Icons.call_outlined,
      ),
    EventContent(:final String summary, :final DateTime start) => Described(
      kind: 'Event',
      icon: Icons.event_outlined,
      title: summary,
      fields: <(String, String)>[('Starts', start.toLocal().toString())],
    ),
    Gs1Content gs1 => Described(
      kind: 'GS1',
      icon: Icons.inventory_2_outlined,
      title: gs1.gtin ?? gs1.sscc ?? gs1.elements.values.first,
      fields: <(String, String)>[
        for (final MapEntry<String, String> e in gs1.elements.entries)
          switch (e.key) {
            '17' when gs1.expiry != null => (
              'Expiry',
              '${_date(gs1.expiry!)}${gs1.isExpired() ? ' · expired' : ''}',
            ),
            _ => (_gs1Names[e.key] ?? '(${e.key})', e.value),
          },
      ],
    ),
    BinaryContent(:final Uint8List bytes) => Described(
      kind: 'Binary',
      icon: Icons.memory_rounded,
      title: '${bytes.length} bytes',
    ),
    PaymentContent payment => Described(
      kind: 'Payment',
      icon: Icons.payments_outlined,
      title: payment.amount == null
          ? or(payment.payee, 'Payment')
          : '${payment.amount} ${payment.currency ?? ''}'.trim(),
      fields: <(String, String)>[
        if (payment.payee != null) ('Payee', payment.payee!),
        if (payment.account != null) ('Account', payment.account!),
        if (payment.reference != null) ('Reference', payment.reference!),
        if (payment case EmvPaymentContent(:final EmvScheme scheme))
          ('Scheme', scheme.name),
        if (payment case EpcPaymentContent(bic: final String bic)) ('BIC', bic),
        if (payment case GostPaymentContent(:final String bankName))
          ('Bank', bankName),
      ],
    ),
    OtpContent otp => Described(
      kind: 'One-time password',
      icon: Icons.password_rounded,
      title: or(otp.issuer, otp.account),
      fields: <(String, String)>[
        ('Account', otp.account),
        if (otp.issuer != null) ('Issuer', otp.issuer!),
        ('Type', otp.type.name.toUpperCase()),
        ('Algorithm', otp.algorithm.name.toUpperCase()),
        ('Digits', '${otp.digits}'),
        if (otp.type == OtpType.totp) ('Period', '${otp.period} s'),
        if (otp.type == OtpType.hotp) ('Counter', '${otp.counter}'),
      ],
      // The secret only behind its own copy button, never in the list.
      secret: otp.secret,
    ),
    EsimContent esim => Described(
      kind: 'eSIM',
      icon: Icons.sim_card_outlined,
      title: esim.smdpAddress,
      fields: <(String, String)>[
        ('SM-DP+', esim.smdpAddress),
        if (esim.matchingId != null) ('Matching ID', esim.matchingId!),
        if (esim.oid != null) ('OID', esim.oid!),
        if (esim.confirmationCodeRequired) ('Confirmation code', 'Required'),
      ],
    ),
    CryptoContent crypto => Described(
      kind: 'Crypto · ${crypto.currency.symbol}',
      icon: Icons.currency_bitcoin_rounded,
      title: crypto.amount == null
          ? or(crypto.label, crypto.currency.name)
          : '${crypto.amount} ${crypto.currency.symbol}',
      fields: <(String, String)>[
        ('Network', crypto.currency.name),
        ('Address', crypto.address),
        if (crypto.amount != null)
          ('Amount', '${crypto.amount} ${crypto.currency.symbol}'),
        if (crypto.value != null) ('Value, wei', crypto.value!),
        if (crypto.label != null) ('Label', crypto.label!),
        if (crypto.message != null) ('Message', crypto.message!),
        if (crypto.chainId != null) ('Chain id', '${crypto.chainId}'),
      ],
    ),
    WifiDppContent dpp => Described(
      kind: 'Wi‑Fi device',
      icon: Icons.router_outlined,
      title: or(dpp.information, or(dpp.macAddress, 'Wi‑Fi Easy Connect')),
      fields: <(String, String)>[
        if (dpp.macAddress != null) ('MAC', dpp.macAddress!),
        if (dpp.channels != null) ('Channels', dpp.channels!),
        ('Public key', dpp.publicKey),
      ],
    ),
    SmartHomeContent home => Described(
      kind: home.platform == SmartHomePlatform.matter ? 'Matter' : 'HomeKit',
      icon: Icons.home_outlined,
      title: home.setupCode,
      fields: <(String, String)>[
        ('Setup code', home.setupCode),
        if (home.vendorId != null)
          ('Vendor id', '0x${home.vendorId!.toRadixString(16).toUpperCase()}'),
        if (home.productId != null)
          (
            'Product id',
            '0x${home.productId!.toRadixString(16).toUpperCase()}',
          ),
        if (home.discriminator != null)
          ('Discriminator', '${home.discriminator}'),
        if (home.category != null) ('Category', '${home.category}'),
        if (home.setupId != null) ('Setup id', home.setupId!),
      ],
    ),
    BoardingPassContent pass => Described(
      kind: 'Boarding pass',
      icon: Icons.flight_takeoff_rounded,
      title: '${pass.legs.first.from} → ${pass.legs.first.to}',
      fields: <(String, String)>[
        ('Passenger', pass.passengerName),
        for (final BoardingPassLeg leg in pass.legs) ...<(String, String)>[
          (
            'Flight',
            '${leg.carrier} ${leg.flightNumber}, ${leg.from} → ${leg.to}',
          ),
          ('Booking', leg.bookingReference),
          if (leg.seat.isNotEmpty) ('Seat', leg.seat),
        ],
      ],
    ),
    DriverLicenseContent id => Described(
      kind: "Driver's license",
      icon: Icons.badge_outlined,
      title: <String>[?id.firstName, ?id.lastName].join(' '),
      fields: <(String, String)>[
        if (id.licenseNumber != null) ('Number', id.licenseNumber!),
        if (id.dateOfBirth != null) ('Born', _date(id.dateOfBirth!)),
        if (id.expiryDate != null) ('Expires', _date(id.expiryDate!)),
        if (id.state != null) ('State', id.state!),
        if (id.city != null) ('City', id.city!),
      ],
    ),
    VinContent vin => Described(
      kind: 'Vehicle',
      icon: Icons.directions_car_outlined,
      title: vin.vin,
      fields: <(String, String)>[
        ('WMI', vin.wmi),
        ('Region', vin.region.name),
        (
          'Check digit',
          vin.hasValidCheckDigit ? 'Valid' : 'Not North American',
        ),
        if (vin.hasValidCheckDigit && vin.modelYear != null)
          ('Model year', '${vin.modelYear}'),
      ],
    ),
    ProductContent product => Described(
      kind: product.isbn13 != null || product.issn != null ? 'Book' : 'Product',
      icon: product.isbn13 != null
          ? Icons.menu_book_outlined
          : Icons.view_week_outlined,
      title: product.number,
      fields: <(String, String)>[
        ('GTIN', product.gtin),
        if (product.isbn13 != null) ('ISBN-13', product.isbn13!),
        if (product.isbn10 != null) ('ISBN-10', product.isbn10!),
        if (product.issn != null) ('ISSN', product.issn!),
        if (product.addOn != null) ('Add-on', product.addOn!),
      ],
    ),
    TextContent(:final String text) => Described(
      kind: 'Text',
      icon: barcode.format.isLinear
          ? Icons.view_week_outlined
          : Icons.notes_rounded,
      title: text,
    ),
    // New kinds come in minor versions of flutter_zxing.
    _ => Described(
      kind: 'Text',
      icon: Icons.notes_rounded,
      title: barcode.text,
    ),
  };
}

/// The names of the common GS1 Application Identifiers.
const Map<String, String> _gs1Names = <String, String>{
  '00': 'SSCC',
  '01': 'GTIN',
  '02': 'Content GTIN',
  '10': 'Batch',
  '11': 'Produced',
  '15': 'Best before',
  '17': 'Expiry',
  '21': 'Serial',
  '37': 'Count',
};

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _security(WifiSecurity s) => switch (s) {
  WifiSecurity.none => 'None',
  WifiSecurity.wep => 'WEP',
  WifiSecurity.wpa3 => 'WPA3',
  _ => 'WPA / WPA2',
};

/// Opens [uri] with the platform; tells the person if nothing can.
Future<void> openUri(BuildContext context, Uri uri) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final bool opened = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  ).catchError((Object _) => false);
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Nothing on this device opens $uri.')),
    );
  }
}

/// [style] for [data] in [format] as a BarcodeView in Dart, for "Copy as
/// Dart". [content] is the Dart that builds the content, when the code
/// was made from a form: the view then gets its `.toPayload()`.
String dartCode(
  String data,
  BarcodeFormat format,
  BarcodeStyle style, {
  String? presetName,
  ErrorCorrection? errorCorrection,
  String? content,
  bool gs1 = false,
  bool showText = false,
}) {
  String hex(Color c) =>
      'Color(0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})';
  String quoted(String s) =>
      "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";
  final String first = content == null
      ? quoted(data)
      : '${content.split('\n').join('\n  ')}.toPayload()';
  final StringBuffer b = StringBuffer('BarcodeView(\n  $first,\n');
  if (format != BarcodeFormat.qrCode) {
    b.writeln('  format: BarcodeFormat.${format.name},');
  }
  if (gs1) {
    b.writeln('  gs1: true,');
  }
  if (showText) {
    b.writeln('  showText: true,');
  }
  if (errorCorrection != null && format.hasErrorCorrection) {
    b.writeln('  errorCorrection: ErrorCorrection.${errorCorrection.name},');
  }
  // The look alone, without the logo, text and card: to name a preset.
  final BarcodeStyle look = BarcodeStyle(
    color: style.color,
    backgroundColor: style.backgroundColor,
    gradient: style.gradient,
    moduleShape: style.moduleShape,
    finderShape: style.finderShape,
    quietZone: style.quietZone,
  );
  final List<String> extras = <String>[
    if (style.logo case final BarcodeLogo logo)
      "logo: BarcodeLogo(AssetImage('assets/logo.png'), "
          'size: ${logo.size.toStringAsFixed(2)}),',
    if (style.title case final BarcodeCaption t)
      'title: ${_captionDart(t, quoted)},',
    if (style.caption case final BarcodeCaption c)
      'caption: ${_captionDart(c, quoted)},',
    if (style.card case final BarcodeCard card)
      'card: ${_cardDart(card, hex)},',
  ];
  if (identical(style, BarcodeStyle.swissQrBill)) {
    b.writeln('  style: BarcodeStyle.swissQrBill,');
  } else if (presetName != null && BarcodeStyle.presets[presetName] == look) {
    if (extras.isEmpty) {
      b.writeln('  style: BarcodeStyle.$presetName,');
    } else {
      b.writeln('  style: BarcodeStyle.$presetName.copyWith(');
      for (final String e in extras) {
        b.writeln('    $e');
      }
      b.writeln('  ),');
    }
  } else if (style != BarcodeStyle.classic) {
    b.writeln('  style: BarcodeStyle(');
    const BarcodeStyle d = BarcodeStyle.classic;
    final Gradient? g = style.gradient;
    if (g != null) {
      b
        ..writeln('    gradient: LinearGradient(colors: [')
        ..writeln('      ${g.colors.map(hex).join(', ')},')
        ..writeln('    ]),');
    } else if (style.color != d.color) {
      b.writeln('    color: ${hex(style.color)},');
    }
    if (style.backgroundColor != d.backgroundColor) {
      b.writeln('    backgroundColor: ${hex(style.backgroundColor)},');
    }
    if (style.moduleShape != d.moduleShape) {
      b.writeln('    moduleShape: ModuleShape.${style.moduleShape.name},');
    }
    if (style.finderShape != d.finderShape) {
      b.writeln('    finderShape: FinderShape.${style.finderShape.name},');
    }
    if (!style.quietZone) {
      b.writeln('    quietZone: false,');
    }
    for (final String e in extras) {
      b.writeln('    $e');
    }
    b.writeln('  ),');
  }
  b.write(')');
  return b.toString();
}

/// The class of [content], by name: `runtimeType` is minified on the web.
String contentClassName(BarcodeContent content) => switch (content) {
  TextContent() => 'TextContent',
  UrlContent() => 'UrlContent',
  WifiContent() => 'WifiContent',
  EmailContent() => 'EmailContent',
  PhoneContent() => 'PhoneContent',
  SmsContent() => 'SmsContent',
  GeoContent() => 'GeoContent',
  ContactContent() => 'ContactContent',
  EventContent() => 'EventContent',
  Gs1Content() => 'Gs1Content',
  BinaryContent() => 'BinaryContent',
  EpcPaymentContent() => 'EpcPaymentContent',
  SwissQrBillContent() => 'SwissQrBillContent',
  GostPaymentContent() => 'GostPaymentContent',
  UpiPaymentContent() => 'UpiPaymentContent',
  EmvPaymentContent() => 'EmvPaymentContent',
  SpaydPaymentContent() => 'SpaydPaymentContent',
  OtpContent() => 'OtpContent',
  EsimContent() => 'EsimContent',
  CryptoContent() => 'CryptoContent',
  WifiDppContent() => 'WifiDppContent',
  SmartHomeContent() => 'SmartHomeContent',
  BoardingPassContent() => 'BoardingPassContent',
  DriverLicenseContent() => 'DriverLicenseContent',
  VinContent() => 'VinContent',
  ProductContent() => 'ProductContent',
  _ => 'BarcodeContent',
};

/// `BarcodeCaption('…', size: …)`, with what differs from the defaults.
String _captionDart(BarcodeCaption c, String Function(String) quoted) {
  final List<String> args = <String>[
    quoted(c.text),
    if (c.size != 0.09) 'size: ${c.size}',
    if (c.style?.color case final Color color)
      'style: TextStyle(color: Color(0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}))',
  ];
  return 'BarcodeCaption(${args.join(', ')})';
}

/// `BarcodeCard(…)`, with what differs from the defaults.
String _cardDart(BarcodeCard c, String Function(Color) hex) {
  final List<String> args = <String>[
    if (c.color case final Color color) 'color: ${hex(color)}',
    if (c.radius != 0.12) 'radius: ${c.radius}',
    if (c.padding != 0.1) 'padding: ${c.padding}',
    if (c.elevation != 0) 'elevation: ${c.elevation}',
  ];
  return 'BarcodeCard(${args.join(', ')})';
}
