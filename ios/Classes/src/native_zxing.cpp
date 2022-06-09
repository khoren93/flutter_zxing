#include "common.h"
#include "ReadBarcode.h"
#include "MultiFormatWriter.h"
#include "TextUtfEncoding.h"
#include "BitMatrix.h"
#include "native_zxing.h"

using namespace ZXing;

extern "C"
{
    bool logEnabled = false;

    FUNCTION_ATTRIBUTE
    void setLogEnabled(int enabled)
    {
        logEnabled = enabled;
    }

    FUNCTION_ATTRIBUTE
    char const *version()
    {
        return "1.3.0";
    }

    FUNCTION_ATTRIBUTE
    struct CodeResult readBarcode(char *bytes, int format, int width, int height, int cropWidth, int cropHeight)
    {
        long long start = get_now();

        long length = width * height;
        auto *data = new uint8_t[length];
        memcpy(data, bytes, length);

        BarcodeFormats formats = BarcodeFormat(format);
        DecodeHints hints = DecodeHints().setTryHarder(false).setTryRotate(true).setFormats(formats);
        ImageView image{data, width, height, ImageFormat::Lum};
        if (cropWidth > 0 && cropHeight > 0 && cropWidth < width && cropHeight < height)
        {
            image = image.cropped(width / 2 - cropWidth / 2, height / 2 - cropHeight / 2, cropWidth, cropHeight);
        }
        Result result = ReadBarcode(image, hints);

        struct CodeResult code = {false, nullptr};
        if (result.isValid())
        {
            code.isValid = result.isValid();

            code.format = Format(static_cast<int>(result.format()));

            const wchar_t *resultText = result.text().c_str();
            size_t size = (wcslen(resultText) + 1) * sizeof(wchar_t);
            code.text = new char[size];
            std::wcstombs(code.text, resultText, size);
        }

        int evalInMillis = static_cast<int>(get_now() - start);
        if (logEnabled)
        {
            platform_log("zxingRead: %d ms", evalInMillis);
        }
        return code;
    }

    FUNCTION_ATTRIBUTE
    struct CodeResults readBarcodes(char *bytes, int format, int width, int height, int cropWidth, int cropHeight)
    {
        long long start = get_now();

        long length = width * height;
        auto *data = new uint8_t[length];
        memcpy(data, bytes, length);

        BarcodeFormats formats = BarcodeFormat(format);
        DecodeHints hints = DecodeHints().setTryHarder(false).setTryRotate(true).setFormats(formats);
        ImageView image{data, width, height, ImageFormat::Lum};
        if (cropWidth > 0 && cropHeight > 0 && cropWidth < width && cropHeight < height)
        {
            image = image.cropped(width / 2 - cropWidth / 2, height / 2 - cropHeight / 2, cropWidth, cropHeight);
        }
        Results results = ReadBarcodes(image, hints);

        auto *codes = new struct CodeResult [results.size()];
        int i = 0;
        for (auto &result : results)
        {
            struct CodeResult code = {false, nullptr};
            if (result.isValid())
            {
                code.isValid = result.isValid();

                code.format = Format(static_cast<int>(result.format()));

                const wchar_t *resultText = result.text().c_str();
                size_t size = (wcslen(resultText) + 1) * sizeof(wchar_t);
                code.text = new char[size];
                std::wcstombs(code.text, resultText, size);
                
                codes[i] = code;
                i++;
            }
        }

        int evalInMillis = static_cast<int>(get_now() - start);
        if (logEnabled)
        {
            platform_log("zxingRead: %d ms", evalInMillis);
        }
        return {i, codes};
    }

    FUNCTION_ATTRIBUTE
    struct EncodeResult encodeBarcode(char *contents, int width, int height, int format, int margin, int eccLevel)
    {
        long long start = get_now();

        struct EncodeResult result = {0, contents, Format(format), nullptr, 0, nullptr};
        try
        {
            auto writer = MultiFormatWriter(BarcodeFormat(format)).setMargin(margin).setEccLevel(eccLevel).setEncoding(CharacterSet::UTF8);
            auto bitMatrix = writer.encode(TextUtfEncoding::FromUtf8(std::string(contents)), width, height);
            result.data = ToMatrix<uint32_t>(bitMatrix).data();
            result.length = bitMatrix.width() * bitMatrix.height();
            result.isValid = true;
        }
        catch (const std::exception &e)
        {
            if (logEnabled)
            {
                platform_log("Can't encode text: %s\nError: %s\n", contents, e.what());
            }
            result.error = new char[strlen(e.what()) + 1];
            strcpy(result.error, e.what());
        }

        int evalInMillis = static_cast<int>(get_now() - start);
        if (logEnabled)
        {
            platform_log("zxingEncode: %d ms", evalInMillis);
        }
        return result;
    }
}
