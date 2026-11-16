// The scanner templates, each with its theme, and the codes to try them
// with. Run it with
//   flutter run -t lib/showcase.dart
// Show the test codes on a second screen (a tablet, a laptop, an emulator:
// --dart-define=PAGE=codes opens them directly) and scan them with the
// phone. The demo app of stage 8 replaces this launcher.
import 'dart:convert';
import 'dart:ui' show FrameTiming;

// material.dart is deprecated since Flutter 3.47 in favour of package:material_ui,
// which needs Flutter 3.47; the example still supports Flutter 3.41.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

void main() {
  _logFrameTimes();
  // On the web, `?template=content&look=darkGlass` opens a template
  // directly, for screenshots.
  final Map<String, String> query = Uri.base.queryParameters;
  // --dart-define=TEMPLATE=minimal does the same on a phone, for frame
  // time measurements without taps.
  final String? direct =
      query['template'] ??
      (const String.fromEnvironment('TEMPLATE') == ''
          ? null
          : const String.fromEnvironment('TEMPLATE'));
  final _Look look = _Look.values.firstWhere(
    (_Look l) =>
        l.name ==
        (query['look'] ??
            (const String.fromEnvironment('LOOK') == ''
                ? null
                : const String.fromEnvironment('LOOK'))),
    orElse: () => _Look.template,
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'flutter_zxing templates',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF2EE6B5)),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2EE6B5),
        brightness: Brightness.dark,
      ),
      // --dart-define=PAGE=codes starts on the codes, for a second device.
      home: const String.fromEnvironment('PAGE') == 'codes'
          ? const TestCodesPage()
          : direct == null
          ? const ShowcasePage()
          : Builder(
              builder: (BuildContext context) => ColoredBox(
                color: Colors.black,
                child: BarcodeScanner(
                  template: _templates(context)[direct]!.$3,
                  theme: look.theme,
                ),
              ),
            ),
    ),
  );
}

/// Logs every 5 s how many frames took longer than 16 ms to build or to
/// rasterize (the glass blur costs raster time), for `flutter run` logs.
void _logFrameTimes() {
  final List<FrameTiming> frames = <FrameTiming>[];
  DateTime last = DateTime.now();
  WidgetsFlutterBinding.ensureInitialized().addTimingsCallback((
    List<FrameTiming> timings,
  ) {
    frames.addAll(timings);
    final DateTime now = DateTime.now();
    if (now.difference(last) < const Duration(seconds: 5) || frames.isEmpty) {
      return;
    }
    last = now;
    const int budget = 16000;
    final int slow = frames
        .where(
          (FrameTiming t) =>
              t.buildDuration.inMicroseconds > budget ||
              t.rasterDuration.inMicroseconds > budget,
        )
        .length;
    int worst(Duration Function(FrameTiming) of) => frames
        .map((FrameTiming t) => of(t).inMicroseconds)
        .reduce((int a, int b) => a > b ? a : b);
    final List<int> raster =
        frames.map((FrameTiming t) => t.rasterDuration.inMicroseconds).toList()
          ..sort();
    debugPrint(
      '[frames] ${frames.length} frames, $slow over 16 ms '
      '(${(100 * slow / frames.length).toStringAsFixed(1)}%), raster median '
      '${(raster[raster.length ~/ 2] / 1000).toStringAsFixed(1)} ms, worst '
      'build ${(worst((FrameTiming t) => t.buildDuration) / 1000).toStringAsFixed(1)} ms, '
      'worst raster ${(worst((FrameTiming t) => t.rasterDuration) / 1000).toStringAsFixed(1)} ms',
    );
    frames.clear();
  });
}

/// The templates by name: title, what they show, the template.
Map<String, (String, String, ScannerTemplate)> _templates(
  BuildContext context,
) => <String, (String, String, ScannerTemplate)>{
  'minimal': (
    'Minimal',
    'Any code, a sheet with what is in it',
    const ScannerTemplate.minimal(),
  ),
  'payment': (
    'Payments',
    'An EPC payment QR: payee, amount, reference',
    ScannerTemplate.payment(resultBuilder: _paymentSheet),
  ),
  'retail': (
    'Retail and warehouse',
    'A list of EAN and shipping codes with counts',
    ScannerTemplate.retail(
      title: 'Shelf B-12',
      onDone: (List<CollectedBarcode> items) =>
          Navigator.of(context).maybePop(),
    ),
  ),
  'ticket': (
    'Tickets and documents',
    'A boarding pass (PDF417) and its fields',
    ScannerTemplate.ticket(
      title: 'Scan your boarding pass',
      resultBuilder: _ticketSheet,
    ),
  ),
  'content': (
    'Content',
    'Wi‑Fi, links, contacts, events',
    ScannerTemplate.content(actionsBuilder: _contentActions),
  ),
};

