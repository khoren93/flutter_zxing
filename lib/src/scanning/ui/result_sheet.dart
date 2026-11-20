import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../content/barcode_content.dart';
import '../../content/link_service.dart';
import 'barcode_label.dart';
import 'glass.dart';
import 'pressable.dart';
import 'scanner_icons.dart';
import 'scanner_strings.dart';
import 'scanner_theme.dart';
import 'thumbnail.dart';

/// A button of a [BarcodeResultSheet].
@immutable
final class ScannerAction {
  /// Creates an action.
  const ScannerAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  }) : _copyText = null;

  /// Copies [text] to the clipboard; the button confirms with "Copied".
  /// [label] replaces [ScannerStrings.copy], such as "Copy IBAN"; an empty
  /// string shows the icon alone.
  const ScannerAction.copy(String text, {this.primary = false, this.label})
    : icon = ScannerIcons.copy,
      onPressed = null,
      _copyText = text;

  /// The text; an empty string shows the [icon] alone. `null` only for
  /// [ScannerAction.copy], which then says [ScannerStrings.copy].
  final String? label;

  /// An icon before the text.
  final ScannerIconData? icon;

  /// Called on tap.
  final VoidCallback? onPressed;

  /// Filled with the accent; a sheet has at most one.
  final bool primary;

  final String? _copyText;
}

/// What a [BarcodeResultSheet] shows next to its title.
enum ResultHeader {
  /// The picture of the code ([BarcodeThumbnail]). The default.
  picture,

  /// An icon of the content's kind, such as a Wi‑Fi sign.
  icon,

  /// The text as the number of a card, such as a loyalty card: large, in
  /// groups of four, under a card badge (`ScannerTemplate.loyalty`). A code
  /// with a secret (an OTP key) shows its picture instead.
  card,

  /// Nothing: the title alone.
  none,
}

/// The result sheet of a scanned code: its kind ("LINK"), a title, details,
/// the raw text, the symbology and buttons.
///
/// ```dart
/// BarcodeResultSheet(
///   barcode,
///   actions: [
///     ScannerAction(label: 'Open', icon: ScannerIcons.open, primary: true, onPressed: open),
///     ScannerAction.copy(barcode.text),
///   ],
/// )
/// ```
///
/// Without [actions] it shows a copy button and, with [onScanAgain],
/// "Scan again". With [actions] that do not scan again, [onScanAgain] puts
/// a close button in the corner, so the scanner is never a tap away from
/// the next code.
class BarcodeResultSheet extends StatelessWidget {
  /// Creates a sheet for [barcode].
  const BarcodeResultSheet(
    this.barcode, {
    super.key,
    this.actions,
    this.onScanAgain,
    this.onClose,
    this.header = ResultHeader.picture,
    this.cutOut,
  });

  /// The code.
  final Barcode barcode;

  /// What shows next to the title: the picture of the code (the default),
  /// an icon of its kind, the text as a card number, or nothing.
  final ResultHeader header;

  /// The camera's cut-out of the code, for the picture of codes that
  /// cannot be drawn exactly. Not disposed by the sheet.
  final ui.Image? cutOut;

  /// The buttons; `null` for copy and "Scan again".
  final List<ScannerAction>? actions;

  /// Hides the sheet and scans again, for the default buttons.
  final VoidCallback? onScanAgain;

