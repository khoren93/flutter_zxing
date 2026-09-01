//! The native C++ FFI impl for `flutter_zxing`.
//!
//! ### Tips writing FFI code
//!
//! Returning allocated memory to Dart or freeing memory allocated from within
//! Dart in C++ must be done _very carefully_. For this to be safe, both C++ and
//! Dart must use the same allocator on each side. Since C++ may use a different
//! allocator for `new`/`free`/other std types:
//!
//! * Manage all memory from/to dart using `dart_allocator` (in `dart_alloc.h`).
//! * Avoid returning memory from `new` to Dart.
//! * Avoid freeing memory from Dart with `delete`.
//!
//! It's also unsafe to unwind across the FFI boundary, so ensure top-level
//! functions are wrapped in a try/catch.

#include "native_zxing.h"

#include "zxcommon.h"
#include "dart_alloc.h"
#include "ReadBarcode.h"
#include "MultiFormatWriter.h"
#include "BitMatrix.h"
#include "Version.h"

#include <algorithm>
#include <chrono>
#include <string>
#include <vector>

using namespace ZXing;
using namespace std;
using std::chrono::steady_clock;

// Forward declare some impls
CodeResult _readBarcode(const DecodeBarcodeParams& params) noexcept;
CodeResults _readBarcodes(const DecodeBarcodeParams& params) noexcept;
EncodeResult _encodeBarcode(const EncodeBarcodeParams& params) noexcept;

//
// Public, exported FFI functions
//

extern "C"
{
    FUNCTION_ATTRIBUTE
    void setLogEnabled(bool enable) noexcept
    {
        setLoggingEnabled(enable);
    }

    FUNCTION_ATTRIBUTE
    char const* version() noexcept
    {
        return ZXING_VERSION_STR;
    }

    FUNCTION_ATTRIBUTE
    CodeResult readBarcode(DecodeBarcodeParams* params) noexcept
    {
        unique_dart_ptr<DecodeBarcodeParams> _params(params);
        return _readBarcode(*_params);
    }

    FUNCTION_ATTRIBUTE
    CodeResults readBarcodes(DecodeBarcodeParams* params) noexcept
    {
        unique_dart_ptr<DecodeBarcodeParams> _params(params);
        return _readBarcodes(*_params);
    }

    FUNCTION_ATTRIBUTE
    EncodeResult encodeBarcode(EncodeBarcodeParams* params) noexcept
    {
        unique_dart_ptr<EncodeBarcodeParams> _params(params);
        return _encodeBarcode(*_params);
    }
}

//
// Helper functions
//

/// An `ImageView` together with the origin of the crop rect it was taken from,
/// so decoded positions can be mapped back onto the full image.
struct CroppedImageView
{
    ImageView image;
    int offsetX;
    int offsetY;
};

CroppedImageView createCroppedImageView(const DecodeBarcodeParams& params)
{
    // Use the bounds-checking `ImageView` constructor: `params.bytes` comes from
    // Dart and a buffer that is too small for `width * height * pixStride` would
    // otherwise be read out of bounds.
    ImageView image {
        reinterpret_cast<const uint8_t*>(params.bytes),
        params.length,
        params.width,
        params.height,
        ImageFormat(params.imageFormat),
    };

    if (params.cropWidth <= 0 || params.cropHeight <= 0)
    {
        return {image, 0, 0};
    }

    // `ImageView::cropped` clamps the rect into the image; mirror that clamping
    // here so the reported offsets describe the view we actually decode.
    int left = std::clamp(params.cropLeft, 0, params.width - 1);
    int top = std::clamp(params.cropTop, 0, params.height - 1);
    return {image.cropped(left, top, params.cropWidth, params.cropHeight), left, top};
}

ReaderOptions createReaderOptions(const DecodeBarcodeParams& params)
{
    return ReaderOptions()
        .setTryHarder(params.tryHarder)
        .setTryRotate(params.tryRotate)
        .setFormats(BarcodeFormat(params.format))
        .setTryInvert(params.tryInvert)
        .setTryDownscale(params.tryDownscale)
        .setMaxNumberOfSymbols(params.maxNumberOfSymbols)
        .setReturnErrors(true);
}

