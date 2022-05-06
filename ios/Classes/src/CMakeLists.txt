cmake_minimum_required(VERSION 3.10)

project(flutter_zxing LANGUAGES C CXX)

set(CPP_PATH ${CMAKE_SOURCE_DIR})
set(ZXING_PATH ${CPP_PATH}/zxing/src)

add_library(
    flutter_zxing
    SHARED
    ${CPP_PATH}/common.cpp
    ${CPP_PATH}/native_zxing.cpp
)


# ZXing library

include_directories(${ZXING_PATH})

if (NOT DEFINED BUILD_WRITERS)
    set (BUILD_WRITERS ON)
endif()

if (NOT DEFINED BUILD_READERS)
    set (BUILD_READERS ON)
endif()


set (COMMON_FILES
    ${ZXING_PATH}/BarcodeFormat.h
    ${ZXING_PATH}/BarcodeFormat.cpp
    ${ZXING_PATH}/BitArray.h
    ${ZXING_PATH}/BitArray.cpp
    ${ZXING_PATH}/BitHacks.h
    ${ZXING_PATH}/BitMatrix.h
    ${ZXING_PATH}/BitMatrix.cpp
    ${ZXING_PATH}/BitMatrixCursor.h
    ${ZXING_PATH}/BitMatrixIO.h
    ${ZXING_PATH}/BitMatrixIO.cpp
    ${ZXING_PATH}/ByteArray.h
    ${ZXING_PATH}/ByteMatrix.h
    ${ZXING_PATH}/CharacterSet.h
    ${ZXING_PATH}/CharacterSetECI.h
    ${ZXING_PATH}/CharacterSetECI.cpp
    ${ZXING_PATH}/ConcentricFinder.h
    ${ZXING_PATH}/ConcentricFinder.cpp
    ${ZXING_PATH}/CustomData.h
    ${ZXING_PATH}/Flags.h
    ${ZXING_PATH}/GenericGF.h
    ${ZXING_PATH}/GenericGF.cpp
    ${ZXING_PATH}/GenericGFPoly.h
    ${ZXING_PATH}/GenericGFPoly.cpp
    ${ZXING_PATH}/GTIN.h
    ${ZXING_PATH}/GTIN.cpp
    ${ZXING_PATH}/LogMatrix.h
    ${ZXING_PATH}/Matrix.h
    ${ZXING_PATH}/Pattern.h
    ${ZXING_PATH}/Point.h
    ${ZXING_PATH}/Quadrilateral.h
    ${ZXING_PATH}/RegressionLine.h
    ${ZXING_PATH}/Scope.h
    ${ZXING_PATH}/TextUtfEncoding.h
    ${ZXING_PATH}/TextUtfEncoding.cpp
    ${ZXING_PATH}/TritMatrix.h
    ${ZXING_PATH}/ZXBigInteger.h
    ${ZXING_PATH}/ZXBigInteger.cpp
    ${ZXING_PATH}/ZXConfig.h
    ${ZXING_PATH}/ZXNullable.h
    ${ZXING_PATH}/ZXContainerAlgorithms.h
    ${ZXING_PATH}/ZXTestSupport.h
)
if (BUILD_READERS)
    set (COMMON_FILES ${COMMON_FILES}
        ${ZXING_PATH}/BinaryBitmap.h
        ${ZXING_PATH}/BinaryBitmap.cpp
        ${ZXING_PATH}/BitSource.h
        ${ZXING_PATH}/BitSource.cpp
        ${ZXING_PATH}/DecodeHints.h
        ${ZXING_PATH}/DecodeHints.cpp
        ${ZXING_PATH}/DecodeStatus.h
        ${ZXING_PATH}/DecodeStatus.cpp
        ${ZXING_PATH}/DecoderResult.h
        ${ZXING_PATH}/DetectorResult.h
        ${ZXING_PATH}/GlobalHistogramBinarizer.h
        ${ZXING_PATH}/GlobalHistogramBinarizer.cpp
        ${ZXING_PATH}/GridSampler.h
        ${ZXING_PATH}/GridSampler.cpp
        ${ZXING_PATH}/HybridBinarizer.h
        ${ZXING_PATH}/HybridBinarizer.cpp
        ${ZXING_PATH}/ImageView.h
        ${ZXING_PATH}/MultiFormatReader.h
        ${ZXING_PATH}/MultiFormatReader.cpp
        ${ZXING_PATH}/PerspectiveTransform.h
        ${ZXING_PATH}/PerspectiveTransform.cpp
        ${ZXING_PATH}/Reader.h
        ${ZXING_PATH}/ReadBarcode.h
        ${ZXING_PATH}/ReadBarcode.cpp
        ${ZXING_PATH}/ReedSolomonDecoder.h
        ${ZXING_PATH}/ReedSolomonDecoder.cpp
        ${ZXING_PATH}/Result.h
        ${ZXING_PATH}/Result.cpp
        ${ZXING_PATH}/ResultPoint.h
        ${ZXING_PATH}/ResultPoint.cpp
        ${ZXING_PATH}/TextDecoder.h
        ${ZXING_PATH}/TextDecoder.cpp
        ${ZXING_PATH}/ThresholdBinarizer.h
        ${ZXING_PATH}/WhiteRectDetector.h
        ${ZXING_PATH}/WhiteRectDetector.cpp
    )
