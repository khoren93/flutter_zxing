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
  s.source           = { :path => '.' }
  s.source_files = 'flutter_zxing/Sources/flutter_zxing/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

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
    # Flutter.framework does not contain a i386 slice.
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'GCC_PREPROCESSOR_DEFINITIONS[config=Release]' => '$(inherited) NDEBUG=1',
    'GCC_PREPROCESSOR_DEFINITIONS[config=Profile]' => '$(inherited) NDEBUG=1',
  }

  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    # <zint.h>, included by CreateBarcode.cpp and WriteBarcode.cpp
    'HEADER_SEARCH_PATHS' => '$(inherited) "$(PODS_TARGET_SRCROOT)/flutter_zxing/Sources/flutter_zxing/src/zxing/libzint"',
  }

  # including C++ library
  s.library = 'c++'

  # # Set as a static lib
  # s.static_framework = true

  # module_map is needed so this module can be used as a framework
  s.module_map = 'flutter_zxing.modulemap'
end