  /// Puts a close button in the corner that hides the sheet without
  /// scanning again, such as back to the other codes of
  /// `ScannerTemplate.pick`.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    final BarcodeContent content = barcode.content;
    // A code with a secret is never shown as a number.
    final bool card = header == ResultHeader.card && content is! OtpContent;
    final _Summary summary = _Summary.forHeader(barcode, header, strings);
    final String kind = summary.kind ?? strings.kindOf(content);
    final List<ScannerAction> actions =
        this.actions ?? summary.actions(barcode, strings, onScanAgain);
    final String symbology = _symbology(barcode);
    final VoidCallback? scanAgain = onScanAgain;
    final VoidCallback? close =
        onClose ??
        (scanAgain != null &&
                !actions.any((ScannerAction a) => a.onPressed == scanAgain)
            ? scanAgain
            : null);

    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          <String>[kind, ?summary.kindDetail].join(' · ').toUpperCase(),
          style: theme.overlineStyle,
        ),
        const SizedBox(height: 4),
        Text(
          summary.title,
          style: theme.titleStyle,
          maxLines: summary.titleLines,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return ScannerSheet(
      label: '$kind: ${summary.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (header == ResultHeader.icon || card) ...<Widget>[
                ScannerBadge(icon: card ? ScannerIcons.card : iconOf(content)),
                const SizedBox(width: 16),
              ] else if (header != ResultHeader.none) ...<Widget>[
                BarcodeThumbnail(barcode, cutOut: cutOut, size: 72),
                const SizedBox(width: 16),
              ],
              Expanded(child: heading),
              if (close != null) ...<Widget>[
                const SizedBox(width: 8),
                _SheetClose(
                  label: onClose != null
                      ? strings.backToCodes
                      : strings.scanAgain,
                  onPressed: close,
                ),
              ],
            ],
          ),
          if (summary.display case final String display) ...<Widget>[
            const SizedBox(height: 16),
            Text(display, style: theme.displayStyle, maxLines: 1),
          ],
          if (summary.detail case final String detail) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              detail,
              style: theme.mutedStyle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (summary.payload case final String payload) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              payload,
              style: theme.dataStyle,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (summary.code case final String code) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              code,
              style: theme.dataStyle.copyWith(
                fontSize: summary.largeCode ? 28 : 20,
                height: summary.largeCode ? 36 / 28 : 28 / 20,
                fontWeight: FontWeight.w600,
                letterSpacing: summary.largeCode ? 1.7 : 0.8,
              ),
            ),
          ],
          if (summary.fields.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            ScannerFields(summary.fields, columns: summary.fieldColumns),
          ],
          if (summary.secret case final String secret) ...<Widget>[
            const SizedBox(height: 16),
            _SecretField(secret, strings: strings),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              ScannerChip(symbology),
              for (final String chip in summary.chips) ScannerChip(chip),
              if (summary.warning case final String warning)
                ScannerChip(warning, tone: ScannerTone.warning),
              if (summary.danger case final String danger)
                ScannerChip(danger, tone: ScannerTone.danger),
            ],
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            ScannerActions(actions),
          ],
        ],
      ),
    );
  }

  /// A neutral sign of [service]'s kind: a chat bubble for messengers, a
  /// profile for social networks and so on. Never a brand's logo.
  static ScannerIconData serviceIconOf(LinkService service) =>
      switch (service) {
        LinkService.whatsApp ||
        LinkService.telegram ||
        LinkService.signal ||
        LinkService.discord => ScannerIcons.messenger,
        LinkService.youTube || LinkService.twitch => ScannerIcons.video,
        LinkService.spotify ||
        LinkService.appleMusic ||
        LinkService.soundCloud => ScannerIcons.music,
        LinkService.appStore || LinkService.googlePlay => ScannerIcons.apps,
        LinkService.googleMaps ||
        LinkService.appleMaps ||
        LinkService.yandexMaps => ScannerIcons.location,
        LinkService.googleReview => ScannerIcons.review,
        _ => ScannerIcons.profile,
      };

  /// The icon of [content]'s kind.
  static ScannerIconData iconOf(BarcodeContent content) => switch (content) {
    UrlContent(:final LinkService service) => serviceIconOf(service),
    UrlContent() => ScannerIcons.link,
    WifiContent() => ScannerIcons.wifi,
    ContactContent() => ScannerIcons.contact,
    EventContent() => ScannerIcons.event,
    EmailContent() => ScannerIcons.email,
    PhoneContent(type: CallType.voice) => ScannerIcons.phone,
    PhoneContent() => ScannerIcons.faceTime,
    SmsContent() => ScannerIcons.sms,
    GeoContent() => ScannerIcons.location,
    PaymentContent() => ScannerIcons.payment,
    OtpContent() => ScannerIcons.otp,
    EsimContent() => ScannerIcons.esim,
    CryptoContent() => ScannerIcons.crypto,
    WifiDppContent() => ScannerIcons.wifiDevice,
    SmartHomeContent() => ScannerIcons.smartHome,
    BoardingPassContent() => ScannerIcons.boardingPass,
    DriverLicenseContent() => ScannerIcons.driverLicense,
    VinContent() => ScannerIcons.vehicle,
    ProductContent(isbn13: null, issn: null) => ScannerIcons.barcode,
    ProductContent() => ScannerIcons.book,
    Gs1Content() => ScannerIcons.parcel,
    BinaryContent() => ScannerIcons.binary,
    // TextContent, and kinds added in later versions.
    _ => ScannerIcons.text,
  };
}

/// Title, details and payload of a result.
final class _Summary {
  const _Summary(
    this.title, {
    this.detail,
    this.payload,
    this.titleLines = 2,
    this.kindDetail,
    this.display,
    this.code,
    this.largeCode = true,
    this.fields = const <String, String>{},
    this.fieldColumns = 3,
    this.secret,
    this.chips = const <String>[],
    this.warning,
    this.danger,
    this.copy,
    this.copyLabel,
    this.kind,
  });

  /// The summary of [barcode] for a sheet with [header].
  factory _Summary.forHeader(
    Barcode barcode,
    ResultHeader header,
    ScannerStrings strings,
  ) => header == ResultHeader.card && barcode.content is! OtpContent
      ? _Summary.card(barcode.text, strings)
      : _Summary.of(barcode, barcode.content, strings);

  /// A card number: [text] large, in groups of four when it has no spaces.
  factory _Summary.card(String text, ScannerStrings strings) {
    final String trimmed = text.trim();
    final String code = trimmed.contains(' ')
        ? trimmed
        : <String>[
            for (int i = 0; i < trimmed.length; i += 4)
              trimmed.substring(i, (i + 4).clamp(0, trimmed.length)),
          ].join(' ');
    return _Summary(
      strings.cardNumber,
      kind: strings.loyaltyCard,
      code: code,
      largeCode: trimmed.length <= 12,
      copy: trimmed,
    );
  }