endif()
if (BUILD_WRITERS)
    set (COMMON_FILES ${COMMON_FILES}
        ${ZXING_PATH}/ByteMatrix.h
        ${ZXING_PATH}/ReedSolomonEncoder.h
        ${ZXING_PATH}/ReedSolomonEncoder.cpp
        ${ZXING_PATH}/TextEncoder.h
        ${ZXING_PATH}/TextEncoder.cpp
        ${ZXING_PATH}/MultiFormatWriter.h
        ${ZXING_PATH}/MultiFormatWriter.cpp
    )
endif()


set (AZTEC_FILES
)
if (BUILD_READERS)
    set (AZTEC_FILES ${AZTEC_FILES}
        ${ZXING_PATH}/aztec/AZDecoder.h
        ${ZXING_PATH}/aztec/AZDecoder.cpp
        ${ZXING_PATH}/aztec/AZDetector.h
        ${ZXING_PATH}/aztec/AZDetector.cpp
        ${ZXING_PATH}/aztec/AZDetectorResult.h
        ${ZXING_PATH}/aztec/AZReader.h
        ${ZXING_PATH}/aztec/AZReader.cpp
    )
endif()
if (BUILD_WRITERS)
    set (AZTEC_FILES ${AZTEC_FILES}
        ${ZXING_PATH}/aztec/AZEncodingState.h
        ${ZXING_PATH}/aztec/AZEncoder.h
        ${ZXING_PATH}/aztec/AZEncoder.cpp
        ${ZXING_PATH}/aztec/AZHighLevelEncoder.h
        ${ZXING_PATH}/aztec/AZHighLevelEncoder.cpp
        ${ZXING_PATH}/aztec/AZToken.h
        ${ZXING_PATH}/aztec/AZToken.cpp
        ${ZXING_PATH}/aztec/AZWriter.h
        ${ZXING_PATH}/aztec/AZWriter.cpp
    )
endif()


set (DATAMATRIX_FILES
    ${ZXING_PATH}/datamatrix/DMBitLayout.h
    ${ZXING_PATH}/datamatrix/DMBitLayout.cpp
    ${ZXING_PATH}/datamatrix/DMVersion.h
    ${ZXING_PATH}/datamatrix/DMVersion.cpp
)
if (BUILD_READERS)
    set (DATAMATRIX_FILES ${DATAMATRIX_FILES}
        ${ZXING_PATH}/datamatrix/DMDataBlock.h
        ${ZXING_PATH}/datamatrix/DMDataBlock.cpp
        ${ZXING_PATH}/datamatrix/DMDecoder.h
        ${ZXING_PATH}/datamatrix/DMDecoder.cpp
        ${ZXING_PATH}/datamatrix/DMDetector.h
        ${ZXING_PATH}/datamatrix/DMDetector.cpp
        ${ZXING_PATH}/datamatrix/DMReader.h
        ${ZXING_PATH}/datamatrix/DMReader.cpp
    )
