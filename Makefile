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

.PHONY: help publish publish-dry test analyze fixtures wasm sources

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
	@echo ""
	@echo "Engine:"
	@echo "  make fixtures        Generate the test corpus from the zxing-cpp samples"
	@echo "                       (not committed; needed by the corpus tests)"
	@echo "  make wasm            Build the WebAssembly engine into assets/web/ (needed"
	@echo "                       to run the example on the web; not committed)"
	@echo "  make sources         Regenerate hook/sources.g.dart after a zxing-cpp update"

publish:
	./scripts/publish.sh $(ARGS)

publish-dry:
	./scripts/publish.sh --dry-run $(ARGS)

test:
	flutter test

analyze:
	flutter analyze

fixtures:
	cd tool && dart pub get && dart run make_fixtures.dart

wasm:
	./tool/build_wasm.sh

sources:
	cd tool && dart pub get && dart run gen_sources.dart