/// The themes to try every template with.
enum _Look {
  template('Template default', null),
  brand(
    'Your brand',
    ScannerTheme(
      accent: Color(0xFFFF6A1A),
      windowRadius: 6,
      buttonShape: ScannerButtonShape.roundedSquare,
    ),
  ),
  darkGlass(
    'Dark glass',
    ScannerTheme(accent: Color(0xFF4D8DFF), brightness: Brightness.dark),
  ),
  lightGlass('Light glass', ScannerTheme(brightness: Brightness.light)),
  noScrimBlur('No scrim blur', ScannerTheme(scrimBlur: false)),
  noBlur('No blur', ScannerTheme(blur: false));

  const _Look(this.label, this.theme);

  final String label;
  final ScannerTheme? theme;
}

/// Picks a template and a theme.
class ShowcasePage extends StatefulWidget {
  /// Creates the page.
  const ShowcasePage({super.key});

  @override
  State<ShowcasePage> createState() => _ShowcasePageState();
}

class _ShowcasePageState extends State<ShowcasePage> {
  _Look _look = _Look.template;

  void _open(ScannerTemplate template) {
    debugPrint('[open] ${_look.name}');
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ColoredBox(
          color: Colors.black,
          child: BarcodeScanner(template: template, theme: _look.theme),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner templates'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Codes to scan',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const TestCodesPage(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final _Look look in _Look.values)
                ChoiceChip(
                  label: Text(look.label),
                  selected: look == _look,
                  onSelected: (_) => setState(() => _look = look),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (String name, String about, ScannerTemplate template)
              in _templates(context).values)
            Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text(about),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _open(template),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () async {
              final Barcode? barcode = await scanBarcode(context);
              if (barcode != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('scanBarcode: ${barcode.text}')),
                );
              }
            },
            child: const Text('scanBarcode(context)'),
          ),
        ],
      ),
    );
  }
}

/// The sheet of the payments template: an EPC QR code ("BCD" payload, the
/// SEPA credit transfer QR printed on European invoices).
Widget _paymentSheet(
  BuildContext context,
  Barcode barcode,
  VoidCallback scanAgain,
) {
  final _Epc? epc = _Epc.parse(barcode.text);
  if (epc == null) {
    return BarcodeResultSheet(barcode, onScanAgain: scanAgain);
  }
  final ScannerTheme theme = ScannerTheme.of(context);
  return ScannerSheet(
    label: 'Payment request',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('PAYMENT REQUEST', style: theme.overlineStyle),
        const SizedBox(height: 4),
        Text(epc.name, style: theme.titleStyle),
        const SizedBox(height: 16),
        Text(epc.amount, style: theme.displayStyle),
        if (epc.reference.isNotEmpty)
          Text('Reference ${epc.reference}', style: theme.mutedStyle),
        const SizedBox(height: 16),
        ScannerChip(
          '${barcode.format.displayName} · ${barcode.symbologyIdentifier}',
        ),
        const SizedBox(height: 16),
        ScannerActions(<ScannerAction>[
          ScannerAction(
            label: 'Pay ${epc.amount}',
            primary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          ScannerAction(label: 'Cancel', onPressed: scanAgain),
        ]),
      ],
    ),
  );
}

final class _Epc {
  const _Epc(this.name, this.amount, this.reference);

  final String name;
  final String amount;
  final String reference;

  static _Epc? parse(String text) {
    final List<String> lines = const LineSplitter().convert(text);
    if (lines.length < 7 || lines[0] != 'BCD' || lines[3] != 'SCT') {
      return null;
    }
    String at(int i) => i < lines.length ? lines[i].trim() : '';
    final String money = at(7);
    final String amount = money.startsWith('EUR')
        ? '€${money.substring(3)}'
        : money;
    final String reference = at(9).isNotEmpty ? at(9) : at(10);
    return _Epc(at(5), amount, reference);
  }
}

/// The sheet of the tickets template: an IATA boarding pass (BCBP).
Widget _ticketSheet(
  BuildContext context,
  Barcode barcode,
  VoidCallback scanAgain,
) {
  final _Bcbp? pass = _Bcbp.parse(barcode.text);
  if (pass == null) {
    return BarcodeResultSheet(barcode, onScanAgain: scanAgain);
  }
  final ScannerTheme theme = ScannerTheme.of(context);
  return ScannerSheet(
    label: 'Boarding pass',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('BOARDING PASS · ${pass.flight}', style: theme.overlineStyle),
        const SizedBox(height: 4),
        Text('${pass.from} → ${pass.to}', style: theme.titleStyle),
        const SizedBox(height: 16),
        ScannerFields(<String, String>{
          'Passenger': pass.name,
          'Date': pass.date,
          'Seat': pass.seat,
          'Class': pass.cabin,
          'Booking': pass.booking,
          'Sequence': pass.sequence,
        }),
        const SizedBox(height: 16),
        ScannerChip(
          '${barcode.format.displayName} · ${barcode.symbologyIdentifier}',
        ),
        const SizedBox(height: 16),
        ScannerActions(<ScannerAction>[
          ScannerAction(
            label: 'Save pass',
            primary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
          ScannerAction(label: 'Scan again', onPressed: scanAgain),
        ]),
      ],
    ),
  );
}