endif()
if (BUILD_WRITERS)
    set (DATAMATRIX_FILES ${DATAMATRIX_FILES}
        ${ZXING_PATH}/datamatrix/DMECEncoder.h
        ${ZXING_PATH}/datamatrix/DMECEncoder.cpp
        ${ZXING_PATH}/datamatrix/DMEncoderContext.h
        ${ZXING_PATH}/datamatrix/DMHighLevelEncoder.h
        ${ZXING_PATH}/datamatrix/DMHighLevelEncoder.cpp
        ${ZXING_PATH}/datamatrix/DMSymbolInfo.h
        ${ZXING_PATH}/datamatrix/DMSymbolInfo.cpp
        ${ZXING_PATH}/datamatrix/DMSymbolShape.h
        ${ZXING_PATH}/datamatrix/DMWriter.h
        ${ZXING_PATH}/datamatrix/DMWriter.cpp
    )
endif()


set (MAXICODE_FILES
)
if (BUILD_READERS)
    set (MAXICODE_FILES ${MAXICODE_FILES}
        ${ZXING_PATH}/maxicode/MCBitMatrixParser.h
        ${ZXING_PATH}/maxicode/MCBitMatrixParser.cpp
        ${ZXING_PATH}/maxicode/MCDecoder.h
        ${ZXING_PATH}/maxicode/MCDecoder.cpp
        ${ZXING_PATH}/maxicode/MCReader.h
        ${ZXING_PATH}/maxicode/MCReader.cpp
    )
endif()


set (ONED_FILES
    ${ZXING_PATH}/oned/ODUPCEANCommon.h
    ${ZXING_PATH}/oned/ODUPCEANCommon.cpp
    ${ZXING_PATH}/oned/ODCode128Patterns.h
    ${ZXING_PATH}/oned/ODCode128Patterns.cpp
)
if (BUILD_READERS)
    set (ONED_FILES ${ONED_FILES}
        ${ZXING_PATH}/oned/ODCodabarReader.h
        ${ZXING_PATH}/oned/ODCodabarReader.cpp
        ${ZXING_PATH}/oned/ODCode39Reader.h
        ${ZXING_PATH}/oned/ODCode39Reader.cpp
        ${ZXING_PATH}/oned/ODCode93Reader.h
        ${ZXING_PATH}/oned/ODCode93Reader.cpp
        ${ZXING_PATH}/oned/ODCode128Reader.h
        ${ZXING_PATH}/oned/ODCode128Reader.cpp
        ${ZXING_PATH}/oned/ODDataBarCommon.h
        ${ZXING_PATH}/oned/ODDataBarCommon.cpp
        ${ZXING_PATH}/oned/ODDataBarReader.h
        ${ZXING_PATH}/oned/ODDataBarReader.cpp
        ${ZXING_PATH}/oned/ODDataBarExpandedReader.h
        ${ZXING_PATH}/oned/ODDataBarExpandedReader.cpp
        ${ZXING_PATH}/oned/ODITFReader.h
        ${ZXING_PATH}/oned/ODITFReader.cpp
        ${ZXING_PATH}/oned/ODMultiUPCEANReader.h
        ${ZXING_PATH}/oned/ODMultiUPCEANReader.cpp
        ${ZXING_PATH}/oned/ODReader.h
        ${ZXING_PATH}/oned/ODReader.cpp
        ${ZXING_PATH}/oned/ODRowReader.h
        ${ZXING_PATH}/oned/ODRowReader.cpp
    )
endif()
if (BUILD_WRITERS)
    set (ONED_FILES ${ONED_FILES}
        ${ZXING_PATH}/oned/ODCodabarWriter.h
        ${ZXING_PATH}/oned/ODCodabarWriter.cpp
        ${ZXING_PATH}/oned/ODCode39Writer.h
        ${ZXING_PATH}/oned/ODCode39Writer.cpp
        ${ZXING_PATH}/oned/ODCode93Writer.h
        ${ZXING_PATH}/oned/ODCode93Writer.cpp
        ${ZXING_PATH}/oned/ODCode128Writer.h
        ${ZXING_PATH}/oned/ODCode128Writer.cpp
        ${ZXING_PATH}/oned/ODEAN8Writer.h
        ${ZXING_PATH}/oned/ODEAN8Writer.cpp
        ${ZXING_PATH}/oned/ODEAN13Writer.h
        ${ZXING_PATH}/oned/ODEAN13Writer.cpp
        ${ZXING_PATH}/oned/ODITFWriter.h
        ${ZXING_PATH}/oned/ODITFWriter.cpp
        ${ZXING_PATH}/oned/ODUPCEWriter.h
        ${ZXING_PATH}/oned/ODUPCEWriter.cpp
        ${ZXING_PATH}/oned/ODUPCAWriter.h
        ${ZXING_PATH}/oned/ODUPCAWriter.cpp
        ${ZXING_PATH}/oned/ODWriterHelper.h
        ${ZXING_PATH}/oned/ODWriterHelper.cpp
    )