/// Returns an owned C-string `char*` copied from a `std::string&`.
/// The owned pointer is safe to send back to Dart.
char* dartCstrFromString(const std::string& s)
{
    auto len = s.length();
    auto* out = dart_malloc<char>(len + 1);
    std::copy(s.begin(), s.end(), out);
    out[len] = '\0';
    return out;
}

/// Returns an owned C-string `char*` copied from the `exception::what()` message.
/// The owned pointer is safe to send back to Dart.
char* dartCstrFromException(const exception& e) noexcept
{
    auto* s = e.what();
    auto len = strlen(s);
    auto* out = dart_malloc<char>(len + 1);
    std::copy_n(s, len, out);
    out[len] = '\0';
    return out;
}

/// Returns an owned byte buffer `uint8_t*` copied from a `std::vector<uint8_t>&`.
/// The owned pointer is safe to send back to Dart.
uint8_t* dartBytesFromVector(const std::vector<uint8_t>& v)
{
    auto* bytes = dart_malloc<uint8_t>(v.size());
    std::copy(v.begin(), v.end(), bytes);
    return bytes;
}

/// Returns an owned byte buffer `uint8_t*` copied from a `Matrix<uint8_t>&`.
/// The owned pointer is safe to send back to Dart.
uint8_t* dartBytesFromMatrix(const Matrix<uint8_t>& matrix)
{
    auto length = matrix.size();
    auto* data = dart_malloc<uint8_t>(length);
    std::copy(matrix.begin(), matrix.end(), data);
    return data;
}

/// Returns an owned, tightly packed luminance buffer `uint8_t*` (one byte per
/// pixel) copied from an `ImageView`.
///
/// The source may be in any supported pixel format and may be row-padded or a
/// crop of a larger image, so every pixel is addressed through `ImageView::data`
/// and converted to luminance. For `Lum` input the conversion is the identity,
/// so this stays a plain copy in the common case.
/// The owned pointer is safe to send back to Dart.
uint8_t* dartLumBytesFromImageView(const ImageView& image)
{
    const int w = image.width();
    const int h = image.height();
    const int pixStride = image.pixStride();
    const ImageFormat format = image.format();
    const int redIndex = RedIndex(format);
    const int greenIndex = GreenIndex(format);
    const int blueIndex = BlueIndex(format);

    // `ImageFormat::None` has no pixel stride, so there is nothing to read.
    if (w <= 0 || h <= 0 || pixStride <= 0) {
        return nullptr;
    }

    auto* out = dart_malloc<uint8_t>(static_cast<size_t>(w) * h);
    for (int y = 0; y < h; ++y) {
        const uint8_t* src = image.data(0, y);
        uint8_t* dst = out + static_cast<size_t>(y) * w;
        for (int x = 0; x < w; ++x, src += pixStride) {
            dst[x] = RGBToLum(src[redIndex], src[greenIndex], src[blueIndex]);
        }
    }
    return out;
}

// Construct a `CodeResult` from a zxing barcode decode `Result` from within an image.
//
// `width`/`height` are the dimensions of the *full* image and `offsetX`/`offsetY`
// the origin of the decoded crop within it. zxing reports positions relative to
// the (possibly cropped) view it was handed, so the offset is added back to make
// every coordinate refer to the full image the caller passed in.
CodeResult codeResultFromResult(
    const Result& result,
    int duration,
    int width,
    int height,
    int offsetX,
    int offsetY,
    const ImageView& image
) {
    auto p = result.position();
    auto tl = p.topLeft();
    auto tr = p.topRight();
    auto bl = p.bottomLeft();
    auto br = p.bottomRight();

    CodeResult code {};
    code.isValid = result.isValid();
    code.text = result.isValid() ? dartCstrFromString(result.text()) : nullptr;
    code.bytes = result.isValid() ? dartBytesFromVector(result.bytes()) : nullptr;
    code.error = result.isValid() ? nullptr : dartCstrFromString(result.error().msg());
    code.length = static_cast<int>(result.bytes().size());
    code.format = static_cast<int>(result.format());
    code.pos = Pos{
        width, height,
        tl.x + offsetX, tl.y + offsetY,
        tr.x + offsetX, tr.y + offsetY,
        bl.x + offsetX, bl.y + offsetY,
        br.x + offsetX, br.y + offsetY,
    };
    code.isInverted = result.isInverted();
    code.isMirrored = result.isMirrored();
    code.duration = duration;

    if (isLoggingEnabled()) {
        code.imageBytes = dartLumBytesFromImageView(image);
        if (code.imageBytes != nullptr) {
            code.imageLength = image.width() * image.height();
            code.imageWidth = image.width();
            code.imageHeight = image.height();
        }
    }

    return code;
}