  factory _Summary.of(
    Barcode barcode,
    BarcodeContent content,
    ScannerStrings strings,
  ) {
    final String text = barcode.text;
    String? raw(String shown) => text.trim() == shown.trim() ? null : text;
    switch (content) {
      case UrlContent(:final Uri url, :final LinkService service):
        final String host = url.host.replaceFirst(RegExp(r'^www\.'), '');
        final String? message = service == LinkService.whatsApp
            ? url.queryParameters['text']
            : null;
        // The address without its query only where the sheet shows all of
        // it: a link that leads on elsewhere shows where.
        final bool shown =
            !url.hasFragment &&
            url.queryParameters.keys.every(
              (String key) =>
                  service == LinkService.whatsApp &&
                  (key == 'text' || key == 'phone'),
            );
        return _Summary(
          _serviceTarget(url, service) ?? host,
          detail: message,
          payload: shown ? '$host${url.path}' : url.toString(),
        );
      case UrlContent(:final Uri url, :final String? title):
        final String host = url.host.isEmpty ? url.toString() : url.host;
        return _Summary(
          title ?? (host.startsWith('www.') ? host.substring(4) : host),
          payload: url.toString(),
        );
      case WifiContent(
        :final String ssid,
        :final String? password,
        :final WifiSecurity security,
      ):
        // An unknown kind of security is left out, not named.
        final String? secured = switch (security) {
          WifiSecurity.none || WifiSecurity.unknown => null,
          WifiSecurity.wep => 'WEP',
          WifiSecurity.wpa => 'WPA',
          WifiSecurity.wpa3 => 'WPA3',
          WifiSecurity.enterprise => strings.wifiEnterprise,
        };
        final String detail = security == WifiSecurity.none
            ? strings.wifiOpen
            : <String>[
                ?secured,
                if (password != null) strings.wifiPassword,
              ].join(' · ');
        return _Summary(
          ssid,
          detail: detail.isEmpty ? null : detail,
          payload: text,
        );
      case ContactContent(
        :final String? name,
        :final String? organization,
        :final List<String> phones,
        :final List<String> emails,
      ):
        final String title =
            name ??
            organization ??
            (phones.isNotEmpty ? phones.first : null) ??
            (emails.isNotEmpty ? emails.first : null) ??
            strings.contact;
        final String detail = <String>[
          if (name != null && organization != null) organization,
          ...phones.take(2),
          ...emails.take(1),
        ].where((String s) => s != title).join(' · ');
        return _Summary(title, detail: detail.isEmpty ? null : detail);
      case EventContent(
        :final String summary,
        :final DateTime start,
        :final DateTime? end,
        :final String? location,
      ):
        final String when = end == null
            ? _dateTime(start, strings)
            : '${_dateTime(start, strings)} – '
                  '${_sameDay(start, end) ? _time(end) : _dateTime(end, strings)}';
        return _Summary(
          summary,
          detail: location == null ? when : '$when · $location',
        );
      case EmailContent(:final String address, :final String? subject):
        return _Summary(address, detail: subject);
      case PhoneContent(:final String number):
        return _Summary(number, payload: raw(number));
      case SmsContent(:final String number, :final String? message):
        return _Summary(number, detail: message);
      case GeoContent(
        :final double latitude,
        :final double longitude,
        :final String? query,
      ):
        return _Summary(
          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
          detail: query,
          payload: text,
        );
      case final PaymentContent payment:
        return _paymentSummary(payment, strings);
      case final OtpContent otp:
        // Never the secret in the title or the payload: the code holds it.
        return _Summary(
          otp.issuer ?? otp.account,
          detail: otp.issuer == null ? null : otp.account,
          fields: <String, String>{
            strings.otpType: otp.type == OtpType.totp
                ? strings.otpTimeBased
                : strings.otpCounterBased,
            strings.otpDigits: '${otp.digits}',
            if (otp.type == OtpType.totp)
              strings.otpPeriod: strings.seconds(otp.period)
            else
              strings.otpCounter: '${otp.counter}',
          },
          secret: otp.secret,
        );
      case final EsimContent esim:
        return _Summary(
          esim.smdpAddress,
          fields: <String, String>{
            if (esim.matchingId case final String id) strings.matchingId: id,
            if (esim.confirmationCodeRequired)
              strings.confirmationCode: strings.needed,
          },
          fieldColumns: 2,
        );
      case final CryptoContent crypto:
        final String? amount = crypto.amount;
        final String currency = _currencyName(crypto.currency);
        return _Summary(
          crypto.label ?? currency,
          kindDetail: currency,
          display: amount == null ? null : '$amount ${crypto.currency.symbol}',
          detail: crypto.message,
          payload: crypto.address,
        );
      case final WifiDppContent dpp:
        return _Summary(
          dpp.information ?? dpp.macAddress ?? strings.wifiDevice,
          fields: <String, String>{
            if (dpp.macAddress case final String mac)
              strings.macAddress: _mac(mac),
            if (dpp.channels case final String channels)
              strings.channels: channels,
          },
          fieldColumns: 2,
        );
      case final SmartHomeContent home:
        final bool matter = home.platform == SmartHomePlatform.matter;
        return _Summary(
          strings.setupCode,
          kindDetail: matter ? 'Matter' : 'HomeKit',
          code: matter && home.setupCode.length == 8
              ? '${home.setupCode.substring(0, 4)}-${home.setupCode.substring(4)}'
              : home.setupCode,
          fields: <String, String>{
            if (home.vendorId case final int id) strings.vendorId: _hexId(id),
            if (home.productId case final int id) strings.productId: _hexId(id),
            if (home.discriminator case final int d)
              strings.discriminator: '$d',
            if (home.category case final int c) strings.category: '$c',
            if (home.setupId case final String id) strings.setupId: id,
          },
        );
      case final BoardingPassContent pass:
        final BoardingPassLeg leg = pass.legs.first;
        final DateTime? day = leg.dateIn(DateTime.now().year);
        return _Summary(
          '${leg.from} → ${leg.to}',
          kindDetail: '${leg.carrier} ${leg.flightNumber}',
          fields: <String, String>{
            strings.passenger: pass.passengerName,
            if (day != null) strings.date: strings.dayAndMonth(day),
            if (leg.seat.isNotEmpty) strings.seat: leg.seat,
            if (leg.cabin.isNotEmpty) strings.cabin: leg.cabin,
            strings.booking: leg.bookingReference,
            if (leg.sequenceNumber.isNotEmpty)
              strings.sequence: leg.sequenceNumber,
          },
          chips: <String>[
            if (pass.legs.length > 1) strings.flightOf(1, pass.legs.length),
          ],
        );
      case final DriverLicenseContent id:
        final DateTime? expiry = id.expiryDate;
        return _Summary(
          <String>[?id.firstName, ?id.middleName, ?id.lastName].join(' '),
          kindDetail: id.state,
          fields: <String, String>{
            if (id.licenseNumber case final String n) strings.licenseNumber: n,
            if (id.birthDate case final DateTime d)
              strings.born: strings.fullDate(d),
            if (expiry != null) strings.expires: strings.fullDate(expiry),
            if (id.city case final String c) strings.city: c,
            if (id.state case final String s) strings.state: s,
            if (id.country case final String c) strings.country: c,
          },
          warning: expiry != null && expiry.isBefore(DateTime.now())
              ? strings.expired
              : null,
        );
      case final VinContent vin:
        final bool checked = vin.hasValidCheckDigit;
        return _Summary(
          strings.vinRegion(vin.region),
          kindDetail: 'VIN',
          code: vin.vin,
          largeCode: false,
          fields: <String, String>{
            strings.makerCode: vin.wmi,
            if (checked && vin.modelYear != null)
              strings.modelYear: '${vin.modelYear}',
            if (checked) strings.checkDigit: strings.valid,
          },
        );
      case final ProductContent product:
        final String? isbn = product.isbn13;
        final String? issn = product.issn;
        return _Summary(
          isbn != null
              ? 'ISBN $isbn'
              : issn != null
              ? 'ISSN $issn'
              : product.number,
          fields: <String, String>{
            if (product.isbn10 case final String isbn10) 'ISBN-10': isbn10,
            if (isbn != null || issn != null) strings.gtin: product.gtin,
            if (product.addOn case final String addOn) strings.addOn: addOn,
          },
          fieldColumns: 2,
          chips: <String>[
            if (isbn != null) 'ISBN' else if (issn != null) 'ISSN',
          ],
        );
      case final Gs1Content gs1:
        return gs1.elements.isEmpty
            ? _Summary(text)
            : _gs1Summary(gs1, strings);
      case BinaryContent(:final Uint8List bytes):
        return _Summary(strings.byteCount(bytes.length), payload: _hex(bytes));
      case TextContent(:final String text):
        // One line is the title alone; more lines put the first in the
        // title and the rest below it, so nothing shows twice.
        final List<String> lines = text.trim().split('\n');
        final String first = lines.first.trim();
        final String rest = lines.skip(1).join('\n').trim();
        if (first.isEmpty || rest.isEmpty) {
          return _Summary(
            text.trim().isEmpty ? ' ' : text.trim(),
            titleLines: 3,
          );
        }
        return _Summary(first, payload: rest);
    }
    // A kind added in a later version.
    return _Summary(text);
  }

