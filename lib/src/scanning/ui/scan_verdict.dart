import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../barcode/barcode.dart';

/// Decides whether the scanner accepts [barcode]: a ticket at the door, a
/// sign-in code of your own service, a value for a form field.
///
/// Return `null` or [ScanVerdict.accept] to accept it, [ScanVerdict.warn]
/// for a code that needs a look, or [ScanVerdict.reject] to refuse it. The
/// check may be asynchronous, such as a request to your server; codes
/// found meanwhile are skipped.
typedef ScannerCheck = FutureOr<ScanVerdict?> Function(Barcode barcode);

/// How a [ScannerCheck] judged a code: the constructor of its
/// [ScanVerdict].
enum ScanVerdictKind {
  /// The code is accepted ([ScanVerdict.accept]).
  accept,

  /// The code is accepted but needs a look, such as a ticket already
  /// checked in ([ScanVerdict.warn]).
  warn,

  /// The code is refused ([ScanVerdict.reject]).
  reject,
}

/// The answer of a [ScannerCheck]: its [kind] and what to tell the user.
///
/// ```dart
/// ScannerTemplate.checkIn(
///   check: (barcode) async {
///     final ticket = await tickets.find(barcode.text);
///     if (ticket == null) return ScanVerdict.reject(title: 'Invalid ticket');
///     if (ticket.used) return ScanVerdict.warn(title: ticket.name, message: 'Already checked in');
///     return ScanVerdict.accept(title: ticket.name, message: ticket.seat);
///   },
/// )
/// ```
///
/// The scanner shows the verdict in [ScannerTheme.lockColor],
/// [ScannerTheme.warningColor] or [ScannerTheme.dangerColor], with a haptic
/// and a sound of its own for each kind.
@immutable
final class ScanVerdict {
  /// Accepts the code.
  const ScanVerdict.accept({this.title, this.message, this.data})
    : kind = ScanVerdictKind.accept;

  /// Accepts the code, which needs a look.
  const ScanVerdict.warn({this.title, this.message, this.data})
    : kind = ScanVerdictKind.warn;

  /// Refuses the code.
  const ScanVerdict.reject({this.title, this.message, this.data})
    : kind = ScanVerdictKind.reject;

  /// The judgement.
  final ScanVerdictKind kind;

  /// The headline, such as a guest's name or "Invalid ticket"; `null`
  /// shows the code's text.
  final String? title;

  /// A line under the [title], such as a seat.
  final String? message;

  /// What the check found, such as the product your server returned for
  /// the code, for the result sheet: `result.verdict?.data` in
  /// `ScannerTemplate.resultBuilder` and `actionsBuilder`. The check is
  /// the place for asynchronous work; the builders run synchronously.
  ///
  /// ```dart
  /// ScannerTemplate.product(
  ///   check: (barcode) async {
  ///     final Product? product = await catalogue.find(barcode.text);
  ///     if (product == null) return const ScanVerdict.reject(title: 'Not in the catalogue');
  ///     return ScanVerdict.accept(title: product.name, message: product.price, data: product);
  ///   },
  ///   actionsBuilder: (context, result) => [
  ///     ScannerAction(
  ///       label: 'Add to cart',
  ///       primary: true,
  ///       onPressed: () => cart.add(result.verdict!.data! as Product),
  ///     ),
  ///   ],
  /// )
  /// ```
  final Object? data;

  @override
  bool operator ==(Object other) =>
      other is ScanVerdict &&
      other.kind == kind &&
      other.title == title &&
      other.message == message &&
      other.data == data;

  @override
  int get hashCode => Object.hash(kind, title, message, data);

  @override
  String toString() =>
      'ScanVerdict.${kind.name}(${<String>[?title, ?message].join(', ')})';
}
