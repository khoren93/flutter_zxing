#pragma once

#ifdef __cplusplus
#include "dart_alloc.h"

#include <cstdint>
#include <cstdlib>
#else
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#endif

#ifdef __cplusplus
#define NOEXCEPT noexcept
#else
#define NOEXCEPT
#endif

#include "common.h"

#ifdef __cplusplus
extern "C"
{
#endif

    /**
     * @brief The BarcodeParams class encapsulates parameters for reading barcodes.
     */
    struct DecodeBarcodeParams
    {
        uint8_t* bytes;  ///< Image bytes. Owned pointer, freed in destructor.
        int imageFormat; ///< Image format
        int format;      ///< Specify a set of BarcodeFormats that should be searched for
        int width;       ///< Image width in pixels
        int height;      ///< Image height in pixels
        int cropLeft;    ///< Crop left
        int cropTop;     ///< Crop top
        int cropWidth;   ///< Crop width
        int cropHeight;  ///< Crop height
        bool tryHarder;  ///< Spend more time to try to find a barcode, optimize for accuracy, not speed
        bool tryRotate;  ///< Also try detecting code in 90, 180 and 270 degree rotated images
        bool tryInvert;  ///< Try inverting the image

#ifdef __cplusplus
        ~DecodeBarcodeParams() noexcept {
            // Dart passes us an owned image bytes pointer; we need to free it.
            dart_free(bytes);
        }

        // Disable copy/move contsructors
        DecodeBarcodeParams(const DecodeBarcodeParams&) = delete;
        DecodeBarcodeParams& operator=(const DecodeBarcodeParams&) = delete;
        DecodeBarcodeParams(DecodeBarcodeParams&&) = delete;
        DecodeBarcodeParams& operator=(DecodeBarcodeParams&&) = delete;
#endif
    };

    /**
     * @brief The EncodeBarcodeParams class encapsulates parameters for encoding barcodes.
     */
    struct EncodeBarcodeParams
    {
        char* contents; ///< The string to encode. Owned pointer, freed in destructor.
        int width;      ///< The width of the barcode in pixels
        int height;     ///< The height of the barcode in pixels
        int format;     ///< The format of the barcode
        int margin;     ///< The margin of the barcode
        int eccLevel;   ///< The error correction level of the barcode. Used for Aztec, PDF417, and QRCode only, [0-8].

#ifdef __cplusplus
        ~EncodeBarcodeParams() noexcept {
            // Dart passes us an owned string; we need to free it.
            dart_free(contents);
        }

        // Disable copy/move contsructors
        EncodeBarcodeParams(const EncodeBarcodeParams&) = delete;
        EncodeBarcodeParams& operator=(const EncodeBarcodeParams&) = delete;
        EncodeBarcodeParams(EncodeBarcodeParams&&) = delete;
        EncodeBarcodeParams& operator=(EncodeBarcodeParams&&) = delete;
#endif
    };

    /**
     * @brief Pos is a position of a barcode in a image.
     *
     */
    struct Pos
    {
        int imageWidth;   ///< The width of the image
        int imageHeight;  ///< The height of the image
        int topLeftX;     ///< x coordinate of top left corner of barcode
        int topLeftY;     ///< y coordinate of top left corner of barcode
        int topRightX;    ///< x coordinate of top right corner of barcode
        int topRightY;    ///< y coordinate of top right corner of barcode
        int bottomLeftX;  ///< x coordinate of bottom left corner of barcode
        int bottomLeftY;  ///< y coordinate of bottom left corner of barcode
        int bottomRightX; ///< x coordinate of bottom right corner of barcode
        int bottomRightY; ///< y coordinate of bottom right corner of barcode
    };

    /**
     * @brief The CodeResult class encapsulates the result of decoding a barcode within an image.
     */
    struct CodeResult
    {
        char* text;      ///< The decoded text. Owned pointer. Must be freed by Dart code if not null.
        bool isValid;    ///< Whether the barcode was successfully decoded
        char* error;     ///< The error message. Owned pointer. Must be freed by Dart code if not null.
        uint8_t* bytes;  ///< The bytes is the raw content without any character set conversions. Owned pointer. Must be freed by Dart code if not null.
        int length;      ///< The length of the bytes
        int format;      ///< The format of the barcode
        struct Pos pos;  ///< The position of the barcode within the image
        bool isInverted; ///< Whether the barcode was inverted
        bool isMirrored; ///< Whether the barcode was mirrored
        int duration;    ///< The duration of the decoding in milliseconds
    };

    /**
     * @brief The CodeResults class encapsulates the result of decoding multiple barcodes within an image.
     */
    struct CodeResults
    {
        int count;                  ///< The number of barcodes detected
        struct CodeResult* results; ///< The results of the barcode decoding. Owned pointer. Must be freed by Dart code.
        int duration;               ///< The duration of the decoding in milliseconds
    };

    /**
     * @brief EncodeResult encapsulates the result of encoding a barcode.
     *
     */
    struct EncodeResult
    {
        bool isValid;  ///< Whether the barcode was successfully encoded
        int format;    ///< The format of the barcode
        uint8_t* data; ///< The encoded data. Owned pointer. Must be freed by Dart code if not null.
        int length;    ///< The length of the encoded data
        char* error;   ///< The error message. Owned pointer. Must be freed by Dart code if not null.
    };

    /**
     * @brief Enables or disables the logging of the library.
     *
     * @param enabled Whether to enable or disable the logging.
     */
    FUNCTION_ATTRIBUTE
    void setLogEnabled(bool enabled) NOEXCEPT;

    /**
     * Returns the version of the zxing-cpp library. Pointer has a static lifetime and must not be freed.
     *
     * @return The version of the zxing-cpp library.
     */
    FUNCTION_ATTRIBUTE
    char const* version() NOEXCEPT;

    /**
     * @brief Read barcode from image bytes.
     * @param params Barcode parameters. Owned pointer. Will be freed before
     *               function returns.
     * @return The barcode result.
     */
    FUNCTION_ATTRIBUTE
    struct CodeResult readBarcode(struct DecodeBarcodeParams* params) NOEXCEPT;

    /**
     * @brief Read barcodes from image bytes.
     * @param params Barcode parameters. Owned pointer. Will be freed before
     *               function returns.
     * @return The barcode results.
     */
    FUNCTION_ATTRIBUTE
    struct CodeResults readBarcodes(struct DecodeBarcodeParams* params) NOEXCEPT;

    /**
     * @brief Encode a string into a barcode
     * @param params Encoding parameters. Owned pointer. Will be freed before
     *               function returns.
     * @return The barcode data
     */
    FUNCTION_ATTRIBUTE
    struct EncodeResult encodeBarcode(struct EncodeBarcodeParams* params) NOEXCEPT;

#ifdef __cplusplus
}
#endif