  /// The default buttons: a copy of what matters (the IBAN of a payment,
  /// with "Copy IBAN"), unless the code holds a secret, and "Scan again".
  List<ScannerAction> actions(
    Barcode barcode,
    ScannerStrings strings,
    VoidCallback? onScanAgain,
  ) => <ScannerAction>[
    // A code with a secret (an OTP key) is not copied unasked.
    if (secret == null)
      ScannerAction.copy(
        copy ?? barcode.text,
        label: copyLabel,
        primary: onScanAgain == null,
      ),
    if (onScanAgain != null)
      ScannerAction(
        label: strings.scanAgain,
        onPressed: onScanAgain,
        primary: true,
      ),
  ];

  final String title;
  final String? detail;
  final String? payload;

  /// After the kind above the title: "BOARDING PASS · LX 423".
  final String? kindDetail;

  /// A large number below the title, such as an amount.
  final String? display;

  /// A code a person types, in large monospace: a setup code, a VIN.
  final String? code;
  final bool largeCode;

  /// Labelled values in a grid.
  final Map<String, String> fields;
  final int fieldColumns;

  /// A value shown only on request, and never copied by default: an OTP
  /// secret.
  final String? secret;

  /// More chips after the symbology ("ISBN", "Flight 1 of 2").
  final List<String> chips;

  /// A chip in the signal color.
  final String? warning;

  /// A chip in the danger color ("Expired").
  final String? danger;

  /// The kind above the title instead of [ScannerStrings.kindOf].
  final String? kind;

  /// What the default copy button copies instead of the whole text, and
  /// its label: a payment's account, "Copy IBAN".
  final String? copy;
  final String? copyLabel;

