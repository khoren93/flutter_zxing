# Shortcuts for the tasks in this repo. Running `make` on its own lists them --
# publishing is never the default goal, so a bare `make` cannot release by
# accident.
#
# Publishing goes through scripts/publish.sh, which checks that the version is
# consistent and documented, refreshes the generated iOS/macOS sources and then
# runs `flutter pub publish`. It does not change the version: bump pubspec.yaml
# and both podspecs alongside the CHANGELOG entry before releasing.

.DEFAULT_GOAL := help

# Extra flags passed straight through to scripts/publish.sh.
ARGS ?=

.PHONY: help publish publish-dry sync test analyze

help:
	@echo "Publishing:"
	@echo "  make publish         Publish the version currently in pubspec.yaml"
	@echo "  make publish-dry     Validate the package without publishing anything"
	@echo ""
	@echo "  Bump the version in pubspec.yaml and both podspecs, and add the"
	@echo "  matching '## <version>' section to CHANGELOG.md, before publishing."
	@echo ""
	@echo "  ARGS=--force         Skip pub.dev's interactive confirmation."
	@echo "                       e.g. make publish ARGS=--force"
	@echo ""
	@echo "Development:"
	@echo "  make sync            Regenerate the iOS/macOS sources from src/"
	@echo "  make test            Run the Dart tests"
	@echo "  make analyze         Run the analyzer"

publish:
	./scripts/publish.sh $(ARGS)

publish-dry:
	./scripts/publish.sh --dry-run $(ARGS)

sync:
	./scripts/update_ios_macos_src.sh

test:
	flutter test

analyze:
	flutter analyze
