#ifdef __cplusplus
    #include <cstdint>
#else
    #include <stdbool.h>
    #include <stdint.h>
#endif

#ifdef __cplusplus
extern "C"
{
#endif

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
        char *text;                 ///< The decoded text. Owned pointer. Must be freed by Dart code if not null.
        bool isValid;               ///< Whether the barcode was successfully decoded
        char *error;                ///< The error message. Owned pointer. Must be freed by Dart code if not null.
        uint8_t* bytes;             ///< The bytes is the raw content without any character set conversions. Owned pointer. Must be freed by Dart code if not null.
        int length;                 ///< The length of the bytes
        int format;                 ///< The format of the barcode
        struct Pos pos;             ///< The position of the barcode within the image
        bool isInverted;            ///< Whether the barcode was inverted
        bool isMirrored;            ///< Whether the barcode was mirrored
        int duration;               ///< The duration of the decoding in milliseconds
    };

    /**
     * @brief The CodeResults class encapsulates the result of decoding multiple barcodes within an image.
     */
    struct CodeResults
    {
        int count;                  ///< The number of barcodes detected
        struct CodeResult *results; ///< The results of the barcode decoding. Owned pointer. Must be freed by Dart code.
        int duration;               ///< The duration of the decoding in milliseconds
    };

    /**
     * @brief EncodeResult encapsulates the result of encoding a barcode.
     *
     */
    struct EncodeResult
    {
        bool isValid;             ///< Whether the barcode was successfully encoded
        char *text;               ///< The encoded text. Owned pointer. Must be freed by Dart code if not null.
        int format;               ///< The format of the barcode
        uint8_t* data;            ///< The encoded data. Owned pointer. Must be freed by Dart code if not null.
        int length;               ///< The length of the encoded data
        char *error;              ///< The error message. Owned pointer. Must be freed by Dart code if not null.
    };

    /**
     * @brief Enables or disables the logging of the library.
     *
     * @param enabled Whether to enable or disable the logging.
     */
    void setLogEnabled(bool enabled);

    /**
     * Returns the version of the zxing-cpp library. Pointer has a static lifetime and must not be freed.
     *
     * @return The version of the zxing-cpp library.
     */
    char const *version();

    /**
     * @brief Read barcode from image bytes.
     * @param bytes Image bytes. Owned pointer. Will be freed by native code.
     * @param imageFormat Image format.
     * @param format Specify a set of BarcodeFormats that should be searched for.
     * @param width Image width in pixels.
     * @param height Image height in pixels.
     * @param cropWidth Crop width.
     * @param cropHeight Crop height.
     * @param tryHarder Spend more time to try to find a barcode; optimize for accuracy, not speed.
     * @param tryRotate Also try detecting code in 90, 180 and 270 degree rotated images.
     * @return The barcode result.
     */
    struct CodeResult readBarcode(uint8_t* bytes, int imageFormat, int format, int width, int height, int cropWidth, int cropHeight, bool tryHarder, bool tryRotate, bool tryInvert);

    /**
     * @brief Read barcodes from image bytes.
     * @param bytes Image bytes. Owned pointer. Will be freed by native code.
     * @param imageFormat Image format.
     * @param format Specify a set of BarcodeFormats that should be searched for.
     * @param width Image width in pixels.
     * @param height Image height in pixels.
     * @param cropWidth Crop width.
     * @param cropHeight Crop height.
     * @param tryHarder Spend more time to try to find a barcode, optimize for accuracy, not speed.
     * @param tryRotate Also try detecting code in 90, 180 and 270 degree rotated images.
     * @return The barcode results.
     */
    struct CodeResults readBarcodes(uint8_t* bytes, int imageFormat, int format, int width, int height, int cropWidth, int cropHeight, bool tryHarder, bool tryRotate, bool tryInvert);

    /**
     * @brief Encode a string into a barcode
     * @param contents The string to encode. Owned pointer. Will be freed by native code.
     * @param width The width of the barcode in pixels.
     * @param height The height of the barcode in pixels.
     * @param format The format of the barcode
     * @param margin The margin of the barcode
     * @param eccLevel The error correction level of the barcode. Used for Aztec, PDF417, and QRCode only, [0-8].
     * @return The barcode data.
     */
    struct EncodeResult encodeBarcode(char* contents, int width, int height, int format, int margin, int eccLevel);

#ifdef __cplusplus
}
#endif