// Returns the duration elapsed in milliseconds since `start`.
int elapsed_ms(const steady_clock::time_point& start)
{
    auto end = steady_clock::now();
    auto duration = end - start;
    return chrono::duration_cast<chrono::milliseconds>(duration).count();
}

//
// FFI impls
//

CodeResult _readBarcode(const DecodeBarcodeParams& params) noexcept
{
    // Absolutely ensure we don't unwind across the FFI boundary.
    try
    {
        auto start = steady_clock::now();

        CroppedImageView cropped = createCroppedImageView(params);
        ReaderOptions hints = createReaderOptions(params);
        Result result = ReadBarcode(cropped.image, hints);

        int duration = elapsed_ms(start);
        platform_log("Read Barcode in: %d ms\n", duration);
        return codeResultFromResult(
            result, duration, params.width, params.height,
            cropped.offsetX, cropped.offsetY, cropped.image
        );
    }
    catch (const exception& e)
    {
        platform_log("Exception while reading barcode: %s\n", e.what());
        CodeResult result{};
        result.isValid = false;
        result.error = dartCstrFromException(e);
        return result;
    }
}

CodeResults _readBarcodes(const DecodeBarcodeParams& params) noexcept
{
    // Absolutely ensure we don't unwind across the FFI boundary.
    try
    {
        auto start = steady_clock::now();

        CroppedImageView cropped = createCroppedImageView(params);
        ReaderOptions hints = createReaderOptions(params);
        Results results = ReadBarcodes(cropped.image, hints);

        int duration = elapsed_ms(start);
        platform_log("Read Barcodes in: %d ms\n", duration);

        if (results.empty())
        {
            return CodeResults {0, nullptr, duration};
        }

        auto* codes = dart_malloc<CodeResult>(results.size());
        int i = 0;
        for (const auto& result : results)
        {
            // if result is invalid skip it
            if (!result.isValid())
            {
                continue;
            }
            codes[i] = codeResultFromResult(
                result, duration, params.width, params.height,
                cropped.offsetX, cropped.offsetY, cropped.image
            );
            i++;
        }

        // Every result was invalid. Dart only frees the array when `count > 0`,
        // so release it here instead of handing back a buffer nobody owns.
        if (i == 0)
        {
            dart_free(codes);
            return CodeResults {0, nullptr, duration};
        }

        return CodeResults {i, codes, duration};
    }
    catch (const exception& e)
    {
        platform_log("Exception while reading barcodes: %s\n", e.what());
        return CodeResults {0, nullptr, 0};
    }
}

EncodeResult _encodeBarcode(const EncodeBarcodeParams& params) noexcept
{
    // Absolutely ensure we don't unwind across the FFI boundary.
    try
    {
        auto start = steady_clock::now();

        // DataMatrixWriter
        auto writer = MultiFormatWriter(BarcodeFormat(params.format))
           .setMargin(params.margin)
           .setEccLevel(params.eccLevel)
           .setEncoding(CharacterSet::UTF8);
        auto bitMatrix = writer.encode(params.contents, params.width, params.height);
        auto matrix = ToMatrix<uint8_t>(bitMatrix);

        EncodeResult result {};
        result.isValid = true;
        result.format = params.format;
        // We need to return an owned pointer across the ffi boundary. Copy.
        result.data = dartBytesFromMatrix(matrix);
        result.length = matrix.size();
        // zxing enlarges the symbol when the requested size is too small to hold
        // it, so the caller cannot assume `params.width` x `params.height`.
        result.width = bitMatrix.width();
        result.height = bitMatrix.height();

        int duration = elapsed_ms(start);
        platform_log("Encode Barcode in: %d ms\n", duration);
        return result;
    }
    catch (const exception& e)
    {
        platform_log(
            "Exception encoding text: \"%s\", error: %s\n",
            params.contents, e.what()
        );

        EncodeResult result {};
        result.isValid = false;
        result.format = params.format;
        result.error = dartCstrFromException(e);
        return result;
    }
}