  /// How many lines the title may take before an ellipsis.
  final int titleLines;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String _dateTime(DateTime t, ScannerStrings strings) {
    final String date = strings.fullDate(t);
    return t.hour == 0 && t.minute == 0 ? date : '$date ${_time(t)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// GS1 data: the GTIN or SSCC as the title, the dates, batch, serial and
  /// quantity by name, and every other element by its identifier.
  static _Summary _gs1Summary(Gs1Content gs1, ScannerStrings strings) {
    final Map<String, String> elements = gs1.elements;
    final Set<String> named = <String>{};
    String? take(String ai) {
      final String? value = elements[ai];
      if (value != null) {
        named.add(ai);
      }
      return value;
    }

    String? kindDetail;
    // AI 02: the trade items a logistic unit contains.
    String? title = take('01') ?? take('02');
    if (title != null) {
      kindDetail = strings.gtin;
    } else if (take('00') case final String sscc) {
      title = sscc;
      kindDetail = strings.sscc;
    }
    final DateTime? expiry = gs1.expiryDate;
    final DateTime? bestBefore = gs1.bestBeforeDate;
    final Map<String, String> fields = <String, String>{
      if (expiry != null) strings.expires: strings.fullDate(expiry),
      if (bestBefore != null) strings.bestBefore: strings.fullDate(bestBefore),
      if (take('10') case final String batch) strings.batch: batch,
      if (take('21') case final String serial) strings.serial: serial,
      if (gs1.count case final int count) strings.quantity: '$count',
      if (title != elements['00'])
        if (take('00') case final String sscc) strings.sscc: sscc,
    };
    if (expiry != null) {
      named.add('17');
    }
    if (bestBefore != null) {
      named.add('15');
    }
    if (gs1.count != null) {
      named.add('37');
    }
    for (final MapEntry<String, String> e in elements.entries) {
      if (!named.contains(e.key)) {
        fields['(${e.key})'] = e.value;
      }
    }
    if (title == null) {
      final MapEntry<String, String> first = elements.entries.first;
      title = first.value;
      fields.remove('(${first.key})');
      kindDetail = '(${first.key})';
    }
    return _Summary(
      title,
      kindDetail: kindDetail,
      fields: fields,
      fieldColumns: 2,
      danger: gs1.isExpired() ? strings.expired : null,
    );
  }

  /// A payment as the approved design shows it: the payee, the amount
  /// large, what it is for, the account and the standard's own fields.
  static _Summary _paymentSummary(
    PaymentContent payment,
    ScannerStrings strings,
  ) {
    final String? amount = payment.amount;
    String? detail;
    Map<String, String> fields = <String, String>{};
    List<String> chips = <String>[];
    String? copyLabel;
    String? copy = payment.account?.replaceAll(' ', '');
    switch (payment) {
      case final EpcPaymentContent epc:
        detail = epc.message ?? epc.information;
        fields = <String, String>{
          strings.iban: _grouped(epc.iban),
          if (epc.bic case final String bic) strings.bic: bic,
          if (epc.creditorReference case final String r)
            strings.paymentReference: _grouped(r),
        };
        chips = <String>['EPC'];
        copyLabel = strings.copyIban;
      case final SwissQrBillContent bill:
        final SwissAddress c = bill.creditor;
        detail = bill.message;
        fields = <String, String>{
          strings.accountNumber: _grouped(bill.iban),
          if (bill.creditorReference case final String r)
            strings.paymentReference:
                bill.referenceType == SwissReferenceType.qrr
                ? _qrReference(r)
                : _grouped(r),
          strings.address: <String>[
            <String>[?c.street, ?c.buildingNumber].join(' '),
            '${c.postalCode} ${c.town}',
          ].where((String s) => s.trim().isNotEmpty).join(', '),
          if (bill.debtor case final SwissAddress d) strings.payableBy: d.name,
        };
        chips = <String>['Swiss QR-bill'];
        copyLabel = strings.copyIban;
      case final GostPaymentContent gost:
        detail = gost.purpose;
        fields = <String, String>{
          strings.accountNumber: gost.personalAccount,
          strings.bic: gost.bic,
          strings.bank: gost.bankName,
          if (gost.payeeInn case final String inn) strings.inn: inn,
          if (gost.kpp case final String kpp) strings.kpp: kpp,
        };
        chips = <String>['ГОСТ Р 56042'];
        copyLabel = strings.copyAccount;
      case final UpiPaymentContent upi:
        detail = upi.note;
        fields = <String, String>{strings.upiId: upi.address};
        chips = <String>['UPI'];
        copyLabel = strings.copyUpiId;
      case final EmvPaymentContent emv:
        detail = emv.merchantCity;
        fields = <String, String>{
          if (emv.pixKey case final String key) strings.pixKey: key,
          if (emv.reference case final String r) strings.transaction: r,
          if (emv.pixKey == null && emv.merchantCity != null)
            strings.city: emv.merchantCity!,
          if (emv.pixKey == null && emv.merchantCategoryCode != null)
            strings.category: emv.merchantCategoryCode!,
        };
        if (emv.pixKey == null) {
          detail = null;
        }
        chips = <String>[
          'EMVCo',
          if (!emv.isDynamic && amount == null) strings.reusable,
        ];
        copyLabel = emv.pixKey == null ? null : strings.copyPixKey;
        copy = emv.pixKey;
      case final SpaydPaymentContent spayd:
        detail = spayd.message;
        fields = <String, String>{
          strings.iban: _grouped(spayd.iban),
          if (spayd.variableSymbol case final String vs)
            strings.variableSymbol: vs,
        };
        chips = <String>['SPAYD'];
        copyLabel = strings.copyIban;
    }
    return _Summary(
      payment.payee ?? strings.payment,
      kindDetail: _paymentStandard(payment),
      display: amount == null ? null : strings.money(amount, payment.currency),
      detail: amount == null
          ? <String>[strings.payerEntersAmount, ?detail].join('\n')
          : detail,
      fields: fields,
      fieldColumns: 2,
      chips: chips,
      copy: copy,
      copyLabel: copy == null ? null : copyLabel,
    );
  }

  /// An IBAN or RF reference in groups of four, as printed.
  static String _grouped(String value) {
    final String v = value.replaceAll(' ', '');
    return <String>[
      for (int i = 0; i < v.length; i += 4)
        v.substring(i, math.min(i + 4, v.length)),
    ].join(' ');
  }

  /// A Swiss QR reference as on the bill: 2 digits, then groups of five.
  static String _qrReference(String value) {
    final String v = value.replaceAll(' ', '');
    if (v.length != 27) {
      return v;
    }
    return <String>[
      v.substring(0, 2),
      for (int i = 2; i < 27; i += 5) v.substring(i, i + 5),
    ].join(' ');
  }

  static String? _paymentStandard(PaymentContent payment) => switch (payment) {
    EpcPaymentContent() => 'SEPA',
    SwissQrBillContent() => 'QR-bill',
    GostPaymentContent() => 'ГОСТ',
    UpiPaymentContent() => 'UPI',
    SpaydPaymentContent() => 'SPAYD',
    EmvPaymentContent(:final EmvScheme scheme) => switch (scheme) {
      EmvScheme.pix => 'PIX',
      EmvScheme.payNow => 'PayNow',
      EmvScheme.promptPay => 'PromptPay',
      EmvScheme.qris => 'QRIS',
      EmvScheme.vietQr => 'VietQR',
      EmvScheme.duitNow => 'DuitNow',
      EmvScheme.unknown => 'EMV',
    },
    _ => null,
  };

  static String _currencyName(CryptoCurrency currency) => switch (currency) {
    CryptoCurrency.bitcoin => 'Bitcoin',
    CryptoCurrency.ethereum => 'Ethereum',
    CryptoCurrency.litecoin => 'Litecoin',
    CryptoCurrency.lightning => 'Lightning',
  };

  /// `0xFFF1`.
  static String _hexId(int id) => '0x${id.toRadixString(16).toUpperCase()}';

  /// `5254005828e5` → `52:54:00:58:28:e5`.
  static String _mac(String mac) => RegExp(r'^[0-9a-fA-F]{12}$').hasMatch(mac)
      ? <String>[
          for (int i = 0; i < 12; i += 2) mac.substring(i, i + 2),
        ].join(':')
      : mac;

  /// Who or what a link to a service leads to: `wa.me/37491234567` becomes
  /// `+37491234567`, an Instagram profile `@name`, a map its search.
  /// `null` for any other link of the service, such as a video, a post or
  /// an invite: the sheet names its host.
  static String? _serviceTarget(Uri url, LinkService service) {
    final List<String> path = url.pathSegments
        .where((String p) => p.isNotEmpty)
        .toList();
    final String host = url.host.toLowerCase().replaceFirst(
      RegExp(r'^(www|m|mobile)\.'),
      '',
    );
    String? at(int i) => i < path.length ? path[i] : null;
    // A profile's name: the first part of the path, unless it is one of
    // the service's own pages.
    String? profile(RegExp name, Set<String> pages) {
      final String? first = at(0);
      return first != null &&
              name.hasMatch(first) &&
              !pages.contains(first.toLowerCase())
          ? '@$first'
          : null;
    }

    // A handle the path starts with: `youtube.com/@name`.
    String? atName() {
      final String? first = at(0);
      return first != null && RegExp(r'^@[\w.\-]+$').hasMatch(first)
          ? first
          : null;
    }

    String? phone(String? digits) =>
        digits != null && RegExp(r'^\+?\d{4,15}$').hasMatch(digits)
        ? '+${digits.replaceFirst('+', '')}'
        : null;
    final RegExp word = RegExp(r'^[\w.\-]+$');
    return switch (service) {
      LinkService.whatsApp =>
        host == 'wa.me'
            ? phone(at(0))
            : at(0) == 'send'
            ? phone(url.queryParameters['phone'])
            : null,
      LinkService.signal =>
        url.fragment.startsWith('p/') ? url.fragment.substring(2) : null,
      LinkService.telegram =>
        profile(RegExp(r'^[A-Za-z]\w{3,31}$'), const <String>{
          'joinchat',
          'addstickers',
          'addemoji',
          'addlist',
          'addtheme',
          'share',
          'proxy',
          'socks',
          'login',
          'setlanguage',
          'boost',
          'contact',
          'confirmphone',
          'iv',
        }),
      LinkService.instagram => profile(word, const <String>{
        'p',
        'reel',
        'reels',
        'tv',
        'stories',
        'explore',
        'accounts',
        'direct',
        'about',
        'legal',
        'developer',
      }),
      LinkService.facebook =>
        host == 'facebook.com' || host == 'fb.com'
            ? profile(RegExp(r'^(?!.*\.php$)[A-Za-z0-9.]+$'), const <String>{
                'watch',
                'groups',
                'events',
                'pages',
                'share',
                'sharer',
                'reel',
                'photo',
                'photos',
                'videos',
                'stories',
                'story',
                'marketplace',
                'gaming',
                'hashtag',
                'login',
                'help',
                'p',
              })
            : null,
      LinkService.x => profile(RegExp(r'^\w{1,15}$'), const <String>{
        'i',
        'home',
        'search',
        'explore',
        'intent',
        'share',
        'hashtag',
        'settings',
        'messages',
        'notifications',
        'compose',
        'login',
      }),
      LinkService.linkedIn =>
        const <String>{'in', 'company', 'school', 'showcase'}.contains(at(0)) &&
                at(1) != null
            ? '@${at(1)}'
            : null,
      LinkService.snapchat =>
        at(0) == 'add' && at(1) != null ? '@${at(1)}' : null,
      LinkService.tikTok ||
      LinkService.youTube ||
      LinkService.threads => atName(),
      LinkService.pinterest =>
        host == 'pinterest.com'
            ? profile(word, const <String>{'pin', 'search', 'ideas', 'today'})
            : null,
      LinkService.twitch => profile(RegExp(r'^\w{3,25}$'), const <String>{
        'videos',
        'directory',
        'settings',
        'search',
        'downloads',
        'p',
      }),
      LinkService.soundCloud => profile(word, const <String>{
        'discover',
        'search',
        'you',
        'stream',
        'upload',
        'pages',
      }),
      LinkService.reddit =>
        host == 'redd.it' || at(1) == null
            ? null
            : at(0) == 'r'
            ? 'r/${at(1)}'
            : at(0) == 'u' || at(0) == 'user'
            ? 'u/${at(1)}'
            : null,
      LinkService.discord =>
        host == 'discord.gg'
            ? at(0)
            : at(0) == 'invite'
            ? at(1)
            : null,
      LinkService.googleMaps ||
      LinkService.appleMaps ||
      LinkService.yandexMaps =>
        url.queryParameters['query'] ??
            url.queryParameters['q'] ??
            url.queryParameters['text'],
      _ => null,
    };
  }

  static String _hex(Uint8List bytes) {
    final Iterable<String> shown = bytes
        .take(24)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'));
    return '${shown.join(' ')}${bytes.length > 24 ? ' …' : ''}';
  }
}

/// The buttons a [BarcodeResultSheet] with [header] shows for [barcode]
/// without its own: a copy of what matters, such as "Copy IBAN" for a
/// payment (none for a code with a secret), and "Scan again" with
/// [onScanAgain].
List<ScannerAction> defaultResultActions(
  Barcode barcode,
  ScannerStrings strings, {
  VoidCallback? onScanAgain,
  ResultHeader header = ResultHeader.picture,
}) => _Summary.forHeader(
  barcode,
  header,
  strings,
).actions(barcode, strings, onScanAgain);

/// A secret behind dots, shown on request: an OTP key.
class _SecretField extends StatefulWidget {
  const _SecretField(this.secret, {required this.strings});

