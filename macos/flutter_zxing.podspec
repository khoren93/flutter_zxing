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

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin. Podspec does not support relative
  # paths, so Classes contains a forwarder C file that relatively imports
  # `../src/*` so that the C sources can be shared among all target platforms.
  s.source           = { :path => '.' }
  # s.source           = { :git => 'https://git.code.sf.net/p/libzueci/code', :branch => 'master' }
  s.source_files = 'flutter_zxing/Sources/flutter_zxing/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  s.xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
  }

  s.library = 'c++'

end
