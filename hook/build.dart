// Builds the fzx engine library with Dart build hooks (native assets).
//
// No CMake, no podspec, no Gradle externalNativeBuild, no copied sources: the
// same hook builds for Android, iOS, macOS, Linux and Windows, and the SDK
// caches the result until a source file changes.
//
// zxing-cpp is compiled in parallel chunks into static libraries (one C
// builder compiles its files one after another), which are then linked into
// one shared library that exports only the fzx_* functions of native/fzx.h.
//
// The source list and defines at the end of this file come from zxing-cpp's
// CMake build, see tool/gen_sources.dart. They live in this file because
// pub.dev accepts no other files in hook/ yet.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Number of static libraries zxing-cpp's C++ sources are split into.
const int _chunks = 8;

const List<String> _includes = <String>[
  'third_party/zxing-cpp/core/src',
  'third_party/zxing-cpp/core/src/libzint',
  'native/generated',
  'third_party/stb',
];

void main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final Logger logger = Logger('')
      ..level = Level.INFO
      // stdout: Flutter labels every stderr line of a hook as an error.
      ..onRecord.listen((LogRecord r) => stdout.writeln(r.message));
    final OS os = input.config.code.targetOS;
    final bool apple = os == OS.iOS || os == OS.macOS;
    final bool windows = os == OS.windows;

    // MSVC: C++ exceptions, UTF-8 sources, per-function sections (the release
    // linker drops unused ones by default), parallel compilation inside one
    // cl call. clang/gcc everywhere else: hidden symbols and per-function
    // sections, so dead code is stripped at link time.
    final List<String> flags = windows
        ? const <String>['/EHsc', '/utf-8', '/Gy', '/Gw', '/MP', '/DNOMINMAX']
        : const <String>[
            '-fvisibility=hidden',
            '-fvisibility-inlines-hidden',
            '-ffunction-sections',
            '-fdata-sections',
          ];
    Map<String, String?> defines(List<String> names) => <String, String?>{
      for (final String d in names) ..._define(d),
    };

    // 1. zxing-cpp's C++ sources, in parallel chunks.
    final int chunkSize = (zxingCppSources.length / _chunks).ceil();
    final List<String> libraries = <String>[];
    final List<CBuilder> builders = <CBuilder>[];
    for (int i = 0; i * chunkSize < zxingCppSources.length; i++) {
      libraries.add('fzx_core$i');
      builders.add(
        CBuilder.library(
          name: 'fzx_core$i',
          sources: zxingCppSources.skip(i * chunkSize).take(chunkSize).toList(),
          includes: _includes,
          defines: defines(zxingCppDefines),
          flags: flags,
          language: Language.cpp,
          std: 'c++20',
          linkModePreference: LinkModePreference.static,
        ),
      );
    }
    // 2. The bundled zint subset and zueci (C).
    libraries.add('fzx_zint');
    builders.add(
      CBuilder.library(
        name: 'fzx_zint',
        sources: zxingCSources,
        includes: _includes,
        defines: defines(zxingCDefines),
        flags: flags,
        linkModePreference: LinkModePreference.static,
      ),
    );
    // A C builder names its object files out0.o, out1.o... in the output
    // directory, so parallel builders need a directory each. The static
    // libraries are intermediates: without an assetName they are not
    // reported as assets.
    final List<String> libraryDirectories = <String>[];
    await Future.wait(<Future<void>>[
      for (final (int i, CBuilder builder) in builders.indexed)
        () {
          final BuildInput part = BuildInput(<String, Object?>{
            ...input.json,
            'out_dir_shared': input.outputDirectory
                .resolve('part$i/')
                .toFilePath(),
          });
          libraryDirectories.add(part.outputDirectory.toFilePath());
          return builder.run(input: part, output: output, logger: logger);
        }(),
    ]);

    // 3. The shared library with the C ABI.
    await CBuilder.library(
      name: 'fzx',
      assetName: 'fzx',
      sources: const <String>['native/fzx.cpp'],
      includes: _includes,
      defines: defines(zxingCppDefines),
      flags: <String>[
        ...flags,
        if (apple) '-Wl,-dead_strip' else if (!windows) '-Wl,--gc-sections',
        // Keep the symbols of the static libraries out of the export table.
        if (!apple && !windows) '-Wl,--exclude-libs,ALL',
        // 16 KB pages (Android 15+). NDK 28 and later already default to it.
        if (os == OS.android) '-Wl,-z,max-page-size=16384',
        // Linux: the unwinder linked in as well, see cppLinkStdLib.
        if (os == OS.linux) '-static-libgcc',
      ],
      language: Language.cpp,
      std: 'c++20',
      // One self-contained library, with the C++ runtime inside and its
      // symbols hidden (--exclude-libs above).
      // - Android: no libc++_shared.so to ship (dlopen fails without it).
      // - Linux: static libstdc++ (`-l:libstdc++.a`) and libgcc. Flutter
      //   3.50's Linux engine exports _Unwind_RaiseException from its own
      //   libunwind; a shared libstdc++ binds to it, and the first C++
      //   exception zxing-cpp throws (and catches) crashes the app.
      cppLinkStdLib: switch (os) {
        OS.android => 'c++_static',
        OS.linux => ':libstdc++.a',
        _ => null,
      },
      libraries: <String>[
        ...libraries,
        // GNU ld (Linux) scans each archive once, in order, so references
        // between the chunks need the list repeated. lld (Android) and ld64
        // (Apple) do not care about the order.
        if (os == OS.linux) ...<String>[...libraries, ...libraries],
        // libm explicitly: Android's dlopen fails with `cannot locate symbol
        // "atan2"` otherwise.
        if (os == OS.android || os == OS.linux) 'm',
        // Again after the objects: the C builder puts cppLinkStdLib before
        // them, and GNU ld takes from an archive only what is undefined when
        // it gets there.
        if (os == OS.linux) ':libstdc++.a',
      ],
      libraryDirectories: libraryDirectories,
    ).run(input: input, output: output, logger: logger);

    output.dependencies.addAll(<Uri>[
      for (final String s in <String>[
        ...zxingCppSources,
        ...zxingCSources,
        'native/fzx.cpp',
        'native/fzx.h',
        'native/generated/Version.h',
      ])
        input.packageRoot.resolve(s),
    ]);
  });
}

