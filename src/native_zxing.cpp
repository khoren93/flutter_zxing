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
#include <cstdlib>
#include <locale>
#include <string>
#include <vector>

using namespace ZXing;
using namespace std;
using std::chrono::steady_clock;

// Returns an owned C-string `char*`, copied from a `std::string&`.
char* cstrFromString(const std::string& s)
{
    auto size = s.length() + 1;
    char* out = new char[size];
    std::copy(s.begin(), s.end(), out);
    out[size] = '\0';
    return out;
}

// Returns an owned byte buffer `uint8_t*`, copied from a
// `std::vector<uint8_t>&`.
uint8_t* bytesFromVector(const std::vector<uint8_t>& v)
{
    auto* bytes = new uint8_t[v.size()];
    std::copy(v.begin(), v.end(), bytes);
    return bytes;
}

// Construct a `CodeResult` from a zxing barcode decode `Result` from within an
// image.
CodeResult codeResultFromResult(
    const Result& result,
    int duration,
    int width,
    int height
) {
    auto p = result.position();
    auto tl = p.topLeft();
    auto tr = p.topRight();
    auto bl = p.bottomLeft();
    auto br = p.bottomRight();

    const auto text = result.text();

    struct CodeResult code {};
    code.text = cstrFromString(text);
    code.isValid = result.isValid();
    code.error = cstrFromString(result.error().msg());
    code.bytes = bytesFromVector(result.bytes());
    code.length = static_cast<int>(result.bytes().size());
    code.format = static_cast<int>(result.format());
    code.pos = Pos {width, height, tl.x, tl.y, tr.x, tr.y, bl.x, bl.y, br.x, br.y};
    code.isInverted = result.isInverted();
    code.isMirrored = result.isMirrored();
    code.duration = duration;
    return code;
}

// Returns the duration elapsed in milliseconds since `start`.
int elapsed_ms(const steady_clock::time_point& start)
{
  auto end = steady_clock::now();
  auto duration = end - start;
  return chrono::duration_cast<chrono::milliseconds>(duration).count();
}

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
    struct CodeResult readBarcode(uint8_t* bytes, int imageFormat, int format, int width, int height, int cropWidth, int cropHeight, bool tryHarder, bool tryRotate, bool tryInvert)
    {
        auto start = steady_clock::now();

        ImageView image {bytes, width, height, ImageFormat(imageFormat)};
        if (cropWidth > 0 && cropHeight > 0 && cropWidth < width && cropHeight < height)
        {
            image = image.cropped(width / 2 - cropWidth / 2, height / 2 - cropHeight / 2, cropWidth, cropHeight);
        }
        ReaderOptions hints = ReaderOptions().setTryHarder(tryHarder).setTryRotate(tryRotate).setFormats(BarcodeFormat(format)).setTryInvert(tryInvert).setReturnErrors(true);
        Result result = ReadBarcode(image, hints);

        // Dart passes us an owned image bytes pointer; we need to free it after
        // we're done decoding.
        delete[] bytes;

        int duration = elapsed_ms(start);
        platform_log("Read Barcode in: %d ms\n", duration);

        return codeResultFromResult(result, duration, width, height);
    }

    FUNCTION_ATTRIBUTE
    struct CodeResults readBarcodes(uint8_t* bytes, int imageFormat, int format, int width, int height, int cropWidth, int cropHeight, bool tryHarder, bool tryRotate, bool tryInvert)
    {
        auto start = steady_clock::now();

        ImageView image{bytes, width, height, ImageFormat(imageFormat)};
        if (cropWidth > 0 && cropHeight > 0 && cropWidth < width && cropHeight < height)
        {
            image = image.cropped(width / 2 - cropWidth / 2, height / 2 - cropHeight / 2, cropWidth, cropHeight);
        }
        ReaderOptions hints = ReaderOptions().setTryHarder(tryHarder).setTryRotate(tryRotate).setFormats(BarcodeFormat(format)).setTryInvert(tryInvert);
        Results results = ReadBarcodes(image, hints);

        // Dart passes us an owned image bytes pointer; we need to free it after
        // we're done decoding.
        delete[] bytes;

        int duration = elapsed_ms(start);
        platform_log("Read Barcode in: %d ms\n", duration);

        if (results.empty()) {
          return CodeResults {0, nullptr, duration};
        }

        auto* codes = new struct CodeResult[results.size()];
        int i = 0;
        for (const auto& result : results) {
            codes[i] = codeResultFromResult(result, duration, width, height);
            i++;
        }
        return CodeResults {i, codes, duration};
    }

    FUNCTION_ATTRIBUTE
    struct EncodeResult encodeBarcode(char* contents, int width, int height, int format, int margin, int eccLevel)
    {
        auto start = steady_clock::now();

        struct EncodeResult result = {0, contents, format, nullptr, 0, nullptr};
        try
        {
            auto writer = MultiFormatWriter(BarcodeFormat(format)).setMargin(margin).setEccLevel(eccLevel).setEncoding(CharacterSet::UTF8);
            auto bitMatrix = writer.encode(contents, width, height);
            auto matrix = ToMatrix<uint8_t>(bitMatrix);

            // We need to return an owned pointer across the ffi boundary. Copy
            // the output (again).
            auto length = matrix.size();
            auto* data = new uint8_t[length];
            std::copy(matrix.begin(), matrix.end(), data);

            result.length = length;
            result.data = data;
            result.isValid = true;
        }
        catch (const exception &e)
        {
            platform_log("Can't encode text: %s\nError: %s\n", contents, e.what());
            result.error = new char[strlen(e.what()) + 1];
            strcpy(result.error, e.what());
        }

        int duration = elapsed_ms(start);
        platform_log("Encode Barcode in: %d ms\n", duration);
        return result;
    }
}