  final String secret;
  final ScannerStrings strings;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = widget.strings;
    // Groups of four, as authenticator apps print keys.
    final String grouped = <String>[
      for (int i = 0; i < widget.secret.length; i += 4)
        widget.secret.substring(i, math.min(i + 4, widget.secret.length)),
    ].join(' ');
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.lineColor),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    strings.secret.toUpperCase(),
                    style: theme.overlineStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _shown ? grouped : '•••• •••• •••• ••••',
                    style: theme.dataStyle.copyWith(
                      color: _shown ? theme.inkColor : theme.inkMutedColor,
                      letterSpacing: _shown ? 0.6 : 2.7,
                    ),
                    // The dots on one line, whatever the font's width.
                    maxLines: _shown ? null : 1,
                    softWrap: _shown,
                    overflow: _shown ? null : TextOverflow.clip,
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              child: Pressable(
                onPressed: () => setState(() => _shown = !_shown),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ScannerIcon(
                          _shown ? ScannerIcons.hide : ScannerIcons.show,
                          size: 20,
                          color: theme.lockInkColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _shown ? strings.hide : strings.show,
                          style: theme.hintStyle.copyWith(
                            color: theme.lockInkColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round close button in the corner of a sheet.
class _SheetClose extends StatelessWidget {
  const _SheetClose({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    const ShapeBorder shape = CircleBorder();
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        shape: shape,
        // A 48 × 48 target around the 40 × 40 button.
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: theme.inkColor.withValues(alpha: 0.08),
                shape: shape,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Center(
                  child: ScannerIcon(
                    ScannerIcons.close,
                    size: 20,
                    color: theme.inkMutedColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded square with an icon in the accent, as next to a Wi‑Fi
/// network's name.
class ScannerBadge extends StatelessWidget {
  /// Creates a badge.
  const ScannerBadge({
    super.key,
    required this.icon,
    this.size = 52,
    this.tone = ScannerTone.accent,
  });

  /// The icon.
  final ScannerIconData icon;

  /// Width and height.
  final double size;

  /// The color: the accent, or a warning or danger for problems.
  final ScannerTone tone;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final (Color fill, Color ink) = switch (tone) {
      ScannerTone.accent => (theme.lockSoftColor, theme.lockInkColor),
      ScannerTone.warning => (
        theme.signalColor.withValues(alpha: 0.2),
        theme.signalInkColor,
      ),
      ScannerTone.danger => (
        theme.dangerColor.withValues(alpha: 0.2),
        theme.dangerInkColor,
      ),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(size * 0.31)),
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: ScannerIcon(icon, size: size * 0.54, color: ink),
        ),
      ),
    );
  }
}

/// Labelled values in a grid, such as the fields of a boarding pass.
class ScannerFields extends StatelessWidget {
  /// Creates the grid; keys are labels, values are shown below them.
  const ScannerFields(this.fields, {super.key, this.columns = 3});

  /// Label → value.
  final Map<String, String> fields;

  /// Values per row.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 16;
        final int columns = math.max(
          1,
          math.min(this.columns, (constraints.maxWidth / 90).floor()),
        );
        final double width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 12,
          children: <Widget>[
            for (final MapEntry<String, String> field in fields.entries)
              SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(field.key.toUpperCase(), style: theme.overlineStyle),
                    const SizedBox(height: 2),
                    Text(
                      field.value,
                      style: theme.labelStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The buttons of a sheet: side by side when they fit, else stacked.
class ScannerActions extends StatelessWidget {
  /// Creates the row.
  const ScannerActions(this.actions, {super.key});

  /// The buttons, primary first.
  final List<ScannerAction> actions;

  Widget _button(ScannerAction action) => action._copyText == null
      ? ScannerActionButton(
          label: action.label ?? '',
          icon: action.icon,
          primary: action.primary,
          onPressed: action.onPressed,
        )
      : _CopyButton(
          text: action._copyText,
          label: action.label,
          primary: action.primary,
        );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final bool row =
          actions.length <= 2 &&
          constraints.maxWidth / actions.length >= 130 &&
          MediaQuery.textScalerOf(context).scale(16) <= 24;
      if (row) {
        return Row(
          children: <Widget>[
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _button(actions[i])),
            ],
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            _button(actions[i]),
          ],
        ],
      );
    },
  );
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({
    required this.text,
    required this.label,
    required this.primary,
  });

  final String text;
  final String? label;
  final bool primary;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  Timer? _reset;
  bool _copied = false;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScannerStrings strings = ScannerStrings.of(context);
    final String label = widget.label ?? strings.copy;
    return ScannerActionButton(
      label: _copied ? (label.isEmpty ? '' : strings.copied) : label,
      semanticLabel: _copied
          ? strings.copied
          : label.isEmpty
          ? strings.copy
          : null,
      icon: _copied ? ScannerIcons.check : ScannerIcons.copy,
      primary: widget.primary,
      onPressed: () => unawaited(_copy()),
    );
  }
}

/// A code in a [BarcodeListSheet] and how often it was scanned.
@immutable
final class CollectedBarcode {
  /// Creates an entry.
  const CollectedBarcode(this.barcode, this.count, {this.cutOut});

  /// The code, as last scanned.
  final Barcode barcode;

  /// How often it was scanned.
  final int count;

  /// The camera's cut-out of the code, for the codes that cannot be drawn
  /// exactly ([BarcodeThumbnail.needsCutOut]); owned by the scanner, valid
  /// while it is shown: `clone()` it to keep it.
  final ui.Image? cutOut;
}

/// A sheet listing scanned codes with counts, the latest first and
/// highlighted, and a "Done" button.
class BarcodeListSheet extends StatelessWidget {
  /// Creates the sheet.
  const BarcodeListSheet({
    super.key,
    required this.items,
    this.onDone,
    this.visibleRows = 3,
  });

  /// The codes, the latest first.
  final List<CollectedBarcode> items;

  /// Called by "Done"; `null` hides the button.
  final VoidCallback? onDone;

  /// Rows shown before the list scrolls.
  final int visibleRows;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    final int total = items.fold(
      0,
      (int sum, CollectedBarcode item) => sum + item.count,
    );
    return ScannerSheet(
      padding: const EdgeInsets.all(16),
      label: '${strings.scanned}: ${strings.itemCount(total)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        strings.scanned.toUpperCase(),
                        style: theme.overlineStyle,
                      ),
                      const SizedBox(height: 2),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          strings.itemCount(total),
                          style: theme.titleStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDone != null)
                  ScannerActionButton(
                    label: strings.done,
                    primary: true,
                    compact: true,
                    onPressed: onDone,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(strings.emptyList, style: theme.mutedStyle),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: visibleRows * 72.0),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) =>
                    _Row(items[index], latest: index == 0),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.item, {required this.latest});

