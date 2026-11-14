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
// The source list and defines come from zxing-cpp's CMake build, see
// tool/gen_sources.dart.
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import 'sources.g.dart';

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
