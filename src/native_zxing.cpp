#include "common.h"
#include "ReadBarcode.h"
#include "MultiFormatWriter.h"
#include "BitMatrix.h"
#include "native_zxing.h"
// #include "ZXVersion.h" // This file is not existing for iOS

#include <algorithm>
#include <chrono>
#include <codecvt>
#include <cstdarg>
#include <locale>
#include <memory>
#include <string>
#include <vector>

using namespace ZXing;
using namespace std;
using std::chrono::steady_clock;

// Forward declare some impls
CodeResult _readBarcode(const DecodeBarcodeParams& params);
CodeResults _readBarcodes(const DecodeBarcodeParams& params);
EncodeResult _encodeBarcode(const EncodeBarcodeParams& params);

// `unique_dart_ptr` is a `unique_ptr` that can safely manage pointers allocated
// from within Dart. In particular, it will dealloc pointers passed from Dart
// using the same allocator that alloc'd them.
//
// On Unix-like systems, this is the libc allocator (`malloc` and `free`). On
// Windows, this is... whatever allocator Windows uses (`CoTaskMemAlloc` and
// `CoTaskMemFree` apparently).
//
// See: <https://pub.dev/documentation/ffi/latest/ffi/malloc-constant.html>
struct dart_deleter {
    template <typename T>
    void operator()(T *p) const;
};
template <typename T>
using unique_dart_ptr = std::unique_ptr<T, dart_deleter>;

//
// Public, exported FFI functions
//

extern "C"
{
    FUNCTION_ATTRIBUTE
    void setLogEnabled(bool enable)
    {
        setLoggingEnabled(enable);
    }

    FUNCTION_ATTRIBUTE
    char const *version()
    {
        // return ZXING_VERSION_STR; // TODO: Not working on iOS for now
        return "2.2.1";
    }

    FUNCTION_ATTRIBUTE
    CodeResult readBarcode(DecodeBarcodeParams* params)
    {
        unique_dart_ptr<DecodeBarcodeParams> _params(params);
        return _readBarcode(*_params);
    }

    FUNCTION_ATTRIBUTE
    CodeResults readBarcodes(DecodeBarcodeParams* params)
    {
        unique_dart_ptr<DecodeBarcodeParams> _params(params);
        return _readBarcodes(*_params);
    }

    FUNCTION_ATTRIBUTE
    EncodeResult encodeBarcode(EncodeBarcodeParams* params)
    {
        unique_dart_ptr<EncodeBarcodeParams> _params(params);
        return _encodeBarcode(*_params);
    }
}

//
// Helper functions
//

ImageView createCroppedImageView(const DecodeBarcodeParams &params)
{
    ImageView image {
        reinterpret_cast<const uint8_t *>(params.bytes),
        params.width,
        params.height,
        ImageFormat(params.imageFormat),
    };
    if (params.cropWidth > 0 && params.cropHeight > 0
        && params.cropWidth < params.width && params.cropHeight < params.height)
    {
        image = image.cropped(params.cropLeft, params.cropTop, params.cropWidth, params.cropHeight);
    }
    return image;
}

ReaderOptions createReaderOptions(const DecodeBarcodeParams &params)
{
    return ReaderOptions()
        .setTryHarder(params.tryHarder)
        .setTryRotate(params.tryRotate)
        .setFormats(BarcodeFormat(params.format))
        .setTryInvert(params.tryInvert)
        .setReturnErrors(true);
}

// Returns an owned C-string `char*`, copied from a `std::string&`.
char *cstrFromString(const std::string &s)
{
    auto size = s.length() + 1;
    char *out = new char[size];
    std::copy(s.begin(), s.end(), out);
    out[size - 1] = '\0';
    return out;
}

// Returns an owned byte buffer `uint8_t*`, copied from a
// `std::vector<uint8_t>&`.
uint8_t *bytesFromVector(const std::vector<uint8_t> &v)
{
    auto *bytes = new uint8_t[v.size()];
    std::copy(v.begin(), v.end(), bytes);
    return bytes;
}