/// `NAME` or `NAME=VALUE` as a C builder define.
Map<String, String?> _define(String d) {
  final int eq = d.indexOf('=');
  return eq < 0
      ? <String, String?>{d: null}
      : <String, String?>{d.substring(0, eq): d.substring(eq + 1)};
}

// BEGIN GENERATED by tool/gen_sources.dart from zxing-cpp's CMake build.
// Do not edit.

const List<String> zxingCppSources = <String>[
  'third_party/zxing-cpp/core/src/Barcode.cpp',
  'third_party/zxing-cpp/core/src/BarcodeFormat.cpp',
  'third_party/zxing-cpp/core/src/BinaryBitmap.cpp',
  'third_party/zxing-cpp/core/src/BitArray.cpp',
  'third_party/zxing-cpp/core/src/BitMatrix.cpp',
  'third_party/zxing-cpp/core/src/BitMatrixIO.cpp',
  'third_party/zxing-cpp/core/src/BitSource.cpp',
  'third_party/zxing-cpp/core/src/CharacterSet.cpp',
  'third_party/zxing-cpp/core/src/ConcentricFinder.cpp',
  'third_party/zxing-cpp/core/src/Content.cpp',
  'third_party/zxing-cpp/core/src/CreateBarcode.cpp',
  'third_party/zxing-cpp/core/src/ECI.cpp',
  'third_party/zxing-cpp/core/src/Error.cpp',
  'third_party/zxing-cpp/core/src/GTIN.cpp',
  'third_party/zxing-cpp/core/src/GlobalHistogramBinarizer.cpp',
  'third_party/zxing-cpp/core/src/GridSampler.cpp',
  'third_party/zxing-cpp/core/src/HRI.cpp',
  'third_party/zxing-cpp/core/src/HybridBinarizer.cpp',
  'third_party/zxing-cpp/core/src/JSON.cpp',
  'third_party/zxing-cpp/core/src/LocalGrid.cpp',
  'third_party/zxing-cpp/core/src/MultiFormatReader.cpp',
  'third_party/zxing-cpp/core/src/PerspectiveTransform.cpp',
  'third_party/zxing-cpp/core/src/ReadBarcode.cpp',
  'third_party/zxing-cpp/core/src/ReedSolomon.cpp',
  'third_party/zxing-cpp/core/src/ResultPoint.cpp',
  'third_party/zxing-cpp/core/src/TextDecoder.cpp',
  'third_party/zxing-cpp/core/src/TextEncoder.cpp',
  'third_party/zxing-cpp/core/src/Utf.cpp',
  'third_party/zxing-cpp/core/src/WhiteRectDetector.cpp',
  'third_party/zxing-cpp/core/src/WriteBarcode.cpp',
  'third_party/zxing-cpp/core/src/ZXingCpp.cpp',
  'third_party/zxing-cpp/core/src/aztec/AZDecoder.cpp',
  'third_party/zxing-cpp/core/src/aztec/AZDetector.cpp',
  'third_party/zxing-cpp/core/src/aztec/AZReader.cpp',
  'third_party/zxing-cpp/core/src/datamatrix/DMBitLayout.cpp',
  'third_party/zxing-cpp/core/src/datamatrix/DMDataBlock.cpp',
  'third_party/zxing-cpp/core/src/datamatrix/DMDecoder.cpp',
  'third_party/zxing-cpp/core/src/datamatrix/DMDetector.cpp',
  'third_party/zxing-cpp/core/src/datamatrix/DMReader.cpp',
  'third_party/zxing-cpp/core/src/datamatrix/DMVersion.cpp',
  'third_party/zxing-cpp/core/src/maxicode/MCBitMatrixParser.cpp',
  'third_party/zxing-cpp/core/src/maxicode/MCDecoder.cpp',
  'third_party/zxing-cpp/core/src/maxicode/MCReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODCodabarReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODCode128Reader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODCode39Reader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODCode93Reader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODDXFilmEdgeReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODDataBarCommon.cpp',
  'third_party/zxing-cpp/core/src/oned/ODDataBarExpandedBitDecoder.cpp',
  'third_party/zxing-cpp/core/src/oned/ODDataBarExpandedReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODDataBarLimitedReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODDataBarReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODITFReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODMultiUPCEANReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODTelepenReader.cpp',
  'third_party/zxing-cpp/core/src/oned/ODUPCEANCommon.cpp',
  'third_party/zxing-cpp/core/src/pdf417/MicroPDFReader.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDF417.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFBarcodeValue.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFBoundingBox.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFCodewordDecoder.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFDecoder.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFDetectionResult.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFDetectionResultColumn.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFDetector.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFReader.cpp',
  'third_party/zxing-cpp/core/src/pdf417/PDFScanningDecoder.cpp',
  'third_party/zxing-cpp/core/src/pdf417/ZXBigInteger.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRBitMatrixParser.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRCodecMode.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRDataBlock.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRDecoder.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRDetector.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRErrorCorrectionLevel.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRFormatInformation.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRReader.cpp',
  'third_party/zxing-cpp/core/src/qrcode/QRVersion.cpp',
];

