# ZXScanner

<p align="center">
  <img src="https://user-images.githubusercontent.com/11523360/178162663-57ec28ac-7075-43ab-ac31-35058298c73e.png" alt="ZXScanner logo" height="100" >
</p>

ZXScanner is a free QR code and barcode scanner app for Android and iOS. It is built using Flutter and the [flutter_zxing](https://github.com/khoren93/flutter_zxing) plugin.

> **Note:** ZXScanner is not currently published on the App Store or Google Play.
> Build it from source to try it out.

## Running the app

From the repository root:

```bash
melos bootstrap
cd zxscanner
flutter run
```

On iOS and macOS, run `./scripts/update_ios_macos_src.sh` from the repository
root first, so the native zxing-cpp sources are in place.

## Demo Screenshots

<pre>
<img alt="01_scanner_screen" src="https://user-images.githubusercontent.com/11523360/219614206-277d4931-9cc7-4130-9c89-72fd220981b1.png" width="240">&nbsp; <img alt="02_creator_screen" src="https://user-images.githubusercontent.com/11523360/219614226-1877e7e0-9166-4961-935b-513f515c6d52.png" width="240">&nbsp;
</pre>

All screenshots for iOS were generated using [Fastlane Snap](https://docs.fastlane.tools/actions/snapshot/). To generate your own, run the command:

```bash
cd zxscanner/ios
bundle exec fastlane screenshots
```