final class _Bcbp {
  const _Bcbp({
    required this.name,
    required this.booking,
    required this.from,
    required this.to,
    required this.flight,
    required this.date,
    required this.cabin,
    required this.seat,
    required this.sequence,
  });

  final String name;
  final String booking;
  final String from;
  final String to;
  final String flight;
  final String date;
  final String cabin;
  final String seat;
  final String sequence;

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// The mandatory fields of the first leg.
  static _Bcbp? parse(String text) {
    if (text.length < 58 || text[0] != 'M') {
      return null;
    }
    String field(int start, int length) =>
        text.substring(start, start + length).trim();
    final int? day = int.tryParse(field(44, 3));
    String date = field(44, 3);
    if (day != null && day >= 1 && day <= 366) {
      final DateTime d = DateTime(
        DateTime.now().year,
      ).add(Duration(days: day - 1));
      date = '${d.day} ${_months[d.month - 1]}';
    }
    final String carrier = field(36, 3);
    final String number = field(39, 5).replaceFirst(RegExp('^0+'), '');
    return _Bcbp(
      name: field(2, 20),
      booking: field(23, 7),
      from: field(30, 3),
      to: field(33, 3),
      flight: '$carrier $number',
      date: date,
      cabin: field(47, 1),
      seat: field(48, 4).replaceFirst(RegExp('^0+'), ''),
      sequence: field(52, 5).replaceFirst(RegExp('^0+'), ''),
    );
  }
}

/// The buttons of the content template: what an app would do with each
/// kind of content. Opening links and joining networks needs plugins
/// (url_launcher, a Wi‑Fi plugin), so here they only say what they would do.
List<ScannerAction> _contentActions(
  BuildContext context,
  Barcode barcode,
  VoidCallback scanAgain,
) {
  void tell(String what) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('Your app would $what')));
  final ScannerAction? primary = switch (barcode.content) {
    UrlContent(:final Uri url) => ScannerAction(
      label: 'Open',
      icon: ScannerIcons.open,
      primary: true,
      onPressed: () => tell('open $url'),
    ),
    WifiContent(:final String ssid) => ScannerAction(
      label: 'Connect',
      icon: ScannerIcons.wifi,
      primary: true,
      onPressed: () => tell('join $ssid'),
    ),
    PhoneContent(:final String number) => ScannerAction(
      label: 'Call',
      icon: ScannerIcons.phone,
      primary: true,
      onPressed: () => tell('call $number'),
    ),
    ContactContent() => ScannerAction(
      label: 'Add contact',
      icon: ScannerIcons.contact,
      primary: true,
      onPressed: () => tell('add the contact'),
    ),
    EventContent() => ScannerAction(
      label: 'Add to calendar',
      icon: ScannerIcons.event,
      primary: true,
      onPressed: () => tell('add the event'),
    ),
    _ => null,
  };
  return <ScannerAction>[
    ?primary,
    ScannerAction.copy(barcode.text, primary: primary == null),
  ];
}

/// The codes the templates expect, to show on a second screen.
class TestCodesPage extends StatelessWidget {
  /// Creates the page.
  const TestCodesPage({super.key});

  static final String _boardingPass =
      'M1${'ZXING/FLUTTER'.padRight(20)}EE7QK3TPZRHAMSLX 0423 318Y012C0034 100';

  static const List<(String, BarcodeFormat, String)>
  _codes = <(String, BarcodeFormat, String)>[
    ('Link', BarcodeFormat.qrCode, 'https://pub.dev/packages/flutter_zxing'),
    (
      'Wi‑Fi',
      BarcodeFormat.qrCode,
      'WIFI:S:Lumen Guest;T:WPA;P:espresso-2026;;',
    ),
    (
      'Payment (EPC)',
      BarcodeFormat.qrCode,
      'BCD\n002\n1\nSCT\n\nKaffeehaus Lumen\nDE89370400440532013000\n'
          'EUR4.80\n\n\nA7F3-21',
    ),
    ('EAN-13', BarcodeFormat.ean13, '5901234123457'),
    ('EAN-13', BarcodeFormat.ean13, '4006381333931'),
    (
      'Contact',
      BarcodeFormat.qrCode,
      'MECARD:N:Doe,Jane;ORG:Lumen;TEL:+41441234567;EMAIL:jane@lumen.example;;',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Codes to scan')),
    backgroundColor: Colors.white,
    body: GridView.extent(
      maxCrossAxisExtent: 360,
      padding: const EdgeInsets.all(24),
      mainAxisSpacing: 24,
      crossAxisSpacing: 24,
      children: <Widget>[
        for (final (String label, BarcodeFormat format, String text) in _codes)
          _Code(label, format, text),
        _Code('Boarding pass', BarcodeFormat.pdf417, _boardingPass),
      ],
    ),
  );
}

class _Code extends StatelessWidget {
  const _Code(this.label, this.format, this.text);

  final String label;
  final BarcodeFormat format;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Expanded(
        child: Center(
          child: BarcodeView(
            text,
            format: format,
            showText: format == BarcodeFormat.ean13,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.black)),
    ],
  );
}
