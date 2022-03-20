#import "FlutterZxingPlugin.h"
#if __has_include(<flutter_zxing/flutter_zxing-Swift.h>)
#import <flutter_zxing/flutter_zxing-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_zxing-Swift.h"
#endif

@implementation FlutterZxingPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterZxingPlugin registerWithRegistrar:registrar];
}
@end
