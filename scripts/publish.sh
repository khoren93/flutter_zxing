#!/usr/bin/env bash

set -euo pipefail

# Publish flutter_zxing to pub.dev.
#
#   ./scripts/publish.sh [--dry-run] [--force]
#
# The version is deliberately not bumped here. Releasing needs a CHANGELOG entry
# written for the new version anyway, and whoever writes it sets the version at
# the same time. What this script does is check that the version is
# documented, build the WebAssembly engine, and publish.
#
# The build is the step that must not be forgotten: the WebAssembly engine in
# assets/web/ is git-ignored (built by tool/build_wasm.sh), and without it the
# package does not work on the web. The native engine needs nothing here: the
# build hook compiles it in every app.

usage() {
    cat >&2 <<'USAGE'
Usage: scripts/publish.sh [--dry-run] [--force]

  --dry-run   Validate the package without publishing it
  --force     Skip pub.dev's interactive confirmation

Before running, bump `version:` in pubspec.yaml and add the matching
`## <version>` section to CHANGELOG.md.
USAGE
    exit 2
}

DRY_RUN=0
FORCE=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --force)   FORCE=1 ;;
        -h|--help) usage ;;
        *) echo "error: unknown argument '$arg'" >&2; usage ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

PUBSPEC="pubspec.yaml"
CHANGELOG="CHANGELOG.md"

# `pub publish` uploads what is on disk, not what is committed -- and that
# includes untracked files that no ignore rule covers.
if [ -n "$(git status --porcelain)" ]; then
    echo "error: the working tree is not clean." >&2
    echo "       Commit, stash or ignore these first -- publishing uploads what is" >&2
    echo "       on disk, including untracked files." >&2
    git status --short >&2
    exit 1
fi

# --- the version has to be documented -----------------------------------------

VERSION="$(sed -n 's/^version:[[:space:]]*\(.*\)$/\1/p' "$PUBSPEC" | head -1)"
[ -n "$VERSION" ] || { echo "error: no 'version:' line found in $PUBSPEC" >&2; exit 1; }

# pub.dev flags a release whose version is missing from the changelog.
ESCAPED="${VERSION//./\\.}"
if ! grep -qE "^##[[:space:]]+v?${ESCAPED}([[:space:]]|$)" "$CHANGELOG"; then
    echo "error: $CHANGELOG has no '## $VERSION' section." >&2
    echo "       Add the release notes for $VERSION first, then re-run." >&2
    exit 1
fi

echo "==> Publishing $VERSION"
echo "    $CHANGELOG documents it"

# --- build the WebAssembly engine --------------------------------------------

# Skipped when assets/web/ was already built from the current sources.
echo "==> Building the WebAssembly engine"
WASM_LOG="$(mktemp)"
if ! ./tool/build_wasm.sh > "$WASM_LOG" 2>&1; then
    echo "error: tool/build_wasm.sh failed:" >&2
    tail -30 "$WASM_LOG" >&2
    rm -f "$WASM_LOG"
    exit 1
fi
rm -f "$WASM_LOG"
echo "    done ($(head -1 assets/web/fzx.js | sed -E 's|// (fzx-sources: [0-9a-f]+).*|\1|'))"

# --- publish -----------------------------------------------------------------

PUBLISH_ARGS=()
[ "$DRY_RUN" -eq 1 ] && PUBLISH_ARGS+=(--dry-run)
[ "$FORCE" -eq 1 ] && PUBLISH_ARGS+=(--force)

echo ""
echo "==> flutter pub publish ${PUBLISH_ARGS[*]:-}"
# `pub publish` exits non-zero on warnings too, so capture the status rather
# than letting `set -e` abort on what may only be a hint.
set +e
flutter pub publish ${PUBLISH_ARGS[@]+"${PUBLISH_ARGS[@]}"}
PUB_STATUS=$?
set -e

if [ "$PUB_STATUS" -ne 0 ]; then
    echo "" >&2
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Dry run finished with warnings (exit $PUB_STATUS). Nothing was published." >&2
    else
        echo "Publishing failed (exit $PUB_STATUS)." >&2
    fi
    exit "$PUB_STATUS"
fi

echo ""
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Dry run passed. Re-run without --dry-run to publish $VERSION."
else
    # Pushed by name: `git push --follow-tags` skips lightweight tags.
    echo "Published $VERSION. Tag it:"
    echo "  git tag -a v$VERSION -m \"v$VERSION\" && git push origin v$VERSION"
fi