endif()


set (ONED_RSS_FILES
)
if (BUILD_READERS)
    set (ONED_RSS_FILES ${ONED_RSS_FILES}
        ${ZXING_PATH}/oned/rss/ODRSSExpandedBinaryDecoder.h
        ${ZXING_PATH}/oned/rss/ODRSSExpandedBinaryDecoder.cpp
        ${ZXING_PATH}/oned/rss/ODRSSFieldParser.h
        ${ZXING_PATH}/oned/rss/ODRSSFieldParser.cpp
        ${ZXING_PATH}/oned/rss/ODRSSGenericAppIdDecoder.h
        ${ZXING_PATH}/oned/rss/ODRSSGenericAppIdDecoder.cpp
    )
endif()


set (PDF417_FILES
)
if (BUILD_READERS)
    set (PDF417_FILES ${PDF417_FILES}
        ${ZXING_PATH}/pdf417/PDFBarcodeMetadata.h
        ${ZXING_PATH}/pdf417/PDFBarcodeValue.h
        ${ZXING_PATH}/pdf417/PDFBarcodeValue.cpp
        ${ZXING_PATH}/pdf417/PDFBoundingBox.h
        ${ZXING_PATH}/pdf417/PDFBoundingBox.cpp
        ${ZXING_PATH}/pdf417/PDFCodeword.h
        ${ZXING_PATH}/pdf417/PDFCodewordDecoder.h
        ${ZXING_PATH}/pdf417/PDFCodewordDecoder.cpp
        ${ZXING_PATH}/pdf417/PDFDecodedBitStreamParser.h
        ${ZXING_PATH}/pdf417/PDFDecodedBitStreamParser.cpp
        ${ZXING_PATH}/pdf417/PDFDecoderResultExtra.h
        ${ZXING_PATH}/pdf417/PDFDetectionResult.h
        ${ZXING_PATH}/pdf417/PDFDetectionResult.cpp
        ${ZXING_PATH}/pdf417/PDFDetectionResultColumn.h
        ${ZXING_PATH}/pdf417/PDFDetectionResultColumn.cpp
        ${ZXING_PATH}/pdf417/PDFDetector.h
        ${ZXING_PATH}/pdf417/PDFDetector.cpp
        ${ZXING_PATH}/pdf417/PDFModulusGF.h
        ${ZXING_PATH}/pdf417/PDFModulusGF.cpp
        ${ZXING_PATH}/pdf417/PDFModulusPoly.h
        ${ZXING_PATH}/pdf417/PDFModulusPoly.cpp
        ${ZXING_PATH}/pdf417/PDFReader.h
        ${ZXING_PATH}/pdf417/PDFReader.cpp
        ${ZXING_PATH}/pdf417/PDFScanningDecoder.h
        ${ZXING_PATH}/pdf417/PDFScanningDecoder.cpp
    )
endif()
if (BUILD_WRITERS)
    set (PDF417_FILES ${PDF417_FILES}
        ${ZXING_PATH}/pdf417/PDFCompaction.h
        ${ZXING_PATH}/pdf417/PDFEncoder.h
        ${ZXING_PATH}/pdf417/PDFEncoder.cpp
        ${ZXING_PATH}/pdf417/PDFHighLevelEncoder.h
        ${ZXING_PATH}/pdf417/PDFHighLevelEncoder.cpp
        ${ZXING_PATH}/pdf417/PDFWriter.h
        ${ZXING_PATH}/pdf417/PDFWriter.cpp
    )
endif()


