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

.PHONY: help publish publish-dry test analyze sheets fixtures wasm sources \
	devices run run-android run-ios run-web run-macos run-windows run-linux \
	run-desktop web-engine diag diag-pull replay accuracy accuracy-causes

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

# FLUTTER_ROOT gives the sheets Roboto from the Flutter SDK.
sheets:
	FLUTTER_ROOT="$(abspath $(dir $(realpath $(shell which flutter)))..)" \
		SHEETS=build/check_sheets \
		flutter test test/tool/check_sheets_test.dart
	-open build/check_sheets/index.html

ONLY ?=
accuracy:
	@[ -x build/zxing_reader/ZXingReader ] || ./tool/build_zxing_reader.sh
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
