#ifdef __cplusplus
extern "C"
{
#endif

    /**
     * @brief Format Enumerates barcode formats known to this package.
     *
     */
    enum Format
    {
        None = 0,                   ///< Used as a return value if no valid barcode has been detected
        Aztec = (1 << 0),           ///< Aztec (2D)
        Codabar = (1 << 1),         ///< Codabar (1D)
        Code39 = (1 << 2),          ///< Code39 (1D)
        Code93 = (1 << 3),          ///< Code93 (1D)
        Code128 = (1 << 4),         ///< Code128 (1D)
        DataBar = (1 << 5),         ///< GS1 DataBar, formerly known as RSS 14
        DataBarExpanded = (1 << 6), ///< GS1 DataBar Expanded, formerly known as RSS EXPANDED
        DataMatrix = (1 << 7),      ///< DataMatrix (2D)
        EAN8 = (1 << 8),            ///< EAN-8 (1D)
        EAN13 = (1 << 9),           ///< EAN-13 (1D)
        ITF = (1 << 10),            ///< ITF (Interleaved Two of Five) (1D)
        MaxiCode = (1 << 11),       ///< MaxiCode (2D)
        PDF417 = (1 << 12),         ///< PDF417 (1D) or (2D)
        QRCode = (1 << 13),         ///< QR Code (2D)
        UPCA = (1 << 14),           ///< UPC-A (1D)
        UPCE = (1 << 15),           ///< UPC-E (1D)

        OneDCodes = Codabar | Code39 | Code93 | Code128 | EAN8 | EAN13 | ITF | DataBar | DataBarExpanded | UPCA | UPCE,
        TwoDCodes = Aztec | DataMatrix | MaxiCode | PDF417 | QRCode,
        Any = OneDCodes | TwoDCodes,
    };

    /**
     * @brief Pos is a position of a barcode in a image.
     *
     */
    struct Pos
    {
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
        int isValid;                ///< Whether the barcode was successfully decoded
        char *text;                 ///< The decoded text
        const unsigned char *bytes; ///< The bytes is the raw / standard content without any modifications like character set conversions
        int length;                 ///< The length of the bytes
        enum Format format;         ///< The format of the barcode
        struct Pos *pos;            ///< The position of the barcode within the image
    };

    /**
     * @brief The CodeResults class encapsulates the result of decoding multiple barcodes within an image.
     */
    struct CodeResults
    {
        int count;                  ///< The number of barcodes detected
        struct CodeResult *results; ///< The results of the barcode decoding
    };

    /**
     * @brief EncodeResult encapsulates the result of encoding a barcode.
     *
     */
    struct EncodeResult
    {
        int isValid;              ///< Whether the barcode was successfully encoded
        char *text;               ///< The encoded text
        enum Format format;       ///< The format of the barcode
        const signed char *data; ///< The encoded data
        int length;               ///< The length of the encoded data
        char *error;              ///< The error message
    };

    /**
     * @brief Enables or disables the logging of the library.
     * @param enable Whether to enable or disable the logging.
     *
     * @param enabled
     */
    void setLogEnabled(int enable);

    /**
     * Returns the version of the zxing-cpp library.
     *
     * @return The version of the zxing-cpp library.
     */
    char const *version();

    /**
     * @brief Read barcode from image bytes.
     * @param bytes Image bytes.
     * @param format Specify a set of BarcodeFormats that should be searched for.
     * @param width Image width in pixels.
     * @param height Image height in pixels.
     * @param cropWidth Crop width.
     * @param cropHeight Crop height.
     * @param tryHarder Spend more time to try to find a barcode; optimize for accuracy, not speed.
     * @param tryRotate Also try detecting code in 90, 180 and 270 degree rotated images.
     * @return The barcode result.
     */
    struct CodeResult readBarcode(char *bytes, int format, int width, int height, int cropWidth, int cropHeight, int tryHarder, int tryRotate);

    /**
     * @brief Read barcodes from image bytes.
     * @param bytes Image bytes.
     * @param format Specify a set of BarcodeFormats that should be searched for.
     * @param width Image width in pixels.
     * @param height Image height in pixels.
     * @param cropWidth Crop width.
     * @param cropHeight Crop height.
     * @param tryHarder Spend more time to try to find a barcode, optimize for accuracy, not speed.
     * @param tryRotate Also try detecting code in 90, 180 and 270 degree rotated images.
     * @return The barcode results.
     */
    struct CodeResults readBarcodes(char *bytes, int format, int width, int height, int cropWidth, int cropHeight, int tryHarder, int tryRotate);

    /**
     * @brief Encode a string into a barcode
     * @param contents The string to encode
     * @param width The width of the barcode in pixels.
     * @param height The height of the barcode in pixels.
     * @param format The format of the barcode
     * @param margin The margin of the barcode
     * @param eccLevel The error correction level of the barcode. Used for Aztec, PDF417, and QRCode only, [0-8].
     * @return The barcode data
     */
    struct EncodeResult encodeBarcode(char *contents, int width, int height, int format, int margin, int eccLevel);

    // Private functions

    void resultToCodeResult(struct CodeResult *code, ZXing::Result result);

#ifdef __cplusplus
}
#endif