// Construct a `CodeResult` from a zxing barcode decode `Result` from within an
// image.
CodeResult codeResultFromResult(
    const Result &result,
    int duration,
    int width,
    int height)
{
    auto p = result.position();
    auto tl = p.topLeft();
    auto tr = p.topRight();
    auto bl = p.bottomLeft();
    auto br = p.bottomRight();

    const auto text = result.text();

    CodeResult code {};
    code.text = cstrFromString(text);
    code.isValid = result.isValid();
    code.error = cstrFromString(result.error().msg());
    code.bytes = bytesFromVector(result.bytes());
    code.length = static_cast<int>(result.bytes().size());
    code.format = static_cast<int>(result.format());
    code.pos = Pos{width, height, tl.x, tl.y, tr.x, tr.y, bl.x, bl.y, br.x, br.y};
    code.isInverted = result.isInverted();
    code.isMirrored = result.isMirrored();
    code.duration = duration;

    return code;
}

// Returns the duration elapsed in milliseconds since `start`.
int elapsed_ms(const steady_clock::time_point &start)
{
    auto end = steady_clock::now();
    auto duration = end - start;
    return chrono::duration_cast<chrono::milliseconds>(duration).count();
}

// A "deleter" for `std::unique_ptr` that can free pointers from Dart.
template <typename T>
void dart_deleter::operator()(T *p) const
{
    // TODO(phlip9): this should use `CoTaskMemFree` on Windows
    std::free(const_cast<std::remove_const_t<T>*>(p));
}

// Ensure `unique_dart_ptr` doesn't add any extra fn ptr overhead. It should
// just be ptr-sized.
static_assert(
    sizeof(unique_ptr<uint8_t>) == sizeof(unique_dart_ptr<uint8_t>),
    "no extra overhead"
);

//
// FFI impls
//

CodeResult _readBarcode(const DecodeBarcodeParams& params)
{
    auto start = steady_clock::now();

    ImageView image = createCroppedImageView(params);
    ReaderOptions hints = createReaderOptions(params);
    Result result = ReadBarcode(image, hints);

    int duration = elapsed_ms(start);
    platform_log("Read Barcode in: %d ms\n", duration);
    return codeResultFromResult(result, duration, params.width, params.height);
}

CodeResults _readBarcodes(const DecodeBarcodeParams& params)
{
    auto start = steady_clock::now();

    ImageView image = createCroppedImageView(params);
    ReaderOptions hints = createReaderOptions(params);
    Results results = ReadBarcodes(image, hints);

    int duration = elapsed_ms(start);
    platform_log("Read Barcode in: %d ms\n", duration);

    if (results.empty())
    {
        return CodeResults{0, nullptr, duration};
    }

    auto *codes = new CodeResult[results.size()];
    int i = 0;
    for (const auto &result : results)
    {
        codes[i] = codeResultFromResult(result, duration, params.width, params.height);
        i++;
    }
    return CodeResults{i, codes, duration};
}

EncodeResult _encodeBarcode(const EncodeBarcodeParams& params)
{
    auto start = steady_clock::now();

    EncodeResult result {0, params.contents, params.format, nullptr, 0, nullptr};
    try
    {
        auto writer = MultiFormatWriter(BarcodeFormat(params.format))
           .setMargin(params.margin)
           .setEccLevel(params.eccLevel)
           .setEncoding(CharacterSet::UTF8);
        auto bitMatrix = writer.encode(params.contents, params.width, params.height);
        auto matrix = ToMatrix<uint8_t>(bitMatrix);

        // We need to return an owned pointer across the ffi boundary. Copy
        // the output (again).
        auto length = matrix.size();
        auto *data = new uint8_t[length];
        std::copy(matrix.begin(), matrix.end(), data);

        result.length = length;
        result.data = data;
        result.isValid = true;
    }
    catch (const exception &e)
    {
        platform_log("Can't encode text: %s\nError: %s\n", params.contents, e.what());
        result.error = new char[strlen(e.what()) + 1];
        strcpy(result.error, e.what());
    }

    int duration = elapsed_ms(start);
    platform_log("Encode Barcode in: %d ms\n", duration);
    return result;
}
