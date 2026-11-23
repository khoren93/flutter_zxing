# Shortcuts for the tasks in this repo. Running `make` on its own lists them --
# publishing is never the default goal, so a bare `make` cannot release by
# accident.
#
# Publishing goes through scripts/publish.sh, which checks that the version is
# documented, builds the WebAssembly engine and then runs `flutter pub
# publish`. It does not change the version: bump pubspec.yaml alongside the
# CHANGELOG entry before releasing.

.DEFAULT_GOAL := help

# Extra flags passed straight through to scripts/publish.sh.
ARGS ?=

# Running the example (see `make help`).
APP ?= main
MODE ?= release
DEVICE ?=
TAB ?=
RUN_FLAGS = -t lib/$(APP).dart --$(MODE) $(if $(TAB),--dart-define=TAB=$(TAB),) $(ARGS)
# DEVICE, or the first connected device of a platform (android, ios; phones
# before tablets) from `flutter devices --machine`; empty if there is none.
first_device = $(or $(DEVICE),$(shell cd example && flutter devices --machine 2>/dev/null | \
	python3 -c "import json,sys; d=sorted((x for x in json.load(sys.stdin) if x['targetPlatform'].startswith('$(1)')), key=lambda x: 'iPad' in x['name'] or 'tablet' in x['name'].lower()); print(d[0]['id'] if d else '')"))

.PHONY: help publish publish-dry test analyze l10n sheets fixtures wasm sources \
	devices run run-android run-ios run-web run-macos run-windows run-linux \
	run-desktop web-engine diag perf diag-pull replay accuracy accuracy-causes \
	site site-build site-shots site-check

help:
	@echo "Publishing:"
	@echo "  make publish         Publish the version currently in pubspec.yaml"
	@echo "  make publish-dry     Validate the package without publishing anything"
	@echo ""
	@echo "  Bump the version in pubspec.yaml and add the matching"
	@echo "  '## <version>' section to CHANGELOG.md before publishing."
	@echo ""
	@echo "  ARGS=--force         Skip pub.dev's interactive confirmation."
	@echo "                       e.g. make publish ARGS=--force"
	@echo ""
	@echo "Development:"
	@echo "  make test            Run the Dart tests"
	@echo "  make analyze         Run the analyzer"
	@echo "  make l10n            Regenerate the scanner's texts from lib/l10n/*.arb"
	@echo "  make sheets          Draw every supported code into files of many sizes"
	@echo "                       and read them back (build/check_sheets/index.html)"
	@echo "  make accuracy        How far every code can be degraded before it stops"
	@echo "                       reading, next to zxing-cpp's own reader"
	@echo "                       (build/accuracy/report.md); ONLY=qrCode,ean13"
	@echo "  make accuracy-causes Try every failed condition again, changed one way at"
	@echo "                       a time, to prove why it fails (causes.json there)"
	@echo ""
	@echo "Running the example app (example/):"
	@echo "  make devices         List the connected devices"
	@echo "  make run             Run on DEVICE, or let flutter pick or ask"
	@echo "  make run-android     Run on the first connected Android device"
	@echo "  make run-ios         Run on the first connected iPhone or iPad"
	@echo "  make run-web         Run in Chrome (builds the WebAssembly engine first"
	@echo "                       if it is missing)"
	@echo "  make run-desktop     Run on this computer (macOS, Windows or Linux)"
	@echo "  make diag            The diagnostics page in a profile build: engine"
	@echo "                       settings on the live camera and their numbers"
	@echo "  make perf            The scanner's load on DEVICE against the budgets:"
	@echo "                       profile build, scenes A and B (asks to point the"
	@echo "                       camera) and M (memory leaks), about 25 min; run"
	@echo "                       before every release"
	@echo "  make diag-pull       Copy the recorded frames from DEVICE to build/recordings"
	@echo "  make replay          Read the recordings in build/recordings again here"
	@echo "                       FILE=<recording>  OPTIONS=tryInvert=true,minLineCount=1"
	@echo "  make run-macos | run-windows | run-linux"
	@echo ""
	@echo "  DEVICE=<id or name>  The device for 'make run', e.g. DEVICE=emulator-5554"
	@echo "  APP=main             The entry point in example/lib: main (the demo),"
	@echo "                       showcase, diagnostics, api_tour, legacy_3x"
	@echo "  MODE=debug           debug, profile or release (the camera is smoother"
	@echo "                       in release)"
	@echo "  TAB=create           Open the demo on a tab: scan, create, history"
	@echo "  ARGS=...             More flags for flutter run"
	@echo "                       e.g. make run-ios MODE=release TAB=create"
	@echo ""
	@echo "Documentation site (website/, published to GitHub Pages):"
	@echo "  make site            Serve it at http://localhost:5173/flutter_zxing/"
	@echo "                       (renders the template screenshots first if missing)"
	@echo "  make site-build      Build it into website/.vitepress/dist"
	@echo "  make site-shots      Render the template screenshots and codes it shows"
	@echo "  make site-check      Check that every Dart sample on it compiles"
	@echo ""
	@echo "Engine:"
	@echo "  make fixtures        Generate the test corpus from the zxing-cpp samples"
	@echo "                       (not committed; needed by the corpus tests)"
	@echo "  make wasm            Build the WebAssembly engine into assets/web/ (needed"
	@echo "                       to run the example on the web; not committed)"
	@echo "  make sources         Regenerate the source lists in hook/build.dart and the"
	@echo "                       GS1 table after"
	@echo "                       a zxing-cpp update"

