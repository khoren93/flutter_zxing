# Contributing to flutter_zxing

Thank you for helping. Bug reports, ideas, documentation fixes and pull
requests are all welcome.

## Reporting a bug

[Open an issue](https://github.com/khoren93/flutter_zxing/issues/new/choose)
with the bug template. What helps most:

- the flutter_zxing version, `flutter --version`, the platform and device;
- a short piece of code that shows the problem;
- for a code that does not read: **the image itself**, or a photo of it.
  Most reading problems can only be reproduced with the picture.

For a question about using the package, open a
[discussion](https://github.com/khoren93/flutter_zxing/discussions) instead.

## Getting the code

zxing-cpp is a git submodule, so clone recursively:

```bash
git clone --recursive https://github.com/khoren93/flutter_zxing.git
cd flutter_zxing
flutter pub get
(cd example && flutter pub get)
```

If you already cloned without `--recursive`: `git submodule update --init --recursive`.

The package's build hook (`hook/build.dart`) compiles zxing-cpp for Android,
iOS, macOS, Linux and Windows: nothing else to install. The first build takes
a minute or two; later builds are cached.

The web engine is WebAssembly built with a pinned Emscripten and is not
committed: `make wasm` builds it into `assets/web/` (it installs Emscripten
into `~/.cache/flutter_zxing/emsdk` the first time).

## The repository

| Path | What |
|---|---|
| `lib/src/` | The Dart package, in layers (below): `barcode/`, `engine/`, `reading/`, `writing/` (core), `content/`, `rendering/`, `scanning/`; `legacy/` is the deprecated 3.x API |
| `native/` | `fzx`, the small C API over zxing-cpp used by every platform |
| `hook/` | The build hook that compiles the native engine |
| `assets/web/` | The Web Worker; the built WebAssembly lands here |
| `third_party/` | zxing-cpp (submodule) and stb |
| `example/` | The demo app (`lib/main.dart`) and developer screens |
| `tool/` | Engine tools: WebAssembly build, source list, test corpus, browser tests |
| `benchmark/` | Scan benchmarks and their raw data |
| `doc/` | Guides |

### Layers

flutter_zxing is zxing-cpp for Flutter first. The core works without
anything else, and every other feature is a layer on top of it.
Dependencies only go down; `test/architecture_test.dart` checks the imports.

| Layer | Folders in `lib/src/` | What belongs there | May import |
|---|---|---|---|
| core | `barcode/`, `engine/`, `reading/`, `writing/`, `errors.dart` | what zxing-cpp does: reading, writing, the module matrix, plain SVG/PNG/raster | the core; Flutter only for `dart:ui` types (`foundation`, `painting`), no widgets |
| content | `content/` | payloads parsed and built by their standards (Wi-Fi, vCard, GS1…) | core |
| rendering | `rendering/` | `BarcodeView`, `BarcodeStyle`, styled export | core |
| scanner | `scanning/` | camera, controller, templates, UI | core, content, rendering |
| legacy | `legacy/` | the 3.x API over the core | core |

Where a new feature goes:

- **Core:** only what zxing-cpp has, close to its own API. No interpreting of
  payloads, no UI.
- **A layer in the package:** based on a standard, or useful to many apps.
- **The example:** only code that shows the API. Logic that users of the
  package would need belongs in the package.

Each layer has its entry point (`lib/core.dart`, `content.dart`,
`rendering.dart`, `scanner.dart`), which exports the entry points of the
layers it builds on; `lib/flutter_zxing.dart` exports everything.

## Running the demo

`make` lists every task. The most used:

```bash
make run-ios            # first connected iPhone or iPad
make run-android        # first connected Android device
make run-web            # Chrome; builds the WebAssembly engine if missing
make run-desktop        # this computer
make run-ios APP=showcase           # the scanner templates
make run-android APP=scanner_dev    # FPS, engine times, the benchmark
```

The camera is much smoother in release builds, the default of `make run-*`
(`MODE=debug` for a debug build).

## Tests

```bash
flutter test --exclude-tags native    # unit and widget tests, no engine
make fixtures                         # the test corpus, once (needs dwebp: brew install webp)
flutter test --tags native            # the real engine on this computer
```

Integration tests run inside the example app on a device:

```bash
cd example
flutter test integration_test                      # Android, iOS
flutter test integration_test/ffi_test.dart -d macos   # desktop: one file at a time
```

A desktop app cannot be started twice in one `flutter test` run;
`scripts/run_integration_tests.sh <device>` runs every file in turn, as CI does.

The web engine is tested in headless Chrome: see the `web` job in
`.github/workflows/main.yml` for the commands.

## Pull requests

- One change per pull request, with a test where it can have one.
- `dart format .` and `flutter analyze` must be clean; CI checks both.
- Public API needs dartdoc. Do not change the public API without opening an
  issue first: after a release it can only change in a new major version.
- Add a line to `CHANGELOG.md` under the unreleased version for anything a
  user of the package would notice.
- Do not commit generated files: the WebAssembly engine, the test corpus,
  screenshots or test images. They are built from the sources.

## Updating zxing-cpp

```bash
cd third_party/zxing-cpp && git fetch && git checkout <tag> && cd -
make sources      # regenerate the source lists in hook/build.dart and the GS1 table
make fixtures     # regenerate the corpus, then run the tests
```

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE) of this project.