set (QRCODE_FILES
    ${ZXING_PATH}/qrcode/QRCodecMode.h
    ${ZXING_PATH}/qrcode/QRCodecMode.cpp
    ${ZXING_PATH}/qrcode/QRErrorCorrectionLevel.h
    ${ZXING_PATH}/qrcode/QRErrorCorrectionLevel.cpp
    ${ZXING_PATH}/qrcode/QRVersion.h
    ${ZXING_PATH}/qrcode/QRVersion.cpp
)
if (BUILD_READERS)
    set (QRCODE_FILES ${QRCODE_FILES}
        ${ZXING_PATH}/qrcode/QRBitMatrixParser.h
        ${ZXING_PATH}/qrcode/QRBitMatrixParser.cpp
        ${ZXING_PATH}/qrcode/QRDataBlock.h
        ${ZXING_PATH}/qrcode/QRDataBlock.cpp
        ${ZXING_PATH}/qrcode/QRDataMask.h
        ${ZXING_PATH}/qrcode/QRDecoder.h
        ${ZXING_PATH}/qrcode/QRDecoder.cpp
        ${ZXING_PATH}/qrcode/QRDetector.h
        ${ZXING_PATH}/qrcode/QRDetector.cpp
        ${ZXING_PATH}/qrcode/QRECB.h
        ${ZXING_PATH}/qrcode/QRFormatInformation.h
        ${ZXING_PATH}/qrcode/QRFormatInformation.cpp
        ${ZXING_PATH}/qrcode/QRReader.h
        ${ZXING_PATH}/qrcode/QRReader.cpp
    )
endif()
if (BUILD_WRITERS)
    set (QRCODE_FILES ${QRCODE_FILES}
        ${ZXING_PATH}/qrcode/QREncoder.h
        ${ZXING_PATH}/qrcode/QREncoder.cpp
        ${ZXING_PATH}/qrcode/QREncodeResult.h
        ${ZXING_PATH}/qrcode/QRMaskUtil.h
        ${ZXING_PATH}/qrcode/QRMaskUtil.cpp
        ${ZXING_PATH}/qrcode/QRMatrixUtil.h
        ${ZXING_PATH}/qrcode/QRMatrixUtil.cpp
        ${ZXING_PATH}/qrcode/QRWriter.h
        ${ZXING_PATH}/qrcode/QRWriter.cpp
    )
endif()


set (TEXT_CODEC_FILES
    ${ZXING_PATH}/textcodec/Big5MapTable.h
    ${ZXING_PATH}/textcodec/Big5MapTable.cpp
    ${ZXING_PATH}/textcodec/KRHangulMapping.h
    ${ZXING_PATH}/textcodec/KRHangulMapping.cpp
)
if (BUILD_READERS)
    set (TEXT_CODEC_FILES ${TEXT_CODEC_FILES}
        ${ZXING_PATH}/textcodec/Big5TextDecoder.h
        ${ZXING_PATH}/textcodec/Big5TextDecoder.cpp
        ${ZXING_PATH}/textcodec/GBTextDecoder.h
        ${ZXING_PATH}/textcodec/GBTextDecoder.cpp
        ${ZXING_PATH}/textcodec/JPTextDecoder.h
        ${ZXING_PATH}/textcodec/JPTextDecoder.cpp
        ${ZXING_PATH}/textcodec/KRTextDecoder.h
        ${ZXING_PATH}/textcodec/KRTextDecoder.cpp
    )
endif()
if (BUILD_WRITERS)
    set (TEXT_CODEC_FILES ${TEXT_CODEC_FILES}
        ${ZXING_PATH}/textcodec/Big5TextEncoder.h
        ${ZXING_PATH}/textcodec/Big5TextEncoder.cpp
        ${ZXING_PATH}/textcodec/GBTextEncoder.h
        ${ZXING_PATH}/textcodec/GBTextEncoder.cpp
        ${ZXING_PATH}/textcodec/JPTextEncoder.h
        ${ZXING_PATH}/textcodec/JPTextEncoder.cpp
        ${ZXING_PATH}/textcodec/KRTextEncoder.h
        ${ZXING_PATH}/textcodec/KRTextEncoder.cpp
    )
endif()

add_library (ZXing
    ${COMMON_FILES}
    ${AZTEC_FILES}
    ${DATAMATRIX_FILES}
    ${MAXICODE_FILES}
    ${ONED_FILES}
    ${ONED_RSS_FILES}
    ${PDF417_FILES}
    ${QRCODE_FILES}
    ${TEXT_CODEC_FILES}
)

# End of ZXing


find_library(log-lib log)
target_link_libraries(flutter_zxing ZXing ${log-lib})