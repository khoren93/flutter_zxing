#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_zxing.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_zxing'
  s.version          = '2.4.0'
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

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # zxing-cpp guards internal invariants with `assert`, which aborts a shipped
  # app when one trips. Compile them out for non-debug builds, matching the
  # CMake release build used on the other platforms.
  s.pod_target_xcconfig = s.pod_target_xcconfig.merge({
    'GCC_PREPROCESSOR_DEFINITIONS[config=Release]' => '$(inherited) NDEBUG=1',
    'GCC_PREPROCESSOR_DEFINITIONS[config=Profile]' => '$(inherited) NDEBUG=1',
  })

  s.xcconfig = { 
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
  }

  # including C++ library
  s.library = 'c++'

  # # Set as a static lib
  # s.static_framework = true

  # module_map is needed so this module can be used as a framework
  s.module_map = 'flutter_zxing.modulemap'
end
