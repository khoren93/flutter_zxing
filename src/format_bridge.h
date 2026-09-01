//! Translation between the barcode format bits `flutter_zxing` exposes to Dart
//! and `ZXing::BarcodeFormat`.
//!
//! zxing-cpp 3.0 dropped the bit-flag `BarcodeFormat` this plugin's public Dart
//! API is built on. Formats are now `(symbology | variant << 8)` ids, sets of
//! them are lists rather than masks, and one symbology can come back as any of
//! several variants (a Code39 scan may report `Code39`, `Code39Ext`, `Code32` or
//! `PZN`). Keeping the Dart side a plain bit mask means users' `Format.a |
//! Format.b` keeps working, at the cost of the mapping in this file.

#pragma once

#include "BarcodeFormat.h"

namespace flutter_zxing
{

/// The format bits handed across the FFI boundary.
/// Keep in sync with `lib/src/models/format.dart`.
namespace DartFormat
{
    constexpr int none            = 0;
    constexpr int aztec           = 1 << 0;
    constexpr int codabar         = 1 << 1;
    constexpr int code39          = 1 << 2;
    constexpr int code93          = 1 << 3;
    constexpr int code128         = 1 << 4;
    constexpr int dataBar         = 1 << 5;
    constexpr int dataBarExpanded = 1 << 6;
    constexpr int dataMatrix      = 1 << 7;
    constexpr int ean8            = 1 << 8;
    constexpr int ean13           = 1 << 9;
    constexpr int itf             = 1 << 10;
    constexpr int maxiCode        = 1 << 11;
    constexpr int pdf417          = 1 << 12;
    constexpr int qrCode          = 1 << 13;
    constexpr int upca            = 1 << 14;
    constexpr int upce            = 1 << 15;
    constexpr int microQRCode     = 1 << 16;
    constexpr int rmqrCode        = 1 << 17;
    constexpr int dxFilmEdge      = 1 << 18;
    constexpr int dataBarLimited  = 1 << 19;
    constexpr int telepen         = 1 << 20;
    constexpr int microPdf417     = 1 << 21;
} // namespace DartFormat

/// The set of formats to scan for, from a Dart format mask.
///
/// An empty set is what zxing reads as "every supported format", so a mask of
/// `0` (`Format.none`) keeps its previous meaning of "no restriction".
ZXing::BarcodeFormats readFormats(int mask) noexcept;

/// The format `MultiFormatWriter` should encode for a single Dart format bit.
/// Returns `BarcodeFormat::None` for bits the old writer cannot produce.
ZXing::BarcodeFormat writeFormat(int bit) noexcept;

/// The Dart format bit a decoded symbol is reported as.
///
/// Variants collapse onto the family they belong to (`Code39Ext` -> `code39`,
/// `QRCodeModel2` -> `qrCode`), so the `format` of a result stays comparable to
/// the `Format.*` constant the caller asked for. Unknown formats map to
/// `DartFormat::none`.
int dartFormat(ZXing::BarcodeFormat format) noexcept;

} // namespace flutter_zxing