  final CollectedBarcode item;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final Barcode barcode = item.barcode;
    String title = barcodeLabel(barcode);
    String detail = _symbology(barcode);
    // GS1 labels of logistics: the container or trade item number, with
    // what the label says about it.
    if (barcode.content case final Gs1Content gs1
        when gs1.sscc != null ||
            gs1.gtin != null ||
            gs1.elements['02'] != null) {
      final ScannerStrings strings = ScannerStrings.of(context);
      final String? sscc = gs1.sscc;
      title = sscc ?? gs1.gtin ?? gs1.elements['02']!;
      detail = <String>[
        if (sscc != null) strings.sscc else strings.gtin,
        if (gs1.count case final int count) '${strings.quantity} $count',
        if (gs1.batch case final String batch) '${strings.batch} $batch',
        if (gs1.expiryDate case final DateTime expiry)
          '${strings.expires} ${strings.fullDate(expiry)}',
        detail,
      ].join(' · ');
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: latest ? theme.lockSoftColor : const Color(0x00000000),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: <Widget>[
          BarcodeThumbnail(barcode, cutOut: item.cutOut, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: theme.dataStyle.copyWith(fontSize: 16, height: 1.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: theme.chipStyle.copyWith(color: theme.inkMutedColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: theme.lockSoftColor,
              shape: theme.pillBorder,
            ),
            child: Text(
              '${item.count}',
              style: theme.labelStyle.copyWith(
                color: theme.lockInkColor,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The format of [barcode] for a chip: "QR Code", or "QR Code · GS1" when
/// it holds GS1 data. The ISO/IEC 15424 identifier (`]Q1`) is for systems,
/// not people; it stays in [Barcode.symbologyIdentifier].
String _symbology(Barcode barcode) => switch (barcode.contentType) {
  BarcodeContentType.gs1 => '${barcode.format.displayName} · GS1',
  BarcodeContentType.iso15434 => '${barcode.format.displayName} · ISO 15434',
  _ => barcode.format.displayName,
};
