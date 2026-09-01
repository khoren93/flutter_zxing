#include "format_bridge.h"

#include <vector>

using namespace ZXing;

namespace flutter_zxing
{

namespace
{

/// Formats to request per Dart bit.
///
/// These are chosen so that scanning keeps the meaning it had with zxing-cpp
/// 2.x. Where 3.x groups several symbologies under one symbology-level format,
/// the variants are listed individually instead: asking for `Code39` would also
/// enable `Code32` and `PZN`, which decode to different text, and asking for
/// `DataBar` would also enable Expanded and Limited, which have their own bits.
struct ReadEntry
{
    int bit;
    BarcodeFormat formats[3]; // `None` pads the unused slots
};

constexpr ReadEntry kReadFormats[] = {
    {DartFormat::aztec,           {BarcodeFormat::Aztec}},
    {DartFormat::codabar,         {BarcodeFormat::Codabar}},
    {DartFormat::code39,          {BarcodeFormat::Code39Std, BarcodeFormat::Code39Ext}},
    {DartFormat::code93,          {BarcodeFormat::Code93}},
    {DartFormat::code128,         {BarcodeFormat::Code128}},
    {DartFormat::dataBar,         {BarcodeFormat::DataBarOmni, BarcodeFormat::DataBarStk, BarcodeFormat::DataBarStkOmni}},
    {DartFormat::dataBarExpanded, {BarcodeFormat::DataBarExp, BarcodeFormat::DataBarExpStk}},
    {DartFormat::dataMatrix,      {BarcodeFormat::DataMatrix}},
    {DartFormat::ean8,            {BarcodeFormat::EAN8}},
    {DartFormat::ean13,           {BarcodeFormat::EAN13}},
    {DartFormat::itf,             {BarcodeFormat::ITF}},
    {DartFormat::maxiCode,        {BarcodeFormat::MaxiCode}},
    {DartFormat::pdf417,          {BarcodeFormat::PDF417, BarcodeFormat::CompactPDF417}},
    {DartFormat::qrCode,          {BarcodeFormat::QRCode}},
    {DartFormat::upca,            {BarcodeFormat::UPCA}},
    {DartFormat::upce,            {BarcodeFormat::UPCE}},
    {DartFormat::microQRCode,     {BarcodeFormat::MicroQRCode}},
    {DartFormat::rmqrCode,        {BarcodeFormat::RMQRCode}},
    {DartFormat::dxFilmEdge,      {BarcodeFormat::DXFilmEdge}},
    {DartFormat::dataBarLimited,  {BarcodeFormat::DataBarLtd}},
    {DartFormat::telepen,         {BarcodeFormat::Telepen}},
    {DartFormat::microPdf417,     {BarcodeFormat::MicroPDF417}},
};

/// The format each Dart bit encodes to. Only the formats `MultiFormatWriter`
/// implements are listed; everything else has no writer and stays `None`.
struct WriteEntry
{
    int bit;
    BarcodeFormat format;
};

constexpr WriteEntry kWriteFormats[] = {
    {DartFormat::aztec,      BarcodeFormat::Aztec},
    {DartFormat::codabar,    BarcodeFormat::Codabar},
    {DartFormat::code39,     BarcodeFormat::Code39},
    {DartFormat::code93,     BarcodeFormat::Code93},
    {DartFormat::code128,    BarcodeFormat::Code128},
    {DartFormat::dataMatrix, BarcodeFormat::DataMatrix},
    {DartFormat::ean8,       BarcodeFormat::EAN8},
    {DartFormat::ean13,      BarcodeFormat::EAN13},
    {DartFormat::itf,        BarcodeFormat::ITF},
    {DartFormat::pdf417,     BarcodeFormat::PDF417},
    {DartFormat::qrCode,     BarcodeFormat::QRCode},
    {DartFormat::upca,       BarcodeFormat::UPCA},
    {DartFormat::upce,       BarcodeFormat::UPCE},
};

/// Every format a reader can put into a result, folded onto the Dart bit that
/// represents its family.
constexpr WriteEntry kReportedFormats[] = {
    {DartFormat::aztec,           BarcodeFormat::Aztec},
    {DartFormat::aztec,           BarcodeFormat::AztecCode},
    {DartFormat::aztec,           BarcodeFormat::AztecRune},
    {DartFormat::codabar,         BarcodeFormat::Codabar},
    {DartFormat::code39,          BarcodeFormat::Code39},
    {DartFormat::code39,          BarcodeFormat::Code39Std},
    {DartFormat::code39,          BarcodeFormat::Code39Ext},
    {DartFormat::code39,          BarcodeFormat::Code32},
    {DartFormat::code39,          BarcodeFormat::PZN},
    {DartFormat::code93,          BarcodeFormat::Code93},
    {DartFormat::code128,         BarcodeFormat::Code128},
    {DartFormat::dataBar,         BarcodeFormat::DataBar},
    {DartFormat::dataBar,         BarcodeFormat::DataBarOmni},
    {DartFormat::dataBar,         BarcodeFormat::DataBarStk},
    {DartFormat::dataBar,         BarcodeFormat::DataBarStkOmni},
    {DartFormat::dataBarExpanded, BarcodeFormat::DataBarExp},
    {DartFormat::dataBarExpanded, BarcodeFormat::DataBarExpStk},
    {DartFormat::dataBarLimited,  BarcodeFormat::DataBarLtd},
    {DartFormat::dataMatrix,      BarcodeFormat::DataMatrix},
    {DartFormat::ean8,            BarcodeFormat::EAN8},
    {DartFormat::ean13,           BarcodeFormat::EAN13},
    {DartFormat::ean13,           BarcodeFormat::EANUPC},
    {DartFormat::ean13,           BarcodeFormat::ISBN},
    {DartFormat::itf,             BarcodeFormat::ITF},
    {DartFormat::itf,             BarcodeFormat::ITF14},
    {DartFormat::maxiCode,        BarcodeFormat::MaxiCode},
    {DartFormat::pdf417,          BarcodeFormat::PDF417},
    {DartFormat::pdf417,          BarcodeFormat::CompactPDF417},
    {DartFormat::microPdf417,     BarcodeFormat::MicroPDF417},
    {DartFormat::qrCode,          BarcodeFormat::QRCode},
    {DartFormat::qrCode,          BarcodeFormat::QRCodeModel1},
    {DartFormat::qrCode,          BarcodeFormat::QRCodeModel2},
    {DartFormat::microQRCode,     BarcodeFormat::MicroQRCode},
    {DartFormat::rmqrCode,        BarcodeFormat::RMQRCode},
    {DartFormat::upca,            BarcodeFormat::UPCA},
    {DartFormat::upce,            BarcodeFormat::UPCE},
    {DartFormat::dxFilmEdge,      BarcodeFormat::DXFilmEdge},
    {DartFormat::telepen,         BarcodeFormat::Telepen},
    {DartFormat::telepen,         BarcodeFormat::TelepenAlpha},
    {DartFormat::telepen,         BarcodeFormat::TelepenNumeric},
};

} // namespace

BarcodeFormats readFormats(int mask) noexcept
{
    // An empty list means "no restriction" to zxing, which is what a mask
    // without any known bit set has always meant here.
    if (mask == DartFormat::none)
    {
        return {};
    }

    std::vector<BarcodeFormat> formats;
    formats.reserve(8);
    for (const auto& entry : kReadFormats)
    {
        if ((mask & entry.bit) == 0)
        {
            continue;
        }
        for (BarcodeFormat format : entry.formats)
        {
            if (format != BarcodeFormat::None)
            {
                formats.push_back(format);
            }
        }
    }

    return BarcodeFormats(std::move(formats));
}

BarcodeFormat writeFormat(int bit) noexcept
{
    for (const auto& entry : kWriteFormats)
    {
        if (entry.bit == bit)
        {
            return entry.format;
        }
    }
    return BarcodeFormat::None;
}

int dartFormat(BarcodeFormat format) noexcept
{
    for (const auto& entry : kReportedFormats)
    {
        if (entry.format == format)
        {
            return entry.bit;
        }
    }
    return DartFormat::none;
}

} // namespace flutter_zxing
