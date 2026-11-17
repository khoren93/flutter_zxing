import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../content/barcode_content.dart';
import '../../content/link_service.dart';
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
  /// [label] replaces [ScannerStrings.copy], such as "Copy IBAN".
  const ScannerAction.copy(String text, {this.primary = false, this.label = ''})
    : icon = ScannerIcons.copy,
      onPressed = null,
      _copyText = text;

  /// The text; for [ScannerAction.copy], empty uses [ScannerStrings.copy].
  final String label;

  /// An icon before the text.
  final ScannerIconData? icon;

  /// Called on tap.
  final VoidCallback? onPressed;

  /// Filled with the accent; a sheet has at most one.
  final bool primary;

  final String? _copyText;
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
    this.showIcon = false,
    this.showPicture = true,
    this.cutOut,
  });

  /// The code.
  final Barcode barcode;

  /// Shows the picture of the code next to the title ([BarcodeThumbnail]),
  /// unless [showIcon].
  final bool showPicture;

  /// The camera's cut-out of the code, for the picture of codes that
  /// cannot be drawn exactly. Not disposed by the sheet.
  final ui.Image? cutOut;

  /// The buttons; `null` for copy and "Scan again".
  final List<ScannerAction>? actions;

  /// Hides the sheet and scans again, for the default buttons.
  final VoidCallback? onScanAgain;

  /// Shows an icon of the content's kind next to the title.
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    final ScannerStrings strings = ScannerStrings.of(context);
    final BarcodeContent content = barcode.content;
    final _Summary summary = _Summary.of(barcode, content, strings);
    final List<ScannerAction> actions =
        this.actions ??
        <ScannerAction>[
          // A code with a secret (an OTP key) is not copied unasked.
          if (summary.secret == null)
            ScannerAction.copy(
              summary.copy ?? barcode.text,
              label: summary.copyLabel ?? '',
              primary: onScanAgain == null,
            ),
          if (onScanAgain != null)
            ScannerAction(
              label: strings.scanAgain,
              onPressed: onScanAgain,
              primary: true,
            ),
        ];
    final String symbology = _symbology(barcode);
    final VoidCallback? scanAgain = onScanAgain;
    final bool close =
        scanAgain != null &&
        !actions.any((ScannerAction a) => a.onPressed == scanAgain);

    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          <String>[
            strings.kindOf(content),
            ?summary.kindDetail,
          ].join(' · ').toUpperCase(),
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
      label: '${strings.kindOf(content)}: ${summary.title}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (showIcon) ...<Widget>[
                ScannerBadge(icon: iconOf(content)),
                const SizedBox(width: 16),
              ] else if (showPicture) ...<Widget>[
                BarcodeThumbnail(barcode, cutOut: cutOut, size: 72),
                const SizedBox(width: 16),
              ],
              Expanded(child: heading),
              if (close) ...<Widget>[
                const SizedBox(width: 12),
                _SheetClose(label: strings.scanAgain, onPressed: scanAgain),
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
          if (content case Gs1Content(
            :final Map<String, String> elements,
          )) ...<Widget>[
            const SizedBox(height: 16),
            ScannerFields(<String, String>{
              for (final MapEntry<String, String> e in elements.entries)
                '(${e.key})': e.value,
            }),
          ] else if (summary.payload case final String payload) ...<Widget>[
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
                ScannerChip(warning, warning: true),
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
    TextContent() => ScannerIcons.text,
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
    this.copy,
    this.copyLabel,
  });

  factory _Summary.of(
    Barcode barcode,
    BarcodeContent content,
    ScannerStrings strings,
  ) {
    final String text = barcode.text;
    String? raw(String shown) => text.trim() == shown.trim() ? null : text;
    switch (content) {
      case UrlContent(:final Uri url, :final LinkService service):
        return _Summary(
          _serviceTarget(url, service),
          detail: service == LinkService.whatsApp
              ? url.queryParameters['text']
              : null,
          // The address without its query: a message is the detail above.
          payload: '${url.host.replaceFirst(RegExp(r'^www\.'), '')}${url.path}',
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
        final String detail = security == WifiSecurity.none
            ? strings.wifiOpen
            : password == null
            ? security.name.toUpperCase()
            : '${security.name.toUpperCase()} · ${strings.wifiPassword}';
        return _Summary(ssid, detail: detail, payload: text);
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
            ? _dateTime(start)
            : '${_dateTime(start)} – ${_sameDay(start, end) ? _time(end) : _dateTime(end)}';
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
          display: amount == null
              ? null
              : crypto.currency == CryptoCurrency.ethereum
              ? '$amount wei'
              : '$amount ${crypto.currency.symbol}',
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
            if (id.dateOfBirth case final DateTime d)
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
              : product.gtin,
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
      case Gs1Content(:final Map<String, String> elements):
        return _Summary(elements['01'] ?? elements.values.firstOrNull ?? text);
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
  }

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

  /// A chip in the signal color ("Expired").
  final String? warning;

  /// What the default copy button copies instead of the whole text, and
  /// its label: a payment's account, "Copy IBAN".
  final String? copy;
  final String? copyLabel;

  /// How many lines the title may take before an ellipsis.
  final int titleLines;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String _dateTime(DateTime t) {
    final String date = '${t.year}-${_two(t.month)}-${_two(t.day)}';
    return t.hour == 0 && t.minute == 0 ? date : '$date ${_time(t)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// A payment as the approved design shows it: the payee, the amount
  /// large, what it is for, the account and the standard's own fields.
  static _Summary _paymentSummary(
    PaymentContent payment,
    ScannerStrings strings,
  ) {
    final String? amount = payment.amount;
    String? detail;
    Map<String, String> fields;
    List<String> chips;
    String? copyLabel;
    String? copy = payment.account?.replaceAll(' ', '');
    switch (payment) {
      case final EpcPaymentContent epc:
        detail = epc.text ?? epc.information;
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
          if (bill.qrReference case final String r)
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

  static String _paymentStandard(PaymentContent payment) => switch (payment) {
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

  /// Who or what a link to a service leads to: `+374 91 234567` becomes
  /// `+37491234567`, an Instagram profile `@name`, a map its search.
  static String _serviceTarget(Uri url, LinkService service) {
    final List<String> path = url.pathSegments
        .where((String p) => p.isNotEmpty)
        .toList();
    String? at(int i) => i < path.length ? path[i] : null;
    String handle(String? name) => name == null
        ? url.host
        : name.startsWith('@')
        ? name
        : '@$name';
    return switch (service) {
      LinkService.whatsApp => at(0) == null ? url.host : '+${at(0)}',
      LinkService.signal =>
        url.fragment.startsWith('p/') ? url.fragment.substring(2) : url.host,
      LinkService.linkedIn || LinkService.snapchat => handle(at(1) ?? at(0)),
      LinkService.reddit =>
        at(0) == 'r' && at(1) != null ? 'r/${at(1)}' : handle(at(1) ?? at(0)),
      LinkService.discord => at(0) ?? url.host,
      LinkService.googleMaps ||
      LinkService.appleMaps ||
      LinkService.yandexMaps =>
        url.queryParameters['query'] ??
            url.queryParameters['q'] ??
            url.queryParameters['text'] ??
            url.host,
      LinkService.appStore ||
      LinkService.googlePlay ||
      LinkService.spotify ||
      LinkService.appleMusic ||
      LinkService.googleReview => url.host.replaceFirst('www.', ''),
      _ => handle(at(0)),
    };
  }

  static String _hex(Uint8List bytes) {
    final Iterable<String> shown = bytes
        .take(24)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'));
    return '${shown.join(' ')}${bytes.length > 24 ? ' …' : ''}';
  }
}

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
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
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
    this.warning = false,
  });

  /// The icon.
  final ScannerIconData icon;

  /// Width and height.
  final double size;

  /// In the signal color instead of the accent, for problems.
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final ScannerTheme theme = ScannerTheme.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: warning
            ? theme.signalColor.withValues(alpha: 0.2)
            : theme.lockSoftColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(size * 0.31)),
        ),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: ScannerIcon(
            icon,
            size: size * 0.54,
            color: warning ? theme.signalInkColor : theme.lockInkColor,
          ),
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
          label: action.label,
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
  final String label;
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
    return ScannerActionButton(
      label: _copied
          ? strings.copied
          : widget.label.isEmpty
          ? strings.copy
          : widget.label,
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
    final String symbology = _symbology(barcode);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
                  barcode.text,
                  style: theme.dataStyle.copyWith(fontSize: 16, height: 1.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  symbology,
                  style: theme.chipStyle.copyWith(color: theme.inkMutedColor),
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