publish:
	./scripts/publish.sh $(ARGS)

publish-dry:
	./scripts/publish.sh --dry-run $(ARGS)

test:
	flutter test

analyze:
	flutter analyze

# The scanner's texts: lib/l10n/*.arb -> lib/src/scanning/l10n/ (committed).
# CI runs it and fails on a diff: the generated code matches the ARB files.
# gen-l10n runs from build/l10n, a project with `generate: true` and the
# options of l10n.yaml: with that flag in pubspec.yaml, every `flutter pub
# get` here would regenerate the code without tool/patch_l10n.dart.
l10n:
	rm -rf build/l10n && mkdir -p build/l10n
	printf 'name: scanner_l10n\nenvironment:\n  sdk: ">=3.11.0 <4.0.0"\nflutter:\n  generate: true\n' > build/l10n/pubspec.yaml
	sed -E 's#^(arb-dir|output-dir): #\1: ../../#' l10n.yaml > build/l10n/l10n.yaml
	cd build/l10n && flutter gen-l10n
	cd tool && dart run patch_l10n.dart ../lib/src/scanning/l10n/scanner_localizations.dart
	dart format lib/src/scanning/l10n

# FLUTTER_ROOT gives the sheets Roboto from the Flutter SDK.
sheets:
	FLUTTER_ROOT="$(abspath $(dir $(realpath $(shell which flutter)))..)" \
		SHEETS=build/check_sheets \
		flutter test test/tool/check_sheets_test.dart
	-open build/check_sheets/index.html

ONLY ?=
accuracy:
	@./tool/build_zxing_reader.sh --if-stale
	ACCURACY=build/accuracy ACCURACY_ONLY="$(ONLY)" flutter test test/tool/accuracy_test.dart --reporter=expanded

accuracy-causes:
	ACCURACY_CAUSES=build/accuracy ACCURACY_ONLY="$(ONLY)" flutter test test/tool/accuracy_test.dart --plain-name "why conditions fail" --reporter=expanded

fixtures:
	cd tool && dart pub get && dart run make_fixtures.dart

wasm:
	./tool/build_wasm.sh

sources:
	cd tool && dart pub get && dart run gen_sources.dart && dart run gen_gs1_table.dart

devices:
	cd example && flutter devices

run:
	cd example && flutter run $(if $(DEVICE),-d "$(DEVICE)",) $(RUN_FLAGS)

run-android:
	@id="$(call first_device,android)"; \
	if [ -z "$$id" ]; then echo "No Android device connected (make devices)."; exit 1; fi; \
	cd example && flutter run -d "$$id" $(RUN_FLAGS)

run-ios:
	@id="$(call first_device,ios)"; \
	if [ -z "$$id" ]; then echo "No iPhone or iPad connected (make devices)."; exit 1; fi; \
	cd example && flutter run -d "$$id" $(RUN_FLAGS)

# The web example needs the WebAssembly engine, which is not committed.
web-engine:
	@[ -f assets/web/fzx.wasm ] || $(MAKE) wasm

run-web: web-engine
	cd example && flutter run -d chrome $(RUN_FLAGS)

# The numbers mean something in profile or release builds only.
diag:
	$(MAKE) run APP=diagnostics MODE=$(if $(filter command line,$(origin MODE)),$(MODE),profile)

# Budgets in tool/perf_run.py. SCENES: A (no code), B (a code), M (memory over
# SOAK=300 seconds and camera open/close cycles); SCENES=M runs the memory alone.
SCENES ?= ABM
perf:
	@[ -n "$(DEVICE)" ] || { echo "Set DEVICE=<id> (make devices)."; exit 1; }
	python3 tool/perf_run.py "$(DEVICE)" $(SCENES)

diag-pull:
	./tool/pull_recordings.sh "$(DEVICE)"

FILE ?= build/recordings
OPTIONS ?=
replay:
	REPLAY="$(FILE)" REPLAY_OPTIONS="$(OPTIONS)" flutter test test/tool/replay_test.dart --reporter=expanded

run-macos:
	cd example && flutter run -d macos $(RUN_FLAGS)

run-windows:
	cd example && flutter run -d windows $(RUN_FLAGS)

run-linux:
	cd example && flutter run -d linux $(RUN_FLAGS)

run-desktop:
	@case "$$(uname -s)" in \
	  Darwin) $(MAKE) run-macos ;; \
	  Linux) $(MAKE) run-linux ;; \
	  MINGW*|MSYS*|CYGWIN*) $(MAKE) run-windows ;; \
	  *) echo "Unknown desktop: $$(uname -s)"; exit 1 ;; \
	esac

# The documentation site. Its screenshots are rendered from the templates, not
# committed; its Dart samples are compiled against the package.
SITE_SHOTS = website/public/shots
SITE_CODES = website/public/codes

site-shots:
	FLUTTER_ROOT="$(abspath $(dir $(realpath $(shell which flutter)))..)" \
		SHOTS="$(CURDIR)/$(SITE_SHOTS)" \
		SITE_IMAGES="$(CURDIR)/$(SITE_CODES)" \
		flutter test test/tool/scanner_shots_test.dart test/tool/site_images_test.dart

website/node_modules: website/package-lock.json
	cd website && npm ci
	@touch $@

site: website/node_modules
	@[ -d $(SITE_SHOTS) ] || $(MAKE) site-shots
	cd website && npm run dev

site-build: website/node_modules site-shots
	cd website && npm run build

site-check:
	cd tool && dart pub get && dart run check_site_snippets.dart
