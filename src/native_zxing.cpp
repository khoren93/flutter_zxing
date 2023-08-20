#include "common.h"
#include "ReadBarcode.h"
#include "MultiFormatWriter.h"
#include "BitMatrix.h"
#include "native_zxing.h"
// #include "ZXVersion.h" // This file is not existing for iOS

#include <locale>
#include <codecvt>
#include <stdarg.h>

using namespace ZXing;
using namespace std;

extern "C"
{
    void resultToCodeResult(struct CodeResult *code, Result result)
    {
        string text = result.text();
        code->text = new char[text.length() + 1];
        strcpy(code->text, text.c_str());

        code->isValid = result.isValid();

        string error = result.error().msg();
        code->error = new char[error.length() + 1];
        strcpy(code->error, error.c_str());

        code->format = static_cast<int>(result.format());

        // TODO: this needs to be allocated and coped as well (see text above). Will also require a delete in some flutter code, I assume
        code->bytes = result.bytes().data();
        code->length = result.bytes().size();

        auto p = result.position();
        auto tl = p.topLeft();
        auto tr = p.topRight();
        auto bl = p.bottomLeft();
        auto br = p.bottomRight();
        code->pos = new Pos{0, 0, tl.x, tl.y, tr.x, tr.y, bl.x, bl.y, br.x, br.y};

        code->isInverted = result.isInverted();
        code->isMirrored = result.isMirrored();
    }

    FUNCTION_ATTRIBUTE
    void setLogEnabled(int enable)
    {
        setLoggingEnabled(enable);
    }

    FUNCTION_ATTRIBUTE
    char const *version()
    {
        // return ZXING_VERSION_STR; // TODO: Not working on iOS for now
        return "2.1.0";
    }

    FUNCTION_ATTRIBUTE
    struct CodeResult readBarcode(char *bytes, int format, int width, int height, int cropWidth, int cropHeight, int tryHarder, int tryRotate, int tryInvert)
    {
        long long start = get_now();

        ImageView image{reinterpret_cast<const uint8_t *>(bytes), width, height, ImageFormat::Lum};
        if (cropWidth > 0 && cropHeight > 0 && cropWidth < width && cropHeight < height)
        {
            image = image.cropped(width / 2 - cropWidth / 2, height / 2 - cropHeight / 2, cropWidth, cropHeight);
        }
        DecodeHints hints = DecodeHints().setTryHarder(tryHarder).setTryRotate(tryRotate).setFormats(BarcodeFormat(format)).setTryInvert(tryInvert).setReturnErrors(true);
        Result result = ReadBarcode(image, hints);

        delete[] bytes;

        struct CodeResult code;
        resultToCodeResult(&code, result);

        int evalInMillis = static_cast<int>(get_now() - start);
        code.duration = evalInMillis;
        code.pos->imageWidth = width;
        code.pos->imageHeight = height;
        platform_log("Read Barcode in: %d ms\n", code.duration);
        return code;
    }

    FUNCTION_ATTRIBUTE
    struct CodeResults readBarcodes(char *bytes, int format, int width, int height, int cropWidth, int cropHeight, int tryHarder, int tryRotate, int tryInvert)
    {
        long long start = get_now();

        ImageView image{reinterpret_cast<const uint8_t *>(bytes), width, height, ImageFormat::Lum};
        if (cropWidth > 0 && cropHeight > 0 && cropWidth < width && cropHeight < height)
        {
            image = image.cropped(width / 2 - cropWidth / 2, height / 2 - cropHeight / 2, cropWidth, cropHeight);
        }
        DecodeHints hints = DecodeHints().setTryHarder(tryHarder).setTryRotate(tryRotate).setFormats(BarcodeFormat(format)).setTryInvert(tryInvert);
        Results results = ReadBarcodes(image, hints);
        delete[] bytes;

        int evalInMillis = static_cast<int>(get_now() - start);
        platform_log("Read Barcode in: %d ms\n", evalInMillis);

        auto *codes = new struct CodeResult[results.size()];
        int i = 0;
        for (auto &result : results)
        {
            struct CodeResult code;
            resultToCodeResult(&code, result);
            code.duration = evalInMillis;
            code.pos->imageWidth = width;
            code.pos->imageHeight = height;
            codes[i] = code;
            i++;
        }

        return {i, codes, evalInMillis};
    }

    FUNCTION_ATTRIBUTE
    struct EncodeResult encodeBarcode(char *contents, int width, int height, int format, int margin, int eccLevel)
    {
        long long start = get_now();

        struct EncodeResult result = {0, contents, format, nullptr, 0, nullptr};
        try
        {
            auto writer = MultiFormatWriter(BarcodeFormat(format)).setMargin(margin).setEccLevel(eccLevel).setEncoding(CharacterSet::UTF8);
            auto bitMatrix = writer.encode(contents, width, height);
            result.data = ToMatrix<int8_t>(bitMatrix).data();
            result.length = bitMatrix.width() * bitMatrix.height();
            result.isValid = true;
        }
        catch (const exception &e)
        {
            platform_log("Can't encode text: %s\nError: %s\n", contents, e.what());
            result.error = new char[strlen(e.what()) + 1];
            strcpy(result.error, e.what());
        }

        int evalInMillis = static_cast<int>(get_now() - start);
        platform_log("Encode Barcode in: %d ms\n", evalInMillis);
        return result;
    }
}
