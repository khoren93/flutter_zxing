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
      kind: 'Link',
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
    Gs1Content(:final Map<String, String> elements) => Described(
      kind: 'GS1',
      icon: Icons.inventory_2_outlined,
      title: elements['01'] ?? elements.values.first,
      fields: <(String, String)>[
        for (final MapEntry<String, String> e in elements.entries)
          ('(${e.key})', e.value),
      ],
    ),
    BinaryContent(:final Uint8List bytes) => Described(
      kind: 'Binary',
      icon: Icons.memory_rounded,
      title: '${bytes.length} bytes',
    ),
    TextContent(:final String text) => Described(
      kind: barcode.format.isLinear && _digits.hasMatch(text)
          ? 'Product'
          : 'Text',
      icon: barcode.format.isLinear
          ? Icons.view_week_outlined
          : Icons.notes_rounded,
      title: text,
    ),
  };
}

final RegExp _digits = RegExp(r'^\d{8,14}$');

String _security(WifiSecurity s) => switch (s) {
  WifiSecurity.none => 'None',
  WifiSecurity.wep => 'WEP',
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

/// The kinds the generator makes.
enum CreateKind {
  text('Text', Icons.notes_rounded),
  link('Link', Icons.link_rounded),
  wifi('Wi‑Fi', Icons.wifi_rounded),
  contact('Contact', Icons.person_outline_rounded),
  email('Email', Icons.mail_outline_rounded),
  phone('Phone', Icons.call_outlined);

  const CreateKind(this.label, this.icon);

  final String label;
  final IconData icon;

  /// The fields the form asks for, by key: label and hint.
  List<(String, String, String)> get fields => switch (this) {
    text => <(String, String, String)>[('text', 'Text', 'Anything')],
    link => <(String, String, String)>[
      ('url', 'Address', 'https://pub.dev/packages/flutter_zxing'),
    ],
    wifi => <(String, String, String)>[
      ('ssid', 'Network name', 'Studio 5G'),
      ('password', 'Password', 'lime-orbit-42'),
    ],
    contact => <(String, String, String)>[
      ('name', 'Name', 'Lilit Ohanyan'),
      ('phone', 'Phone', '+374 91 234567'),
      ('email', 'Email', 'lilit@example.com'),
    ],
    email => <(String, String, String)>[
      ('to', 'To', 'hello@example.com'),
      ('subject', 'Subject', 'Hello'),
    ],
    phone => <(String, String, String)>[('number', 'Number', '+374 10 123456')],
  };

  /// The text to encode from the form's [values] (keys of [fields]).
  String encode(Map<String, String> values, {WifiSecurity? security}) {
    String v(String key) => (values[key] ?? '').trim();
    String esc(String s) =>
        s.replaceAllMapped(RegExp(r'[\\;,:"]'), (Match m) => '\\${m[0]}');
    return switch (this) {
      text => v('text'),
      link => v('url'),
      wifi => () {
        final WifiSecurity s = security ?? WifiSecurity.wpa;
        final String t = switch (s) {
          WifiSecurity.none => 'nopass',
          WifiSecurity.wep => 'WEP',
          _ => 'WPA',
        };
        final String pass = s == WifiSecurity.none
            ? ''
            : 'P:${esc(v('password'))};';
        return 'WIFI:T:$t;S:${esc(v('ssid'))};$pass;';
      }(),
      contact => <String>[
        'BEGIN:VCARD',
        'VERSION:3.0',
        'FN:${v('name')}',
        if (v('phone').isNotEmpty) 'TEL:${v('phone')}',
        if (v('email').isNotEmpty) 'EMAIL:${v('email')}',
        'END:VCARD',
      ].join('\n'),
      email =>
        v('subject').isEmpty
            ? 'mailto:${v('to')}'
            : 'mailto:${v('to')}?subject=${Uri.encodeComponent(v('subject'))}',
      phone => 'tel:${v('number').replaceAll(' ', '')}',
    };
  }
}

/// [style] for [data] in [format] as a BarcodeView in Dart, for "Copy as
/// Dart".
String dartCode(
  String data,
  BarcodeFormat format,
  BarcodeStyle style, {
  String? presetName,
}) {
  String hex(Color c) =>
      'Color(0x${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})';
  String quoted(String s) =>
      "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n')}'";
  final StringBuffer b = StringBuffer('BarcodeView(\n  ${quoted(data)},\n');
  if (format != BarcodeFormat.qrCode) {
    b.writeln('  format: BarcodeFormat.${format.name},');
  }
  final BarcodeStyle plain = style.copyWith();
  if (presetName != null &&
      BarcodeStyle.presets[presetName] == plain &&
      style.logo == null) {
    b.writeln('  style: BarcodeStyle.$presetName,');
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
    if (style.logo != null) {
      b.writeln(
        "    logo: BarcodeLogo(AssetImage('assets/logo.png'), "
        'size: ${style.logo!.size.toStringAsFixed(2)}),',
      );
    }
    b.writeln('  ),');
  }
  b.write(')');
  return b.toString();
}
