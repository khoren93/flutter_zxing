import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../barcode/barcode.dart';
import '../../content/barcode_content.dart';
import 'glass.dart';
import 'scanner_icons.dart';
import 'scanner_strings.dart';
import 'scanner_theme.dart';

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
  const ScannerAction.copy(String text, {this.primary = false})
    : label = '',
      icon = ScannerIcons.copy,
      onPressed = null,
      _copyText = text;

  /// The text; empty for [ScannerAction.copy], which uses
  /// [ScannerStrings.copy].
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
/// "Scan again".
class BarcodeResultSheet extends StatelessWidget {
  /// Creates a sheet for [barcode].
  const BarcodeResultSheet(
    this.barcode, {
    super.key,
    this.actions,
    this.onScanAgain,
    this.showIcon = false,
  });

  /// The code.
  final Barcode barcode;

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
          ScannerAction.copy(barcode.text, primary: onScanAgain == null),
          if (onScanAgain != null)
            ScannerAction(
              label: strings.scanAgain,
              onPressed: onScanAgain,
              primary: true,
            ),
        ];
    final String symbology = barcode.symbologyIdentifier.isEmpty
        ? barcode.format.displayName
        : '${barcode.format.displayName} · ${barcode.symbologyIdentifier}';

    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(strings.kindOf(content).toUpperCase(), style: theme.overlineStyle),
        const SizedBox(height: 4),
        Text(
          summary.title,
          style: theme.titleStyle,
          maxLines: 2,
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
          if (showIcon)
            Row(
              children: <Widget>[
                ScannerBadge(icon: iconOf(content)),
                const SizedBox(width: 16),
                Expanded(child: heading),
              ],
            )
          else
            heading,
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
          const SizedBox(height: 16),
          ScannerChip(symbology),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            ScannerActions(actions),
          ],
        ],
      ),
    );
  }

  /// The icon of [content]'s kind.
  static ScannerIconData iconOf(BarcodeContent content) => switch (content) {
    UrlContent() => ScannerIcons.link,
    WifiContent() => ScannerIcons.wifi,
    ContactContent() => ScannerIcons.contact,
    EventContent() => ScannerIcons.event,
    EmailContent() => ScannerIcons.email,
    PhoneContent() => ScannerIcons.phone,
    SmsContent() => ScannerIcons.sms,
    GeoContent() => ScannerIcons.location,
    Gs1Content() => ScannerIcons.parcel,
    BinaryContent() => ScannerIcons.binary,
    TextContent() => ScannerIcons.text,
  };
}

/// Title, details and payload of a result.
final class _Summary {
  const _Summary(this.title, {this.detail, this.payload});

  factory _Summary.of(
    Barcode barcode,
    BarcodeContent content,
    ScannerStrings strings,
  ) {
    final String text = barcode.text;
    String? raw(String shown) => text.trim() == shown.trim() ? null : text;
    switch (content) {
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
      case Gs1Content(:final Map<String, String> elements):
        return _Summary(elements['01'] ?? elements.values.firstOrNull ?? text);
      case BinaryContent(:final Uint8List bytes):
        return _Summary(strings.byteCount(bytes.length), payload: _hex(bytes));
      case TextContent(:final String text):
        final String firstLine = text.split('\n').first.trim();
        final bool short = firstLine.length <= 40 && !text.contains('\n');
        return _Summary(
          short || firstLine.isEmpty ? (text.isEmpty ? ' ' : text) : firstLine,
          payload: short ? null : text,
        );
    }
  }

  final String title;
  final String? detail;
  final String? payload;

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String _dateTime(DateTime t) {
    final String date = '${t.year}-${_two(t.month)}-${_two(t.day)}';
    return t.hour == 0 && t.minute == 0 ? date : '$date ${_time(t)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _hex(Uint8List bytes) {
    final Iterable<String> shown = bytes
        .take(24)
        .map((int b) => b.toRadixString(16).padLeft(2, '0'));
    return '${shown.join(' ')}${bytes.length > 24 ? ' …' : ''}';
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
      : _CopyButton(text: action._copyText, primary: action.primary);

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
  const _CopyButton({required this.text, required this.primary});

  final String text;
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
      label: _copied ? strings.copied : strings.copy,
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
  const CollectedBarcode(this.barcode, this.count);

  /// The code, as last scanned.
  final Barcode barcode;

  /// How often it was scanned.
  final int count;
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
    final String symbology = barcode.symbologyIdentifier.isEmpty
        ? barcode.format.displayName
        : '${barcode.format.displayName} · ${barcode.symbologyIdentifier}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: latest ? theme.lockSoftColor : const Color(0x00000000),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Row(
        children: <Widget>[
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
