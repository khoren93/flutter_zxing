#include "common.h"
#include "ReadBarcode.h"
#include "MultiFormatWriter.h"
#include "TextUtfEncoding.h"
#include "BitMatrix.h"
#include "native_zxing.h"

using namespace ZXing;

extern "C"
{
    FUNCTION_ATTRIBUTE
    char *zxingVersion()
    {
        return "1.3.0";
    }

    FUNCTION_ATTRIBUTE
    struct CodeResult zxingRead(char *bytes, int format, int width, int height, int cropWidth, int cropHeight, int logEnabled)
    {
        long long start = get_now();

        long length = width * height;
        uint8_t *data = new uint8_t[length];
        memcpy(data, bytes, length);

        BarcodeFormats formats = BarcodeFormat(format); // BarcodeFormat::Any;
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
            code.text = new char[result.text().length() + 1];
            std::string text = std::string(result.text().begin(), result.text().end());
            strcpy(code.text, text.c_str());
            code.format = Format(static_cast<int>(result.format()));
        }

        int evalInMillis = static_cast<int>(get_now() - start);
        if (logEnabled)
        {
            platform_log("zxingRead: %d ms", evalInMillis);
        }
        return code;
    }

    FUNCTION_ATTRIBUTE
    struct EncodeResult zxingEncode(char *contents, int width, int height, int format, int margin, int eccLevel, int logEnabled)
    {
        long long start = get_now();

        struct EncodeResult result = {nullptr, 0, false, nullptr};
        try
        {
            auto writer = MultiFormatWriter(BarcodeFormat(format)).setMargin(margin).setEccLevel(eccLevel);
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
