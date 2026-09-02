#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_zxing.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_zxing'
  s.version          = '3.0.0'
  s.summary          = 'A barcode scanner and generator natively in Flutter with Dart FFI based on ZXing.'
  s.description      = <<-DESC
A barcode scanner and generator natively in Flutter with Dart FFI based on ZXing.
                       DESC
  s.homepage         = 'https://github.com/khoren93/flutter_zxing'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Khoren Markosyan' => 'khoren.markosyan@gmail.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  # s.source           = { :git => 'https://git.code.sf.net/p/libzueci/code', :branch => 'master' }
  s.source_files = 'flutter_zxing/Sources/flutter_zxing/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.swift_version = '5.0'

  # zxing-cpp expects ZXING_INTERNAL while its own sources are being compiled.
  # ZXING_READERS / ZXING_WRITERS / ZXING_USE_ZINT and the ZXING_ENABLE_*
  # switches come from the Version.h that scripts/update_ios_macos_src.sh
  # generates, so they must not be repeated here. ZINT_NO_PNG matches the
  # COMPILE_OPTIONS the zxing CMake build sets on the bundled libzint sources.
  s.compiler_flags = ['-DZXING_INTERNAL', '-DZINT_NO_PNG']

  # zxing-cpp guards internal invariants with `assert`, which aborts a shipped
  # app when one trips. Compile them out for non-debug builds, matching the
  # CMake release build used on the other platforms.
  #
  # Pod::Specification only defines a writer for pod_target_xcconfig (no
  # reader), so the whole hash has to be assigned in one place.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'GCC_PREPROCESSOR_DEFINITIONS[config=Release]' => '$(inherited) NDEBUG=1',
    'GCC_PREPROCESSOR_DEFINITIONS[config=Profile]' => '$(inherited) NDEBUG=1',
  }

  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    # <zint.h>, included by CreateBarcode.cpp and WriteBarcode.cpp
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/flutter_zxing/Sources/flutter_zxing/src/zxing/libzint"',
  }

  s.library = 'c++'

end
