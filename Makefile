# Shortcuts for the tasks in this repo. Running `make` on its own lists them --
# publishing is never the default goal, so a bare `make` cannot release by
# accident.
#
# Publishing goes through scripts/publish.sh, which bumps the version in
# pubspec.yaml and both podspecs, refreshes the generated iOS/macOS sources and
# then runs `flutter pub publish`.

.DEFAULT_GOAL := help

# Which part of the version a publish target increments, and any extra flags
# passed straight through to scripts/publish.sh.
LEVEL ?= patch
ARGS  ?=

.PHONY: help publish publish-dry publish-minor publish-major sync test analyze

help:
	@echo "Publishing:"
	@echo "  make publish         Publish a patch release (3.0.0 -> 3.0.1)"
	@echo "  make publish-minor   Publish a minor release (3.0.0 -> 3.1.0)"
	@echo "  make publish-major   Publish a major release (3.0.0 -> 4.0.0)"
	@echo "  make publish-dry     Validate the package without publishing anything"
	@echo ""
	@echo "  ARGS=--commit        Commit the version bump before publishing, so the"
	@echo "                       release is in git history and pub.dev has no"
	@echo "                       uncommitted changes to warn about."
	@echo "  ARGS=--force         Skip pub.dev's interactive confirmation."
	@echo "  LEVEL=minor          Change the bump of any publish target."
	@echo ""
	@echo "  e.g. make publish ARGS=--commit"
	@echo ""
	@echo "Development:"
	@echo "  make sync            Regenerate the iOS/macOS sources from src/"
	@echo "  make test            Run the Dart tests"
	@echo "  make analyze         Run the analyzer"

publish:
	./scripts/publish.sh $(LEVEL) $(ARGS)

publish-dry:
	./scripts/publish.sh $(LEVEL) --dry-run $(ARGS)

publish-minor:
	@$(MAKE) --no-print-directory publish LEVEL=minor

publish-major:
	@$(MAKE) --no-print-directory publish LEVEL=major

sync:
	./scripts/update_ios_macos_src.sh

test:
	flutter test

analyze:
	flutter analyze