const List<String> zxingCSources = <String>[
  'third_party/zxing-cpp/core/src/libzint/2of5inter.c',
  'third_party/zxing-cpp/core/src/libzint/2of5inter_based.c',
  'third_party/zxing-cpp/core/src/libzint/aztec.c',
  'third_party/zxing-cpp/core/src/libzint/codabar.c',
  'third_party/zxing-cpp/core/src/libzint/code.c',
  'third_party/zxing-cpp/core/src/libzint/code128.c',
  'third_party/zxing-cpp/core/src/libzint/common.c',
  'third_party/zxing-cpp/core/src/libzint/dmatrix.c',
  'third_party/zxing-cpp/core/src/libzint/dxfilmedge.c',
  'third_party/zxing-cpp/core/src/libzint/eci.c',
  'third_party/zxing-cpp/core/src/libzint/filemem.c',
  'third_party/zxing-cpp/core/src/libzint/general_field.c',
  'third_party/zxing-cpp/core/src/libzint/gs1.c',
  'third_party/zxing-cpp/core/src/libzint/large.c',
  'third_party/zxing-cpp/core/src/libzint/library.c',
  'third_party/zxing-cpp/core/src/libzint/maxicode.c',
  'third_party/zxing-cpp/core/src/libzint/medical.c',
  'third_party/zxing-cpp/core/src/libzint/output.c',
  'third_party/zxing-cpp/core/src/libzint/pdf417.c',
  'third_party/zxing-cpp/core/src/libzint/qr.c',
  'third_party/zxing-cpp/core/src/libzint/raster.c',
  'third_party/zxing-cpp/core/src/libzint/reedsol.c',
  'third_party/zxing-cpp/core/src/libzint/rss.c',
  'third_party/zxing-cpp/core/src/libzint/stubs.c',
  'third_party/zxing-cpp/core/src/libzint/svg.c',
  'third_party/zxing-cpp/core/src/libzint/telepen.c',
  'third_party/zxing-cpp/core/src/libzint/upcean.c',
  'third_party/zxing-cpp/core/src/libzint/vector.c',
  'third_party/zxing-cpp/core/src/libzueci/zueci.c',
];

const List<String> zxingCppDefines = <String>['ZXING_INTERNAL'];

const List<String> zxingCDefines = <String>[
  'ZINT_NO_PNG',
  'ZUECI_EMBED_NO_TO_ECI',
  'ZXING_INTERNAL',
];

// END GENERATED
